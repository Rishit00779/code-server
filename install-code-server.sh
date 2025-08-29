#!/bin/bash

# Code-Server Installation Script for Data Science on AWS EC2
# User-level installation script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CODE_SERVER_VERSION="4.89.1"
INSTALL_DIR="$HOME/.local"
CONFIG_DIR="$HOME/.config/code-server"
SERVICE_DIR="$HOME/.config/systemd/user"

echo -e "${BLUE}🚀 Starting Code-Server Installation for Data Science${NC}"

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on supported OS
check_os() {
    print_status "Checking operating system..."
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command -v apt-get &> /dev/null; then
            OS="ubuntu"
            print_status "Detected Ubuntu/Debian system"
        elif command -v yum &> /dev/null; then
            OS="centos"
            print_status "Detected CentOS/RHEL system"
        elif command -v dnf &> /dev/null; then
            OS="fedora"
            print_status "Detected Fedora system"
        else
            print_error "Unsupported Linux distribution"
            exit 1
        fi
    else
        print_error "This script is designed for Linux systems only"
        exit 1
    fi
}

# Install system dependencies
install_dependencies() {
    print_status "Installing system dependencies..."
    
    case $OS in
        "ubuntu")
            sudo apt update
            sudo apt install -y curl wget git build-essential python3 python3-pip nodejs npm nginx certbot python3-certbot-nginx
            ;;
        "centos"|"fedora")
            if command -v dnf &> /dev/null; then
                sudo dnf update -y
                sudo dnf install -y --allowerasing curl wget git gcc gcc-c++ make python3 python3-pip nodejs npm nginx certbot python3-certbot-nginx
            else
                sudo yum update -y
                sudo yum install -y --allowerasing curl wget git gcc gcc-c++ make python3 python3-pip nodejs npm nginx certbot python3-certbot-nginx
            fi
            ;;
    esac
}

# Create necessary directories
create_directories() {
    print_status "Creating directories..."
    mkdir -p "$INSTALL_DIR/bin"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$SERVICE_DIR"
    mkdir -p "$HOME/data-science-workspace"
    mkdir -p "$HOME/.local/share/code-server/extensions"
}

# Download and install code-server
install_code_server() {
    print_status "Downloading code-server v$CODE_SERVER_VERSION..."
    
    # Use a more reliable temporary directory
    # Create a unique temporary directory for this session
    TEMP_DIR=$(mktemp -d)
    
    # Check for sufficient disk space (optional but good practice)
    # Get available space in kilobytes
    AVAILABLE_SPACE=$(df -k "$TEMP_DIR" | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=150000 # ~150 MB in KB, a safe estimate
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        print_error "Not enough disk space to install code-server. Required: ~150MB, Available: $(($AVAILABLE_SPACE / 1024))MB."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    cd "$TEMP_DIR"
    
    # Determine architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64)
            ARCH="amd64"
            ;;
        aarch64)
            ARCH="arm64"
            ;;
        armv7l)
            ARCH="armv7"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            rm -rf "$TEMP_DIR"
            exit 1
            ;;
    esac
    
    # Download code-server
    wget -O code-server.tar.gz "https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-${ARCH}.tar.gz"
    
    # Extract and install
    tar -xzf code-server.tar.gz
    
    # Copy the entire code-server directory to preserve structure
    EXTRACTED_DIR="code-server-${CODE_SERVER_VERSION}-linux-${ARCH}"
    
    # Copy binary
    cp "$EXTRACTED_DIR/bin/code-server" "$INSTALL_DIR/bin/"
    
    # Copy lib directory maintaining structure
    if [ -d "$EXTRACTED_DIR/lib" ]; then
        mkdir -p "$INSTALL_DIR/lib"
        cp -r "$EXTRACTED_DIR/lib/"* "$INSTALL_DIR/lib/"
    fi
    
    # Copy node_modules if they exist
    if [ -d "$EXTRACTED_DIR/node_modules" ]; then
        cp -r "$EXTRACTED_DIR/node_modules" "$INSTALL_DIR/"
    fi
    
    # Make executable
    chmod +x "$INSTALL_DIR/bin/code-server"
    
    # Verify the installation
    print_status "Verifying code-server installation..."
    if [ -f "$INSTALL_DIR/bin/code-server" ]; then
        print_status "Binary installed successfully"
        # Test that the binary is not corrupted
        if file "$INSTALL_DIR/bin/code-server" | grep -q "ELF"; then
            print_status "Binary appears to be valid"
        else
            print_error "Binary may be corrupted"
            exit 1
        fi
    else
        print_error "Binary installation failed"
        exit 1
    fi
    
    # Create a wrapper script to handle any path issues
    cat > "$INSTALL_DIR/bin/code-server-wrapper" << 'EOF'
