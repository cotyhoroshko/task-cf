# pylint: disable=C0301
# pylint: disable=W1203
from os import getenv
import logging
import time
import json

import requests

from google.cloud import bigquery, pubsub_v1

logging.basicConfig(level=logging.INFO)

PROJECT_ID = getenv("GCP_PROJECT")
DATASET_ID = getenv("DATASET_ID")
OUTPUT_TABLE = getenv("OUTPUT_TABLE")
PUBSUB_TOPIC_NAME = getenv("PUBSUB_TOPIC_NAME")


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


def publish_to_pubsub_topic(data: str) -> None:
    print("####")
    publisher = pubsub_v1.PublisherClient()
    topic_path = publisher.topic_path(PROJECT_ID, PUBSUB_TOPIC_NAME)
    print("DDD")
    publisher.publish(topic_path, data.encode("utf-8"))
    print("!!!")


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

        print("!!!!!!!!", event)
        publish_to_pubsub_topic(event)

        return "", 204

    return {"error": f"{request.method} method is not supported"}, 500, \
        {'Content-Type': 'application/json; charset=utf-8'}
