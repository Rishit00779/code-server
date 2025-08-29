#!/bin/bash

# Quick Setup Script for Code-Server Data Science Environment
# Run this script to perform the complete installation

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Display welcome message
print_header "Code-Server Data Science Setup"
echo -e "${BLUE}Welcome to the automated Code-Server setup for data science on AWS EC2!${NC}"
echo
echo "This script will:"
echo "1. Install code-server with user-level setup"
echo "2. Set up Python data science environment"
echo "3. Install essential VS Code extensions"
echo "4. Configure security settings (optional)"
echo "5. Set up SSL/HTTPS (optional)"
echo

# Check if running on EC2
check_environment() {
    print_status "Checking environment..."
    
    # Check if running on AWS EC2
    if curl -s --connect-timeout 5 http://169.254.169.254/latest/meta-data/ &> /dev/null; then
        print_status "✅ Running on AWS EC2"
        IS_EC2=true
    else
        print_warning "⚠️  Not running on AWS EC2 - some features will be limited"
        IS_EC2=false
    fi
    
    # Check OS
    if [[ "$OSTYPE" != "linux-gnu"* ]]; then
        print_error "❌ This script requires Linux"
        exit 1
    fi
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "❌ This script should not be run as root"
        print_error "Please run as a regular user with sudo privileges"
        exit 1
    fi
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        print_warning "⚠️  This script requires sudo access"
        echo "You may be prompted for your password during installation"
    fi
    
    print_status "✅ Environment check passed"
}

# Get user preferences
get_user_preferences() {
    echo
    print_header "Configuration Options"
    
    # Ask about AWS security setup
    if [ "$IS_EC2" = true ]; then
        read -p "Configure AWS security features? (IAM roles, security groups, CloudWatch) [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            SETUP_AWS_SECURITY=true
        else
            SETUP_AWS_SECURITY=false
        fi
    else
        SETUP_AWS_SECURITY=false
    fi
    
    # Ask about SSL setup
    read -p "Do you have a domain name for SSL setup? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        SETUP_SSL=true
        read -p "Enter your domain name: " DOMAIN_NAME
        read -p "Enter your email for Let's Encrypt: " SSL_EMAIL
        
        if [ -z "$DOMAIN_NAME" ] || [ -z "$SSL_EMAIL" ]; then
            print_warning "Domain or email not provided - SSL setup will be skipped"
            SETUP_SSL=false
        fi
    else
        SETUP_SSL=false
    fi
    
    # Ask about password
    read -p "Set a custom password for code-server? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        read -s -p "Enter password: " CUSTOM_PASSWORD
        echo
        read -s -p "Confirm password: " CUSTOM_PASSWORD_CONFIRM
        echo
        
        if [ "$CUSTOM_PASSWORD" != "$CUSTOM_PASSWORD_CONFIRM" ]; then
            print_warning "Passwords don't match - random password will be generated"
            unset CUSTOM_PASSWORD
        else
            export CODE_SERVER_PASSWORD="$CUSTOM_PASSWORD"
        fi
    fi
}

# Run installation steps
run_installation() {
    echo
    print_header "Starting Installation"
    
    # Step 1: Install code-server
    print_status "Step 1: Installing code-server and Python environment..."
    if ! ./install-code-server.sh; then
        print_error "❌ Code-server installation failed"
        exit 1
    fi
    
    # Step 2: Install extensions
    print_status "Step 2: Installing VS Code extensions..."
    if ! ./install-extensions.sh; then
        print_warning "⚠️  Extension installation encountered issues (continuing...)"
    fi
    
    # Step 3: AWS security setup
    if [ "$SETUP_AWS_SECURITY" = true ]; then
        print_status "Step 3: Configuring AWS security..."
        if ! ./aws-security-setup.sh; then
            print_warning "⚠️  AWS security setup encountered issues (continuing...)"
        fi
    else
        print_status "Step 3: Skipping AWS security setup"
    fi
    
    # Step 4: SSL setup
    if [ "$SETUP_SSL" = true ]; then
        print_status "Step 4: Setting up SSL..."
        if ! ./ssl-setup.sh "$DOMAIN_NAME" "$SSL_EMAIL"; then
            print_warning "⚠️  SSL setup encountered issues (continuing...)"
        fi
    else
        print_status "Step 4: Skipping SSL setup"
    fi
}

