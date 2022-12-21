terraform {
  backend "gcs" {
      bucket = "cf-task"
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

#resource "google_project_iam_policy" "project" {
#  project     = var.project_id
#  policy_data = data.google_iam_policy.admin.policy_data
#}
#
#data "google_iam_policy" "admin" {
#  binding {
#    role = "roles/editor"
#
#    members = [
#      "user:andrii.mruts.knm.2019@lpnu.ua",
#      "serviceAccount:access-service-account@task-cf-370913.iam.gserviceaccount.com"
#    ]
#  }
#}

#data "google_iam_policy" "cloudbuild-runner" {
#  binding {
##    role = "roles/bigquery.dataOwner"
#    role = "dataflow.jobs.create"
#
#    members = [
#      "allUsers",
#    ]
#  }
#}

resource "google_storage_bucket" "task-cf-bucket" {
  name          = "bucket-project-id"
  location      = var.location
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_storage_bucket_iam_member" "member" {
  bucket = google_storage_bucket.task-cf-bucket.name
  role = "roles/storage.admin"
  member = "allUsers"
}

resource "google_storage_default_object_access_control" "public_rule" {
  bucket = google_storage_bucket.task-cf-bucket.name
  role   = "OWNER"
  entity = "allUsers"
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
  role   = "roles/editor"
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
  role = "roles/owner"
  member = "allUsers"
}

resource "google_pubsub_subscription" "cf-subtask-sub" {
  project = var.project_id
  name    = "cf-subtask-sub"
  topic   = google_pubsub_topic.cf-subtask-topic.name
}

#resource "google_pubsub_subscription_iam_member" "sub-owner" {
#  subscription = google_pubsub_subscription.cf-subtask-sub.name
#  role = "roles/owner"
#  member = "allUsers"
#}

#resource "google_service_account" "sa" {
#  account_id   = "my-service-account"
#  display_name = "A service account"
#}
#
#resource "google_service_account_iam_binding" "admin-account-iam" {
#  service_account_id = google_service_account.sa.name
#  role               = "roles/iam.serviceAccountUser"
#
#  members = [
#    "user:andrii.mruts.knm.2019@lpnu.ua",
##    "serviceAccount:task-cf-370913@appspot.gserviceaccount.com",
#    "serviceAccount:task-cf-372314@appspot.gserviceaccount.com",
#    "serviceAccount:projects/task-cf-372314/serviceAccounts/my-service-account@task-cf-372314.iam.gserviceaccount.com"
#  ]
#}

#guration: googleapi: Error 403: Caller is missing permission 'iam.serviceaccounts.actAs'
#on service account task-cf-370913@appspot.gserviceaccount.com. Grant the role
#'roles/iam.serviceAccountUser' to the caller on the service account task-cf-370913@appspot.gserviceaccount.com. You can do that by running
#'gcloud iam service-accounts add-iam-policy-binding task-cf-370913@appspot.gserviceaccount.com --member MEMBER --role roles/iam.serviceAccountUser'
#where MEMBER has a prefix like 'user:' or 'serviceAccount:'. Details and instructions for the Cloud Console can be found at
#https://cloud.google.com/functions/docs/reference/iam/roles#additional-configuration. Please visit https://cloud.google.com/functions/docs/troubleshooting
#for in-depth troubleshooting documentation., forbidden

# gcloud iam service-accounts add-iam-policy-binding task-cf-370913@appspot.gserviceaccount.com --member 'allUsers' --role roles/iam.serviceAccountUser
# access-service-account@task-cf-370913.iam.gserviceaccount.com
# projects/task-cf-372314/serviceAccounts/my-service-account@task-cf-372314.iam.gserviceaccount.com
# projects/task-cf-372314/serviceAccounts/my-service-account@task-cf-372314.iam.gserviceaccount.com


#resource "google_bigquery_table" "task-two-table" {
#  dataset_id = var.dataset_id
#  table_id   = var.task_two_table_id
#  schema     = file("schemas/bq_table_schema/task-2-raw.json")
#  deletion_protection = false
#
#  depends_on = [
#    google_bigquery_dataset.task_cf_dataset
#  ]
#}
#
#resource "google_bigquery_table" "task-two-error-table" {
#  dataset_id = var.dataset_id
#  table_id   = var.task_two_error_table_id
#  schema     = file("schemas/bq_table_schema/task-2-error-raw.json")
#  deletion_protection = false
#
#  depends_on = [
#    google_bigquery_dataset.task_cf_dataset
#  ]
#}

#resource "google_dataflow_job" "big_data_job" {
#  name              = "dataflow-job-task"
#  template_gcs_path = "gs://task-cf/template/test-job"
#  temp_gcs_location = "gs://task-cf/tmp"
#}
