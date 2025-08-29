#!/bin/bash

# Data Science Extensions Installation Script for Code-Server
# Installs essential extensions for data science workflow

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

# Check if code-server is installed
check_code_server() {
    if ! command -v code-server &> /dev/null; then
        print_error "code-server not found. Please install code-server first."
        exit 1
    fi
    
    print_status "Found code-server: $(code-server --version | head -1)"
}

# Install extension function
install_extension() {
    local extension_id=$1
    local extension_name=$2
    
    print_status "Installing $extension_name..."
    
    if code-server --install-extension "$extension_id" --force; then
        print_status "✅ $extension_name installed successfully"
    else
        print_warning "⚠️  Failed to install $extension_name"
    fi
}

# Install Python and data science extensions
install_python_extensions() {
    print_status "Installing Python and Data Science extensions..."
    
    # Python essentials
    install_extension "ms-python.python" "Python"
    install_extension "ms-python.vscode-pylance" "Pylance"
    install_extension "ms-python.black-formatter" "Black Formatter"
    install_extension "ms-python.isort" "isort"
    install_extension "ms-python.flake8" "Flake8"
    install_extension "ms-python.mypy-type-checker" "Mypy Type Checker"
    
    # Jupyter and notebooks
    install_extension "ms-toolsai.jupyter" "Jupyter"
    install_extension "ms-toolsai.vscode-jupyter-cell-tags" "Jupyter Cell Tags"
    install_extension "ms-toolsai.vscode-jupyter-slideshow" "Jupyter Slide Show"
    
    # Data science and visualization
    install_extension "RandomFractalsInc.vscode-data-preview" "Data Preview"
    install_extension "mechatroner.rainbow-csv" "Rainbow CSV"
    install_extension "janisdd.vscode-edit-csv" "Edit CSV"
    install_extension "GrapeCity.gc-excelviewer" "Excel Viewer"
}

# Install development tools
install_dev_tools() {
    print_status "Installing development tools..."
    
    # Version control
    install_extension "eamodio.gitlens" "GitLens"
    install_extension "mhutchie.git-graph" "Git Graph"
    install_extension "donjayamanne.githistory" "Git History"
    
    # Code quality and formatting
    install_extension "streetsidesoftware.code-spell-checker" "Code Spell Checker"
    install_extension "esbenp.prettier-vscode" "Prettier"
    install_extension "bradlc.vscode-tailwindcss" "Tailwind CSS IntelliSense"
    
    # Markdown and documentation
    install_extension "yzhang.markdown-all-in-one" "Markdown All in One"
    install_extension "shd101wyy.markdown-preview-enhanced" "Markdown Preview Enhanced"
    install_extension "DavidAnson.vscode-markdownlint" "markdownlint"
    
    # Containers and deployment
    install_extension "ms-vscode-remote.remote-containers" "Dev Containers"
    install_extension "ms-azuretools.vscode-docker" "Docker"
    
    # AWS and cloud tools
    install_extension "amazonwebservices.aws-toolkit-vscode" "AWS Toolkit"
    install_extension "GoogleCloudTools.cloudcode" "Cloud Code"
}

# Install database and API tools
install_database_tools() {
    print_status "Installing database and API tools..."
    
    # Database tools
    install_extension "mtxr.sqltools" "SQLTools"
    install_extension "mtxr.sqltools-driver-pg" "SQLTools PostgreSQL"
    install_extension "mtxr.sqltools-driver-mysql" "SQLTools MySQL"
    install_extension "mtxr.sqltools-driver-sqlite" "SQLTools SQLite"
    install_extension "mongodb.mongodb-vscode" "MongoDB"
    
    # API and REST tools
    install_extension "humao.rest-client" "REST Client"
    install_extension "42Crunch.vscode-openapi" "OpenAPI (Swagger) Editor"
    install_extension "Postman.postman-for-vscode" "Postman"
}

# Install productivity extensions
install_productivity_tools() {
    print_status "Installing productivity tools..."
    
    # File management
    install_extension "alefragnani.project-manager" "Project Manager"
    install_extension "alefragnani.Bookmarks" "Bookmarks"
    install_extension "formulahendry.auto-rename-tag" "Auto Rename Tag"
    
    # Code navigation
    install_extension "ms-vscode.vscode-json" "JSON Tools"
    install_extension "redhat.vscode-yaml" "YAML"
    install_extension "ms-vscode.vscode-typescript-next" "TypeScript Importer"
    
    # Themes and appearance
    install_extension "PKief.material-icon-theme" "Material Icon Theme"
    install_extension "GitHub.github-vscode-theme" "GitHub Theme"
    install_extension "dracula-theme.theme-dracula" "Dracula Official"
    
    # Utilities
    install_extension "formulahendry.code-runner" "Code Runner"
    install_extension "ms-vscode.live-server" "Live Server"
    install_extension "ritwickdey.LiveServer" "Live Server (Alternative)"
}

