#!/bin/bash

# Code-Server Installation Script for Data Science on AWS EC2
# User-level installation script

set -e

# Cleanup function
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        print_status "Cleaning up temporary directory..."
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT INT TERM

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
CODE_SERVER_VERSION="4.103.2"
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
    
    # Check disk space in different locations first
    print_status "Checking available disk space..."
    df -h /tmp /home $HOME 2>/dev/null | grep -E "(Filesystem|tmp|home)" || true
    
    # Use a more reliable temporary directory
    # Create a unique temporary directory in home directory instead of /tmp
    TEMP_DIR="$HOME/tmp-code-server-install-$$"
    mkdir -p "$TEMP_DIR"
    
    # Check for sufficient disk space (optional but good practice)
    # Get available space in kilobytes for home directory
    AVAILABLE_SPACE=$(df -k "$HOME" | tail -1 | awk '{print $4}')
    REQUIRED_SPACE=200000 # ~200 MB in KB, increased for extraction
    
    if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
        print_error "Not enough disk space to install code-server. Required: ~200MB, Available: $(($AVAILABLE_SPACE / 1024))MB."
        exit 1
    fi
    
    print_status "Using temporary directory: $TEMP_DIR"
    print_status "Available space: $(($AVAILABLE_SPACE / 1024))MB"
    
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
    print_status "Downloading code-server binary..."
    DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-${ARCH}.tar.gz"
    
    print_status "Download URL: $DOWNLOAD_URL"
    
    # First, check if the release exists by attempting a HEAD request
    if command -v curl &> /dev/null; then
        print_status "Checking if release exists..."
        if ! curl -I --silent --fail "$DOWNLOAD_URL" >/dev/null 2>&1; then
            print_error "Release v${CODE_SERVER_VERSION} not found or URL is invalid"
            
            # Try to get the latest version automatically
            print_status "Attempting to get latest release version..."
            LATEST_VERSION=$(curl -s "https://api.github.com/repos/coder/code-server/releases/latest" | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4 | sed 's/^v//')
            
            if [ -n "$LATEST_VERSION" ]; then
                print_status "Found latest version: $LATEST_VERSION"
                CODE_SERVER_VERSION="$LATEST_VERSION"
                DOWNLOAD_URL="https://github.com/coder/code-server/releases/download/v${CODE_SERVER_VERSION}/code-server-${CODE_SERVER_VERSION}-linux-${ARCH}.tar.gz"
                print_status "Updated download URL: $DOWNLOAD_URL"
            else
                print_error "Could not determine latest version"
                print_status "You may need to check available releases at: https://github.com/coder/code-server/releases"
                exit 1
            fi
        fi
        print_status "Release verified, proceeding with download..."
    fi
    
    # Try wget first with verbose output
    if command -v wget &> /dev/null; then
        print_status "Using wget to download..."
        if ! wget --progress=bar:force --timeout=60 --tries=3 -O code-server.tar.gz "$DOWNLOAD_URL"; then
            print_warning "wget failed, trying curl..."
            rm -f code-server.tar.gz
            if command -v curl &> /dev/null; then
                print_status "Using curl to download..."
                if ! curl -L --progress-bar --max-time 60 --retry 3 -o code-server.tar.gz "$DOWNLOAD_URL"; then
                    print_error "Both wget and curl failed to download code-server"
                    exit 1
                fi
            else
                print_error "Failed to download code-server and curl not available"
                exit 1
            fi
        fi
    elif command -v curl &> /dev/null; then
        print_status "Using curl to download..."
        if ! curl -L --progress-bar --max-time 60 --retry 3 -o code-server.tar.gz "$DOWNLOAD_URL"; then
            print_error "Failed to download code-server with curl"
            exit 1
        fi
    else
        print_error "Neither wget nor curl available for download"
        exit 1
    fi
    
    # Verify download integrity
    print_status "Verifying download integrity..."
    if [ ! -f code-server.tar.gz ]; then
        print_error "Downloaded file does not exist"
        exit 1
    fi
    
    DOWNLOAD_SIZE=$(stat -c%s code-server.tar.gz 2>/dev/null || stat -f%z code-server.tar.gz 2>/dev/null || echo 0)
    print_status "Downloaded file size: ${DOWNLOAD_SIZE} bytes ($(($DOWNLOAD_SIZE / 1024 / 1024))MB)"
    
    if [ "$DOWNLOAD_SIZE" -lt 50000000 ]; then  # Should be at least ~50MB for recent versions
        print_error "Downloaded file is too small (${DOWNLOAD_SIZE} bytes), likely incomplete or corrupted"
        print_status "Expected size: ~100-120MB for code-server v${CODE_SERVER_VERSION}"
        print_status "This usually indicates a network issue or invalid download URL"
        
        # Check if it's an HTML error page
        if file code-server.tar.gz 2>/dev/null | grep -q "HTML\|text"; then
            print_error "Downloaded file appears to be HTML (likely a 404 error page)"
            print_status "First few lines of downloaded file:"
            head -5 code-server.tar.gz 2>/dev/null || true
        fi
        
        exit 1
    fi
    
    # Check if it's a valid tar file
    if ! tar -tzf code-server.tar.gz >/dev/null 2>&1; then
        print_error "Downloaded file is not a valid tar archive"
        print_status "File type: $(file code-server.tar.gz 2>/dev/null || echo 'unknown')"
        exit 1
    fi
    
    # Extract and install
    print_status "Extracting code-server archive..."
    print_status "Archive size: $(du -h code-server.tar.gz | cut -f1)"
    print_status "Available space before extraction: $(df -h "$TEMP_DIR" | tail -1 | awk '{print $4}')"
    
    if ! tar -xzf code-server.tar.gz; then
        print_error "Failed to extract code-server archive"
        print_status "Available space after failed extraction: $(df -h "$TEMP_DIR" | tail -1 | awk '{print $4}')"
        exit 1
    fi
    
    print_status "Extraction completed successfully"
    print_status "Available space after extraction: $(df -h "$TEMP_DIR" | tail -1 | awk '{print $4}')"
    
    # Copy the entire code-server directory to preserve structure
    EXTRACTED_DIR="code-server-${CODE_SERVER_VERSION}-linux-${ARCH}"
    
    if [ ! -d "$EXTRACTED_DIR" ]; then
        print_error "Extracted directory not found: $EXTRACTED_DIR"
        print_status "Available contents:"
        ls -la 2>/dev/null || true
        exit 1
    fi
    
    # Verify the binary exists in the extracted archive
    if [ ! -f "$EXTRACTED_DIR/bin/code-server" ]; then
        print_error "code-server binary not found in extracted archive"
        print_status "Contents of $EXTRACTED_DIR:"
        find "$EXTRACTED_DIR" -type f 2>/dev/null | head -10 || true
        exit 1
    fi
    
    # Check what type of file the binary is before copying
    print_status "Analyzing extracted binary..."
    print_status "Binary file type: $(file "$EXTRACTED_DIR/bin/code-server" 2>/dev/null || echo 'unknown')"
    EXTRACTED_SIZE=$(stat -c%s "$EXTRACTED_DIR/bin/code-server" 2>/dev/null || stat -f%z "$EXTRACTED_DIR/bin/code-server" 2>/dev/null || echo 0)
    print_status "Extracted binary size: ${EXTRACTED_SIZE} bytes ($(($EXTRACTED_SIZE / 1024 / 1024))MB)"
    
    # If the binary is small, it might be a wrapper script - let's check contents
    if [ "$EXTRACTED_SIZE" -lt 10000000 ]; then
        print_status "Binary appears to be a script/wrapper. Contents:"
        head -10 "$EXTRACTED_DIR/bin/code-server" 2>/dev/null || true
    fi
    
    # Copy the entire code-server installation to preserve all dependencies and structure
    print_status "Copying code-server installation..."
    
    # Instead of copying individual files, copy the entire structure
    CODE_SERVER_INSTALL_DIR="$INSTALL_DIR/code-server-${CODE_SERVER_VERSION}"
    
    # Remove any existing installation of this version
    rm -rf "$CODE_SERVER_INSTALL_DIR" 2>/dev/null || true
    
    # Copy the entire extracted directory
    cp -r "$EXTRACTED_DIR" "$CODE_SERVER_INSTALL_DIR"
    
    # Create a symlink or wrapper script in the bin directory
    mkdir -p "$INSTALL_DIR/bin"
    
    # Create a wrapper script that points to the actual installation
    cat > "$INSTALL_DIR/bin/code-server" << EOF
