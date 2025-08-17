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

# Ensure venv activation is in bashrc (check if not already added)
if ! grep -q "Auto-activate virtual environment" /root/.bashrc; then
    echo "" >> /root/.bashrc
    echo "# Environment variables for persistent workspace" >> /root/.bashrc
    echo "export WORKSPACE_PATH=\"/workspace\"" >> /root/.bashrc
    echo "export COMFYUI_PATH=\"/workspace/comfyui\"" >> /root/.bashrc
    echo "export VENV_PATH=\"/workspace/venv\"" >> /root/.bashrc
    echo "export UV_LINK_MODE=copy" >> /root/.bashrc
    echo "" >> /root/.bashrc
    echo "# Auto-activate virtual environment" >> /root/.bashrc
    echo "if [ -f \"\$VENV_PATH/bin/activate\" ]; then" >> /root/.bashrc
    echo "    source \"\$VENV_PATH/bin/activate\"" >> /root/.bashrc
    echo "    export PATH=\"\$VENV_PATH/bin:\$PATH\"" >> /root/.bashrc
    echo "fi" >> /root/.bashrc
    echo "" >> /root/.bashrc
    echo "# ComfyUI convenience aliases" >> /root/.bashrc
    echo "alias comfyinstall='comfy --workspace=\$COMFYUI_PATH install'" >> /root/.bashrc
    echo "alias comfylaunch='cd \$COMFYUI_PATH && \$VENV_PATH/bin/python main.py --listen 0.0.0.0 --port 8080'" >> /root/.bashrc
    echo "alias comfypip='find \$COMFYUI_PATH -type f -name requirements.txt -exec \$VENV_PATH/bin/pip install -r \"{}\" \\;'" >> /root/.bashrc
    echo "✅ Virtual environment activation added to shell profile"
fi

# Upgrade pip in venv (safe to do on existing venv)
pip install --upgrade pip

# Install uv package manager in venv (required by ComfyUI-Manager)
echo "📦 Installing uv package manager in virtual environment..."
pip install uv

# ==================================================================
# Core Python Package Installation
# ------------------------------------------------------------------

# Check if packages are already installed to skip reinstallation
if python -c "import torch" 2>/dev/null; then
    echo "✅ PyTorch already installed, skipping..."
else
    echo "📦 Installing PyTorch and CUDA packages..."
    pip install \
        "torch==2.8.0+cu128" \
        "torchvision==0.23.0+cu128" \
        "torchaudio==2.8.0" \
        --index-url https://download.pytorch.org/whl/cu128
fi

echo "📦 Installing essential Python packages for data science and ML..."
pip install \
    numpy \
    scipy \
    pandas \
    matplotlib \
    seaborn \
    scikit-learn \
    scikit-image \
    "opencv-python-headless==4.10.0.84" \
    pillow \
    tqdm \
    ipython \
    ipywidgets \
    fastapi \
    uvicorn \
    pydantic \
    imageio-ffmpeg || echo "⚠️  Some essential packages failed to install, continuing..."

echo "📦 Installing platform-specific Python packages..."
pip install \
    huggingface_hub[cli] \
    comfy-cli

echo "📦 Installing Wan2.2 specific requirements..."
pip install \
    "diffusers>=0.31.0" \
    "transformers>=4.49.0" \
    "tokenizers>=0.20.3" \
    "accelerate>=1.1.1" \
    "imageio[ffmpeg]" \
    easydict \
    ftfy \
    dashscope \
    imageio-ffmpeg

echo "📦 Installing flash attention (may take a while)..."
pip install flash_attn --no-build-isolation || echo "⚠️  Flash attention installation failed, continuing without it"

echo "📦 Installing ComfyUI specific requirements..."
pip install \
    "comfyui-frontend-package==1.25.8" \
    "comfyui-workflow-templates==0.1.59" \
    "comfyui-embedded-docs==0.2.6" \
    torchsde \
    einops \
    sentencepiece \
    "safetensors>=0.4.2" \
    "aiohttp>=3.11.8" \
    "yarl>=1.18.0" \
    pyyaml \
    psutil \
    alembic \
    SQLAlchemy \
    "av>=14.2.0" \
    "kornia>=0.7.1" \
    spandrel \
    soundfile \
    "pydantic-settings~=2.0" \
    onnx \
    onnxruntime-gpu

echo "📦 Installing optional performance packages..."
pip install sageattention || echo "⚠️  SageAttention installation failed, continuing without it"

echo "📦 Installing Jupyter packages..."
pip install \
    "jupyterlab>=4.0.0,<5.0.0" \
    "jupyter_server>=2.7.0,<3.0.0" \
    "notebook>=7.0.0,<8.0.0" \
    "jupyter>=1.0.0" \
    "jupyter-events>=0.7.0" \
    jupyterlab-widgets

echo "📦 Installing ipykernel for notebook environments..."
pip install ipykernel
python -m ipykernel install --user --name torch28 --display-name "Python (torch2.8-cu128)"

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
if command -v comfy &> /dev/null; then
    comfy set-default "$COMFYUI_PATH/" || echo "⚠️  ComfyUI configuration failed, but continuing..."
else
    echo "⚠️  ComfyUI CLI not found, skipping default path setup"
fi
echo "✅ ComfyUI workspace configured"
echo "💡 Use 'comfylaunch' command to start ComfyUI with persistent venv"

# ==================================================================
# Jupyter Setup
# ------------------------------------------------------------------

# Change back to workspace root
cd $WORKSPACE_PATH

# Start Jupyter Lab (will use venv when activated)
echo "Starting Jupyter Lab with hybrid environment (system + persistent packages)..."
exec jupyter lab --allow-root --ip=0.0.0.0 --port=8888 --no-browser --IdentityProvider.token='' --ServerApp.password='' --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin=* --ServerApp.allow_credentials=True
