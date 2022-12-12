terraform {
  backend "gcs" {
    bucket  = "task-cf"
    prefix = "cf/task-cf"
  }
}

#locals {
#  deletion_protection = false
#}

provider "google" {

#  credentials = file("tfsvc.json")

  project = var.project_id
  region  = var.region
}

resource "google_bigquery_dataset" "dataset" {
  dataset_id = var.dataset_id
  location   = var.location
}

resource "google_bigquery_table" "table" {
  dataset_id = google_bigquery_dataset.dataset.dataset_id
  table_id   = var.table_id
  schema     = file("schemas/bq_table_schema/task-cf-raw.json")
  deletion_protection = false
}

resource "google_pubsub_topic" "topic" {
  name = var.topic_id
}

resource "google_pubsub_subscription" "subscription" {
  name  = var.subscription_id
  topic = google_pubsub_topic.topic.name
}

resource "google_storage_bucket" "bucket" {
  name     = var.bucket_id
  location = var.location
  force_destroy = true
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "./function"
  output_path = "/tmp/function.zip"
}

resource "google_storage_bucket_object" "archive" {
  name   = "code.zip"
  source = data.archive_file.source.output_path
  bucket = google_storage_bucket.bucket.name
  content_type = "application/zip"
}

resource "google_cloudfunctions_function" "function" {
  name         = "task-function"
  description  = "a new function"

  runtime      = "python310"
  trigger_http = true
  entry_point  = "main"

  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name

  environment_variables = {
    PROJECT_ID    = var.project_id
    OUTPUT_TABLE  = "${google_bigquery_dataset.dataset.dataset_id}.${google_bigquery_table.table.table_id}"
    TOPIC_ID      = var.topic_id
  }
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = var.project_id
  region         = var.region
  cloud_function = google_cloudfunctions_function.function.name

  role   = "roles/cloudfunctions.invoker"
  member = "allUsers"
}

resource "google_cloudbuild_trigger" "github-trigger" {
  project  = var.project_id
  name     = "github-updates-trigger"
  filename = "cloudbuild.yaml"
  github {
    owner = "cotyhoroshko"
    name  = "task-cf"
    push {
      branch = "^master"
    }
  }
}