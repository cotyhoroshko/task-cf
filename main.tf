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

data "google_project" "project" {}

resource "google_project_service" "api_services" {
  count   = length(var.api_services)
  project = var.project_id
  service = element(var.api_services, count.index)
}

# permissions
resource "google_project_iam_member" "project-me" {
  project = var.project_id
  role    = "roles/owner"
  member  = "user:loskoton1@gmail.com"
}

resource "google_project_iam_member" "project-cloud-build" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"
}

resource "google_project_iam_member" "project-airflow-composer" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:service-${data.google_project.project.number}@cloudcomposer-accounts.iam.gserviceaccount.com"
}

resource "google_project_iam_member" "project-airflow-composer-acc" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "project-airflow-composer-acc-worker" {
  project = var.project_id
  role    = "roles/composer.worker"
  member  = "serviceAccount:${data.google_project.project.number}-compute@developer.gserviceaccount.com"
}

resource "google_project_iam_member" "project-cloudservices-acc" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com"
}
resource "google_project_iam_member" "project-cloudservices-acc-editor" {
  project = var.project_id
  role    = "roles/editor"
  member  = "serviceAccount:${data.google_project.project.number}@cloudservices.gserviceaccount.com"
}

resource "google_project_iam_member" "project-cloudservices-accd" {
  project = var.project_id
  role    = "roles/owner"
  member  = "serviceAccount:task-gcp-374512@appspot.gserviceaccount.com"
}

# gcloud composer environments create task-three-env --location=us-central1 --image-version=composer-2.1.2-airflow-2.2.5 --scheduler-count=1

#output "proj-numer" {
#  value = data.google_project.project.number
#}

# trigger
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

# cloud function
resource "google_cloudfunctions_function" "task-cf-function" {
  name    = "task-cf-function"
  runtime = "python39"

  source_archive_bucket = google_storage_bucket.task-cf-bucket.name
  source_archive_object = google_storage_bucket_object.zip.name

  entry_point  = "main"
  trigger_http = true

  environment_variables = {
    GCP_PROJECT       = var.project_id
    DATASET_ID        = var.dataset_name
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

# Pub/Sub
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

# Dataflow
resource "google_dataflow_job" "big_data_job_task" {
  name              = "dataflow-job-task-three"
  template_gcs_path = "gs://${google_storage_bucket_object.template_folder.bucket}/${google_storage_bucket_object.template_folder.name}test-job"
  temp_gcs_location = "gs://${google_storage_bucket_object.temp_folder.bucket}/${google_storage_bucket_object.temp_folder.name}"

  depends_on = [
    google_project_service.api_services,
    google_storage_bucket_object.temp_folder,
    google_storage_bucket_object.template_folder
  ]
}

# deprecated
resource "google_dataflow_job" "big_data_job" {
  name              = "dataflow-job-task"
  template_gcs_path = "gs://${google_storage_bucket_object.template_folder.bucket}/${google_storage_bucket_object.template_folder.name}test-job_v2"
  temp_gcs_location = "gs://${google_storage_bucket_object.temp_folder.bucket}/${google_storage_bucket_object.temp_folder.name}"

  depends_on = [
    google_project_service.api_services,
    google_storage_bucket_object.temp_folder,
    google_storage_bucket_object.template_folder
  ]
}

resource "google_cloudbuild_trigger" "github-trigger-af" {
  project  = var.project_id
  name     = "github-updates-trigger-af"
  filename = "af_task/cloudbuild.yaml"

  github {
    owner = "cotyhoroshko"
    name  = "task-cf"
    push {
      branch = "^master"
    }
  }

  substitutions = {
    "_COMPOSER_ENV_NAME": var.af-composer-name,
    "_COMPOSER_LOCATION": var.af-composer-location,
    "_LOCATION": var.af-composer-location,
    "_APP": "af_task"
  }
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