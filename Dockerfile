# Dockerfile for stable, reproducible PyTorch 2.4.0+cu121 + CUDA 12.1 environment
FROM nvidia/cuda:12.1.1-devel-ubuntu22.04

# Prevent interactive prompts
ENV DEBIAN_FRONTEND=noninteractive

# Set up locale and essentials
RUN apt-get update --fix-missing && apt-get install -y --no-install-recommends \
    software-properties-common \
    wget \
    curl \
    git \
    ca-certificates \
    build-essential \
    unzip \
    pkg-config \
    python3.11 \
    python3.11-venv \
    python3.11-distutils \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Ensure python3.11 is default python
RUN update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
 && update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

# Upgrade pip and install torch 2.4.0+cu121
RUN python -m pip install --upgrade pip setuptools wheel

# Install PyTorch + related (matching CUDA 12.1)
RUN python -m pip install \
    "torch==2.4.0+cu121" \
    "torchvision==0.19.0+cu121" \
    "torchaudio==2.4.0" \
    --index-url https://download.pytorch.org/whl/cu121

# Optional: install Jupyter and common utilities
RUN python -m pip install jupyterlab fastapi uvicorn pydantic

# Create workspace dir
WORKDIR /workspace

# Install ipykernel so you can select this env in notebooks
RUN python -m pip install ipykernel \
 && python -m ipykernel install --user --name torch24 --display-name "Python (torch24)"

CMD jupyter notebook --allow-root --ip=0.0.0.0 --no-browser --ServerApp.trust_xheaders=True --ServerApp.disable_check_xsrf=False --ServerApp.allow_remote_access=True --ServerApp.allow_origin='*' --ServerApp.allow_credentials=True