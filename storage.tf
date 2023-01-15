resource "google_storage_bucket" "task-cf-bucket" {
  name          = var.project_id
  location      = var.location
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

resource "google_bigquery_dataset" "task_cf_dataset" {
  dataset_id  = var.dataset_name
  location    = var.location
  description = "Public dataset"
}

resource "google_bigquery_dataset" "airflow_output_dataset" {
  dataset_id  = var.airflow_output_dataset_name
  location    = var.location
  description = "Public dataset"
}

# Storage bucket objects
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

# BigQuery tables
resource "google_bigquery_table" "task-cf-table" {
  dataset_id          = var.dataset_name
  table_id            = var.table_id
  schema              = file("schemas/bq_table_schema/task-cf-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_bigquery_table" "task-two-table" {
  dataset_id          = var.dataset_name
  table_id            = var.task_two_table_id
  schema              = file("schemas/bq_table_schema/task-2-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_bigquery_table" "task-two-error-table" {
  dataset_id          = var.dataset_name
  table_id            = var.task_two_error_table_id
  schema              = file("schemas/bq_table_schema/task-2-error-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_bigquery_table" "airflow-table" {
  dataset_id          = var.airflow_output_dataset_name
  table_id            = var.airflow_table_id
  schema              = file("schemas/bq_table_schema/airflow-table-raw.json")
  deletion_protection = false

  depends_on = [
    google_bigquery_dataset.task_cf_dataset
  ]
}

resource "google_storage_bucket" "airflow-task-bucket" {
  name          = var.airflow_bucket_name
  location      = var.location
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}