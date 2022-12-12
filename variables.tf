variable "project_id" {
  default     = "task-cf-370913"
  type        = string
  description = "Project ID"
}

variable "region" {
  default     = "us-central1"
  type        = string
  description = "Region"
}

variable "zone" {
  default     = "us-central1-a"
  type        = string
  description = "Zone"
}

variable "location" {
  default     = "US"
  type        = string
  description = "Location"
}

variable "dataset_idd" {
  default     = "cf_dataset"
  type        = string
  description = "Dataset ID"
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

variable "deletion_protection" {
  default = false
}


variable "force_destroy" {
  default = true
}

variable "bucket_id" {
  type = string
  default = "task-cf-bucket1"
}

variable "topic_id" {
  type = string
  default = "cf_topic"
}

variable "subscription_id" {
  type = string
  default = "cf_sub"
}