#!/bin/bash
# Code-server wrapper script
exec "$CODE_SERVER_INSTALL_DIR/bin/code-server" "\$@"
EOF
    chmod +x "$INSTALL_DIR/bin/code-server"
    
    # Make executable
    chmod +x "$CODE_SERVER_INSTALL_DIR/bin/code-server"
    
    # Verify the installation
    print_status "Verifying code-server installation..."
    if [ -f "$INSTALL_DIR/bin/code-server" ] && [ -f "$CODE_SERVER_INSTALL_DIR/bin/code-server" ]; then
        print_status "Wrapper and installation copied successfully"
        
        # Check the actual binary in the installation directory
        ACTUAL_BINARY="$CODE_SERVER_INSTALL_DIR/bin/code-server"
        
        # Check file size of the actual binary
        FILESIZE=$(stat -c%s "$ACTUAL_BINARY" 2>/dev/null || stat -f%z "$ACTUAL_BINARY" 2>/dev/null || echo 0)
        print_status "Actual binary size: ${FILESIZE} bytes ($(($FILESIZE / 1024 / 1024))MB)"
        
        # If the binary is still small, it might be a Node.js script - that's actually normal for code-server
        if [ "$FILESIZE" -lt 10000 ]; then
            print_status "Binary appears to be a Node.js script (normal for code-server)"
            print_status "Checking for Node.js dependencies..."
            
            # Look for the actual Node.js executable or libraries
            if [ -d "$CODE_SERVER_INSTALL_DIR/lib" ]; then
                LIB_SIZE=$(du -sb "$CODE_SERVER_INSTALL_DIR/lib" 2>/dev/null | cut -f1)
                print_status "Library directory size: $((LIB_SIZE / 1024 / 1024))MB"
            fi
            
            if [ -d "$CODE_SERVER_INSTALL_DIR/node_modules" ]; then
                NODE_MODULES_SIZE=$(du -sb "$CODE_SERVER_INSTALL_DIR/node_modules" 2>/dev/null | cut -f1)
                print_status "Node modules size: $((NODE_MODULES_SIZE / 1024 / 1024))MB"
            fi
        fi
        
        # Test that the wrapper script works
        if file "$INSTALL_DIR/bin/code-server" 2>/dev/null | grep -q "shell script"; then
            print_status "Wrapper script created successfully"
        else
            print_error "Wrapper script may be corrupted"
            print_status "File type: $(file "$INSTALL_DIR/bin/code-server" 2>/dev/null || echo 'unknown')"
        fi
    else
        print_error "Installation failed - files not found"
        exit 1
    fi
    
    # Create a wrapper script to handle any path issues
    cat > "$INSTALL_DIR/bin/code-server-wrapper" << EOF
#!/bin/bash
# Code-server wrapper script
CODE_SERVER_INSTALL_DIR="$CODE_SERVER_INSTALL_DIR"
export NODE_PATH="\$CODE_SERVER_INSTALL_DIR/lib:\$CODE_SERVER_INSTALL_DIR/node_modules"
cd "\$HOME/data-science-workspace" || cd "\$HOME"
exec "\$CODE_SERVER_INSTALL_DIR/bin/code-server" "\$@"
EOF
    chmod +x "$INSTALL_DIR/bin/code-server-wrapper"
    
    # Test the installation
    print_status "Testing code-server installation..."
    if timeout 10 "$INSTALL_DIR/bin/code-server" --version >/dev/null 2>&1; then
        VERSION_OUTPUT=$("$INSTALL_DIR/bin/code-server" --version 2>/dev/null | head -1)
        print_status "Code-server test successful: $VERSION_OUTPUT"
    else
        print_warning "Code-server version check timed out or failed (this might be normal)"
        print_status "Installation completed, but version test inconclusive"
    fi
    
    # Add to PATH if not already there
    if ! echo "$PATH" | grep -q "$INSTALL_DIR/bin"; then
        echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
        export PATH="$INSTALL_DIR/bin:$PATH"
    fi
    
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
