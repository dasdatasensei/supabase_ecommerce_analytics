import unittest
from datetime import datetime
import os
import sys
from pathlib import Path

# Add the src directory to the Python path
sys.path.append(str(Path(__file__).parent.parent))

# This test assumes the DAG is defined in src/dags/ecommerce_analytics_pipeline.py
from airflow.models import DagBag


class TestEcommerceAnalyticsPipeline(unittest.TestCase):
    """Integration tests for the ecommerce analytics pipeline DAG."""

    def setUp(self):
        """Set up the test environment."""
        self.dagbag = DagBag(dag_folder="src/dags", include_examples=False)

    def test_dag_loaded(self):
        """Test that the DAG was loaded correctly."""
        dag_id = "ecommerce_analytics_pipeline"
        self.assertIn(dag_id, self.dagbag.dags)
        self.assertEqual(
            len(self.dagbag.import_errors),
            0,
            f"DAG import errors: {self.dagbag.import_errors}",
        )

    def test_dag_structure(self):
        """Test that the DAG has the expected structure."""
        dag_id = "ecommerce_analytics_pipeline"
        dag = self.dagbag.get_dag(dag_id)

        # Test general properties
        self.assertEqual(dag.schedule_interval, "0 5 * * *")  # Daily at 5 AM
        self.assertEqual(dag.catchup, False)

        # Test that the DAG has the expected number of tasks
        # Adjust this number based on your actual DAG
        self.assertGreaterEqual(len(dag.tasks), 3)

        # Test that extract task exists
        self.assertIsNotNone(
            next((t for t in dag.tasks if "extract" in t.task_id), None)
        )

        # Test that dbt task exists
        self.assertIsNotNone(next((t for t in dag.tasks if "dbt" in t.task_id), None))

        # Test for presence of metabase refresh task
        self.assertIsNotNone(
            next((t for t in dag.tasks if "refresh" in t.task_id), None)
        )

    def test_task_dependencies(self):
        """Test that task dependencies are set correctly."""
        dag_id = "ecommerce_analytics_pipeline"
        dag = self.dagbag.get_dag(dag_id)

        # Get extract task
        extract_task = next((t for t in dag.tasks if "extract" in t.task_id), None)

        # Get dbt task
        dbt_task = next((t for t in dag.tasks if "dbt_run" in t.task_id), None)

        # Check dependency: extract should be upstream of dbt
        if extract_task and dbt_task:
            self.assertIn(
                extract_task.task_id, [t.task_id for t in dbt_task.upstream_list]
            )


if __name__ == "__main__":
    unittest.main()
