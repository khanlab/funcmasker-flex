Bootstrap: docker
From: python:3.8.12-bullseye


%setup
mkdir -p $SINGULARITY_ROOTFS/src
cp -Rv . $SINGULARITY_ROOTFS/src

%runscript
funcmasker-flex "$@"

%post

apt install -y graphviz-dev && pip install --upgrade pip && pip install /src

%environment

#add external binaries to the path
export PATH=/src/ext-bin:$PATH