# Start code-server service
start_services() {
    print_status "Starting code-server service..."
    
    # Start and enable code-server
    systemctl --user daemon-reload
    systemctl --user enable code-server
    systemctl --user start code-server
    
    # Wait for service to start
    sleep 5
    
    # Check service status
    if systemctl --user is-active code-server &> /dev/null; then
        print_status "✅ Code-server service started successfully"
    else
        print_error "❌ Failed to start code-server service"
        systemctl --user status code-server
        return 1
    fi
}

# Display final information
show_completion_info() {
    echo
    print_header "Installation Complete!"
    
    # Get access information
    if [ -f "$HOME/.config/code-server/config.yaml" ]; then
        PASSWORD=$(grep "password:" "$HOME/.config/code-server/config.yaml" | cut -d' ' -f2)
    else
        PASSWORD="Check installation logs"
    fi
    
    # Get IP information
    if [ "$IS_EC2" = true ]; then
        PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || echo "unknown")
    else
        PUBLIC_IP=$(hostname -I | cut -d' ' -f1)
    fi
    
    echo -e "${GREEN}🎉 Your code-server data science environment is ready!${NC}"
    echo
    echo -e "${BLUE}Access Information:${NC}"
    
    if [ "$SETUP_SSL" = true ] && [ ! -z "$DOMAIN_NAME" ]; then
        echo -e "${CYAN}🌐 HTTPS URL: https://$DOMAIN_NAME${NC}"
        echo -e "${CYAN}🌐 HTTP URL:  http://$DOMAIN_NAME (redirects to HTTPS)${NC}"
    else
        echo -e "${CYAN}🌐 Local URL:  http://localhost:8080${NC}"
        echo -e "${CYAN}🌐 Public URL: http://$PUBLIC_IP:8080${NC}"
        echo -e "${YELLOW}⚠️  Public access requires security group configuration${NC}"
    fi
    
    echo -e "${CYAN}🔑 Password:   $PASSWORD${NC}"
    echo
    
    echo -e "${BLUE}Service Management:${NC}"
    echo "• Start:   systemctl --user start code-server"
    echo "• Stop:    systemctl --user stop code-server"
    echo "• Status:  systemctl --user status code-server"
    echo "• Restart: systemctl --user restart code-server"
    echo
    
    echo -e "${BLUE}Python Environment:${NC}"
    echo "• Activate: conda activate datascience"
    echo "• Location: ~/miniconda3/envs/datascience"
    echo "• Jupyter:  jupyter lab --port=8888 --no-browser"
    echo
    
    echo -e "${BLUE}Workspace:${NC}"
    echo "• Location: ~/data-science-workspace"
    echo "• Notebooks: ~/data-science-workspace/notebooks"
    echo "• Scripts: ~/data-science-workspace/scripts"
    echo
    
    if [ "$SETUP_SSL" = false ]; then
        echo -e "${YELLOW}💡 Pro Tips:${NC}"
        echo "• To set up SSL later: ./ssl-setup.sh your-domain.com your-email@domain.com"
        echo "• To configure AWS security: ./aws-security-setup.sh"
        echo "• Check README.md for detailed documentation"
    fi
    
    echo
    echo -e "${GREEN}🚀 Happy coding and data science!${NC}"
}

# Error handling
handle_error() {
    print_error "❌ Installation failed on line $1"
    echo
    echo "Troubleshooting steps:"
    echo "1. Check the logs above for specific error messages"
    echo "2. Ensure you have sudo privileges"
    echo "3. Check internet connectivity"
    echo "4. Try running individual scripts manually"
    echo "5. Check README.md for troubleshooting guide"
    echo
    echo "For support, check the documentation or create an issue."
    exit 1
}

# Set error trap
trap 'handle_error $LINENO' ERR

# Main execution
main() {
    # Make sure all scripts are executable
    chmod +x *.sh
    
    check_environment
    get_user_preferences
    run_installation
    start_services
    show_completion_info
}

# Run main function
main "$@"
