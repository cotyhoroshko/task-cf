terraform {
  backend "gcs" {
      bucket = "task-cf"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_storage_bucket" "task-cf-bucket" {
  name          = "project-id-bucket"
  location      = var.location
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_bigquery_dataset" "task_cf_dataset" {
  dataset_id  = var.dataset_id
  location = var.location
  description = "Public dataset"
}

resource "google_bigquery_dataset_iam_member" "owner" {
  dataset_id  = google_bigquery_dataset.task_cf_dataset.dataset_id
  role = "roles/bigquery.dataOwner"
  member = "allUsers"
}

resource "google_bigquery_table" "task-cf-table" {
  dataset_id = var.dataset_id
  table_id   = var.table_id
  schema     = file("schemas/bq_table_schema/task-cf-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "./function"
  output_path = "/tmp/function.zip"
}

resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.task-cf-bucket.name
}

resource "google_cloudfunctions_function" "task-cf-function" {
  name    = "task-cf-function"
  runtime = "python39"

  source_archive_bucket = google_storage_bucket.task-cf-bucket.name
  source_archive_object = google_storage_bucket_object.zip.name

  entry_point  = "main"
  trigger_http = true

  environment_variables = {
    FUNCTION_REGION = var.region
    GCP_PROJECT     = var.project_id
    DATASET_ID      = var.dataset_id
    OUTPUT_TABLE    = google_bigquery_table.task-cf-table.table_id
    PUBSUB_TOPIC_NAME = google_pubsub_topic.cf-subtask-topic.name
  }

  depends_on = [
    google_storage_bucket.task-cf-bucket,
    google_storage_bucket_object.zip
  ]
}

resource "google_cloudfunctions_function_iam_member" "invoker" {
  project        = google_cloudfunctions_function.task-cf-function.project
  region         = google_cloudfunctions_function.task-cf-function.region
  cloud_function = google_cloudfunctions_function.task-cf-function.name

#  role   = "roles/cloudfunctions.invoker"
  role   = "roles/owner"
  member = "allUsers"

  depends_on = [
    google_cloudfunctions_function.task-cf-function
  ]
}

#resource "google_service_account" "cloudbuild_service_account" {
#  account_id = "my-service-account"
#}
#
#resource "google_bigquery_dataset_iam_member" "dataset-editor" {
#  dataset_id = var.dataset_id
#  role    = "roles/bigquery.dataEditor"
#  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
#}

#resource "google_project_iam_member" "project-editor" {
#  project = var.dataset_id
#  role    = "roles/editor"
#  member  = "serviceAccount:${google_service_account.cloudbuild_service_account.email}"
#}

resource "google_cloudbuild_trigger" "github-trigger" {
  project  = var.project_id
  name     = "github-updates-trigger"
  filename = "cloudbuild.yaml"
#  service_account = "andrii.mruts.knm.2019@lpnu.ua"
#  service_account = google_service_account.cloudbuild_service_account.id

  github {
    owner = "cotyhoroshko"
    name  = "task-cf"
    push {
      branch = "^master"
    }
  }

#  depends_on = [
#    google_service_account.cloudbuild_service_account,
#    google_project_iam_member.project-editor,
#    google_bigquery_dataset_iam_member.dataset-editor
#  ]
}

resource "google_pubsub_topic" "cf-subtask-topic" {
  project = var.project_id
  name = "cf-subtask-topic"
}

resource "google_pubsub_topic_iam_member" "member" {
  project = google_pubsub_topic.cf-subtask-topic.project
  topic = google_pubsub_topic.cf-subtask-topic.name
#  role = "roles/pubsub.admin"
  role = "roles/owner"
  member = "allUsers"
}

resource "google_pubsub_subscription" "cf-subtask-sub" {
  project = var.project_id
  name    = "cf-subtask-sub"
  topic   = google_pubsub_topic.cf-subtask-topic.name
}

resource "google_pubsub_subscription_iam_member" "sub-owner" {
  subscription = google_pubsub_subscription.cf-subtask-sub.name
  role = "roles/owner"
  member = "allUsers"
}