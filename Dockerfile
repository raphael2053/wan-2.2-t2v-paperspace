# Dockerfile for stable, reproducible PyTorch 2.8.0+cu128 + CUDA 12.8 environment on Ubuntu 22.04
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV SHELL=/bin/bash

# Public SSH key for root user, set at runtime
ENV PUBLIC_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDTZDMPu+VfsxfKyR1geHFo8FoU6b+K8syw3AZuMAYpWbxWzsyjy3Y9r0EkhqyO+svUZ2xGrrdELPW6Rh6NDW4+MoF11r0bczdgvDX3hibktR33+P86GfvBBzQ8woIxzM4CHu3cfiX6u28bwfcg0jx+o3qwN3YzL5QJM6FjCNVLwEiXIF6zSTlsvzRHDXY89IYQh6TWIgFdhFufBYEkY553qzaJErayLimx3n4heqOjY4YeQ5u+uI1uugSJbIyNNrw3SPbMDTCBGPGC9uV27YPxkxVH3wgP3tSchS4VWGGlyczIwWwsP8ZHRwZUjybp7pmNKq65rB/0dnBNYocFWHoHdeq5Ac/jSv66uRTV1yCljL+4meH5iNW7B8X0MOaNQ65nr6lNPb6DrRHFQT0GTKCUDS9pGeuruv+zwo8258Idwd176A/RM4qSeisq9oIEs0qCDDEc3Rw7uCnaew+CEUs55i9qZ5Te692X6UJW7lUG1I3LUdA9poyJQVCxm5uXqhk= raphael.guan@icloud.com"

# Convenient environment variables for package installation
ENV APT_INSTALL="apt-get install -y --no-install-recommends"
ENV PIP_INSTALL="python3 -m pip --no-cache-dir install"

# Path
ENV WORKSPACE_PATH="/workspace"
ENV COMFYUI_PATH="/workspace/comfyui"

# Set up locale and essentials
RUN apt-get update --fix-missing && $APT_INSTALL \
    software-properties-common \
    wget \
    curl \
    git \
    ca-certificates \
    build-essential \
    unzip \
    pkg-config \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    bash-completion \
    readline-common \
    libreadline8 \
    nano \
    vim \
    less \
    htop \
    tmux \
    rsync \
    zip \
    unrar \
    jq \
    man-db \
    manpages \
    manpages-dev \
    openssh-client \
    openssh-server \
    iputils-ping \
    iproute2 \
    net-tools \
    sudo \
    dialog \
    ninja-build \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libgomp1 \
    libglib2.0-0 \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Ensure python3 is default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3 1 \
 && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Upgrade pip and install essential tools
RUN python3 -m pip install --upgrade pip setuptools wheel

# Install uv (fast Python package manager) for ComfyUI compatibility
RUN $PIP_INSTALL uv

# Configure bash completion and readline
RUN echo 'source /etc/bash_completion' >> /root/.bashrc \
 && echo 'set completion-ignore-case on' >> /root/.inputrc \
 && echo 'set show-all-if-ambiguous on' >> /root/.inputrc \
 && echo 'set completion-query-items 200' >> /root/.inputrc

# Install PyTorch + related (matching CUDA 12.8)
RUN $PIP_INSTALL \
    "torch==2.8.0+cu128" \
    "torchvision==0.23.0+cu128" \
    "torchaudio==2.8.0" \
    --index-url https://download.pytorch.org/whl/cu128

# Essential Python packages for data science and ML
RUN $PIP_INSTALL \
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
    imageio-ffmpeg

# Install Platform-specific Python packages
RUN $PIP_INSTALL \
    huggingface_hub[cli] \
    comfy-cli

# Install Wan2.2 specific requirements
RUN $PIP_INSTALL \
    "diffusers>=0.31.0" \
    "transformers>=4.49.0" \
    "tokenizers>=0.20.3" \
    "accelerate>=1.1.1" \
    "imageio[ffmpeg]" \
    easydict \
    ftfy \
    dashscope \
    imageio-ffmpeg

# Install flash attention (requires compilation, done separately for better error handling)
RUN $PIP_INSTALL flash_attn --no-build-isolation || echo "Flash attention installation failed, continuing without it"

# Install ComfyUI specific requirements
RUN $PIP_INSTALL \
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

# Install optional performance packages for ComfyUI
RUN $PIP_INSTALL sageattention || echo "SageAttention installation failed, continuing without it"

# Create workspace dir
WORKDIR /workspace

# Install ipykernel so you can select this env in notebooks
RUN $PIP_INSTALL ipykernel \
 && python3 -m ipykernel install --user --name torch28 --display-name "Python (torch2.8-cu128)"

# ==================================================================
# JupyterLab & Notebook with Extensions
# ------------------------------------------------------------------

# Install Jupyter packages (updated for compatibility)
RUN $PIP_INSTALL \
    "jupyterlab>=4.0.0,<5.0.0" \
    "jupyter_server>=2.7.0,<3.0.0" \
    "notebook>=7.0.0,<8.0.0" \
    "jupyter>=1.0.0" \
    "jupyter-events>=0.7.0"

# Install Node.js for JupyterLab extensions
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash && \
    $APT_INSTALL nodejs && \
    $PIP_INSTALL \
        jupyterlab-widgets && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip cache purge

# ==================================================================
# SSH Configuration
# ------------------------------------------------------------------

# Configure SSH server
RUN mkdir -p /var/run/sshd && \
    mkdir -p /root/.ssh && \
    chmod 700 /root/.ssh && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config && \
    sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config

# Create startup script to handle SSH and Jupyter
RUN tee /start.sh > /dev/null <<'EOF'
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

# Start Jupyter Lab
echo "Starting Jupyter Lab..."
exec jupyter lab --allow-root --ip=0.0.0.0 --port=8888 --no-browser --IdentityProvider.token='' --ServerApp.password='' --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin=* --ServerApp.allow_credentials=True
EOF

RUN chmod +x /start.sh

# ==================================================================
# Startup
# ------------------------------------------------------------------

EXPOSE 8888 8080 22

CMD ["/start.sh"]