#!/bin/bash
# Code-server wrapper script
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
INSTALL_DIR="$(dirname "$SCRIPT_DIR")"
export NODE_PATH="$INSTALL_DIR/lib:$INSTALL_DIR/node_modules"
cd "$HOME/data-science-workspace" || cd "$HOME"
exec "$SCRIPT_DIR/code-server" "$@"
EOF
    chmod +x "$INSTALL_DIR/bin/code-server-wrapper"
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$INSTALL_DIR/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$INSTALL_DIR/bin:$PATH"
    fi
    
    # Clean up the temporary directory
    rm -rf "$TEMP_DIR"
    
    print_status "Code-server installed successfully!"
}

# Generate configuration
generate_config() {
    print_status "Generating code-server configuration..."
    
    # Generate random password if not provided
    if [ -z "$CODE_SERVER_PASSWORD" ]; then
        CODE_SERVER_PASSWORD=$(openssl rand -base64 32)
        print_warning "Generated password: $CODE_SERVER_PASSWORD"
        print_warning "Please save this password safely!"
    fi
    
    cat > "$CONFIG_DIR/config.yaml" << EOF
bind-addr: 127.0.0.1:8080
auth: password
password: $CODE_SERVER_PASSWORD
cert: false
user-data-dir: $HOME/.local/share/code-server
extensions-dir: $HOME/.local/share/code-server/extensions
disable-telemetry: true
disable-update-check: true
EOF

    print_status "Configuration created at $CONFIG_DIR/config.yaml"
}

# Create systemd user service
create_service() {
    print_status "Creating systemd user service..."
    
    cat > "$SERVICE_DIR/code-server.service" << EOF
[Unit]
Description=code-server
After=network.target

[Service]
Type=exec
ExecStart=$INSTALL_DIR/bin/code-server-wrapper --config $CONFIG_DIR/config.yaml $HOME/data-science-workspace
Restart=always
RestartSec=10
WorkingDirectory=$HOME/data-science-workspace
Environment=HOME=$HOME
Environment=PATH=$INSTALL_DIR/bin:/usr/local/bin:/usr/bin:/bin

[Install]
WantedBy=default.target
EOF

    # Enable systemd user services
    systemctl --user daemon-reload
    systemctl --user enable code-server
    
    print_status "Systemd service created and enabled"
}

# Install Python data science environment
install_python_environment() {
    print_status "Setting up Python data science environment with uv..."

    # Change to home directory to avoid directory issues
    cd "$HOME"

    # Install uv if not present
    if ! command -v uv &> /dev/null; then
        print_status "Installing uv (Python package manager)..."
        curl -Ls https://astral.sh/uv/install.sh | bash
        export PATH="$HOME/.local/bin:$PATH"
        # Source bashrc to ensure uv is in PATH
        source "$HOME/.bashrc" 2>/dev/null || true
    fi

    # Create virtual environment with uv
    WORKON_HOME="$HOME/.virtualenvs"
    ENV_NAME="datascience"
    mkdir -p "$WORKON_HOME"
    
    # Change to workspace directory for venv creation
    cd "$HOME/data-science-workspace"
    
    if [ ! -d "$WORKON_HOME/$ENV_NAME" ]; then
        print_status "Creating Python 3.11 virtual environment with uv..."
        uv venv "$WORKON_HOME/$ENV_NAME" --python=3.11 || uv venv "$WORKON_HOME/$ENV_NAME"
    fi

    # Activate the environment
    # shellcheck disable=SC1090
    source "$WORKON_HOME/$ENV_NAME/bin/activate"

    # Install essential data science packages
    print_status "Installing data science packages with uv..."
    uv pip install --upgrade pip
    uv pip install jupyter jupyterlab pandas numpy scipy matplotlib seaborn scikit-learn plotly bokeh streamlit dash fastapi uvicorn

    # Create activation script for easy access
    cat > "$HOME/activate_datascience.sh" << 'EOF'
#!/bin/bash
source "$HOME/.virtualenvs/datascience/bin/activate"
echo "Data science environment activated!"
EOF
    chmod +x "$HOME/activate_datascience.sh"

    print_status "Python environment setup complete!"
    print_status "To activate environment: source ~/.virtualenvs/datascience/bin/activate"
    print_status "Or run: ./activate_datascience.sh"
}

# Main installation function
main() {
    print_status "Starting code-server installation..."
    
    check_os
    install_dependencies
    create_directories
    install_code_server
    generate_config
    create_service
    install_python_environment
    
    print_status "✅ Installation completed successfully!"
    echo
    echo -e "${GREEN}🎉 Code-Server is now installed!${NC}"
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Start code-server: systemctl --user start code-server"
    echo "2. Check status: systemctl --user status code-server"
    echo "3. Access via: http://localhost:8080"
    echo "4. Configure nginx proxy (see nginx-config.conf)"
    echo "5. Set up SSL with Let's Encrypt (see ssl-setup.sh)"
    echo
    echo -e "${YELLOW}Password: $CODE_SERVER_PASSWORD${NC}"
    echo -e "${YELLOW}Config location: $CONFIG_DIR/config.yaml${NC}"
}

# Run main function
main "$@"