# Install specialized data science tools
install_specialized_tools() {
    print_status "Installing specialized data science tools..."
    
    # Machine learning and AI
    install_extension "ms-toolsai.vscode-ai" "AI Tools"
    install_extension "GitHub.copilot" "GitHub Copilot"
    install_extension "GitHub.copilot-chat" "GitHub Copilot Chat"
    
    # R language support (if needed)
    install_extension "REditorSupport.r" "R"
    install_extension "RDebugger.r-debugger" "R Debugger"
    
    # Julia language support (if needed)
    install_extension "julialang.language-julia" "Julia"
    
    # Scala and Spark (if needed)
    install_extension "scalameta.metals" "Metals (Scala)"
}

# Configure settings for data science
configure_settings() {
    print_status "Configuring VS Code settings for data science..."
    
    SETTINGS_DIR="$HOME/.local/share/code-server/User"
    mkdir -p "$SETTINGS_DIR"
    
    cat > "$SETTINGS_DIR/settings.json" << 'EOF'
{
    "python.defaultInterpreterPath": "~/miniconda3/envs/datascience/bin/python",
    "python.condaPath": "~/miniconda3/bin/conda",
    "python.terminal.activateEnvironment": true,
    "python.linting.enabled": true,
    "python.linting.pylintEnabled": false,
    "python.linting.flake8Enabled": true,
    "python.formatting.provider": "black",
    "python.sortImports.args": ["--profile", "black"],
    "jupyter.askForKernelRestart": false,
    "jupyter.alwaysTrustNotebooks": true,
    "jupyter.sendSelectionToInteractiveWindow": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 1000,
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": true
    },
    "terminal.integrated.defaultProfile.linux": "bash",
    "terminal.integrated.profiles.linux": {
        "bash": {
            "path": "/bin/bash",
            "args": ["-l"]
        },
        "conda": {
            "path": "~/miniconda3/bin/conda",
            "args": ["activate", "datascience"]
        }
    },
    "workbench.iconTheme": "material-icon-theme",
    "workbench.colorTheme": "GitHub Dark",
    "git.enableSmartCommit": true,
    "git.autofetch": true,
    "explorer.confirmDelete": false,
    "explorer.confirmDragAndDrop": false,
    "csv-preview.theme": "dark",
    "rainbow_csv.enable_auto_csv_lint": true,
    "gitlens.currentLine.enabled": false,
    "gitlens.hovers.currentLine.over": "line",
    "markdown.preview.fontSize": 14,
    "markdown.preview.lineHeight": 1.6
}
EOF

    print_status "Settings configured successfully"
}

