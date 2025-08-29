# Troubleshooting Guide for Code-Server Data Science Setup

This guide helps you resolve common issues during and after the code-server installation.

## 🔍 General Troubleshooting

### Check System Status
```bash
# Check if code-server is running
systemctl --user status code-server

# View service logs
journalctl --user -u code-server -f

# Check configuration
cat ~/.config/code-server/config.yaml
```

### Network Connectivity
```bash
# Test local access
curl http://localhost:8080

# Check if port is listening
netstat -tlnp | grep 8080

# Test external connectivity (if applicable)
curl -I http://your-public-ip:8080
```

## 🚨 Installation Issues

### Script Permission Denied
```bash
# Make scripts executable
chmod +x *.sh

# Or for individual scripts
chmod +x install-code-server.sh
```

### curl-minimal Package Error (Amazon Linux)
If you see an error like:
```
Problem: problem with installed package curl-minimal-8.11.1-4.amzn2023.0.1.x86_64
```
Try the following steps:
```bash
# Clean yum/dnf cache
sudo dnf clean all

# Update all packages
sudo dnf update -y

# Reinstall curl and dependencies
sudo dnf reinstall curl curl-minimal -y

# If the problem persists, remove and install again
sudo dnf remove curl curl-minimal -y
sudo dnf install curl -y
```
If you still have issues, check for broken dependencies:
```bash
sudo dnf check
sudo dnf repoquery --unsatisfied
```
Refer to the latest Amazon Linux release notes or open an issue with the exact error message.

### Sudo Password Prompts
```bash
# Configure sudo timeout (optional)
sudo visudo
# Add: Defaults timestamp_timeout=60
```

### Package Installation Failures

#### Ubuntu/Debian
```bash
# Update package lists
sudo apt update

# Fix broken packages
sudo apt --fix-broken install

# Clean package cache
sudo apt clean && sudo apt autoclean
```

#### CentOS/RHEL
```bash
# Update system
sudo yum update -y

# Clean cache
sudo yum clean all

# For newer versions
sudo dnf update -y
sudo dnf clean all
```

## 🐍 Python Environment Issues

### Conda Installation Problems
```bash
# Check if conda is in PATH
which conda

# Manually initialize conda
~/miniconda3/bin/conda init bash
source ~/.bashrc

# List environments
conda env list

# Remove and recreate environment
conda remove -n datascience --all
conda create -n datascience python=3.11
```

### Package Installation Errors
```bash
# Update conda
conda update conda

# Update pip
pip install --upgrade pip

# Force reinstall packages
conda install --force-reinstall package_name
```

### Kernel Issues in Jupyter
```bash
# Install ipykernel
conda activate datascience
pip install ipykernel

# Register kernel
python -m ipykernel install --user --name datascience --display-name "Data Science"

# List kernels
jupyter kernelspec list
```

## 🌐 Network and Access Issues

### Can't Access Code-Server

#### Local Access (localhost:8080)
```bash
# Check if service is running
systemctl --user is-active code-server

# Check configuration
grep bind-addr ~/.config/code-server/config.yaml

# Try restarting
systemctl --user restart code-server
```

#### External Access Issues
```bash
# Check firewall (Ubuntu)
sudo ufw status
sudo ufw allow 8080/tcp

# Check firewall (CentOS/RHEL)
sudo firewall-cmd --list-all
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

### AWS EC2 Specific Issues

#### Security Group Configuration
1. Go to EC2 Console → Security Groups
2. Select your instance's security group
3. Add inbound rules:
   - Type: Custom TCP, Port: 80, Source: 0.0.0.0/0
   - Type: Custom TCP, Port: 443, Source: 0.0.0.0/0
   - Type: Custom TCP, Port: 8080, Source: 0.0.0.0/0 (temporary)

#### Instance Connect Issues
```bash
# Check public IP
curl http://169.254.169.254/latest/meta-data/public-ipv4

# Check security groups
aws ec2 describe-instances --instance-ids i-1234567890abcdef0 \
  --query 'Reservations[0].Instances[0].SecurityGroups'

