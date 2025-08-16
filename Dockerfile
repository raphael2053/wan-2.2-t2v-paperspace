# Dockerfile for stable, reproducible PyTorch 2.8.0+cu128 + CUDA 12.8 environment on Ubuntu 22.04
FROM nvidia/cuda:12.8.1-devel-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV SHELL=/bin/bash

# Convenient environment variables for package installation
ENV APT_INSTALL="apt-get install -y --no-install-recommends"
ENV PIP_INSTALL="python3 -m pip --no-cache-dir install"

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
    opencv-python \
    pillow \
    tqdm \
    ipython \
    ipywidgets \
    fastapi \
    uvicorn \
    pydantic

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
    imageio-ffmpeg \
    flash_attn

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
RUN tee /start.sh > /dev/null <<EOF
#!/bin/bash

# Setup SSH keys from environment if provided
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    echo "$PUBLIC_KEY" > /root/.ssh/authorized_keys
    chmod 600 /root/.ssh/authorized_keys
    echo "SSH public key configured"
else
    echo "No PUBLIC_KEY provided - SSH access will not be available"
    echo "To enable SSH access, set the PUBLIC_KEY environment variable with your public key"
fi

# Start SSH daemon
service ssh start
echo "SSH service started"

# # Setup ComfyUI
# echo "Setting up ComfyUI..."
# if [ -d "/workspace/comfyui" ]; then
#     echo "ComfyUI directory exists, setting default path"
#     comfy set-default /workspace/comfyui/
    
#     # Start ComfyUI in background
#     echo "Starting ComfyUI..."
#     nohup comfy launch -- --listen 0.0.0.0 --port 8080 &
#     COMFY_PID=$!
#     echo "ComfyUI started with PID: $COMFY_PID on port 8080"
#     echo "ComfyUI is running as an independent process"
    
#     # Wait a moment and check if ComfyUI is still running
#     sleep 3
#     if kill -0 $COMFY_PID 2>/dev/null; then
#         echo "ComfyUI is running successfully"
#         echo "Access ComfyUI at: http://localhost:8080"
#     else
#         echo "WARNING: ComfyUI may have failed to start"
#     fi
# else
#     echo "ComfyUI directory /workspace/comfyui does not exist, skipping ComfyUI setup"
#     echo "To use ComfyUI, please install it in /workspace/comfyui/"
# fi

# Start Jupyter Lab
echo "Starting Jupyter Lab..."
exec jupyter lab --allow-root --ip=0.0.0.0 --no-browser --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin=* --ServerApp.allow_credentials=True
EOF

RUN chmod +x /start.sh

# ==================================================================
# Startup
# ------------------------------------------------------------------

EXPOSE 8888 8080 6006 22

CMD ["/start.sh"]