variable "project_id" {
  default     = "task-gcp-374512"
  type        = string
  description = "Project ID"
}

variable "region" {
  default     = "us-central1"
  type        = string
  description = "Region"
}

variable "location" {
  default     = "US"
  type        = string
  description = "Location"
}

variable "api_services" {
  description = "List of API Services"
  default     = [
    "iam.googleapis.com",
    "cloudbuild.googleapis.com",
    "cloudfunctions.googleapis.com",
    "pubsub.googleapis.com",
    "dataflow.googleapis.com",
    "composer.googleapis.com",
  ]

  # useful link : GCP List of API Services https://gist.github.com/coryodaniel/13eaee16a87a7fdca5e738123216862a
}

variable "dataset_name" {
  default     = "task_cf_dataset"
  type        = string
  description = "Dataset ID"
}

variable "table_id" {
  default     = "task_cf_table"
  type        = string
  description = "Table task ID"
}

variable "task_two_table_id" {
  default     = "task_two_table"
  type        = string
  description = "Table task 2 ID"
}

variable "task_two_error_table_id" {
  default     = "task_two_error_table"
  type        = string
  description = "Error table task 2 ID"
}

variable "airflow_output_dataset_name" {
  default     = "airflow_output_dataset"
  type        = string
  description = "Airflow output table task 3"
}

variable "airflow_table_id" {
  default     = "airflow_table"
  type        = string
  description = "Airflow table task 3 ID"
}

variable "airflow_bucket_name" {
  default     = "airflow-task-bucket"
  type        = string
  description = "Airflow bucket task 3 name"
}

variable "af-composer-name" {
  default = "dev-airflow-task-wnv"
  type = string
  description = "Airflow composer task 3 name"
}

variable "af-composer-location" {
  default = "us-east4"
  type = string
  description = "Airflow composer task 3 location"
}