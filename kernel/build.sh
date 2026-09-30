#!/bin/bash
# Configures and builds the kernel source in the current directory for
# virtink (Cloud Hypervisor) guests, and writes vmlinux and config to $1.
#
# The config is the architecture's defconfig and kvm_guest.config, followed by
# the fragments of the kernel's series directory next to this script:
# common.config, then $TARGETARCH.config if it exists.
#
# Environment: KERNEL_VERSION (such as 6.18.54), TARGETARCH (amd64 or arm64).
set -euo pipefail

out=$1
series=$(echo "$KERNEL_VERSION" | cut -d. -f1-2)
config_dir="$(dirname "$(realpath "$0")")/$series"

if [ ! -f "$config_dir/common.config" ]; then
    echo >&2 "error: no config for kernel series $series in $config_dir"
    exit 1
fi

case "$TARGETARCH" in
    amd64) export ARCH=x86 CROSS_COMPILE=x86_64-linux-gnu- ;;
    arm64) export ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- ;;
    *) echo >&2 "error: unsupported architecture '$TARGETARCH'"; exit 1 ;;
esac
export KBUILD_BUILD_USER=virtink KBUILD_BUILD_HOST=virtink-linux

fragments=("$config_dir/common.config")
if [ -f "$config_dir/$TARGETARCH.config" ]; then
    fragments+=("$config_dir/$TARGETARCH.config")
fi

make defconfig kvm_guest.config
scripts/kconfig/merge_config.sh -m .config "${fragments[@]}"
make olddefconfig

# merge_config.sh only warns about values Kconfig dropped, such as ones with
# unmet dependencies, so check that every requested value made it.
failed=0
while IFS= read -r line; do
    case "$line" in
        CONFIG_*=*)
            if ! grep -qxF -- "$line" .config; then
                echo >&2 "error: requested '$line', got '$(grep -E "^(# )?${line%%=*}[= ]" .config || echo "<undefined>")'"
                failed=1
            fi
            ;;
        "# CONFIG_"*" is not set")
            symbol=$(echo "$line" | cut -d' ' -f2)
            if grep -q "^$symbol=" .config; then
                echo >&2 "error: requested '$line', got '$(grep "^$symbol=" .config)'"
                failed=1
            fi
            ;;
    esac
done < <(cat "${fragments[@]}")
if [ "$failed" -ne 0 ]; then
    exit 1
fi

mkdir -p "$out"
case "$TARGETARCH" in
    amd64)
        # Cloud Hypervisor boots the uncompressed ELF through its PVH entry
        # point. The flag is from its kernel build instructions, and stops the
        # assembler adding x86 ISA property notes to the ELF.
        make -j"$(nproc)" KCFLAGS="-Wa,-mx86-used-note=no" bzImage
        cp arch/x86/boot/compressed/vmlinux.bin "$out/vmlinux"
        ;;
    arm64)
        make -j"$(nproc)" Image
        cp arch/arm64/boot/Image "$out/vmlinux"
        ;;
esac
cp .config "$out/config"
