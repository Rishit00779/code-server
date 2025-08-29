#!/bin/bash

# SSL Setup Script for Code-Server with Let's Encrypt
# This script configures HTTPS for your code-server installation

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

# Check if domain is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <your-domain.com> [email@example.com]"
    print_error "Example: $0 codeserver.mydomain.com admin@mydomain.com"
    exit 1
fi

DOMAIN=$1
EMAIL=${2:-"webmaster@${DOMAIN}"}

print_status "Setting up SSL for domain: $DOMAIN"
print_status "Using email: $EMAIL"

# Verify domain points to this server
verify_domain() {
    print_status "Verifying domain DNS..."
    
    # Get server's public IP
    SERVER_IP=$(curl -s ifconfig.me || curl -s ipinfo.io/ip || curl -s icanhazip.com)
    
    if [ -z "$SERVER_IP" ]; then
        print_error "Could not determine server IP address"
        exit 1
    fi
    
    print_status "Server IP: $SERVER_IP"
    
    # Check if domain resolves to server IP
    DOMAIN_IP=$(dig +short "$DOMAIN" | tail -n1)
    
    if [ "$DOMAIN_IP" != "$SERVER_IP" ]; then
        print_warning "Domain $DOMAIN resolves to $DOMAIN_IP, but server IP is $SERVER_IP"
        print_warning "Please ensure your domain's A record points to $SERVER_IP"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_status "Domain verification successful!"
    fi
}

# Install and configure nginx
setup_nginx() {
    print_status "Setting up Nginx configuration..."
    
    # Copy nginx configuration
    sudo cp nginx-config.conf /etc/nginx/sites-available/code-server
    
    # Replace domain placeholder
    sudo sed -i "s/your-domain.com/$DOMAIN/g" /etc/nginx/sites-available/code-server
    
    # Enable site
    sudo ln -sf /etc/nginx/sites-available/code-server /etc/nginx/sites-enabled/
    
    # Remove default nginx site if it exists
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if sudo nginx -t; then
        print_status "Nginx configuration is valid"
    else
        print_error "Nginx configuration test failed"
        exit 1
    fi
    
    # Restart nginx
    sudo systemctl restart nginx
    print_status "Nginx restarted successfully"
}

# Setup SSL with Let's Encrypt
setup_ssl() {
    print_status "Setting up SSL certificate with Let's Encrypt..."
    
    # Stop nginx temporarily for standalone mode
    sudo systemctl stop nginx
    
    # Get SSL certificate
    if sudo certbot certonly \
        --standalone \
        --non-interactive \
        --agree-tos \
        --email "$EMAIL" \
        -d "$DOMAIN"; then
        print_status "SSL certificate obtained successfully!"
    else
        print_error "Failed to obtain SSL certificate"
        sudo systemctl start nginx
        exit 1
    fi
    
    # Start nginx
    sudo systemctl start nginx
    
    # Set up automatic renewal
    setup_auto_renewal
}

# Setup automatic certificate renewal
setup_auto_renewal() {
    print_status "Setting up automatic certificate renewal..."
    
    # Create renewal script
    sudo tee /etc/cron.d/certbot-renewal << 'EOF'
# Renew Let's Encrypt certificates
0 3 * * * root /usr/bin/certbot renew --quiet --deploy-hook "systemctl reload nginx"
EOF
    
    # Test renewal (dry run)
    if sudo certbot renew --dry-run; then
        print_status "Certificate auto-renewal setup successfully!"
    else
        print_warning "Certificate renewal test failed, but certificate is installed"
    fi
}

# Configure firewall
setup_firewall() {
    print_status "Configuring firewall..."
    
    # Check if ufw is installed
    if command -v ufw &> /dev/null; then
        sudo ufw allow 22/tcp   # SSH
        sudo ufw allow 80/tcp   # HTTP
        sudo ufw allow 443/tcp  # HTTPS
        
        # Ask before enabling firewall
        print_warning "About to enable UFW firewall with SSH, HTTP, and HTTPS access"
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            sudo ufw --force enable
            print_status "Firewall configured and enabled"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewall
        sudo firewall-cmd --permanent --add-service=ssh
        sudo firewall-cmd --permanent --add-service=http
        sudo firewall-cmd --permanent --add-service=https
        sudo firewall-cmd --reload
        print_status "Firewall configured (firewalld)"
    else
        print_warning "No firewall detected. Please manually configure firewall rules."
    fi
}

# Security hardening
apply_security_hardening() {
    print_status "Applying security hardening..."
    
    # Disable server tokens in nginx
    if ! grep -q "server_tokens off;" /etc/nginx/nginx.conf; then
        sudo sed -i '/http {/a \ \ \ \ server_tokens off;' /etc/nginx/nginx.conf
    fi
    
    # Set up fail2ban for additional security
    if command -v fail2ban-server &> /dev/null; then
        print_status "Configuring fail2ban..."
        
        sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3

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
EOF
        
        sudo systemctl restart fail2ban
        print_status "Fail2ban configured"
    fi
    
    # Reload nginx with new configuration
    sudo systemctl reload nginx
}

# Main function
main() {
    print_status "🔒 Starting SSL setup for Code-Server..."
    
    # Check if running as non-root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root"
        exit 1
    fi
    
    # Check if nginx config exists
    if [ ! -f "nginx-config.conf" ]; then
        print_error "nginx-config.conf not found in current directory"
        exit 1
    fi
    
    verify_domain
    setup_nginx
    setup_ssl
    setup_firewall
    apply_security_hardening
    
    print_status "✅ SSL setup completed successfully!"
    echo
    echo -e "${GREEN}🎉 Your code-server is now accessible via HTTPS!${NC}"
    echo -e "${BLUE}URL: https://$DOMAIN${NC}"
    echo -e "${BLUE}Certificate: /etc/letsencrypt/live/$DOMAIN/fullchain.pem${NC}"
    echo -e "${BLUE}Private Key: /etc/letsencrypt/live/$DOMAIN/privkey.pem${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Start code-server: systemctl --user start code-server"
    echo "2. Check nginx status: sudo systemctl status nginx"
    echo "3. View SSL certificate: sudo certbot certificates"
    echo "4. Monitor logs: sudo tail -f /var/log/nginx/code-server.access.log"
}

# Run main function
main "$@"
