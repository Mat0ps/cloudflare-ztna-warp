# Cloudflare ZTNA with WARP

<div align="center">

![Zero Trust](https://img.shields.io/badge/Zero%20Trust-Security-blue?style=for-the-badge&logo=cloudflare&logoColor=white)
![WARP](https://img.shields.io/badge/WARP-Routing-orange?style=for-the-badge&logo=cloudflare&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-Infrastructure-purple?style=for-the-badge&logo=terraform&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-yellow?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terragrunt](https://img.shields.io/badge/Terragrunt-Orchestration-green?style=for-the-badge&logo=terraform&logoColor=white)

</div>

<div align="center">
  <img src="https://pixelswap.fr/entry/allowing-multicast-protocols-on-cloudflare-warp/featured_hu2e63bfda86247eed35fb723a19188c51_101382_1300x600_fill_q100_h2_box_center.webp" alt="Cloudflare Zero Trust" width="900"/>
</div>

---

## 🏗️ Architecture

This Terraform/Terragrunt module creates a complete **Cloudflare Zero Trust Network Access (ZTNA)** solution with **WARP routing** to securely connect users to private AWS VPC resources without traditional VPN infrastructure.

### 🌐 **Core Components**

#### **Cloudflare Zero Trust Tunnel**
- **Cloudflared Tunnel**: Secure outbound tunnel connecting AWS VPC to Cloudflare Edge
- **WARP Routing**: Routes traffic from Cloudflare WARP clients to private networks
- **Zero Trust Access**: Identity-based access control without exposing infrastructure
- **Private Network Routes**: Direct routing to VPC CIDR blocks through the tunnel

#### **AWS Infrastructure**
- **EC2 Jump Host**: Ubuntu-based instance running cloudflared daemon
- **Security Groups**: Minimal access control (SSH only)
- **IAM Roles & Policies**: Least-privilege access to AWS Secrets Manager
- **SSH Key Management**: Auto-generated RSA keys stored in AWS Secrets Manager
- **Secrets Management**: Secure storage of tunnel tokens and SSH keys

#### **Network Architecture**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   WARP Client   │    │  Cloudflare Edge │    │   AWS VPC       │
│                 │◄──►│                  │◄──►│                 │
│ (User Device)   │    │   Zero Trust     │    │  Jump Host      │
└─────────────────┘    └──────────────────┘    │  + cloudflared  │
                                               └─────────────────┘
```

## 🚀 Quick Start

### Prerequisites

**For Terraform Deployment:**
- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- Cloudflare account with Zero Trust enabled
- AWS VPC with public subnet

**For Terragrunt Deployment:**
- Terragrunt >= 0.38.0
- Proper directory structure with account/region/env configurations
- VPC dependency configured

### Option 1: Direct Terraform Deployment

1. **Configure Variables:**
   ```hcl
   # terraform.tfvars
   cloudflare_account_id       = "your-cloudflare-account-id"
   cloudflare_token_secret_arn = "arn:aws:secretsmanager:region:account:secret:cloudflare-token"
   zone_id                     = "your-cloudflare-zone-id"
   vpc_id                      = "vpc-xxxxxxxxx"
   vpc_cidr                    = "10.0.0.0/16"
   subnet_id                   = "subnet-xxxxxxxxx"
   identifier                  = "dev"
   ```

2. **Deploy Infrastructure:**
   ```bash
   terraform init
   terraform plan
   terraform apply
   ```

3. **Retrieve Connection Information:**
   ```bash
   # Get SSH key for jump host access
   aws secretsmanager get-secret-value \
     --secret-id "dev-cloudflare-routing/private-key" \
     --query SecretString --output text > jumphost-key.pem
   chmod 600 jumphost-key.pem
   ```

### Option 2: Terragrunt Deployment

1. **Ensure Dependencies:**
   ```bash
   # VPC must be deployed first
   cd ../vpc
   terragrunt apply
   ```

2. **Deploy ZTNA Infrastructure:**
   ```bash
   cd cloudflare-ztna-warp
   terragrunt plan
   terragrunt apply
   ```

3. **Verify Deployment:**
   ```bash
   terragrunt output
   ```

## 🌐 Configuration

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `cloudflare_account_id` | Cloudflare account identifier | `abc123def456...` |
| `cloudflare_token_secret_arn` | AWS Secret ARN containing Cloudflare API token | `arn:aws:secretsmanager:...` |
| `zone_id` | Cloudflare DNS zone ID | `xyz789abc123...` |
| `vpc_id` | Target VPC for private access | `vpc-0123456789abcdef0` |
| `vpc_cidr` | VPC CIDR block to route traffic to | `10.0.0.0/16` |
| `subnet_id` | Public subnet for jump host | `subnet-0123456789abcdef0` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `instance_type` | EC2 instance type for jump host | `t3.micro` |
| `identifier` | Unique identifier for resource naming | - |
| `tags` | Resource tags | `{}` |

### Cloudflare API Token Requirements

The Cloudflare API token must have the following permissions:
- **Zone:Read** - Access to zone information
- **Account:Read** - Access to account details  
- **Cloudflare Tunnel:Edit** - Create and manage tunnels
- **Access:Edit** - Configure Zero Trust policies

## 📋 Features

### Security Features
- ✅ **Zero Trust Architecture**: No traditional VPN infrastructure required
- ✅ **Identity-Based Access**: Integration with Cloudflare Access policies
- ✅ **Encrypted Tunnels**: All traffic encrypted end-to-end
- ✅ **Minimal Attack Surface**: No inbound ports except cloudflared tunnel
- ✅ **Automated Key Management**: SSH keys auto-generated and stored securely
- ✅ **Least Privilege IAM**: Minimal AWS permissions for operation

### Network Features
- ✅ **WARP Routing**: Direct routing from WARP clients to private networks
- ✅ **Private Network Access**: Access to any resource in VPC CIDR
- ✅ **Automatic Discovery**: No manual route configuration required
- ✅ **High Availability**: Cloudflare's global edge network
- ✅ **Performance Optimization**: Traffic routed through nearest edge location

### Operational Features
- ✅ **Infrastructure as Code**: Complete Terraform/Terragrunt automation
- ✅ **Secret Management**: Automated secret generation and storage
- ✅ **Service Integration**: Cloudflared runs as systemd service
- ✅ **Monitoring Ready**: Structured logging and service status
- ✅ **Multi-Environment**: Support for dev/staging/prod deployments

## 🔧 Usage

### Accessing Private Resources

1. **Install Cloudflare WARP Client:**
   - Download from [Cloudflare WARP](https://1.1.1.1/)
   - Configure for your organization

2. **Connect Through WARP:**
   ```bash
   # WARP automatically routes traffic to private networks
   # No additional configuration needed
   ```

3. **Access Jump Host via SSH:**
   ```bash
   # Retrieve SSH key
   aws secretsmanager get-secret-value \
     --secret-id "dev-cloudflare-routing/private-key" \
     --query SecretString --output text > key.pem
   chmod 600 key.pem
   
   # Connect to jump host (private IP accessible through WARP)
   ssh -i key.pem ubuntu@10.0.1.100
   ```

4. **Access Other VPC Resources:**
   ```bash
   # From WARP client, directly access any VPC resource
   curl http://10.0.2.50:8080/api/health
   ssh user@10.0.3.10
   ```

### Setting Up Zero Trust Policies

1. **Create Device Enrollment Rules:**
   ```javascript
   // Cloudflare Zero Trust Dashboard > Settings > WARP Client
   // Configure device enrollment policies
   ```

2. **Configure Network Policies:**
   ```javascript
   // Zero Trust Dashboard > Gateway > Firewall policies
   // Control access to specific private networks
   ```

## 📊 Outputs

The module provides the following outputs:

| Output | Description |
|--------|-------------|
| `tunnel_id` | Cloudflare tunnel identifier |
| `tunnel_token` | Tunnel authentication token (sensitive) |
| `jump_host_id` | EC2 instance ID |
| `jump_host_private_ip` | Private IP address of jump host |
| `jump_host_public_ip` | Public IP address of jump host |
| `ssh_key_secret_name` | AWS Secret name containing SSH private key |
| `ssh_connection_command` | Ready-to-use SSH connection command |

## 🔍 Monitoring & Troubleshooting

### Service Status Checks

```bash
# Check cloudflared service on jump host
ssh -i key.pem ubuntu@<jump-host-ip>
sudo systemctl status cloudflared

# View cloudflared logs
sudo journalctl -u cloudflared -f

# Check tunnel connectivity
sudo cloudflared tunnel info <tunnel-id>
```

### Common Issues

#### Tunnel Connection Issues
1. **Tunnel not connecting**: Check AWS security groups and egress rules
2. **Authentication failures**: Verify Cloudflare API token permissions
3. **Route not working**: Ensure VPC CIDR is correctly configured

#### Access Issues
1. **Can't reach private resources**: Verify WARP client is connected
2. **SSH key not working**: Check AWS Secrets Manager permissions
3. **DNS resolution**: Ensure proper DNS configuration in VPC

### Debug Commands

```bash
# Check tunnel status from Cloudflare
cloudflared tunnel list

# Test connectivity from jump host
ping 8.8.8.8  # Internet connectivity
curl -v https://api.cloudflare.com/client/v4/accounts/<account-id>

# Check AWS permissions
aws sts get-caller-identity
aws secretsmanager describe-secret --secret-id <secret-name>
```

## 🔧 Customization

### Adding Custom Routes

Modify the tunnel configuration to add additional private networks:

```hcl
resource "cloudflare_zero_trust_tunnel_cloudflared_route" "additional_network" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.tunnel_cloudflared.id
  network    = "192.168.0.0/16"
  comment    = "Additional private network"
}
```

### Custom User Data Script

Extend the `user_data.sh` script for additional software installation:

```bash
# Add to user_data/user_data.sh
echo "Installing additional tools..."
apt-get install -y docker.io kubectl helm
```

### Security Group Modifications

Add additional ports or restrict access:

```hcl
resource "aws_security_group_rule" "custom_rule" {
  type              = "ingress"
  from_port         = 8080
  to_port           = 8080
  protocol          = "tcp"
  cidr_blocks       = [var.vpc_cidr]
  security_group_id = aws_security_group.jump_host.id
}
```

## 📚 Documentation

### Official Documentation
- [Cloudflare Zero Trust](https://developers.cloudflare.com/cloudflare-one/)
- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
- [WARP Client Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-devices/)
- [Terraform Cloudflare Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest)

### Local Configuration Files
- [Main Configuration](./main.tf)
- [Variables Definition](./variables.tf)
- [Outputs Definition](./outputs.tf)
- [Terragrunt Configuration](./terragrunt.hcl)
- [User Data Script](./user_data/user_data.sh)

### Multi-Environment Support
- Environment-specific configurations through Terragrunt
- Separate tunnels per environment (dev/staging/prod)
- Environment-specific access policies

### Compliance & Governance
- All network traffic logged and auditable
- Identity-based access with user attribution
- Integration with corporate identity providers
- Compliance with zero trust security model

### Cost Optimization
- Use t3.micro instances for basic routing needs
- Scale instance size based on throughput requirements
- Leverage Cloudflare's global infrastructure for performance
