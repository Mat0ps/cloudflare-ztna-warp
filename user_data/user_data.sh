#!/bin/bash
set -e  # Exit on any error
exec > >(tee /var/log/user-data.log) 2>&1  # Log all output

echo "Starting user_data script execution at $(date)"

# Configure AWS CLI with region
export AWS_DEFAULT_REGION=${aws_region}

# Update and install required packages for Ubuntu
echo "Installing required packages..."
apt-get update
apt-get install -y awscli jq curl python3-pip

# Enable IP forwarding for routing functionality
echo "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
echo 'net.ipv6.conf.all.forwarding=1' >> /etc/sysctl.conf
sysctl -p

# Install kubectl
echo "Installing kubectl..."
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Install Cloudflared on Ubuntu
echo "Installing Cloudflared..."
# Add cloudflare gpg key
mkdir -p --mode=0755 /usr/share/keyrings
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null

# Add this repo to your apt repositories
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | tee /etc/apt/sources.list.d/cloudflared.list

# Install cloudflared
apt-get update
apt-get install -y cloudflared

# Wait for AWS credentials to be available
echo "Waiting for AWS credentials..."
while ! aws sts get-caller-identity >/dev/null 2>&1; do
    echo "Waiting for AWS credentials to become available..."
    sleep 10
done

echo "AWS credentials available, proceeding with Secrets Manager access..."

# Get tunnel token from Secrets Manager with retry logic
echo "Retrieving tunnel token from Secrets Manager..."
max_retries=5
retry_count=0
while [ $retry_count -lt $max_retries ]; do
    if TUNNEL_TOKEN=$(aws secretsmanager get-secret-value --secret-id ${identifier}/cloudflare-tunnel-routing-token --region ${aws_region} --query SecretString --output text | jq -r '.tunnel_token' 2>/dev/null); then
        echo "Successfully retrieved tunnel token"
        break
    else
        retry_count=$((retry_count + 1))
        echo "Failed to retrieve tunnel token, attempt $retry_count/$max_retries"
        if [ $retry_count -eq $max_retries ]; then
            echo "Failed to retrieve tunnel token after $max_retries attempts"
            exit 1
        fi
        sleep 30
    fi
done

# Create Cloudflared config directory
echo "Creating Cloudflared configuration..."
mkdir -p /etc/cloudflared

# Create Cloudflared config file
cat > /etc/cloudflared/config.yml << 'EOF'
tunnel: ${tunnel_id}
credentials-file: /etc/cloudflared/credentials.json
warp-routing:
  enabled: true
EOF

# Create credentials file
cat > /etc/cloudflared/credentials.json << 'EOF'
{
  "AccountTag": "${cloudflare_account_id}",
  "TunnelSecret": "${tunnel_secret_b64}",
  "TunnelID": "${tunnel_id}"
}
EOF

# Set proper permissions
echo "Setting file permissions..."
chmod 600 /etc/cloudflared/credentials.json
chown root:root /etc/cloudflared/credentials.json

# Setup Cloudflared as a service
echo "Setting up Cloudflared service..."
cloudflared service install
systemctl enable cloudflared
systemctl start cloudflared

# Verify service status
echo "Cloudflared service status:"
systemctl status cloudflared --no-pager

echo "User_data script completed successfully at $(date)" 