# Get instance ID automatically
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].SecurityGroups'
```

### EC2 Instance Creation and Connection Issues

#### SSH Connection Failures
```bash
# Check key permissions (must be 400)
chmod 400 your-key.pem
ls -la your-key.pem

# Test SSH connection with verbose output
ssh -v -i your-key.pem ubuntu@your-public-ip

# Try different users based on AMI:
# Ubuntu AMI: ubuntu
# Amazon Linux: ec2-user
# CentOS: centos
# Debian: admin
```

#### Security Group Configuration Issues
1. **Check Inbound Rules**: Ensure these ports are open
   ```
   SSH (22): Your IP only (not 0.0.0.0/0)
   HTTP (80): 0.0.0.0/0 (for Let's Encrypt)
   HTTPS (443): 0.0.0.0/0 (for web access)
   Custom TCP (8080): Your IP (temporary, for initial setup)
   ```

2. **Fix Security Group**:
   ```bash
   # Get your public IP
   MY_IP=$(curl -s ifconfig.me)/32
   
   # Get security group ID
   SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
     --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)
   
   # Add HTTP rule
   aws ec2 authorize-security-group-ingress --group-id $SG_ID \
     --protocol tcp --port 80 --cidr 0.0.0.0/0
   
   # Add HTTPS rule
   aws ec2 authorize-security-group-ingress --group-id $SG_ID \
     --protocol tcp --port 443 --cidr 0.0.0.0/0
   ```

#### Instance Size/Performance Issues
```bash
# Check instance type
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].InstanceType'

# Monitor CPU credits (for t3 instances)
aws cloudwatch get-metric-statistics --namespace AWS/EC2 \
  --metric-name CPUCreditBalance --dimensions Name=InstanceId,Value=$INSTANCE_ID \
  --start-time 2023-01-01T00:00:00Z --end-time 2023-01-02T00:00:00Z \
  --period 3600 --statistics Average

# Check memory usage
free -h
htop
```

#### Storage Issues
```bash
# Check disk space
df -h

# Check EBS volumes
lsblk
sudo fdisk -l

# Expand EBS volume if needed (after resizing in AWS Console)
sudo growpart /dev/xvda1 1
sudo resize2fs /dev/xvda1
```

#### Domain and DNS Issues
```bash
# Check if domain points to your instance
nslookup your-domain.com
dig +short your-domain.com

# Get your instance's public IP
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
  --query 'Reservations[0].Instances[0].PublicIpAddress'

# Test HTTP connectivity to domain
curl -I http://your-domain.com
curl -I https://your-domain.com
```

## 🔒 SSL and HTTPS Issues

### Certificate Generation Failures

#### Domain Not Pointing to Server
```bash
# Check DNS resolution
nslookup your-domain.com
dig +short your-domain.com

# Compare with server IP
curl -s ifconfig.me
```

#### Let's Encrypt Rate Limits
```bash
# Check certificate status
sudo certbot certificates

# Use staging environment for testing
sudo certbot --staging certonly --standalone -d your-domain.com
```

#### Firewall Blocking HTTP/HTTPS
```bash
# Check if ports are open
sudo netstat -tlnp | grep ':80\|:443'

# Allow HTTP/HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

### Nginx Configuration Issues
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# View nginx logs
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/code-server.error.log
```

### Certificate Renewal Issues
```bash
# Test renewal (dry run)
sudo certbot renew --dry-run

# Force renewal
sudo certbot renew --force-renewal

# Check cron job
crontab -l
sudo crontab -l
```

## 📊 Extension and VS Code Issues

### Extensions Won't Install
```bash
# Check extensions directory
ls -la ~/.local/share/code-server/extensions/

# Clear extension cache
rm -rf ~/.local/share/code-server/CachedExtensions/

# Install manually
code-server --install-extension ms-python.python --force
```

### Python Extension Not Working
```bash
# Check Python interpreter
which python
conda activate datascience && which python

# Reload VS Code window
# Command palette: Developer: Reload Window

