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
ENV VENV_PATH="/workspace/venv"

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

# Upgrade pip to latest version
RUN python3 -m pip install --upgrade pip setuptools wheel

# Create workspace dir
WORKDIR /workspace

# Configure bash completion and readline
RUN echo 'source /etc/bash_completion' >> /root/.bashrc \
 && echo 'set completion-ignore-case on' >> /root/.inputrc \
 && echo 'set show-all-if-ambiguous on' >> /root/.inputrc \
 && echo 'set completion-query-items 200' >> /root/.inputrc

# Install Node.js for JupyterLab extensions (needed at build time)
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash && \
    $APT_INSTALL nodejs && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

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

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# ==================================================================
# Startup
# ------------------------------------------------------------------

EXPOSE 8888 8080 22

CMD ["/start.sh"]