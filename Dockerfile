# Dockerfile for stable, reproducible PyTorch 2.8.0+cu128 + CUDA 12.8 environment
FROM nvidia/cuda:12.8.1-devel-ubuntu24.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV SHELL=/bin/bash

# Convenient environment variables for package installation
ENV APT_INSTALL="apt-get install -y --no-install-recommends"
ENV PIP_INSTALL="python3.12 -m pip --no-cache-dir install --break-system-packages"

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
    python3.12 \
    python3.12-venv \
    python3.12-dev \
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
    sudo \
    dialog \
    && rm -rf /var/lib/apt/lists/*

# Ensure python3.12 is default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
 && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Configure pip to always use --break-system-packages
RUN mkdir -p /root/.pip && \
    echo '[global]\nbreak-system-packages = true' > /root/.pip/pip.conf

# Configure bash completion and readline
RUN echo 'source /etc/bash_completion' >> /root/.bashrc \
 && echo 'set completion-ignore-case on' >> /root/.inputrc \
 && echo 'set show-all-if-ambiguous on' >> /root/.inputrc \
 && echo 'set completion-query-items 200' >> /root/.inputrc

# Upgrade pip and install torch 2.8.0+cu128 (use python3.12 explicitly)
RUN python3.12 -m pip install --upgrade --ignore-installed pip setuptools wheel --break-system-packages

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
 && python3.12 -m ipykernel install --user --name torch28 --display-name "Python (torch2.8-cu128)"

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
    python3.12 -m pip cache purge

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

# Start Jupyter Lab
echo "Starting Jupyter Lab..."
exec jupyter lab --allow-root --ip=0.0.0.0 --no-browser --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin=* --ServerApp.allow_credentials=True
EOF

RUN chmod +x /start.sh

# ==================================================================
# Startup
# ------------------------------------------------------------------

EXPOSE 8888 6006 22

CMD ["/start.sh"]