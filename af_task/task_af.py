import os
from airflow import DAG
from datetime import datetime
from airflow.contrib.operators import bigquery_operator
from airflow.contrib.operators.bigquery_to_gcs import BigQueryToCloudStorageOperator

DEFAULT_DAG_ARGS = {
    "depends_on_past": False,
    "email_on_failure": False,
}

with DAG(
        "airflow_task_job_0010",
        schedule_interval="0 * * * *",
        default_args={
            'start_date': datetime(2023, 1, 16),
            **DEFAULT_DAG_ARGS,
        },
) as dag:
    PROJECT_ID = os.getenv('GCP_PROJECT')
    ENV = PROJECT_ID[-3:]
    CORE_CATALOGUE_ENV = "stg" if ENV == "dev" else ENV

    AF_TASK_INPUT_DATASET_NAME = f"{PROJECT_ID}.task_cf_dataset"
    AF_TASK_INPUT_TABLE = f"{AF_TASK_INPUT_DATASET_NAME}.task_two_table"

    AF_TASK_OUTPUT_DATASET_NAME = f"{PROJECT_ID}.airflow_output_dataset"
    AF_TASK_OUTPUT_TABLE = f"{AF_TASK_OUTPUT_DATASET_NAME}.airflow_table"

    gcs_bucket_name = f"gs://{PROJECT_ID}/"
    gcs_file_name = f"af_task{datetime.utcnow()}.json"
    gcs_file_full_name = f"{gcs_bucket_name}{gcs_file_name}"

    # BigQuery Task
    airflow_BQ_task = bigquery_operator.BigQueryOperator(
        dag=dag,
        task_id="af_task_BQ_job",
        sql="sql/af_task_query.sql",
        use_legacy_sql=False,
        write_disposition="WRITE_APPEND",
        allow_large_results=True,
        destination_dataset_table=AF_TASK_OUTPUT_TABLE,
        params={
            "AF_TASK_INPUT_TABLE": AF_TASK_INPUT_TABLE
        }
    )

    # GCS Writing Tasks
    airflow_GCS_task = BigQueryToCloudStorageOperator(
        task_id='af_task_GCS_job',
        source_project_dataset_table=AF_TASK_OUTPUT_TABLE,
        destination_cloud_storage_uris=gcs_file_full_name,
        export_format='NEWLINE_DELIMITED_JSON')

    airflow_BQ_task >> airflow_GCS_task
