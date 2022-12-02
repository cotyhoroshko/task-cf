variable "project_id" {
  default     = "task-cf-370408"
  type        = string
  description = "Project ID to deploy resources in."
}

variable "region" {
  default     = "us-central1"
  type        = string
  description = "Region"
}

variable "dataset_id" {
  default     = "task_cf_dataset"
  type        = string
  description = "Project ID to deploy resources in."
}

variable "table_id" {
  default     = "task_cf_table"
  type        = string
  description = "Project ID to deploy resources in."
}

variable "table_id_d" {
  default     = "task_cf_table"
  type        = string
  description = "Project ID to deploy resources in."
}



variable "deletion_protection" {
  default = false
}
variable "length" {
  default = "2"
}
variable "force_destroy" {
  default = true
}
#deletion_protection = false
#TF_DELETION_PROTECTION