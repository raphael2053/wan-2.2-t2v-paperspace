#!/bin/bash
set -e

# Setup SSH keys from environment if provided
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "SSH public key configured from PUBLIC_KEY environment variable"
else
    echo "No PUBLIC_KEY provided at startup - SSH key authentication not configured"
fi

# Start SSH daemon
service ssh start
if [ $? -eq 0 ]; then
    echo "SSH service started successfully"
else
    echo "Failed to start SSH service"
    exit 1
fi

# ==================================================================
# Python Virtual Environment Setup
# ------------------------------------------------------------------

# Setup persistent virtual environment with system-site-packages access
if [ ! -d "$VENV_PATH" ]; then
    echo "Creating new persistent Python virtual environment..."
    python3 -m venv "$VENV_PATH" --system-site-packages
    echo "✅ Virtual environment created at $VENV_PATH"
else
    echo "✅ Using existing virtual environment at $VENV_PATH"
fi

# Activate virtual environment
source "$VENV_PATH/bin/activate"
export PATH="$VENV_PATH/bin:$PATH"
echo "✅ Virtual environment activated (with access to system packages)"

# Upgrade pip in venv (safe to do on existing venv)
pip install --upgrade pip

# Install user requirements if they exist
if [ -f "$WORKSPACE_PATH/requirements.txt" ]; then
    echo "📦 Installing additional packages from requirements.txt..."
    pip install -r "$WORKSPACE_PATH/requirements.txt"
    echo "✅ Additional requirements installed successfully"
fi

# ==================================================================
# ComfyUI Setup
# ------------------------------------------------------------------

# Set ComfyUI default path
echo "Setting ComfyUI default workspace path..."
comfy set-default "$COMFYUI_PATH/" || true

# ==================================================================
# Jupyter Setup
# ------------------------------------------------------------------

# Change back to workspace root
cd $WORKSPACE_PATH

# Start Jupyter Lab (will use venv when activated)
echo "Starting Jupyter Lab with hybrid environment (system + persistent packages)..."
exec jupyter lab --allow-root --ip=0.0.0.0 --port=8888 --no-browser --IdentityProvider.token='' --ServerApp.password='' --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin=* --ServerApp.allow_credentials=True
