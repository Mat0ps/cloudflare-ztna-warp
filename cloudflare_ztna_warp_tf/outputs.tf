# Cloudflare tunnel outputs
output "tunnel_token" {
  value     = data.cloudflare_zero_trust_tunnel_cloudflared_token.tunnel_cloudflared_token.token
  sensitive = true
}

output "tunnel_id" {
  value = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
}

output "secret_name" {
  value = "${var.identifier}/cloudflare-tunnel-token"
}

# EC2 jump host outputs
output "jump_host_id" {
  description = "ID of the EC2 jump host instance"
  value       = aws_instance.jump_host.id
}

output "jump_host_private_ip" {
  description = "Private IP address of the EC2 jump host"
  value       = aws_instance.jump_host.private_ip
}

output "jump_host_public_ip" {
  description = "Public IP address of the EC2 jump host, if applicable"
  value       = aws_instance.jump_host.public_ip
}

output "security_group_id" {
  description = "ID of the security group attached to the jump host"
  value       = aws_security_group.jump_host.id
}

output "ssh_key_secret_name" {
  description = "Name of the AWS Secret containing the SSH private key"
  value       = aws_secretsmanager_secret.jump_host_private_key.name
}

output "ssh_connection_command" {
  description = "Command to SSH into the jump host through Cloudflare WARP (after retrieving the key)"
  value       = <<-EOT
    # Retrieve and save the SSH key
    aws secretsmanager get-secret-value --secret-id ${aws_secretsmanager_secret.jump_host_private_key.name} --query SecretString --output text > ${var.identifier}-jumphost-key.pem
    chmod 600 ${var.identifier}-jumphost-key.pem
    
    # Connect via SSH
    ssh -i ${var.identifier}-jumphost-key.pem ubuntu@${aws_instance.jump_host.private_ip}
  EOT
} 
