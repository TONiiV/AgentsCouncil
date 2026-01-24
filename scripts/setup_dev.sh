#!/bin/bash

# Development Setup Script
# Usage: ./scripts/setup_dev.sh <agent>

# This script is for general development environment setup.
# Currently, it installs the UI/UX Pro Skill for the specified AI agent.

# Function to setup UI/UX Pro Skill
setup_ui_ux_pro_skill() {
    local agent=$1
    echo "Step 1: Setting up UI/UX Pro Skill..."

    # Check if npm is installed
    if ! command -v npm &> /dev/null; then
        echo "Error: npm is not installed. Please install Node.js and npm first."
        exit 1
    fi

    # Check if uipro-cli is already installed
    if npm list -g uipro-cli --depth=0 &> /dev/null; then
        echo "uipro-cli is already installed. Updating..."
        npm update -g uipro-cli
    else
        echo "Installing uipro-cli globally..."
        npm install -g uipro-cli
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to install/update uipro-cli. You might need to run this with sudo."
        exit 1
    fi

    # Initialize for the specific agent
    echo "Initializing uipro for $agent..."
    uipro init --ai "$agent"

    if [ $? -eq 0 ]; then
        echo "UI/UX Pro Skill setup successful."
    else
        echo "Warning: UI/UX Pro Skill setup encountered an issue."
    fi
}

# Check if an argument is provided
if [ -z "$1" ]; then
    echo "Error: No AI agent specified."
    echo "Usage: $0 <agent>"
    echo "Available agents: claude, cursor, windsurf, antigravity, copilot, kiro, codex, qoder, roocode, gemini, trae, opencode, continue, codebuddy, all"
    exit 1
fi

AGENT=$1

echo "========================================"
echo "Starting Development Setup for: $AGENT"
echo "========================================"

setup_ui_ux_pro_skill "$AGENT"

echo "========================================"
echo "Development Setup Complete for $AGENT"