# Create sample workspace
create_sample_workspace() {
    print_status "Creating sample data science workspace..."
    
    WORKSPACE_DIR="$HOME/data-science-workspace"
    
    # Create directory structure
    mkdir -p "$WORKSPACE_DIR"/{notebooks,scripts,data/{raw,processed},models,docs,config}
    
    # Create sample files
    cat > "$WORKSPACE_DIR/README.md" << 'EOF'
# Data Science Workspace

This is your data science workspace with code-server on AWS EC2.

## Directory Structure

```
data-science-workspace/
├── notebooks/          # Jupyter notebooks
├── scripts/           # Python scripts
├── data/             # Data files
│   ├── raw/          # Raw data
│   └── processed/    # Processed data
├── models/           # Saved models
├── docs/            # Documentation
└── config/          # Configuration files
```

## Getting Started

1. Activate the conda environment: `conda activate datascience`
2. Start Jupyter Lab: `jupyter lab --port=8888 --no-browser`
3. Open notebooks in the `notebooks/` directory
4. Save scripts in the `scripts/` directory

## Installed Packages

- pandas, numpy, scipy
- matplotlib, seaborn, plotly
- scikit-learn
- jupyter, jupyterlab
- And many more!

## Extensions Installed

- Python support with Pylance
- Jupyter notebooks
- Data visualization tools
- Git integration
- AWS tools
- And more!
EOF

    # Create sample notebook
    cat > "$WORKSPACE_DIR/notebooks/welcome.ipynb" << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Welcome to Your Data Science Environment\n",
    "\n",
    "This is a sample notebook to get you started with data science on code-server."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import pandas as pd\n",
    "import numpy as np\n",
    "import matplotlib.pyplot as plt\n",
    "import seaborn as sns\n",
    "\n",
    "print(\"Welcome to your data science environment!\")\n",
    "print(f\"Pandas version: {pd.__version__}\")\n",
    "print(f\"NumPy version: {np.__version__}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Create sample data\n",
    "data = {\n",
    "    'x': np.random.randn(100),\n",
    "    'y': np.random.randn(100)\n",
    "}\n",
    "df = pd.DataFrame(data)\n",
    "\n",
    "# Plot\n",
    "plt.figure(figsize=(10, 6))\n",
    "plt.scatter(df['x'], df['y'], alpha=0.6)\n",
    "plt.xlabel('X values')\n",
    "plt.ylabel('Y values')\n",
    "plt.title('Sample Scatter Plot')\n",
    "plt.grid(True, alpha=0.3)\n",
    "plt.show()"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "name": "python",
   "version": "3.11.0"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

    # Create sample Python script
    cat > "$WORKSPACE_DIR/scripts/data_analysis.py" << 'EOF'
#!/usr/bin/env python3
"""
Sample data analysis script
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from pathlib import Path

def load_data(filepath):
    """Load data from CSV file"""
    return pd.read_csv(filepath)

def basic_analysis(df):
    """Perform basic data analysis"""
    print("Dataset Info:")
    print(f"Shape: {df.shape}")
    print(f"Columns: {df.columns.tolist()}")
    print("\nBasic Statistics:")
    print(df.describe())
    print("\nMissing Values:")
    print(df.isnull().sum())

def create_visualizations(df, output_dir):
    """Create basic visualizations"""
    output_dir = Path(output_dir)
    output_dir.mkdir(exist_ok=True)
    
    # Set style
    plt.style.use('seaborn-v0_8')
    
    # Example visualization
    if len(df.select_dtypes(include=[np.number]).columns) >= 2:
        numeric_cols = df.select_dtypes(include=[np.number]).columns[:2]
        
        plt.figure(figsize=(10, 6))
        plt.scatter(df[numeric_cols[0]], df[numeric_cols[1]], alpha=0.6)
        plt.xlabel(numeric_cols[0])
        plt.ylabel(numeric_cols[1])
        plt.title(f'{numeric_cols[0]} vs {numeric_cols[1]}')
        plt.tight_layout()
        plt.savefig(output_dir / 'scatter_plot.png', dpi=300, bbox_inches='tight')
        plt.show()

if __name__ == "__main__":
    print("Welcome to the sample data analysis script!")
    print("This script demonstrates basic data analysis workflows.")
    
    # Example with synthetic data
    np.random.seed(42)
    sample_data = pd.DataFrame({
        'feature1': np.random.randn(1000),
        'feature2': np.random.randn(1000) * 2 + 1,
        'category': np.random.choice(['A', 'B', 'C'], 1000)
    })
    
    basic_analysis(sample_data)
    
    # Save sample data
    data_dir = Path("../data/processed")
    data_dir.mkdir(parents=True, exist_ok=True)
    sample_data.to_csv(data_dir / "sample_data.csv", index=False)
    print(f"\nSample data saved to {data_dir / 'sample_data.csv'}")
EOF

    # Create requirements file
    cat > "$WORKSPACE_DIR/requirements.txt" << 'EOF'
# Data Science Core
pandas>=1.5.0
numpy>=1.24.0
scipy>=1.10.0

# Visualization
matplotlib>=3.6.0
seaborn>=0.12.0
plotly>=5.15.0
bokeh>=3.0.0

# Machine Learning
scikit-learn>=1.3.0
xgboost>=1.7.0
lightgbm>=4.0.0

# Deep Learning (optional)
# tensorflow>=2.13.0
# torch>=2.0.0

# Jupyter
jupyter>=1.0.0
jupyterlab>=4.0.0
ipywidgets>=8.0.0

# Web Frameworks
streamlit>=1.25.0
dash>=2.14.0
fastapi>=0.100.0
uvicorn>=0.23.0

# Database
sqlalchemy>=2.0.0
psycopg2-binary>=2.9.0
pymongo>=4.5.0

# AWS SDK
boto3>=1.28.0
awscli>=1.29.0

# Utilities
requests>=2.31.0
python-dotenv>=1.0.0
tqdm>=4.66.0
pytest>=7.4.0
EOF

    print_status "Sample workspace created at $WORKSPACE_DIR"
}

# Main function
main() {
    print_status "🔧 Installing Data Science Extensions for Code-Server..."
    
    check_code_server
    install_python_extensions
    install_dev_tools
    install_database_tools
    install_productivity_tools
    install_specialized_tools
    configure_settings
    create_sample_workspace
    
    print_status "✅ Data Science extensions installation completed!"
    echo
    echo -e "${GREEN}🎉 Your code-server is now ready for data science!${NC}"
    echo -e "${BLUE}Workspace location: $HOME/data-science-workspace${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Restart code-server: systemctl --user restart code-server"
    echo "2. Open workspace: File -> Open Folder -> ~/data-science-workspace"
    echo "3. Activate conda environment: conda activate datascience"
    echo "4. Start Jupyter Lab: jupyter lab --port=8888 --no-browser"
    echo "5. Open the welcome notebook in notebooks/welcome.ipynb"
}

# Run main function
main "$@"
