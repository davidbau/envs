#!/usr/bin/env bash

# Bash script to set up an anaconda python-based deep learning environment
# that has support for pytorch, tensorflow, pycaffe in the same environment,
# long with juypter, scipy etc.

# This should not require root.  However, it does copy and build a lot of
# binaries into your ~/.conda directory.  If you do not want to store
# these in your homedir disk, then ~/.conda can be a symlink somewhere else.
# (At MIT CSAIL, you should symlink ~/.conda to a directory on NFS or local
# disk instead of leaving it on AFS, or else you will exhaust your quota.)

# Start from parent directory of script
cd "$(dirname "$(dirname "$(readlink -f "$0")")")"

# Default RECIPE 'p3t4' can be overridden by 'RECIPE=foo setup.sh'
RECIPE=${RECIPE:-p3t4}
# Default ENV_NAME 'p3t41' can be overridden by 'ENV_NAME=foo setup.sh'
ENV_NAME="${ENV_NAME:-p3t41}"
echo "Creating conda environment ${ENV_NAME}"

if [[ ! $(type -P conda) ]]
then
    echo "conda not in PATH"
    echo "read: https://conda.io/docs/user-guide/install/index.html"
    exit 1
fi

if df "${HOME}/.conda" --type=afs > /dev/null 2>&1
then
    echo "Not installing: your ~/.conda directory is on AFS."
    echo "Use 'ln -s /some/nfs/dir ~/.conda' to avoid using up your AFS quota."
    exit 1
fi

# Uninstall existing environment
source deactivate
rm -rf ~/.conda/envs/${ENV_NAME}
rm -rf pytorch torchvision

# Build new environment: torch and torch vision from source
conda env create --name=${ENV_NAME} -f script/${RECIPE}.yml
source activate ${ENV_NAME}
export CMAKE_PREFIX_PATH="$(dirname $(which conda))/../"
conda uninstall -y pytorch
pip uninstall -y torch
# Repair this missing symlink
pushd $(dirname $(which caffe))/../lib
ln -s libgflags.so.2.2 libgflags.so.2
popd
PYTORCH_SRC="${HOME}/.conda/envs/${ENV_NAME}/source/pytorch"
mkdir -p "${PYTORCH_SRC}"
# Post-v0.4.0 version that fixes eigen build issue.
git clone --depth 1 --recursive \
    --branch v0.4.1 \
    https://github.com/pytorch/pytorch \
    "${PYTORCH_SRC}"
pushd "${PYTORCH_SRC}"
# Cross-compile for all common NVIDIA hardware, not just this machine's.
CMAKE_PREFIX_PATH="${HOME}/.conda/envs/${ENV_NAME}/" \
TORCH_CUDA_ARCH_LIST="3.5 5.2 6.1 7.0 7.0+PTX" \
MAX_JOBS=12 \
python setup.py install
popd
TVISION_SRC="${HOME}/.conda/envs/${ENV_NAME}/source/torchvision"
mkdir -p "${TVISION_SRC}"
git clone --depth 1 --recursive --branch v0.2.1 \
    https://github.com/pytorch/vision \
    "${TVISION_SRC}"
pushd "${TVISION_SRC}"
MKLROOT="${HOME}/.conda/envs/${ENV_NAME}/" \
TORCH_CUDA_ARCH_LIST="3.5 5.2 6.1 7.0 7.0+PTX" \
MAX_JOBS=12 \
python setup.py install
popd
