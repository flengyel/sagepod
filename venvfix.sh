#!/bin/bash
# Exit on any error
set -e
# Check if a Python version is passed as an argument
if [ $# -eq 0 ]; then
    PYTHON=python3
else
    PYTHON=$1
fi
# Remove old virtual environment components
echo "Removing old virtual environment directories..."
rm -rf bin include lib pyvenv.cfg
# Rebuild virtual environment
echo "Creating new virtual environment with $PYTHON..."
$PYTHON -m venv .
# Activate the virtual environment
source bin/activate
# Upgrade essential tools
echo "Upgrading pip, setuptools, and wheel..."
pip install --upgrade pip setuptools wheel
# Install dependencies
if [ -f requirements.txt ]; then
    echo "Installing dependencies from requirements.txt..."
    pip install -r requirements.txt
else
    echo "requirements.txt not found! Skipping dependency installation."
fi
# Deactivate the virtual environment
deactivate
echo "Virtual environment rebuilt."

