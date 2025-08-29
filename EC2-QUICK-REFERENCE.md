# EC2 Quick Reference for Code-Server Setup

## 🚀 One-Page Setup Guide

### 1. EC2 Instance Configuration

```yaml
Instance Settings:
  AMI: Ubuntu Server 22.04 LTS (ami-0c7217cdde317cfec)
  Instance Type: t3.large (2 vCPU, 8GB RAM)
  Key Pair: Create new RSA key pair
  Storage: 30-50 GB gp3 SSD
  Security Group: Custom (see rules below)
```

### 2. Security Group Rules (REQUIRED)

| Type | Protocol | Port | Source | Description |
|------|----------|------|--------|-------------|
| SSH | TCP | 22 | **Your IP** | SSH access |
| HTTP | TCP | 80 | 0.0.0.0/0 | Let's Encrypt |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Web access |
| Custom TCP | TCP | 8080 | **Your IP** | Initial setup |

⚠️ **NEVER use 0.0.0.0/0 for SSH (port 22)**

### 3. Essential Commands

```bash
# Connect to instance
ssh -i "your-key.pem" ubuntu@YOUR_PUBLIC_IP

# Update system
sudo apt update && sudo apt upgrade -y

# Upload setup files
scp -i "your-key.pem" -r code-server/ ubuntu@YOUR_PUBLIC_IP:~/

# Run setup
cd code-server && chmod +x *.sh && ./setup.sh
```

## 🌍 Instance Sizing Guide

| Workload | Instance Type | vCPU | RAM | Storage | $/Month* |
|----------|---------------|------|-----|---------|----------|
| **Learning** | t3.medium | 2 | 4GB | 30GB | ~$30 |
| **Development** | t3.large | 2 | 8GB | 50GB | ~$60 |
| **Heavy Work** | t3.xlarge | 4 | 16GB | 100GB | ~$120 |
| **Production** | m5.xlarge | 4 | 16GB | 100GB | ~$140 |

*Approximate costs for us-east-1, running 24/7

## 🔒 Security Checklist

- [ ] ✅ SSH key pair created and secured (chmod 400)
- [ ] ✅ Security group configured (no 0.0.0.0/0 for SSH)
- [ ] ✅ Elastic IP allocated (for domain setup)
- [ ] ✅ Domain DNS pointing to Elastic IP
- [ ] ✅ Billing alerts configured
- [ ] ✅ CloudWatch monitoring enabled

## 🌐 Domain Setup (Optional)

1. **Buy domain** (Route 53, Namecheap, etc.)
2. **Create Elastic IP** in AWS Console
3. **Associate** Elastic IP with instance
4. **Create A record**: domain → Elastic IP
5. **Wait for DNS** propagation (5-30 minutes)
6. **Test**: `nslookup your-domain.com`

## 💰 Cost Optimization

```bash
# Stop instance when not needed (saves ~90% on compute)
aws ec2 stop-instances --instance-ids i-1234567890abcdef0

# Start instance when needed
aws ec2 start-instances --instance-ids i-1234567890abcdef0

# Check running instances
aws ec2 describe-instances --query 'Reservations[].Instances[].[InstanceId,State.Name,InstanceType]' --output table
```

## 🔧 Quick Troubleshooting

### Can't SSH?
```bash
# Check key permissions
chmod 400 your-key.pem

# Check security group allows your IP for port 22
# Try: ssh -v -i your-key.pem ubuntu@PUBLIC_IP
```

### Can't access code-server?
```bash
# Check service status on instance
systemctl --user status code-server

# Check security group allows port 80/443
# Check domain DNS resolution: nslookup your-domain.com
```

### SSL certificate fails?
```bash
# Ensure domain points to your instance IP
# Ensure ports 80/443 are open in security group
# Check nginx is running: sudo systemctl status nginx
```

## 📋 Post-Setup Verification

```bash
# On your EC2 instance, verify:
systemctl --user status code-server    # Should be active
sudo systemctl status nginx            # Should be active (if SSL setup)
conda activate datascience && python --version  # Should show Python 3.11
curl http://localhost:8080             # Should connect
```

## 🚨 Emergency Recovery

### Instance unresponsive?
1. **EC2 Console** → Instance → Actions → Instance State → Reboot
2. Check **System Log** in EC2 Console
3. Try **EC2 Instance Connect** from browser

### Lost SSH access?
1. Create new **Key Pair**
2. Stop instance, detach EBS volume
3. Attach volume to new instance
4. Modify authorized_keys file
5. Reattach volume to original instance

### Billing alert triggered?
1. **Stop** instance immediately: `aws ec2 stop-instances --instance-ids i-xxx`
2. Check **CloudWatch** billing metrics
3. Review **Cost Explorer** for usage breakdown
4. Consider **downsizing** instance type

---

## 📞 Quick Help

**AWS Support**: [AWS Console] → Support → Create Case
**Documentation**: Check `README.md` and `TROUBLESHOOTING.md`
**Common Issues**: 95% are security group or SSH key problems

**🎯 Success Indicator**: You can access `https://your-domain.com` and see code-server login page!
