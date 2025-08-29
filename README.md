# Code-Server Data Science Setup for AWS EC2

A comprehensive setup for running code-server as a data science environment on AWS EC2 with user-level installation, SSL, security hardening, and essential extensions.

## 🚀 Quick Start

1. **Clone or download this repository** to your EC2 instance
2. **Make scripts executable**:
   ```bash
   chmod +x *.sh
   ```
3. **Run the installation**:
   ```bash
   ./install-code-server.sh
   ```
4. **Install extensions**:
   ```bash
   ./install-extensions.sh
   ```
5. **Configure AWS security** (optional but recommended):
   ```bash
   ./aws-security-setup.sh
   ```
6. **Setup SSL** (requires domain):
   ```bash
   ./ssl-setup.sh your-domain.com your-email@domain.com
   ```

## 📋 Prerequisites

- AWS EC2 instance (Ubuntu 20.04+ or Amazon Linux 2) - [**See EC2 Setup Guide**](EC2-SETUP-GUIDE.md)
- Domain name (for SSL setup) - optional but recommended
- Basic knowledge of Linux commands
- Sudo access on the instance

> 📖 **New to EC2?** Check out our comprehensive [EC2 Setup Guide](EC2-SETUP-GUIDE.md) for step-by-step instance creation, or use the [Quick Reference](EC2-QUICK-REFERENCE.md) for a one-page overview.

## 🛠 Installation Scripts

### 1. `install-code-server.sh`
Main installation script that:
- Installs code-server v4.89.1 at user level
- Sets up Python data science environment with Miniconda
- Creates systemd user service
- Configures essential settings
- Creates workspace structure

### 2. `install-extensions.sh`
Extension installation script that adds:
- **Python Development**: Python, Pylance, Black, Flake8, isort
- **Data Science**: Jupyter, Data Preview, CSV tools
- **Version Control**: GitLens, Git Graph
- **Development Tools**: Docker, AWS Toolkit, REST Client
- **Productivity**: Themes, formatters, spell checker
- **Database Tools**: SQLTools with multiple drivers

### 3. `nginx-config.conf`
Nginx reverse proxy configuration with:
- SSL termination
- WebSocket support for code-server and Jupyter
- Security headers
- Gzip compression
- Large file upload support

### 4. `ssl-setup.sh`
SSL configuration script that:
- Obtains Let's Encrypt certificates
- Configures automatic renewal
- Sets up security headers
- Configures firewall rules
- Enables fail2ban protection

### 5. `aws-security-setup.sh`
AWS-specific security configuration:
- Creates IAM roles with minimal permissions
- Configures security groups
- Sets up CloudWatch monitoring
- Applies system hardening
- Creates automated backups

## 📁 Directory Structure

After installation, you'll have:

```
~/
├── .config/
│   ├── code-server/           # Code-server configuration
│   └── systemd/user/          # User systemd services
├── .local/
│   ├── bin/code-server        # Code-server binary
│   └── share/code-server/     # Extensions and data
├── miniconda3/                # Conda installation
└── data-science-workspace/    # Main workspace
    ├── notebooks/             # Jupyter notebooks
    ├── scripts/              # Python scripts
    ├── data/                 # Data files
    │   ├── raw/              # Raw data
    │   └── processed/        # Processed data
    ├── models/               # Saved models
    ├── docs/                 # Documentation
    └── config/               # Configuration files
```

## 🔧 Configuration

### Environment Variables
The installation creates a conda environment called `datascience` with:
- Python 3.11
- Essential data science packages (pandas, numpy, scipy, matplotlib, seaborn, scikit-learn)
- Jupyter Lab
- Web frameworks (Streamlit, Dash, FastAPI)

### Code-Server Settings
Pre-configured with:
- Python interpreter pointing to conda environment
- Jupyter integration
- Auto-save enabled
- Black formatting on save
- Git integration
- Material icon theme

### System Service
Code-server runs as a systemd user service:
```bash
# Control the service
systemctl --user start code-server
systemctl --user stop code-server
systemctl --user status code-server
systemctl --user restart code-server
```

## 🌐 Access

### Local Development
After installation, access via:
- **Local**: http://localhost:8080
- **Password**: Generated during installation (saved in terminal output)

