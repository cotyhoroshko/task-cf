import datetime
import json
import pdb

import apache_beam as beam
import argparse
from apache_beam.options.pipeline_options import PipelineOptions
from apache_beam.options.pipeline_options import SetupOptions

SCHEMA = ",".join(
    [
        "name:STRING",
        "age:INTEGER",
        "height:FLOAT64",
        "timestamp:TIMESTAMP",
    ]
)

ERROR_SCHEMA = ",".join(
    [
        "msg:STRING",
        "timestamp:TIMESTAMP",
    ]
)


class Parser(beam.DoFn):
    ERROR_TAG = 'error'

    def process(self, line):
        try:
            # data_row = json.loads(element.decode("utf-8"))
            print("LLL", line)
            result_line = {}
            result_line["name"] = str(json.loads(line.decode("utf-8")))
            result_line["timestamp"] = datetime.datetime.utcnow()
            result_line["age"] = 12
            result_line["height"] = None
            print("RR", result_line)
            yield result_line
        except Exception as error:
            print("EE", error)
            error_row = {"msg": str(error), "timestamp": datetime.datetime.utcnow()}
            # error_row =  # parse json message according to ERRORS table schema
            # yield beam.pvalue.TaggedOutput(self.ERROR_TAG, error_row)
            yield beam.pvalue.TaggedOutput(self.ERROR_TAG, error_row)


def run(options, input_subscription, output_table, output_error_table):
    with beam.Pipeline(options=options) as pipeline:
        rows, error_rows = \
            (pipeline | 'Read from PubSub' >> beam.io.ReadFromPubSub(subscription=input_subscription)
             | 'Parse JSON messages' >> beam.ParDo(Parser()).with_outputs(Parser.ERROR_TAG, main='rows')
             )

        _ = (rows | 'Write data to BigQuery'
             >> beam.io.WriteToBigQuery(output_table,
                                        create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                                        write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                                        schema=SCHEMA
                                        )
             )

        _ = (error_rows | 'Write errors to BigQuery'
             >> beam.io.WriteToBigQuery(output_error_table,
                                        create_disposition=beam.io.BigQueryDisposition.CREATE_NEVER,
                                        write_disposition=beam.io.BigQueryDisposition.WRITE_APPEND,
                                        schema=ERROR_SCHEMA
                                        )
             )


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument(
        '--input_subscription', required=True,
        help='Input PubSub subscription of the form "/subscriptions/<PROJECT>/<SUBSCRIPTION>".')
    parser.add_argument(
        '--output_table', required=True,
        help='Output BigQuery table for data')
    parser.add_argument(
        '--output_error_table', required=True,
        help='Output BigQuery table for errors')
    print("####")
    known_args, pipeline_args = parser.parse_known_args()
    pipeline_options = PipelineOptions(pipeline_args)
    pipeline_options.view_as(SetupOptions).save_main_session = True
    print("###", pipeline_options.__dict__)
    pipeline_options = {
        'project': 'task-cf-372314',
        'runner': 'DataflowRunner',
        'region': 'US',
        'staging_location': 'gs://task-cf/tmp',
        'temp_location': 'gs://task-cf/tmp',
        'template_location': 'gs://task-cf/template/test-job',
        'save_main_session': True,
        'streaming': True,
        'job_name': 'dataflow-custom-pipeline-v1',
    }
    pipeline_options = PipelineOptions.from_dictionary(pipeline_options)
    run(pipeline_options, known_args.input_subscription, known_args.output_table, known_args.output_error_table)
    # run(
    #     options=pipeline_options,
    #     input_subscription="projects/task-cf-372314/subscriptions/cf-subtask-sub",
    #     output_table="projects/task-cf-372314/datasets/task_cf_dataset/tables/task_two_table",
    #     output_error_table="projects/task-cf-372314/datasets/task_cf_dataset/tables/task_two_error_table"
    # )


# python task_two/main.py
#     --streaming
#     --input_subscription projects/task-cf-372314/subscriptions/cf-subtask-sub
#     --output_table task-cf-372314:task_cf_dataset.task_two_table
#     --output_error_table task-cf-372314:task_cf_dataset.task_two_error_table
