WITH
airflow_data AS (
    SELECT
        *,
        CHAR_LENGTH(name) as length
    FROM
        `{{ params.AF_TASK_INPUT_TABLE }}` output_table
    WHERE
        output_table.timestamp > DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -1 HOUR)
)
SELECT * FROM airflow_data