### Production (with SSL)
After SSL setup:
- **HTTPS**: https://your-domain.com
- **HTTP**: Automatically redirects to HTTPS

## 🔒 Security Features

### System Security
- SSH hardening with key-based authentication only
- Fail2ban intrusion detection
- Automatic security updates
- Firewall configuration (UFW/firewalld)
- Non-root user execution

### AWS Security
- IAM roles with minimal required permissions
- Security group configuration for HTTPS/HTTP only
- CloudWatch monitoring and logging
- Encrypted connections (SSL/TLS)

### Application Security
- Password-protected access
- Secure reverse proxy with security headers
- WebSocket support for real-time features
- Large file upload protection

## 📊 Monitoring and Logging

### CloudWatch Integration
- System metrics (CPU, memory, disk)
- Application logs
- Nginx access/error logs
- Custom namespace: `CodeServer/EC2`

### Log Locations
- **Code-server logs**: `~/.config/code-server/coder-logs/`
- **Nginx logs**: `/var/log/nginx/code-server.*`
- **System logs**: `/var/log/auth.log`, `/var/log/syslog`

## 💾 Backup

Automated daily backup script (`~/backup-codeserver.sh`) that:
- Backs up code-server configuration
- Backs up workspace files
- Uploads to S3 (requires configuration)
- Runs daily at 2 AM via cron

## 🐍 Python Environment

### Conda Environment: `datascience`
```bash
# Activate environment
conda activate datascience

# Install additional packages
conda install package_name
pip install package_name

# List installed packages
conda list
```

### Pre-installed Packages
- **Core**: pandas, numpy, scipy
- **Visualization**: matplotlib, seaborn, plotly, bokeh
- **ML**: scikit-learn, xgboost, lightgbm
- **Notebooks**: jupyter, jupyterlab
- **Web**: streamlit, dash, fastapi
- **Database**: sqlalchemy, psycopg2, pymongo
- **AWS**: boto3, awscli
- **Utilities**: requests, tqdm, pytest

## 🚦 Troubleshooting

### Code-server won't start
```bash
# Check service status
systemctl --user status code-server

# View logs
journalctl --user -u code-server -f

# Check configuration
cat ~/.config/code-server/config.yaml
```

### SSL certificate issues
```bash
# Check certificate status
sudo certbot certificates

# Test renewal
sudo certbot renew --dry-run

# Check nginx configuration
sudo nginx -t
```

### Extension issues
```bash
# List installed extensions
code-server --list-extensions

# Install extension manually
code-server --install-extension extension-id
```

### Python environment issues
```bash
# Check conda environments
conda env list

# Recreate environment
conda remove -n datascience --all
conda create -n datascience python=3.11
```

## 🔄 Updates

### Update code-server
1. Download new version to `~/.local/bin/`
2. Restart service: `systemctl --user restart code-server`

### Update extensions
Run: `./install-extensions.sh` (safe to run multiple times)

### Update Python packages
```bash
conda activate datascience
conda update --all
```

### Update SSL certificates
Automatic renewal is configured. Manual renewal:
```bash
sudo certbot renew
sudo systemctl reload nginx
```

## ⚠️ Important Notes

1. **Domain Setup**: Ensure your domain's A record points to your EC2 instance's public IP before running SSL setup.

2. **Security Groups**: The AWS security setup script will try to configure security groups automatically, but you may need to verify in the AWS Console.

3. **IAM Permissions**: The script creates IAM roles with minimal permissions. Adjust as needed for your use case.

4. **Backup Configuration**: Update the S3 bucket name in `~/backup-codeserver.sh` before relying on backups.

5. **Password Security**: The generated password is displayed once during installation. Save it securely.

6. **Resource Usage**: This setup includes many extensions and packages. Consider your EC2 instance size (recommend t3.medium or larger).

## 📖 Additional Resources

- [Code-Server Documentation](https://coder.com/docs/code-server)
- [Jupyter Lab Documentation](https://jupyterlab.readthedocs.io/)
- [AWS EC2 User Guide](https://docs.aws.amazon.com/ec2/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Nginx Documentation](https://nginx.org/en/docs/)

## 🤝 Contributing

Feel free to submit issues and pull requests to improve this setup!

## 📄 License

This project is open source and available under the MIT License.
