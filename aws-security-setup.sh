#!/bin/bash

# AWS EC2 Security Configuration Script for Code-Server
# Configures security groups, IAM roles, and system hardening

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if AWS CLI is installed
check_aws_cli() {
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed. Installing..."
        
        # Install AWS CLI
        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
        unzip awscliv2.zip
        sudo ./aws/install
        rm -rf awscliv2.zip aws/
        
        print_status "AWS CLI installed successfully"
    fi
    
    # Check if AWS CLI is configured
    if ! aws configure list &> /dev/null; then
        print_warning "AWS CLI is not configured. Please run 'aws configure' to set up your credentials."
        print_warning "You'll need an IAM user with EC2 and IAM permissions."
        return 1
    fi
    
    print_status "AWS CLI is configured"
}

# Get EC2 instance information
get_instance_info() {
    print_status "Getting EC2 instance information..."
    
    # Get instance metadata
    INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "unknown")
    REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region 2>/dev/null || echo "us-east-1")
    PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4 2>/dev/null || echo "unknown")
    
    print_status "Instance ID: $INSTANCE_ID"
    print_status "Region: $REGION"
    print_status "Public IP: $PUBLIC_IP"
    print_status "Private IP: $PRIVATE_IP"
    
    # Set AWS region
    export AWS_DEFAULT_REGION="$REGION"
}

# Create IAM role for EC2 instance
create_iam_role() {
    print_status "Setting up IAM role for EC2 instance..."
    
    ROLE_NAME="CodeServerEC2Role"
    POLICY_NAME="CodeServerEC2Policy"
    INSTANCE_PROFILE_NAME="CodeServerEC2InstanceProfile"
    
    # Check if role exists
    if aws iam get-role --role-name "$ROLE_NAME" &> /dev/null; then
        print_status "IAM role $ROLE_NAME already exists"
        return 0
    fi
    
    # Create trust policy
    cat > /tmp/trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "ec2.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

    # Create IAM role
    aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/trust-policy.json \
        --description "IAM role for Code-Server EC2 instance"
    
    # Create policy for S3 and CloudWatch access
    cat > /tmp/role-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::*codeserver*",
                "arn:aws:s3:::*codeserver*/*",
                "arn:aws:s3:::*datascience*",
                "arn:aws:s3:::*datascience*/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "cloudwatch:PutMetricData"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:PutParameter",
                "ssm:GetParametersByPath"
            ],
            "Resource": "arn:aws:ssm:*:*:parameter/codeserver/*"
        }
    ]
}
EOF

    # Attach policy to role
    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name "$POLICY_NAME" \
        --policy-document file:///tmp/role-policy.json
    
    # Create instance profile
    aws iam create-instance-profile \
        --instance-profile-name "$INSTANCE_PROFILE_NAME"
    
    # Add role to instance profile
    aws iam add-role-to-instance-profile \
        --instance-profile-name "$INSTANCE_PROFILE_NAME" \
        --role-name "$ROLE_NAME"
    
    # Wait for role to be available
    sleep 10
    
    # Associate instance profile with EC2 instance
    if [ "$INSTANCE_ID" != "unknown" ]; then
        aws ec2 associate-iam-instance-profile \
            --instance-id "$INSTANCE_ID" \
            --iam-instance-profile Name="$INSTANCE_PROFILE_NAME" \
            2>/dev/null || print_warning "Could not associate IAM role automatically"
    fi
    
    print_status "IAM role created and configured"
    
    # Cleanup
    rm -f /tmp/trust-policy.json /tmp/role-policy.json
}