# Check Python extension logs
# View → Output → Python
```

### Jupyter Extension Issues
```bash
# Check Jupyter installation
jupyter --version
jupyter kernelspec list

# Start Jupyter manually
jupyter lab --port=8888 --no-browser

# Check if kernel is accessible
python -c "import jupyter_core; print(jupyter_core.paths.jupyter_runtime_dir())"
```

## 🗄️ Database and Storage Issues

### Disk Space Issues
```bash
# Check disk usage
df -h

# Find large files
du -sh ~/.[^.]* ~/* | sort -rh | head -20

# Clean conda cache
conda clean --all

# Clean npm cache (if applicable)
npm cache clean --force

# Clean code-server logs
rm -rf ~/.config/code-server/coder-logs/*.log
```

### Permission Issues
```bash
# Fix ownership of code-server files
sudo chown -R $USER:$USER ~/.config/code-server
sudo chown -R $USER:$USER ~/.local/share/code-server

# Check file permissions
ls -la ~/.config/code-server/
```

## 🔧 Service Management Issues

### Service Won't Start
```bash
# Check service status
systemctl --user status code-server

# View detailed logs
journalctl --user -u code-server --no-pager

# Check systemd user session
systemctl --user show-environment

# Enable lingering (allows services to start without login)
sudo loginctl enable-linger $USER
```

### Service Configuration Issues
```bash
# Reload systemd configuration
systemctl --user daemon-reload

# Edit service file
systemctl --user edit code-server

# Reset to default
systemctl --user revert code-server
```

## 🔍 AWS Specific Troubleshooting

### IAM Permission Issues
```bash
# Check current IAM role
aws sts get-caller-identity

# Test S3 access
aws s3 ls

# Check CloudWatch agent
sudo systemctl status amazon-cloudwatch-agent
```

### CloudWatch Monitoring Issues
```bash
# Check agent configuration
sudo cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

# Restart agent
sudo systemctl restart amazon-cloudwatch-agent

# View agent logs
sudo tail -f /opt/aws/amazon-cloudwatch-agent/logs/amazon-cloudwatch-agent.log
```

### Backup Issues
```bash
# Test backup script
bash -x ~/backup-codeserver.sh

# Check S3 bucket access
aws s3 ls s3://your-backup-bucket/

# Verify cron job
crontab -l
```

## 🚀 Performance Issues

### High CPU/Memory Usage
```bash
# Check resource usage
htop
ps aux | grep code-server

# Check system resources
free -h
df -h

# Monitor in real-time
watch -n 2 'ps aux | grep code-server | head -5'
```

### Slow Performance
```bash
# Check available extensions
code-server --list-extensions | wc -l

# Disable unused extensions
code-server --disable-extension extension-id

# Check network latency (for remote access)
ping your-domain.com
traceroute your-domain.com
```

## 📝 Log Locations

### Application Logs
- Code-server: `~/.config/code-server/coder-logs/`
- Nginx: `/var/log/nginx/code-server.*.log`
- CloudWatch: `/opt/aws/amazon-cloudwatch-agent/logs/`

### System Logs
```bash
# System journal
sudo journalctl -f

# Authentication logs
sudo tail -f /var/log/auth.log

# System messages
sudo tail -f /var/log/syslog
```

## 🆘 Getting Help

### Before Asking for Help
1. Check this troubleshooting guide
2. Review the main README.md
3. Check service status and logs
4. Test with minimal configuration
5. Document error messages exactly

### Information to Include
- Operating system and version
- Error messages (full text)
- Steps to reproduce the issue
- Configuration files (without passwords)
- Service status output
- Log file excerpts

### Useful Commands for Support
```bash
# System information
uname -a
cat /etc/os-release

# Code-server version
code-server --version

# Service status
systemctl --user status code-server

# Recent logs
journalctl --user -u code-server -n 50 --no-pager

# Configuration (remove password first!)
grep -v password ~/.config/code-server/config.yaml

# Network configuration
netstat -tlnp | grep 8080
```

---

Remember: When in doubt, check the logs first! Most issues leave traces in the service logs or system journal.
