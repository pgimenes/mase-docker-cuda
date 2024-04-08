# This Dockerfile configures a Docker environment that
# contains all the required packages for the tool
FROM ubuntu:22.04

USER root
RUN apt-get update -y && apt-get install apt-utils -y
RUN DEBIAN_FRONTEND="noninteractive" apt-get -y install tzdata

# Install basic packages
RUN apt-get upgrade -y
RUN apt-get update -y \
    && apt-get install -y clang graphviz-dev libclang-dev \
                          pkg-config g++ libxtst6 xdg-utils \
                          libboost-all-dev llvm gcc ninja-build \
                          python3 python3-pip build-essential \
                          libssl-dev git vim wget htop sudo \
                          lld parallel clang-format clang-tidy \
                          libtinfo5 libidn11-dev \
                          locales python3-sphinx graphviz

RUN locale-gen en_US.UTF-8

# Install SystemVerilog formatter
RUN mkdir -p /srcPkgs \
    && cd /srcPkgs \
    && wget https://github.com/chipsalliance/verible/releases/download/v0.0-2776-gbaf0efe9/verible-v0.0-2776-gbaf0efe9-Ubuntu-22.04-jammy-x86_64.tar.gz \
    && mkdir -p verible \
    && tar xzvf verible-*-x86_64.tar.gz -C verible --strip-components 1
# Install verilator from source - version v5.020
RUN apt-get update -y \
    && apt-get install -y git perl make autoconf flex bison \
                          ccache libgoogle-perftools-dev numactl \
                          perl-doc libfl2 libfl-dev zlib1g zlib1g-dev \
                          help2man
# Install Verilator from source
RUN mkdir -p /srcPkgs \
    && cd /srcPkgs \
    && git clone https://github.com/verilator/verilator \
    && unset VERILATOR_ROOT \
    && cd verilator \
    && git checkout v5.020 \
    && autoconf \
    && ./configure \
    && make -j 4 \
    && make install

# Install latest Cmake from source
RUN mkdir -p /srcPkgs \
    && cd /srcPkgs \
    && wget https://github.com/Kitware/CMake/releases/download/v3.28.0-rc5/cmake-3.28.0-rc5.tar.gz \
    && mkdir -p cmake \
    && tar xzvf cmake-*.tar.gz -C cmake --strip-components 1 \
    && cd cmake \
    && ./bootstrap --prefix=/usr/local \
    && make -j 4 \
    && make install

# Append any packages you need here
# RUN apt-get ...
RUN apt-get update -y \
    && apt-get install -y clang-12

RUN export DEBIAN_FRONTEND=noninteractive \
    && apt-get install -y software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt update -y \
    && apt install -y python3.11 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 100 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 200 \
    && update-alternatives --config python3
RUN apt install -y python3.11-dev

CMD ["bash"]

# Install PyTorch and Torch-MLIR
RUN pip3 install --upgrade pip
RUN pip3 install --pre torch-mlir torchvision \
                 -f https://github.com/llvm/torch-mlir-release/releases/expanded_assets/dev-wheels \
                 --extra-index-url https://download.pytorch.org/whl/nightly/cpu
RUN pip3 install onnx black toml GitPython colorlog cocotb[bus]==1.8.0 \
                 pytest pytorch-lightning transformers toml \
                 timm pytorch-nlp datasets ipython ipdb \
                 sentencepiece einops deepspeed pybind11 \
                 tabulate tensorboardx hyperopt accelerate \
                 optuna stable-baselines3 h5py scikit-learn \
                 scipy onnxruntime matplotlib sphinx-rtd-theme \
                 imageio imageio-ffmpeg opencv-python kornia einops \
                 ghp-import optimum pytest-profiling myst_parser \
                 pytest-cov pytest-xdist pytest-sugar pytest-html \
                 lightning wandb bitarray bitstring emoji \
    && pip install -U Pillow \
    && pip install mpmath==1.3.0 

# Add environment variables
ARG VHLS_PATH
ARG VHLS_VERSION
RUN printf "\
\nexport LIBRARY_PATH=/usr/lib/x86_64-linux-gnu:\$LIBRARY_PATH \
\n# Basic PATH setup \
\nexport PATH=/workspace/scripts:/workspace/hls/build/bin:/workspace/llvm/build/bin:\$PATH:/srcPkgs/verible/bin \
\n# Vitis HLS setup \
\nexport VHLS=${vhls} \
\nexport XLNX_VERSION=\$XLNX_VERSION \
\n# source \$VHLS_PATH/Vitis_HLS/\$XLNX_VERSION/settings64.sh \
\n# MLIR-AIE PATH setup \
\nexport PATH=/srcPkgs/cmake/bin:/workspace/hls/build/bin:/workspace/llvm/build/bin:/workspace/mlir-aie/install/bin:/workspace/mlir-air/install/bin:\$PATH \
\nexport PYTHONPATH=/workspace:/workspace/machop:/workspace/mlir-aie/install/python:/workspace/mlir-air/install/python:\$PYTHONPATH \
\nexport LD_LIBRARY_PATH=/workspace/mlir-aie/lib:/workspace/mlir-air/lib:/opt/xaiengine:\$LD_LIBRARY_PATH \
\n# Thread setup \
\nexport nproc=\$(grep -c ^processor /proc/cpuinfo) \
\n# Terminal color... \
\nexport PS1=\"[\\\\\\[\$(tput setaf 3)\\\\\\]\\\t\\\\\\[\$(tput setaf 2)\\\\\\] \\\u\\\\\\[\$(tput sgr0)\\\\\\]@\\\\\\[\$(tput setaf 2)\\\\\\]\\\h \\\\\\[\$(tput setaf 7)\\\\\\]\\\w \\\\\\[\$(tput sgr0)\\\\\\]] \\\\\\[\$(tput setaf 6)\\\\\\]$ \\\\\\[\$(tput sgr0)\\\\\\]\" \
\nexport LS_COLORS='rs=0:di=01;96:ln=01;36:mh=00:pi=40;33:so=01;35:do=01;35:bd=40;33;01' \
\nalias ls='ls --color' \
\nalias grep='grep --color'\n" >> /root/.bashrc

#Add vim environment
RUN printf "\
\nset autoread \
\nautocmd BufWritePost *.cpp silent! !clang-format -i <afile> \
\nautocmd BufWritePost *.c   silent! !clang-format -i <afile> \
\nautocmd BufWritePost *.h   silent! !clang-format -i <afile> \
\nautocmd BufWritePost *.hpp silent! !clang-format -i <afile> \
\nautocmd BufWritePost *.cc  silent! !clang-format -i <afile> \
\nautocmd BufWritePost *.py  silent! set tabstop=4 shiftwidth=4 expandtab \
\nautocmd BufWritePost *.py  silent! !python3 -m black <afile> \
\nautocmd BufWritePost *.sv  silent! !verible-verilog-format --inplace <afile> \
\nautocmd BufWritePost *.v  silent! !verible-verilog-format --inplace <afile> \
\nautocmd BufWritePost * redraw! \
\n" >> /root/.vimrc
