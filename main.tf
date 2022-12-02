terraform {
  backend "gcs" {
    prefix = "cf/task-cf"
  }
}

# task-cf-bucket
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = "us-central1-a"
}

resource "google_storage_bucket" "task-cf-bucket" {
    name     = "${var.project_id}-bucket"
    location = var.region
    force_destroy = true
}

data "archive_file" "source" {
    type        = "zip"
    source_dir  = "./function"
    output_path = "/tmp/function.zip"
}

resource "google_storage_bucket_object" "zip" {
    source       = data.archive_file.source.output_path
    content_type = "application/zip"

    name         = "src-${data.archive_file.source.output_md5}.zip"
    bucket       = google_storage_bucket.task-cf-bucket.name

    depends_on   = [
        google_storage_bucket.task-cf-bucket,
        data.archive_file.source
    ]
}

resource "google_cloudfunctions_function" "task-cf-function" {
    name                  = "task-cf-function"
    runtime               = "python39"

    source_archive_bucket = google_storage_bucket.task-cf-bucket.name
    source_archive_object = google_storage_bucket_object.zip.name

    entry_point           = "main"
    trigger_http          = true

    environment_variables = {
      FUNCTION_REGION = var.region
      GCP_PROJECT = var.project_id
      DATASET_ID = var.dataset_id
      OUTPUT_TABLE = google_bigquery_table.task-cf-table.table_id
    }

    depends_on            = [
        google_storage_bucket.task-cf-bucket,
        google_storage_bucket_object.zip
    ]
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.task-cf-function.project
  region         = google_cloudfunctions_function.task-cf-function.region
  cloud_function = google_cloudfunctions_function.task-cf-function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_bigquery_dataset" "task-cf-dataset" {
  dataset_id = var.dataset_id
  description                 = "This dataset is public"
  location                    = "US"
}

resource "google_bigquery_table" "task-cf-table" {
  dataset_id = var.dataset_id
  table_id   = var.table_id
  schema = file("schemas/bq_table_schema/task-cf-raw.json")
}

#locals {
#  env = substr(var.project_id, -3, -1)
#}

#module "task_cf_function" {
#  project_id          = var.project_id
#  name                = "task_cf_function"
#  source_directory    = "function"
#  function_type       = "http"
#  available_memory_mb = 256
#  timeout_s           = 540
#  entry_point         = "main"
#  runtime             = "python38"
#  public_function     = true
#
#  environment_variables = {
#    BDE_GCP_PROJECT = var.project_id
#    OUTPUT_TABLE    = "data_set_name.task-cf-data"
#    FUNCTION_REGION = "europe-west1"
#  }
#}

#module "task_cf_dataset" {
#  project_id = var.project_id
#  dataset_id = "data_set_name"
#  tables     = {
#    task-cf-data = {
#      schema                   = file("schemas/task-cf-raw.json")
#      require_partition_filter = true
#      time_partitioning_field  = "timestamp"
#      time_partitioning_type   = "DAY"
#    }
#  }
#  source = "./"
#}

#variable "deletion_protection" {
#  default = false
#  type        = bool
#  description = "Project ID to deploy resources in."
#}
