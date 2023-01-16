WITH
airflow_data AS (
    SELECT
        output_table.name,
        CHAR_LENGTH(name) as length,
        output_table.timestamp
    FROM
        `{{ params.AF_TASK_INPUT_TABLE }}` output_table
    WHERE
        output_table.timestamp > DATE_ADD(CURRENT_TIMESTAMP(), INTERVAL -1 HOUR)
)
SELECT * FROM airflow_data
