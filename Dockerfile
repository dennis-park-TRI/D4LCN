ARG BASE_DOCKER_IMAGE
FROM $BASE_DOCKER_IMAGE
# FROM nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04

ARG python=3.6
ENV PYTHON_VERSION=${python}

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
      # essential
      build-essential \
      cmake \
      ffmpeg \
      g++-4.8 \
      git \
      curl \
      docker.io \
      vim \
      wget \
      unzip \
      ca-certificates \
      htop \
      libjpeg-dev \
      libpng-dev \
      libavdevice-dev \
      pkg-config \
      # python
      python${PYTHON_VERSION} \
      python${PYTHON_VERSION}-dev \
      python3-tk \
      python${PYTHON_VERSION}-distutils \
      # opencv
      python3-opencv \
      # For compiling native KITTI evaluator
      libboost-all-dev \
    # set python
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python \
    && ln -sf /usr/bin/python${PYTHON_VERSION} /usr/bin/python3 \
    && rm -rf /var/lib/apt/lists/*

# (dennis.park) For KITTI offical evaluator.
RUN wget https://dl.bintray.com/boostorg/release/1.74.0/source/boost_1_74_0.tar.gz
RUN mkdir -p /usr/include/boost && tar zxf boost_1_74_0.tar.gz -C /usr/include/boost --strip-components=1
ENV BOOST_ROOT=/usr/include/boost

RUN curl -O https://bootstrap.pypa.io/get-pip.py && \
    python get-pip.py && \
    rm get-pip.py

RUN pip install -U \
    numpy scipy pandas matplotlib seaborn boto3 requests tenacity tqdm awscli scikit-image

RUN pip install -U \
    torchfile numba visdom easydict shapely

# TRI-specific environment variables.
ARG AWS_SECRET_ACCESS_KEY
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

ARG AWS_ACCESS_KEY_ID
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}

ARG AWS_DEFAULT_REGION
ENV AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

ARG WANDB_ENTITY
ENV WANDB_ENTITY=${WANDB_ENTITY}

ARG WANDB_API_KEY
ENV WANDB_API_KEY=${WANDB_API_KEY}

ARG MDM_API_KEY
ENV MDM_API_KEY=${MDM_API_KEY}


# Install Open MPI
RUN mkdir /tmp/openmpi && \
    cd /tmp/openmpi && \
    wget https://www.open-mpi.org/software/ompi/v4.0/downloads/openmpi-4.0.0.tar.gz && \
    tar zxf openmpi-4.0.0.tar.gz && \
    cd openmpi-4.0.0 && \
    ./configure --enable-orterun-prefix-by-default && \
    make -j $(nproc) all && \
    make install && \
    ldconfig && \
    rm -rf /tmp/openmpi

# Install OpenSSH for MPI to communicate between containers
RUN apt-get update && apt-get install -y --no-install-recommends openssh-client openssh-server && \
    mkdir -p /var/run/sshd

# Allow OpenSSH to talk to containers without asking for confirmation
RUN cat /etc/ssh/ssh_config | grep -v StrictHostKeyChecking > /etc/ssh/ssh_config.new && \
    echo "    StrictHostKeyChecking no" >> /etc/ssh/ssh_config.new && \
    mv /etc/ssh/ssh_config.new /etc/ssh/ssh_config

# Install pytorch
# RUN pip install -U torch torchvision # This uses CUDA 10.2
# RUN pip install torch==1.5.1+cu101 torchvision==0.6.1+cu101 -f https://download.pytorch.org/whl/torch_stable.html
# nightly

# ouroboros install pytorch 1.4, so upgrade it.
RUN pip install numpy && pip install -U --pre torch torchvision -f https://download.pytorch.org/whl/nightly/cu101/torch_nightly.html

# Install cocoapi
# RUN pip install cython && pip install 'git+https://github.com/cocodataset/cocoapi.git#subdirectory=PythonAPI'
RUN pip install cython && pip install -U pycocotools

# Install fvcore
RUN pip install 'git+https://github.com/facebookresearch/fvcore'
ENV FVCORE_CACHE="/tmp"

RUN pip install -U wandb mpi4py onnx==1.5.0 onnxruntime coloredlogs pycuda

# Copy and install package
ARG WORKSPACE
COPY . ${WORKSPACE}
WORKDIR ${WORKSPACE}
# # ENV TORCH_CUDA_ARCH_LIST="Kepler;Kepler+Tesla;Maxwell;Maxwell+Tegra;Pascal;Volta;Turing"
# ENV TORCH_CUDA_ARCH_LIST="Pascal;Volta;Turing"
# ENV FORCE_CUDA="1"
# # RUN mkdir ${WORKSPACE}/detectron2_C && touch ${WORKSPACE}/detectron2_C/__init__.py
# # RUN python setup.py build develop

# RUN ln -s /mnt/fsx/datasets/KITTI3D data/kitti
# RUN ln -s /mnt/fsx/datasets/KITTI3D/testing data/kitti_split1/testing
# RUN ln -s /mnt/fsx/kitti_dorn_depth data/kitti_dorn_depth

# RUN python data/kitti_split1/setup_split.py
# RUN python data/kitti_split1/setup_depth.py

# RUN sh data/kitti_split1/devkit/cpp/build.sh
RUN cd lib/nms && make

RUN mkdir -p ${WORKSPACE}/../d4lcn_lib/
# RUN cp -r ${WORKSPACE}/lib ${WORKSPACE}/../d4lcn_lib/
RUN cp -r ${WORKSPACE}/lib/nms ${WORKSPACE}/../d4lcn_lib/

RUN mkdir -p ${WORKSPACE}/../d4lcn_data

WORKDIR ${WORKSPACE}

#######################
# Optional pip packages
#######################

# # Install cityscapesscripts
# # To use detectron2 Cityscapes dataset (data preparation, eval)
# RUN pip install pip install cityscapesscripts shapely

# ouroboros-evaluate for 3D detection.
WORKDIR ${WORKSPACE}/../
RUN git clone https://github.awsinternal.tri.global/ouroboros/ouroboros-evaluate.git
RUN pip install -U numba

WORKDIR ${WORKSPACE}

# For eGPU on Lenovo P52
ENV CUDA_VISIBLE_DEVICES=0
