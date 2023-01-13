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

variable "dataset_id" {
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