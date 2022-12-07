# pylint: disable=C0301
# pylint: disable=W1203
from os import getenv
import logging
import time
import json
from datetime import datetime, time as date_time
import requests

from google.cloud import bigquery

logging.basicConfig(level=logging.INFO)

FUNCTION_REGION = getenv("FUNCTION_REGION")
PROJECT_ID = getenv("GCP_PROJECT")
DATASET_ID = getenv("DATASET_ID")
OUTPUT_TABLE = getenv("OUTPUT_TABLE")


def convert_timestamp_to_sql_date_time(value):
    return time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(value))


def store_data_into_bq(dataset, timestamp, event):
    try:
        query = f"INSERT INTO `{dataset}` VALUES ('{timestamp}', '{event}')"

        bq_client = bigquery.Client()
        query_job = bq_client.query(query=query)
        query_job.result()

        logging.info(f"Query results loaded to the {dataset}")
    except AttributeError as error:
        logging.error(f"Query job could not be completed: {error}")


def main(request):
    logging.info("Request: %s", request)

    if request.method == "POST":  # currently function works only with POST method
        event: str
        try:
            event = json.dumps(request.json)
        except TypeError as error:
            return {"error": f"Function only works with JSON. Error: {error}"}, 415, \
                   {'Content-Type': 'application/json; charset=utf-8'}

        timestamp = time.time()
        dataset = f"{PROJECT_ID}.{DATASET_ID}.{OUTPUT_TABLE}"
        store_data_into_bq(dataset,
                           convert_timestamp_to_sql_date_time(timestamp),
                           event)

        return "R", 204

    return {"error": f"{request.method} method is not supported"}, 500, \
           {'Content-Type': 'application/json; charset=utf-8'}
