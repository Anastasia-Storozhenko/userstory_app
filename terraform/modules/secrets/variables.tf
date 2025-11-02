variable "secret_name" {
  description = "Name for the database secret."
  type        = string
  default     = "userstory-db-secret-dev"
}

variable "db_username" {
  description = "The database user name."
  type        = string
  default     = "userstory_admin"
}

variable "db_password_length" {
  description = "Length of the randomly generated password."
  type        = number
  default     = 20
}