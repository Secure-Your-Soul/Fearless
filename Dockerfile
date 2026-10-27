FROM debian:stable-slim
ARG HOST_UID=1000
ARG HOST_GID=1000
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build Project
    make \
    # Initramfs
    curl ca-certificates \
    # Kernel
    ccache clang lld bc llvm libelf-dev libssl-dev flex bison \
    # ISO
    xorriso dosfstools mtools\
    # Test ISO
    file genisoimage parted \
    # Sign
    gnupg pcscd \
    # Qemu Test
    qemu-system-x86 ovmf \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -g "${HOST_GID}" builder && \
    useradd -m -u "${HOST_UID}" -g "${HOST_GID}" -s /bin/bash builder
USER builder
WORKDIR /build