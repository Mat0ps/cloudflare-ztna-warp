# ============= CLOUDFLARE TUNNEL CONFIGURATION =============

# Get Cloudflare API Token from AWS Secrets Manager
data "aws_secretsmanager_secret_version" "cloudflare_api_token" {
  secret_id = var.cloudflare_token_secret_arn
}

provider "cloudflare" {
  api_token = jsondecode(data.aws_secretsmanager_secret_version.cloudflare_api_token.secret_string).api_token
}

# Cloudflare Zone
data "cloudflare_zone" "this" {
  zone_id = var.zone_id
}

# Tunnel Secret Generation
resource "random_password" "tunnel_secret" {
  length  = 64
  special = false
}

# Single Zero Trust Tunnel for routing
resource "cloudflare_zero_trust_tunnel_cloudflared" "tunnel_cloudflared" {
  account_id    = var.cloudflare_account_id
  name          = var.tunnel_name
  config_src    = "cloudflare"
  tunnel_secret = base64encode(random_password.tunnel_secret.result)
}

# Tunnel Token
data "cloudflare_zero_trust_tunnel_cloudflared_token" "tunnel_cloudflared_token" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
}

# Create Cloudflare Tunnel Token Secret in AWS Secrets Manager if it doesn't exist
resource "aws_secretsmanager_secret" "cloudflare_tunnel_token" {
  name                    = var.tunnel_token_secret_name
  description             = "Cloudflare Zero Trust Tunnel Token for ${var.identifier} Routing"
  tags                    = var.tags
  recovery_window_in_days = 0
}

# Always create a new version of the secret with the current token
resource "aws_secretsmanager_secret_version" "cloudflare_tunnel_token" {
  secret_id     = aws_secretsmanager_secret.cloudflare_tunnel_token.id
  secret_string = jsonencode({
    tunnel_token = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel_cloudflared_token.token
  })
}

# Configure tunnel for VPC CIDR routing
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_cloudflared_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
  
  config = {
    warp_routing = {
      enabled = true
    }
    ingress = [
      {
        service = "http_status:404"
      }
    ]
  }
}

# Configure private network for VPC CIDR routing
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "vpc_network" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
  network    = var.vpc_cidr
  comment    = "Route traffic to VPC network"
}

# ============= EC2 JUMP HOST CONFIGURATION =============

resource "aws_security_group" "jump_host" {
  name        = var.security_group_name
  description = "Security group for Cloudflare tunnel jump host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow SSH traffic"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(
    var.tags,
    {
      Name = var.security_group_name
    }
  )
}

# Create SSH key pair for the jump host
resource "tls_private_key" "jump_host_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create AWS key pair using the generated public key
resource "aws_key_pair" "jump_host_key_pair" {
  key_name   = var.key_pair_name
  public_key = tls_private_key.jump_host_key.public_key_openssh
  
  tags = var.tags
}

# Store private key in AWS Secrets Manager
resource "aws_secretsmanager_secret" "jump_host_private_key" {
  name                    = var.private_key_secret_name
  description             = "Private SSH key for accessing the ${var.identifier} jump host"
  recovery_window_in_days = 0
  tags                    = var.tags
}

resource "aws_secretsmanager_secret_version" "jump_host_private_key" {
  secret_id     = aws_secretsmanager_secret.jump_host_private_key.id
  secret_string = tls_private_key.jump_host_key.private_key_pem
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_iam_role" "jump_host_role" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "jump_host_policy" {
  name = var.iam_policy_name
  role = aws_iam_role.jump_host_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "secretsmanager:GetSecretValue",
        ]
        Effect = "Allow"
        Resource = [
          aws_secretsmanager_secret.cloudflare_tunnel_token.arn,
          aws_secretsmanager_secret.jump_host_private_key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "jump_host_profile" {
  name = var.iam_instance_profile_name
  role = aws_iam_role.jump_host_role.name
}

resource "aws_instance" "jump_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.jump_host.id]
  iam_instance_profile        = aws_iam_instance_profile.jump_host_profile.name
  key_name                    = aws_key_pair.jump_host_key_pair.key_name
  associate_public_ip_address = true
  
  user_data = base64encode(templatefile("${path.module}/user_data/user_data.sh", {
    aws_region = var.aws_region
    identifier = var.identifier
    cloudflare_account_id = var.cloudflare_account_id
    tunnel_id = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
    tunnel_secret_b64 = base64encode(random_password.tunnel_secret.result)
  }))

  tags = merge(
    var.tags,
    {
      Name = var.instance_name
    }
  )
  
  depends_on = [aws_secretsmanager_secret_version.cloudflare_tunnel_token, aws_secretsmanager_secret_version.jump_host_private_key]
} 