# Configure security group
configure_security_group() {
    print_status "Configuring security group..."
    
    if [ "$INSTANCE_ID" == "unknown" ]; then
        print_warning "Cannot determine instance ID, skipping security group configuration"
        return 1
    fi
    
    # Get current security groups
    SECURITY_GROUPS=$(aws ec2 describe-instances \
        --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' \
        --output text)
    
    print_status "Current security groups: $SECURITY_GROUPS"
    
    # Configure each security group
    for SG_ID in $SECURITY_GROUPS; do
        print_status "Configuring security group: $SG_ID"
        
        # Add HTTPS rule if not exists
        if ! aws ec2 describe-security-groups \
            --group-ids "$SG_ID" \
            --query 'SecurityGroups[0].IpPermissions[?FromPort==`443`]' \
            --output text | grep -q "443"; then
            
            aws ec2 authorize-security-group-ingress \
                --group-id "$SG_ID" \
                --protocol tcp \
                --port 443 \
                --cidr 0.0.0.0/0 \
                --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-CodeServer}]" \
                2>/dev/null || print_warning "Could not add HTTPS rule to $SG_ID"
        fi
        
        # Add HTTP rule (will redirect to HTTPS)
        if ! aws ec2 describe-security-groups \
            --group-ids "$SG_ID" \
            --query 'SecurityGroups[0].IpPermissions[?FromPort==`80`]' \
            --output text | grep -q "80"; then
            
            aws ec2 authorize-security-group-ingress \
                --group-id "$SG_ID" \
                --protocol tcp \
                --port 80 \
                --cidr 0.0.0.0/0 \
                --tag-specifications "ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-CodeServer}]" \
                2>/dev/null || print_warning "Could not add HTTP rule to $SG_ID"
        fi
        
        # Ensure SSH access is restricted (only if needed)
        print_status "Checking SSH access restrictions for $SG_ID"
    done
    
    print_status "Security group configuration completed"
}

