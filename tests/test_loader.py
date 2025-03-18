import unittest
from unittest.mock import patch, MagicMock
import os
import sys
import logging
from pathlib import Path

# Add the src directory to the Python path
sys.path.append(str(Path(__file__).parent.parent))

from src.etl.loader import SupabaseDataLoader


class TestSupabaseDataLoader(unittest.TestCase):
    """Unit tests for the SupabaseDataLoader class."""

    @patch("src.etl.loader.create_engine")
    def setUp(self, mock_create_engine):
        """Set up test environment."""
        self.mock_engine = MagicMock()
        self.mock_conn = MagicMock()
        mock_create_engine.return_value = self.mock_engine
        self.mock_engine.connect.return_value = self.mock_conn

        self.test_config = {
            "host": "localhost",
            "port": 5432,
            "user": "test_user",
            "password": "test_password",
            "database": "test_db",
        }

        self.loader = SupabaseDataLoader(self.test_config)
        self.loader.connect_to_db()

    def test_connect_to_db(self):
        """Test database connection is established correctly."""
        from sqlalchemy.engine import create_engine
        from src.etl.loader import create_engine as loader_create_engine

        # Verify connection was established with correct parameters
        self.assertEqual(self.loader.engine, self.mock_engine)
        self.assertEqual(self.loader.conn, self.mock_conn)

    @patch("pandas.read_csv")
    def test_load_csv_data(self, mock_read_csv):
        """Test loading data from CSV file."""
        # Mock the pandas DataFrame
        mock_df = MagicMock()
        mock_read_csv.return_value = mock_df
        mock_df.to_sql = MagicMock()

        # Call the method
        self.loader.load_csv_data("test.csv", "test_table")

        # Verify the method was called with correct parameters
        mock_read_csv.assert_called_once_with("test.csv")
        mock_df.to_sql.assert_called_once()

    def test_close_connection(self):
        """Test closing the database connection."""
        self.loader.close_connection()
        self.mock_conn.close.assert_called_once()


if __name__ == "__main__":
    unittest.main()
