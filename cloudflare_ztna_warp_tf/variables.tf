variable "cloudflare_token_secret_arn" {
  type        = string
  description = "Cloudflare API token secret ARN"
}

variable "cloudflare_account_id" {
  type        = string
  description = "Cloudflare account ID"
}

variable "zone_id" {
  type        = string
  description = "Cloudflare DNS zone ID"
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the resources"
  default     = {}
}

variable "identifier" {
  type        = string
  description = "Unique identifier for naming resources"
}

variable "domain" {
  type        = string
  description = "The domain of the Cloudflare zone"
}

variable "aws_region" {
  type        = string
  description = "AWS region where resources are deployed"
}

variable "team_name" {
  type        = string
  description = "The name of the team"
}

variable "vpc_cidr" {
  type        = string
  description = "The CIDR block of the network to route traffic to"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the jump host will be deployed"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID where the jump host will be deployed (should be a public subnet for internet access)"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.micro"
}

# Name variables
variable "tunnel_name" {
  type        = string
  description = "Name for the Cloudflare tunnel"
}

variable "security_group_name" {
  type        = string
  description = "Name for the jump host security group"
}

variable "key_pair_name" {
  type        = string
  description = "Name for the SSH key pair"
}

variable "iam_role_name" {
  type        = string
  description = "Name for the IAM role"
}

variable "iam_policy_name" {
  type        = string
  description = "Name for the IAM policy"
}

variable "iam_instance_profile_name" {
  type        = string
  description = "Name for the IAM instance profile"
}

variable "instance_name" {
  type        = string
  description = "Name for the EC2 instance"
}

variable "tunnel_token_secret_name" {
  type        = string
  description = "Name for the Cloudflare tunnel token secret"
}

variable "private_key_secret_name" {
  type        = string
  description = "Name for the jump host private key secret"
}