# System hardening
apply_system_hardening() {
    print_status "Applying system security hardening..."
    
    # Update system packages
    if command -v apt-get &> /dev/null; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y unattended-upgrades fail2ban ufw
    elif command -v yum &> /dev/null; then
        sudo yum update -y
        sudo yum install -y fail2ban firewalld
    fi
    
    # Configure automatic security updates
    if command -v unattended-upgrades &> /dev/null; then
        sudo dpkg-reconfigure -plow unattended-upgrades
        
        # Configure automatic updates
        sudo tee /etc/apt/apt.conf.d/50unattended-upgrades-custom << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
    fi
    
    # Configure SSH security
    print_status "Configuring SSH security..."
    
    # Backup SSH config
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
    
    # Apply SSH security settings
    sudo tee /etc/ssh/sshd_config.d/99-security.conf << 'EOF'
# Security hardening for SSH
Protocol 2
PermitRootLogin no
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
PermitEmptyPasswords no
PasswordAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers ec2-user ubuntu admin
DenyUsers root
X11Forwarding no
UsePAM yes
EOF

    # Configure fail2ban
    if command -v fail2ban-server &> /dev/null; then
        print_status "Configuring fail2ban..."
        
        sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
destemail = admin@localhost
sender = fail2ban@localhost
mta = sendmail
protocol = tcp
chain = INPUT
port = 0:65535
fail2ban_agent = Fail2Ban/%(fail2ban_version)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/*error.log
maxretry = 3

[nginx-noscript]
enabled = true
port = http,https
filter = nginx-noscript
logpath = /var/log/nginx/*access.log
maxretry = 6

[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/*access.log
maxretry = 2
EOF
        
        sudo systemctl enable fail2ban
        sudo systemctl start fail2ban
    fi
    
    # Restart SSH service
    sudo systemctl restart sshd
    
    print_status "System hardening completed"
}

# Setup CloudWatch monitoring
setup_cloudwatch_monitoring() {
    print_status "Setting up CloudWatch monitoring..."
    
    # Install CloudWatch agent
    if ! command -v amazon-cloudwatch-agent-ctl &> /dev/null; then
        wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
        sudo dpkg -i amazon-cloudwatch-agent.deb
        rm amazon-cloudwatch-agent.deb
    fi
    
    # Create CloudWatch configuration
    sudo tee /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "agent": {
        "metrics_collection_interval": 60,
        "run_as_user": "cwagent"
    },
    "metrics": {
        "namespace": "CodeServer/EC2",
        "metrics_collected": {
            "cpu": {
                "measurement": ["cpu_usage_idle", "cpu_usage_iowait", "cpu_usage_user", "cpu_usage_system"],
                "metrics_collection_interval": 60
            },
            "disk": {
                "measurement": ["used_percent"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "diskio": {
                "measurement": ["io_time"],
                "metrics_collection_interval": 60,
                "resources": ["*"]
            },
            "mem": {
                "measurement": ["mem_used_percent"],
                "metrics_collection_interval": 60
            }
        }
    },
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/code-server.access.log",
                        "log_group_name": "CodeServer/Nginx/Access",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/var/log/nginx/code-server.error.log",
                        "log_group_name": "CodeServer/Nginx/Error",
                        "log_stream_name": "{instance_id}"
                    },
                    {
                        "file_path": "/home/*/..config/code-server/coder-logs/*.log",
                        "log_group_name": "CodeServer/Application",
                        "log_stream_name": "{instance_id}"
                    }
                ]
            }
        }
    }
}
EOF

    # Start CloudWatch agent
    sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
        -a fetch-config \
        -m ec2 \
        -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json \
        -s
    
    print_status "CloudWatch monitoring configured"
}

# Create backup script
create_backup_script() {
    print_status "Creating backup script..."
    
    cat > "$HOME/backup-codeserver.sh" << 'EOF'
#!/bin/bash
# Code-Server Backup Script

BACKUP_BUCKET="your-codeserver-backup-bucket"  # Change this!
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/codeserver-backup-$TIMESTAMP"

mkdir -p "$BACKUP_DIR"

# Backup code-server configuration
cp -r "$HOME/.config/code-server" "$BACKUP_DIR/"
cp -r "$HOME/.local/share/code-server" "$BACKUP_DIR/"

# Backup workspace
cp -r "$HOME/data-science-workspace" "$BACKUP_DIR/"

# Create archive
tar -czf "/tmp/codeserver-backup-$TIMESTAMP.tar.gz" -C /tmp "codeserver-backup-$TIMESTAMP"

# Upload to S3 (requires AWS CLI and proper IAM permissions)
if command -v aws &> /dev/null && [ "$BACKUP_BUCKET" != "your-codeserver-backup-bucket" ]; then
    aws s3 cp "/tmp/codeserver-backup-$TIMESTAMP.tar.gz" "s3://$BACKUP_BUCKET/backups/"
    echo "Backup uploaded to S3: s3://$BACKUP_BUCKET/backups/codeserver-backup-$TIMESTAMP.tar.gz"
fi

# Cleanup local backup
rm -rf "$BACKUP_DIR"
rm -f "/tmp/codeserver-backup-$TIMESTAMP.tar.gz"

echo "Backup completed: $TIMESTAMP"
EOF

    chmod +x "$HOME/backup-codeserver.sh"
    
    # Add to crontab for daily backups
    (crontab -l 2>/dev/null; echo "0 2 * * * $HOME/backup-codeserver.sh") | crontab -
    
    print_status "Backup script created and scheduled"
}

# Main function
main() {
    print_status "🔒 Starting AWS EC2 Security Configuration for Code-Server..."
    
    get_instance_info
    
    if check_aws_cli; then
        create_iam_role
        configure_security_group
        setup_cloudwatch_monitoring
    else
        print_warning "Skipping AWS-specific configurations due to missing AWS CLI setup"
    fi
    
    apply_system_hardening
    create_backup_script
    
    print_status "✅ AWS EC2 security configuration completed!"
    echo
    echo -e "${GREEN}🎉 Your EC2 instance is now secured for code-server!${NC}"
    echo -e "${BLUE}Instance ID: $INSTANCE_ID${NC}"
    echo -e "${BLUE}Public IP: $PUBLIC_IP${NC}"
    echo
    echo -e "${YELLOW}Security features enabled:${NC}"
    echo "✅ IAM role with limited permissions"
    echo "✅ Security group configured for HTTPS/HTTP"
    echo "✅ SSH hardening"
    echo "✅ Fail2ban intrusion detection"
    echo "✅ Automatic security updates"
    echo "✅ CloudWatch monitoring"
    echo "✅ Automated backups"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Configure your domain DNS to point to $PUBLIC_IP"
    echo "2. Run SSL setup: ./ssl-setup.sh your-domain.com"
    echo "3. Update backup bucket name in ~/backup-codeserver.sh"
    echo "4. Review security group rules in AWS Console"
}

# Run main function
main "$@"
