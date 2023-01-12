terraform {
  backend "gcs" {
    bucket = "task-gcp"
  }
  required_version = ">= 1.0.0"
}

provider "google" {
  project = var.project_id
  region  = var.region
}

variable "api_services" {
  description = "List of API Services"
  default     = [
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "dataflow.googleapis.com"
  ]

  # useful link : GCP List of API Services https://gist.github.com/coryodaniel/13eaee16a87a7fdca5e738123216862a
}

resource "google_project_service" "api_services" {
  count   = length(var.api_services)
  project = var.project_id
  service = element(var.api_services, count.index)
}

resource "google_project_iam_member" "project-me" {
  project = var.project_id
  role    = "roles/owner"
  member  = "user:loskoton1@gmail.com"
}

resource "google_project_iam_member" "project-cloud-build" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
  #  member = data.google_service_account.cloudbuild_account.name
}

resource "google_storage_bucket" "task-cf-bucket" {
  name          = var.project_id
  location      = var.location
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_storage_bucket_object" "temp_folder" {
  name    = "tmp/"
  content = "Temporary gcp location"
  bucket  = google_storage_bucket.task-cf-bucket.name
}

resource "google_storage_bucket_object" "template_folder" {
  name    = "template/"
  content = "Template gcp location"
  bucket  = google_storage_bucket.task-cf-bucket.name
}

resource "google_bigquery_dataset" "task_cf_dataset" {
  dataset_id  = var.dataset_id
  location    = var.location
  description = "Public dataset"
}


resource "google_bigquery_table" "task-cf-table" {
  dataset_id          = var.dataset_id
  table_id            = var.table_id
  schema              = file("schemas/bq_table_schema/task-cf-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

data "archive_file" "source" {
  type        = "zip"
  source_dir  = "./function"
  output_path = "function.zip"
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
    GCP_PROJECT       = var.project_id
    DATASET_ID        = var.dataset_id
    OUTPUT_TABLE      = google_bigquery_table.task-cf-table.table_id
    PUBSUB_TOPIC_NAME = google_pubsub_topic.cf-subtask-topic.name
  }

  depends_on = [
    google_project_service.api_services,
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

  depends_on = [
    google_cloudfunctions_function.task-cf-function
  ]
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

resource "google_pubsub_topic" "cf-subtask-topic" {
  project = var.project_id
  name    = "cf-subtask-topic"

  depends_on = [google_project_service.api_services]
}

resource "google_pubsub_subscription" "cf-subtask-sub" {
  project = var.project_id
  name    = "cf-subtask-sub"
  topic   = google_pubsub_topic.cf-subtask-topic.name
}

#guration: googleapi: Error 403: Caller is missing permission 'iam.serviceaccounts.actAs'
#on service account task-cf-370913@appspot.gserviceaccount.com. Grant the role
#'roles/iam.serviceAccountUser' to the caller on the service account task-cf-370913@appspot.gserviceaccount.com. You can do that by running
#'gcloud iam service-accounts add-iam-policy-binding task-cf-370913@appspot.gserviceaccount.com --member MEMBER --role roles/iam.serviceAccountUser'
#where MEMBER has a prefix like 'user:' or 'serviceAccount:'. Details and instructions for the Cloud Console can be found at
#https://cloud.google.com/functions/docs/reference/iam/roles#additional-configuration. Please visit https://cloud.google.com/functions/docs/troubleshooting
#for in-depth troubleshooting documentation., forbidden

# gcloud iam service-accounts add-iam-policy-binding task-cf-370913@appspot.gserviceaccount.com --member 'allUsers' --role roles/iam.serviceAccountUser
# access-service-account@task-cf-370913.iam.gserviceaccount.com
# projects/task-gcp-374512/serviceAccounts/my-service-account@task-gcp-374512.iam.gserviceaccount.com
# projects/task-gcp-374512/serviceAccounts/my-service-account@task-gcp-374512.iam.gserviceaccount.com


resource "google_bigquery_table" "task-two-table" {
  dataset_id          = var.dataset_id
  table_id            = var.task_two_table_id
  schema              = file("schemas/bq_table_schema/task-2-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_bigquery_table" "task-two-error-table" {
  dataset_id          = var.dataset_id
  table_id            = var.task_two_error_table_id
  schema              = file("schemas/bq_table_schema/task-2-error-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_bigquery_table" "task-two-error-table-test" {
  dataset_id          = var.dataset_id
  table_id            = "test_task_two_error_table_id"
  schema              = file("schemas/bq_table_schema/task-2-error-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}


resource "google_dataflow_job" "big_data_job" {
  name                  = "dataflow-job-task"
  template_gcs_path     = "gs://${google_storage_bucket_object.template_folder.bucket}/${google_storage_bucket_object.template_folder.name}test-job_v2"
  temp_gcs_location     = "gs://${google_storage_bucket_object.temp_folder.bucket}/${google_storage_bucket_object.temp_folder.name}"
#  service_account_email = "cloud-builder-account@task-gcp-374512.iam.gserviceaccount.com"

  depends_on = [
    google_project_service.api_services,
    google_storage_bucket_object.temp_folder,
    google_storage_bucket_object.template_folder
  ]
}


#resource "google_bigquery_table" "" {
#  dataset_id = var.dataset_id
#  table_id   = ""
#}