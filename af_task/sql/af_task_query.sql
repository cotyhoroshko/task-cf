WITH
airflow_data AS (
    SELECT
        name,
        CHAR_LENGTH(name) as length
        CURRENT_TIMESTAMP() as timestamp
    FROM
        `{{ params.AF_TASK_INPUT_TABLE }}`
)
SELECT * FROM airflow_data
