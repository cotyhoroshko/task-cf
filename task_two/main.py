import argparse
import datetime
import json

import apache_beam as beam
from apache_beam.options.pipeline_options import PipelineOptions

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
            line = json.loads(line.decode("utf-8"))
            if not ("name" in line or "age" in line):
                raise ValueError("Missing required parameters: 'name' and 'age' fields should be specified")
            line["timestamp"] = datetime.datetime.utcnow()
            yield line

        except Exception as error:
            err_record = {"msg": str(error), "timestamp": datetime.datetime.utcnow()}
            yield beam.pvalue.TaggedOutput(self.ERROR_TAG, err_record)


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
    parser.add_argument(
        '--project', required=True,
        help='Project Id')
    parser.add_argument(
        '--region', required=False, default="US",
        help='Region')
    parser.add_argument(
        '--job_name', required=False, default="dataflow-job-task-three",
        help='Dataflow Job name')
    parser.add_argument(
        '--template_location', required=True,
        help='Template location')
    parser.add_argument(
        '--staging_location', required=True,
        help='Staging location')
    parser.add_argument(
        '--temp_location', required=True,
        help='Temporary location')
    parser.add_argument(
        '--runner', required=False, default="DataflowRunner",
        help='DF runner')
    parser.add_argument(
        '--setup_file', required=False, default="task_two/setup.py",
        help='Setup file path')
    parser.add_argument(
        '--autoscaling_algorithm', required=False, default=None,
        help='Autoscaling algorithm')

    args = parser.parse_args()
    pipeline_options = {
        'project': args.project,
        'runner': args.runner,
        'region': args.region,
        'staging_location': args.staging_location,
        'temp_location': args.temp_location,
        'template_location': args.template_location,
        'save_main_session': True,
        'streaming': True,
        'job_name': args.job_name,
    }
    pipeline_options = PipelineOptions.from_dictionary(pipeline_options)
    run(
        options=pipeline_options,
        input_subscription=args.input_subscription,
        output_table=args.output_table,
        output_error_table=args.output_error_table,
    )
