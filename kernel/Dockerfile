# syntax=docker/dockerfile:1

# Builds a kernel.org kernel for virtink (Cloud Hypervisor) guests into an
# image that holds nothing but /vmlinux, which is the layout virtink expects of
# kernel images. The build context is the kernel directory, and the config is
# taken from the directory of the kernel's series, such as 6.18/ for 6.18.54.
#
#   docker buildx build kernel --build-arg KERNEL_VERSION=6.18.54 \
#     --platform linux/amd64,linux/arm64 -t virtink-kernel:6.18.54
#
# The "artifacts" target exports the kernel and its final .config instead:
#
#   docker buildx build kernel --build-arg KERNEL_VERSION=6.18.54 \
#     --target artifacts --output type=local,dest=out

# Every architecture is cross-compiled on the build platform, which is much
# faster than building under emulation.
FROM --platform=$BUILDPLATFORM debian:trixie-slim AS toolchain

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bc bison ca-certificates cpio curl flex gcc gcc-aarch64-linux-gnu gcc-x86-64-linux-gnu \
        libc6-dev libelf-dev libssl-dev make python3 xz-utils && \
    rm -rf /var/lib/apt/lists/*

FROM toolchain AS source

ARG KERNEL_VERSION

WORKDIR /src
RUN set -eu; \
    test -n "$KERNEL_VERSION" || { echo >&2 "error: KERNEL_VERSION is required"; exit 1; }; \
    tarball="linux-$KERNEL_VERSION.tar.xz"; \
    base="https://cdn.kernel.org/pub/linux/kernel/v${KERNEL_VERSION%%.*}.x"; \
    curl -fsSLO "$base/$tarball"; \
    curl -fsSL "$base/sha256sums.asc" | grep -F "  $tarball" > "$tarball.sha256" || { echo >&2 "error: no checksum for $tarball"; exit 1; }; \
    sha256sum -c "$tarball.sha256"; \
    tar -xJf "$tarball" --strip-components=1; \
    rm "$tarball" "$tarball.sha256"

FROM source AS build

ARG KERNEL_VERSION
ARG TARGETARCH

COPY . /virtink/
RUN /virtink/build.sh /out

FROM scratch AS artifacts

COPY --from=build /out/ /

FROM scratch

COPY --from=build /out/vmlinux /vmlinux
