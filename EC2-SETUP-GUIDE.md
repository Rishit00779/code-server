# AWS EC2 Instance Setup Guide for Code-Server Data Science

This guide walks you through creating and configuring an AWS EC2 instance optimized for the code-server data science environment.

## 🚀 Quick Setup Checklist

- [ ] AWS account with billing configured
- [ ] Domain name (optional but recommended for SSL)
- [ ] SSH key pair for secure access
- [ ] Basic understanding of AWS EC2

## 📋 Step-by-Step EC2 Instance Creation

### Step 1: Launch EC2 Instance

1. **Sign in to AWS Console**
   - Go to [AWS Console](https://console.aws.amazon.com/)
   - Navigate to EC2 Dashboard

2. **Launch Instance**
   - Click "Launch Instance"
   - Name your instance: `codeserver-datascience`

### Step 2: Choose AMI (Amazon Machine Image)

**Recommended Options:**

#### Option A: Ubuntu 22.04 LTS (Recommended)
- **AMI**: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
- **AMI ID**: `ami-0c7217cdde317cfec` (us-east-1)
- **Why**: Excellent package support, well-documented, stable

#### Option B: Amazon Linux 2023
- **AMI**: Amazon Linux 2023 AMI
- **Why**: Optimized for AWS, good performance, free tier eligible

### Step 3: Choose Instance Type

**Recommended Instance Types:**

| Instance Type | vCPU | RAM | Storage | Price/Hour* | Best For |
|---------------|------|-----|---------|-------------|----------|
| **t3.medium** | 2 | 4 GB | EBS | ~$0.042 | Light data science, learning |
| **t3.large** | 2 | 8 GB | EBS | ~$0.083 | **Recommended for most users** |
| **t3.xlarge** | 4 | 16 GB | EBS | ~$0.166 | Heavy workloads, large datasets |
| **m5.large** | 2 | 8 GB | EBS | ~$0.096 | Consistent performance |
| **m5.xlarge** | 4 | 16 GB | EBS | ~$0.192 | Production workloads |

*Prices are approximate and vary by region

**💡 Recommendation: t3.large** - Best balance of performance and cost

### Step 4: Configure Key Pair

1. **Create New Key Pair** (if you don't have one)
   - Key pair name: `codeserver-datascience-key-pair.pem`
   - Key pair type: RSA
   - Private key format: `.pem`
   - **Download and save** the `.pem` file securely

2. **Set Permissions**
Do in ./~ssh/ folder

  **Linux/Mac:**
      ```bash
      chmod 400 codeserver-datascience-key-pair.pem
      ```
      **Important:** This sets the file to be readable only by the owner, which is the strictest and most secure permission for SSH private keys. Avoid using permissions like 0555 (readable by everyone), as they are too open and pose a security risk.
- **Windows:**
    - If using Windows Subsystem for Linux (WSL), run the same `chmod` command above inside your WSL terminal.
    - If using PuTTY, permissions are handled by PuTTY and Windows, so you do not need to set permissions on the `.pem` file. Just ensure the file is stored securely and not accessible to others.




### Step 5: Network Settings (Security Groups)

**Create New Security Group:**

```
Security Group Name: codeserver-sg
Description: Security group for code-server data science setup

Inbound Rules:
┌─────────────────────────────────────────────────────────┐
│ Type        │ Protocol │ Port │ Source    │ Description │
├─────────────────────────────────────────────────────────┤
│ SSH         │ TCP      │ 22   │ My IP     │ SSH access  │
│ HTTP        │ TCP      │ 80   │ 0.0.0.0/0 │ Web access  │
│ HTTPS       │ TCP      │ 443  │ 0.0.0.0/0 │ SSL access  │
│ Custom TCP  │ TCP      │ 8080 │ My IP     │ Code-server │
└─────────────────────────────────────────────────────────┘
```

**Important Notes:**
- Replace "My IP" with your current IP address for SSH and port 8080
- Port 8080 rule is temporary - remove after SSL setup
- Never use 0.0.0.0/0 for SSH (port 22)

### How to Find Your IP Address ("My IP")

You need your public IP address to restrict SSH and code-server access in your security group rules.

#### Option 1: Use a Web Service

Open your terminal and run:

```bash
curl ifconfig.me
```
or
```bash
curl https://checkip.amazonaws.com
```

#### Option 2: Search in Your Browser

Go to [https://whatismyipaddress.com/](https://whatismyipaddress.com/) or search "what is my IP" in Google.

**Tip:** If your ISP uses dynamic IPs, your address may change. Update your security group if you lose access.

### Step 6: Configure Storage

**Recommended Storage Configuration:**

```
Storage Type: gp3 (General Purpose SSD)
Size: 30 GB (minimum) - 50 GB (recommended)
IOPS: 3000 (default)
Throughput: 125 MB/s (default)
Encryption: Enabled (recommended)
Delete on Termination: Yes
```

**For Heavy Data Science Work:**
- Size: 100+ GB
- Consider adding additional EBS volumes for data

### Step 7: Advanced Details (Optional but Recommended)

### IAM Role: Minimal Permissions Setup

To follow the principle of least privilege, create an IAM role with only the permissions required for code-server setup and monitoring. This role will be attached to your EC2 instance.

#### 1. Create IAM Role

1. Go to the [IAM Console](https://console.aws.amazon.com/iam/).
2. Click **Roles** > **Create role**.
3. Select **AWS service** > **EC2**.
4. Click **Next**.

```iam role json

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
```

#### 2. Attach Minimal Policy

Click **Create policy** and use the following JSON for a minimal set of permissions (adjust as needed for your use case):
```policy json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "AllowCloudWatchAndEC2Describe",
            "Effect": "Allow",
            "Action": [
                "cloudwatch:PutMetricData",
                "cloudwatch:GetMetricStatistics",
                "cloudwatch:ListMetrics",
                "ec2:DescribeInstances",
                "ec2:DescribeVolumes",
                "ec2:DescribeTags",
                "ec2:DescribeSecurityGroups",
                "logs:PutLogEvents",
                "logs:CreateLogGroup",
                "logs:CreateLogStream"
            ],
            "Resource": "*"
        }
    ]
}

```

- Name the policy (e.g., `CodeServerMinimalEC2Policy`).
- Attach this policy to your new role.

#### 3. Attach Role to Instance

#### 3. Attach Role to Instance

1. In the EC2 Console, select your instance.
2. Click **Actions** > **Security** > **Modify IAM Role**.
3. If your newly created role doesn't appear in the list:
   - Verify the role was created successfully in the IAM console
   - Ensure the role has EC2 as a trusted entity
   - Try refreshing the page or clearing browser cache
   - Wait a few minutes as IAM changes can take time to propagate
4. Alternative: Create the role during instance launch
   - If starting a new instance, create the role in advance
   - Select it from the dropdown in the "Advanced details" section

> **Note:** Our `aws-security-setup.sh` script will further configure permissions as needed.

> **Note:** Our `aws-security-setup.sh` script will further configure permissions as needed.

- Leave empty for now - our `aws-security-setup.sh` will handle this

#### User Data Script (Optional)
Add this to automatically update the system on first boot:

```bash
#!/bin/bash
apt update && apt upgrade -y
```

### Step 8: Launch Instance

1. **Review** all settings
2. **Launch** the instance
3. **Note down** the Instance ID and Public IP

---

## 🔗 Connect to Your Instance

### Method 1: SSH (Recommended)

#### For Linux/Mac:
```bash
# Connect to instance
ssh -i "codeserver-key.pem" ubuntu@YOUR_PUBLIC_IP

# Or create SSH config for easier access
cat >> ~/.ssh/config << EOF
Host codeserver
    HostName YOUR_PUBLIC_IP
    User ubuntu
    IdentityFile ~/path/to/codeserver-key.pem
    ServerAliveInterval 60
EOF

# Then connect simply with:
ssh codeserver
```

#### For Windows:
1. **Option A**: Use Windows Subsystem for Linux (WSL)
2. **Option B**: Use PuTTY
   - Convert `.pem` to `.ppk` using PuTTYgen
   - Use `ec2-user@YOUR_PUBLIC_IP` as hostname
3. **Option C**: Use Windows Terminal with OpenSSH

### Method 2: EC2 Instance Connect (Browser-based)
1. Go to EC2 Console
2. Select your instance
3. Click "Connect"
4. Choose "EC2 Instance Connect"

---

## 🛠 Initial Server Setup

Once connected, run these commands:

```bash
# Update system packages
sudo yum update -y

# Install essential tools
sudo yum install -y curl wget git unzip htop

# Create workspace directory
mkdir -p ~/workspace

# Download the code-server setup files
# Option 1: If you have the files locally, upload them:
# scp -i codeserver-datascience-key-pair.pem -r code-server/ ubuntu@YOUR_PUBLIC_IP:~/

# Option 2: Clone from repository (if you've pushed to GitHub)
# git clone https://github.com/yourusername/code-server-setup.git

# Option 3: Create the files manually using the setup we created
```

---

## 🌐 Domain Setup (Optional but Recommended)

### Step 1: Purchase/Configure Domain
1. Purchase domain from Route 53, Namecheap, etc.
2. Get your EC2 instance's **Elastic IP** (recommended for stability)

### Step 2: Create Elastic IP
```bash
# In AWS Console:
# EC2 → Network & Security → Elastic IPs
# → Allocate Elastic IP address
# → Associate with your instance
```

### Step 3: Configure DNS
Create an **A record** pointing your domain to the Elastic IP:

```
Type: A
Name: @ (for root domain) or codeserver (for subdomain)
Value: YOUR_ELASTIC_IP
TTL: 300
```

### Step 4: Wait for DNS Propagation
```bash
# Test DNS resolution
nslookup your-domain.com
dig +short your-domain.com
```

---

## 🚀 Install Code-Server

Now you can run the setup scripts:

```bash
# Make scripts executable
chmod +x *.sh

# Run interactive setup
./setup.sh

# Or run individual scripts:
# ./install-code-server.sh
# ./install-extensions.sh
# ./aws-security-setup.sh
# ./ssl-setup.sh your-domain.com your-email@domain.com
```

---

## 💰 Cost Optimization Tips

### 1. Instance Scheduling
```bash
# Create stop/start scripts for non-24/7 usage
# Stop instance when not in use (you only pay for storage)

# AWS CLI commands:
aws ec2 stop-instances --instance-ids i-1234567890abcdef0
aws ec2 start-instances --instance-ids i-1234567890abcdef0
```

### 2. Spot Instances (Advanced)
- Save up to 90% compared to On-Demand pricing
- Risk: Can be terminated with 2-minute notice
- Good for: Non-critical development work

### 3. Reserved Instances
- Save up to 75% for predictable, long-term usage
- Commit to 1 or 3 years
- Good for: Production environments

### 4. Right-Sizing
- Monitor CPU/memory usage with CloudWatch
- Scale down if consistently underutilized
- Scale up only when needed

---

## 🔒 Security Best Practices

### 1. SSH Key Management
```bash
# Generate a new key pair specifically for this instance
ssh-keygen -t rsa -b 4096 -f ~/.ssh/codeserver_rsa

# Add public key to instance
ssh-copy-id -i ~/.ssh/codeserver_rsa.pub ubuntu@YOUR_PUBLIC_IP
```

### 2. Security Group Rules
- **Principle of Least Privilege**: Only open necessary ports
- **Source Restrictions**: Use specific IPs instead of 0.0.0.0/0
- **Regular Audits**: Review and remove unused rules

### 3. System Updates
```bash
# Enable automatic security updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### 4. Monitoring
- Enable CloudWatch monitoring
- Set up billing alerts
- Monitor login attempts

---

## 📊 Monitoring Your Instance

### CloudWatch Metrics to Monitor:
- **CPU Utilization**: Should be < 80% normally
- **Memory Utilization**: Monitor for memory leaks
- **Disk Space**: Set alert at 80% full
- **Network In/Out**: Monitor for unusual traffic

### Set Up Billing Alerts:
1. AWS Console → Billing → Billing preferences
2. Enable "Receive Billing Alerts"
3. CloudWatch → Alarms → Create Alarm
4. Select "Billing" metric

---

## 🔧 Troubleshooting EC2 Issues

### Instance Won't Start
```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids i-1234567890abcdef0

# View system logs
# EC2 Console → Instance → Actions → Monitor and troubleshoot → Get system log
```

### Can't Connect via SSH
```bash
# Check security group allows SSH from your IP
# Check key pair is correct
# Try EC2 Instance Connect as alternative
```

### Performance Issues
```bash
# Check instance metrics in CloudWatch
# Consider upgrading instance type
# Check for CPU credits (t3 instances)
```

---

## 📝 Instance Configuration Checklist

After launching, verify:

- [ ] ✅ Instance is running
- [ ] ✅ Security group configured correctly  
- [ ] ✅ SSH access working
- [ ] ✅ Elastic IP associated (if using domain)
- [ ] ✅ Domain DNS pointing to instance
- [ ] ✅ System packages updated
- [ ] ✅ Code-server setup files uploaded
- [ ] ✅ Setup scripts executable
- [ ] ✅ Ready to run `./setup.sh`

---

## 💡 Pro Tips

1. **Use Session Manager**: Instead of SSH, consider AWS Systems Manager Session Manager for browser-based terminal access without exposing SSH port.

2. **Backup Strategy**: 
   - Create AMI snapshots regularly
   - Use EBS snapshots for data volumes
   - Configure automated backups

3. **Multi-AZ**: For production, consider running instances in multiple availability zones.

4. **Load Balancer**: For high availability, use Application Load Balancer with multiple instances.

5. **Auto Scaling**: Set up Auto Scaling groups for automatic scaling based on demand.

---

**🎉 You're now ready to launch your EC2 instance and install the code-server data science environment!**

For the next steps, follow the main README.md after your instance is running.
