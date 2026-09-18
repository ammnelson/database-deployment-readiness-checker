variable "region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.30.0.0/16"
}

variable "allowed_ips" {
  description = "CIDRs allowed to reach SSH (22) and Jenkins (8080)"
  type        = list(string)
}

variable "instance_type" {
  description = "Build host instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name for the EC2 key pair"
  type        = string
  default     = "ddrc-module5"
}

variable "public_key_path" {
  description = "Path to the SSH public key uploaded as the key pair"
  type        = string
}

variable "enable_sqs" {
  description = "Feature toggle: true routes /validate through SQS, false validates inline"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Email address subscribed to DDRC alarm notifications"
  type        = string
}
