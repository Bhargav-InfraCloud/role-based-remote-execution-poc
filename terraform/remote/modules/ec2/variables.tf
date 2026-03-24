variable "prefix" {
  description = "A common prefix for resources"
  type        = string
  default     = ""
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "ami_id" {
  description = "AMI ID"
  type        = string
  default     = "ami-00399ec92321828f5" # Amazon Linux 2 AMI for Ubuntu 20.04 for us-east-2
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = ""
}

variable "ssh_key_pair_name" {
  description = "SSH key-pair name"
  type        = string
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key file"
  type        = string
}

variable "github_pat" {
  description = "GitHub Personal Access Token for cloning private repositories"
  type        = string
  # TODO :: Bhargav :: If this is sensitive, all user data steps executed on the bastion host will be masked/redacted.
  #                    To minimize redaction, order the steps carefully and isolate those that require the token, then
  #                    set this to true.
  sensitive = false
}

variable "github_user" {
  description = "GitHub username for authentication"
  type        = string
}

variable "license_file_path" {
  description = "Path to the license file to copy to the bastion host"
  type        = string
  default     = ""
}
