import os
import subprocess
import logging
from pathlib import Path
import pandas as pd
import sqlalchemy
from sqlalchemy import create_engine
from dotenv import load_dotenv
from tqdm import tqdm
import time
import numpy as np

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    handlers=[logging.FileHandler("logs/etl.log"), logging.StreamHandler()],
)
logger = logging.getLogger(__name__)


class OlistDataLoader:
    """Loads Olist E-Commerce dataset into Supabase (PostgreSQL) database."""

    def __init__(self):
        """Initialize the data loader."""
        print("\n=== Initializing Olist Data Loader ===")

        # Load environment variables
        load_dotenv(".env.dev")  # Explicitly load from .env.dev
        print("✓ Environment variables loaded")

        # Validate Supabase configuration
        required_env_vars = {
            "SUPABASE_URL": os.getenv("SUPABASE_URL"),
            "SUPABASE_SERVICE_KEY": os.getenv("SUPABASE_SERVICE_KEY"),
            "DB_SCHEMA": os.getenv("DB_SCHEMA"),
            "DB_HOST": os.getenv("DB_HOST"),
            "DB_PORT": os.getenv("DB_PORT"),
            "DB_NAME": os.getenv("DB_NAME"),
            "DB_USER": os.getenv("DB_USER"),
            "DB_PASSWORD": os.getenv("DB_PASSWORD"),
        }

        # Check for missing environment variables
        missing_vars = [key for key, value in required_env_vars.items() if not value]
        if missing_vars:
            print("\n❌ Missing required environment variables:")
            for var in missing_vars:
                print(f"   - {var}")
            print("\nPlease add these variables to your .env.dev file.")
            raise EnvironmentError(
                f"Missing required environment variables: {', '.join(missing_vars)}"
            )

        # Database configuration for Supabase
        self.db_config = {
            "host": required_env_vars["DB_HOST"],
            "port": int(required_env_vars["DB_PORT"]),
            "database": required_env_vars["DB_NAME"],
            "user": required_env_vars["DB_USER"],
            "password": required_env_vars["DB_PASSWORD"],
        }
        self.schema = required_env_vars["DB_SCHEMA"]
        self.supabase_url = required_env_vars["SUPABASE_URL"]
        self.supabase_key = required_env_vars["SUPABASE_SERVICE_KEY"]
        self.engine = None
        self.conn = None
        print("✓ Supabase configuration initialized")

        # Dataset configuration
        self.dataset_path = Path("src/data/raw")
        self.kaggle_dataset = "olistbr/brazilian-ecommerce"
        print("✓ Dataset configuration initialized")
        print("\nReady to start ETL process...")

    def download_dataset(self):
        """Download the Olist dataset from Kaggle."""
        try:
            print("\n=== Downloading Olist Dataset ===")
            logger.info(f"Starting download of dataset: {self.kaggle_dataset}")

            # Create directory if it doesn't exist
            os.makedirs(self.dataset_path, exist_ok=True)
            print(f"✓ Created directory: {self.dataset_path}")

            # Check if Kaggle credentials exist in environment variables
            kaggle_username = os.getenv("KAGGLE_USERNAME")
            kaggle_key = os.getenv("KAGGLE_KEY")

            if not kaggle_username or not kaggle_key:
                print("❌ Kaggle API credentials not found in environment variables!")
                logger.error(
                    "Kaggle API credentials not found in environment variables."
                )
                print("\nTo set up Kaggle credentials:")
                print("1. Go to https://www.kaggle.com/account")
                print("2. Click on 'Create New API Token'")
                print("3. Add these lines to your .env.dev file:")
                print("   KAGGLE_USERNAME=your_kaggle_username")
                print("   KAGGLE_KEY=your_kaggle_api_key")
                return False

            # Set Kaggle credentials as environment variables for the current process
            os.environ["KAGGLE_USERNAME"] = kaggle_username
            os.environ["KAGGLE_KEY"] = kaggle_key

            print("✓ Kaggle credentials verified")
            print("\nDownloading dataset (this may take a few minutes)...")

            # Download the dataset using the Kaggle API
            result = subprocess.run(
                [
                    "kaggle",
                    "datasets",
                    "download",
                    self.kaggle_dataset,
                    "--path",
                    str(self.dataset_path),
                    "--unzip",
                ],
                check=True,
                capture_output=True,
                text=True,
            )

            print("✓ Dataset downloaded and extracted successfully")
            print(f"✓ Files saved to: {self.dataset_path}")

            # List downloaded files
            files = list(self.dataset_path.glob("*.csv"))
            print("\nDownloaded files:")
            for file in files:
                print(f"  - {file.name}")

            logger.info("Dataset downloaded and extracted successfully.")
            return True

        except subprocess.CalledProcessError as e:
            print(f"\n❌ Error downloading dataset: {e.stderr}")
            logger.error(f"Error downloading dataset: {e}")
            return False
        except Exception as e:
            print(f"\n❌ Unexpected error: {str(e)}")
            logger.error(f"Unexpected error: {e}")
            return False

    def connect_to_db(self):
        """Establish connection to Supabase database."""
        try:
            print("\n=== Connecting to Supabase Database ===")
            print("Attempting to connect to Supabase...")
            print(f"  URL: {self.supabase_url}")
            print(f"  Host: {self.db_config['host']}")
            print(f"  Port: {self.db_config['port']}")
            print(f"  Database: {self.db_config['database']}")
            print(f"  User: {self.db_config['user']}")
            print(f"  Schema: {self.schema}")

            # Create connection string with database credentials
            connection_string = (
                f"postgresql://{self.db_config['user']}:{self.db_config['password']}"
                f"@{self.db_config['host']}:{self.db_config['port']}/{self.db_config['database']}"
            )

            self.engine = create_engine(connection_string)

            # Test the connection
            print("Testing connection...", end="", flush=True)
            self.conn = self.engine.connect()
            print(" ✓")

            # Create schema if it doesn't exist
            print("Setting up schema...", end="", flush=True)
            with self.engine.begin() as connection:
                connection.execute(
                    sqlalchemy.text(f"CREATE SCHEMA IF NOT EXISTS {self.schema}")
                )
            print(" ✓")

            print(f"✓ Successfully connected to Supabase")
            print(f"✓ Schema '{self.schema}' is ready")
            logger.info(
                f"Successfully connected to Supabase and ensured schema {self.schema} exists"
            )
            return True
        except Exception as e:
            print(f"\n❌ Supabase connection failed!")
            print(f"Error details: {str(e)}")
            print("\nPlease verify your Supabase configuration in .env.dev:")
            print("1. Make sure SUPABASE_SERVICE_KEY is correct")
            print("2. Verify the Supabase server is running")
            print("3. Check if the port and host are correct")
            print("4. Ensure the database exists")
            logger.error(f"Error connecting to Supabase: {e}")
            return False

    def load_csv_to_table(self, csv_path, table_name, if_exists="replace"):
        """
        Load CSV data into a Supabase table.

        Args:
            csv_path: Path to the CSV file
            table_name: Name of the target table
            if_exists: Strategy if table exists ('replace', 'append')
        """
        try:
            print(f"\nLoading {table_name} table:")
            logger.info(
                f"Loading data from {csv_path} to table {self.schema}.{table_name}"
            )

            # Read CSV file
            print("  ◦ Reading CSV file...", end="", flush=True)
            df = pd.read_csv(csv_path)
            print(" ✓")

            # Clean column names
            print("  ◦ Cleaning column names...", end="", flush=True)
            df.columns = [col.lower().replace(" ", "_") for col in df.columns]
            print(" ✓")

            # Load data with progress bar
            print(f"  ◦ Loading {len(df):,} rows into database...")
            chunks = np.array_split(df, max(1, len(df) // 1000))
            with tqdm(total=len(chunks), desc="    Progress", ncols=80) as pbar:
                for chunk in chunks:
                    chunk.to_sql(
                        name=table_name,
                        con=self.engine,
                        schema=self.schema,
                        if_exists="append" if chunk.index[0] > 0 else if_exists,
                        index=False,
                    )
                    pbar.update(1)

            # Enable basic table security
            print("  ◦ Setting up table permissions...", end="", flush=True)
            with self.engine.begin() as connection:
                # Grant usage on schema
                connection.execute(
                    sqlalchemy.text(
                        f"GRANT USAGE ON SCHEMA {self.schema} TO {self.db_config['user']}"
                    )
                )

                # Grant basic permissions on table
                connection.execute(
                    sqlalchemy.text(
                        f"GRANT ALL PRIVILEGES ON TABLE {self.schema}.{table_name} TO {self.db_config['user']}"
                    )
                )
            print(" ✓")

            print(f"✓ Successfully loaded {table_name} table")
            logger.info(
                f"Successfully loaded {len(df)} rows into {self.schema}.{table_name}"
            )
            return True
        except Exception as e:
            print(f"\n❌ Error loading {table_name}: {str(e)}")
            logger.error(f"Error loading data: {e}")
            return False

    def load_all_datasets(self):
        """Load all Olist datasets into the database."""
        try:
            print("\n=== Loading Datasets into Database ===")

            # List of CSV files and their corresponding table names
            datasets = [
                {"file": "olist_customers_dataset.csv", "table": "customers"},
                {"file": "olist_geolocation_dataset.csv", "table": "geolocation"},
                {"file": "olist_order_items_dataset.csv", "table": "order_items"},
                {"file": "olist_order_payments_dataset.csv", "table": "order_payments"},
                {"file": "olist_order_reviews_dataset.csv", "table": "order_reviews"},
                {"file": "olist_orders_dataset.csv", "table": "orders"},
                {"file": "olist_products_dataset.csv", "table": "products"},
                {"file": "olist_sellers_dataset.csv", "table": "sellers"},
                {
                    "file": "product_category_name_translation.csv",
                    "table": "product_categories",
                },
            ]

            total_datasets = len(datasets)
            print(f"Found {total_datasets} datasets to load")

            for i, dataset in enumerate(datasets, 1):
                print(f"\n[{i}/{total_datasets}] Processing {dataset['table']}")
                csv_path = self.dataset_path / dataset["file"]
                if csv_path.exists():
                    if not self.load_csv_to_table(csv_path, dataset["table"]):
                        return False
                else:
                    print(f"❌ File not found: {dataset['file']}")
                    logger.warning(
                        f"File {csv_path} not found. Skipping table {dataset['table']}."
                    )

            print("\n✓ All datasets loaded successfully")
            logger.info("All datasets loaded successfully.")
            return True
        except Exception as e:
            print(f"\n❌ Error loading datasets: {str(e)}")
            logger.error(f"Error loading datasets: {e}")
            return False

    def close_connection(self):
        """Close database connection."""
        if self.conn:
            self.conn.close()
        if self.engine:
            self.engine.dispose()
        print("\n✓ Database connection closed")
        logger.info("Database connection closed")

    def run_etl(self):
        """Run the complete ETL process."""
        try:
            print("\n=== Starting ETL Process ===")

            # Ensure logs directory exists
            os.makedirs("logs", exist_ok=True)
            print("✓ Log directory created")

            # Download the dataset
            if not self.download_dataset():
                return False

            # Connect to the database
            if not self.connect_to_db():
                return False

            # Load all datasets
            success = self.load_all_datasets()

            # Close connection
            self.close_connection()

            return success
        except Exception as e:
            print(f"\n❌ ETL process failed: {str(e)}")
            logger.error(f"ETL process failed: {e}")
            return False


if __name__ == "__main__":
    start_time = time.time()
    loader = OlistDataLoader()
    success = loader.run_etl()
    end_time = time.time()

    if success:
        duration = end_time - start_time
        print("\n=== ETL Process Complete ===")
        print(f"✓ Total time: {duration:.2f} seconds")
        print("✓ All data has been successfully loaded into the database")
        logger.info("ETL process completed successfully.")
    else:
        print("\n=== ETL Process Failed ===")
        print("❌ Please check the logs for more details")
        logger.error("ETL process failed.")
