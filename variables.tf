variable "project" {
    type = string
}

variable "credentials_file" {
}

variable "region" {
    default = "us-west1"
}

variable "zone" {
    default = "us-west1-b"
}

variable "cidrs" {
    default = []
}

variable "environment" {
  type    = string
  default = "dev"
}

variable "machine_types" {
  type    = map
  default = {
    dev  = "f1-micro"
    test = "n1-highcpu-32"
    prod = "n1-highcpu-32"
  }
}

variable "instance_count" {
  default = "2"
}

variable "service_port" {
  default = 80
}

variable "service_port_name" {
  type = string
  default = "http"
}

variable "username" {
    type = string
    default = "tennisonyu"
}

variable public_key {
    type = string
    default = "~/.ssh/id_rsa.pub"
}
