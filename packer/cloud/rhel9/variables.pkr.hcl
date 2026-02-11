variable "region" {
  type = string
}

variable "source_ami" {
  type = string
}

variable "ami_name_prefix" {
  type = string
}

variable "os" {
  type = string
  default = "rhel9"
}

variable "qualys_username" {
  type = string
}

variable "qualys_password" {
  type = string
}

variable "report_bucket" {
  type = string
}

variable "report_prefix" {
  type = string
}

variable "build_number" {
  type    = string
  default = "local"
}

variable "build_url" {
  type    = string
  default = "local"
}
