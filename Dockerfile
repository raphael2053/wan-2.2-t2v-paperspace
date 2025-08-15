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
    iputils-ping \
    sudo \
    dialog \
    && rm -rf /var/lib/apt/lists/*

# Ensure python3.12 is default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.12 1 \
 && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

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

# Install Jupyter packages
RUN $PIP_INSTALL \
    jupyterlab==4.0.5 \
    jupyter_server==2.7.2 \
    notebook==7.0.3 \
    jupyter==1.0.0

# Install Node.js for Jupyter extensions (updated versions for compatibility)
RUN curl -sL https://deb.nodesource.com/setup_18.x | bash && \
    $APT_INSTALL nodejs && \
    $PIP_INSTALL \
        jupyter_contrib_nbextensions==0.7.0 \
        jupyter_nbextensions_configurator==0.6.3 \
        jupyterlab-widgets==3.0.8 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3.12 -m pip cache purge

# Enable nbextensions and menubar (with error handling)
RUN jupyter nbextensions_configurator enable --user || true && \
    jupyter contrib nbextension install --user || true

# Enable useful Jupyter Notebook extensions (with error handling for compatibility)
RUN jupyter nbextension enable spellchecker/main || true && \
    jupyter nbextension enable snippets_menu/main || true && \
    jupyter nbextension enable snippets/main || true && \
    jupyter nbextension enable freeze/main || true && \
    jupyter nbextension enable livemdpreview/livemdpreview || true && \
    jupyter nbextension enable highlight_selected_word/main || true && \
    jupyter nbextension enable execute_time/ExecuteTime || true && \
    jupyter nbextension enable toc2/main || true

# ==================================================================
# Startup
# ------------------------------------------------------------------

EXPOSE 8888 6006

CMD ["jupyter", "lab", "--allow-root", "--ip=0.0.0.0", "--no-browser", "--ServerApp.trust_xheaders=True", "--ServerApp.disable_check_xsrf=False", "--ServerApp.allow_remote_access=True", "--ServerApp.allow_origin=*", "--ServerApp.allow_credentials=True"]