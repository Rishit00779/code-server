<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Code-Server Data Science Environment Setup

This workspace contains scripts and configurations for setting up a comprehensive code-server data science environment on AWS EC2 with user-level installation.

## Project Context

This is a deployment and configuration project for:
- Code-server installation with data science extensions
- Python environment setup with conda and essential packages
- AWS EC2 security hardening and monitoring
- SSL/HTTPS configuration with Let's Encrypt
- Nginx reverse proxy configuration
- Automated backup and monitoring setup

## Key Components

1. **Installation Scripts**: Bash scripts for automated setup
2. **Configuration Files**: Nginx, systemd, and application configs
3. **Security Scripts**: AWS security group, IAM, and system hardening
4. **Documentation**: Comprehensive setup and troubleshooting guides

## Development Guidelines

When working with this project:
- Follow bash scripting best practices with error handling and logging
- Maintain security-first approach for all configurations
- Ensure scripts are idempotent (safe to run multiple times)
- Include comprehensive error messages and user feedback
- Test on Ubuntu/Amazon Linux environments
- Keep configurations modular and well-documented

## Code Style

- Use consistent color coding for script output
- Include proper error trapping and cleanup
- Add verbose status messages for user feedback
- Follow AWS security best practices
- Use meaningful variable names and comments
