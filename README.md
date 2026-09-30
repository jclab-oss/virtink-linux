# virtink-linux

Kernel and rootfs images for [virtink](https://github.com/jclab-oss/virtink)
VMs that boot with [direct kernel boot](https://github.com/jclab-oss/virtink/blob/main/docs/direct_kernel_boot.md):

- **Kernel images** hold nothing but `/vmlinux`, a kernel.org Linux kernel
  configured for Cloud Hypervisor guests, for `spec.instance.kernel`.
- **Rootfs images** are bootable root filesystems for
  [`imageRootfs`](https://github.com/jclab-oss/virtink/blob/main/docs/disks_and_volumes.md#imagerootfs-volume)
  volumes.

All images are built for `linux/amd64` and `linux/arm64`.

| Image | Source |
| --- | --- |
| `ghcr.io/jclab-oss/virtink-linux-kernel:<version>` | [`kernel/`](kernel) |
| `ghcr.io/jclab-oss/virtink-linux-rootfs-alpine:<version>` | [`rootfs/alpine/`](rootfs/alpine) |

## Usage

```yaml
apiVersion: virt.virtink.smartx.com/v1alpha1
kind: VirtualMachine
metadata:
  name: alpine
spec:
  instance:
    memory:
      size: 1Gi
    kernel:
      image: ghcr.io/jclab-oss/virtink-linux-kernel:6.18
      cmdline: "console=ttyS0 root=/dev/vda rw" # console=ttyAMA0 on arm64
    disks:
      - name: rootfs
      - name: cloud-init
    interfaces:
      - name: pod
  volumes:
    - name: rootfs
      imageRootfs:
        image: ghcr.io/jclab-oss/virtink-linux-rootfs-alpine:3.24
        size: 4Gi
    - name: cloud-init
      cloudInit:
        userData: |-
          #cloud-config
          password: password
          chpasswd: { expire: False }
          ssh_pwauth: True
  networks:
    - name: pod
      pod: {}
```

The Alpine rootfs has no password for root. Log in as `alpine`, the default
user of cloud-init, which can use `doas` and `sudo`.

## Layout

```
kernel/
  Dockerfile, build.sh     build of every kernel series
  <series>/                config of a kernel series, such as 6.18
    common.config          config fragment for all architectures
    <arch>.config          config fragment for amd64 or arm64, optional
rootfs/
  <distro>/<series>/       build of a rootfs series, such as alpine/3.24
    Dockerfile
.github/
  scripts/parse-tag.sh     maps a release tag to its directory and image tags
  workflows/               kernel.yml and rootfs.yml, run on release tags
```

A series directory builds every version of the series, such as `kernel/6.18`
for 6.18.54, so a new patch release only needs a new tag.

## Releasing

Push a tag `<directory>/<version>`, and the workflow builds the series
directory that the version belongs to:

| Tag | Builds | Image tags |
| --- | --- | --- |
| `kernel/6.18.54` | `kernel/6.18` with Linux 6.18.54 | `6.18.54`, `6.18` |
| `rootfs/alpine/3.24.2` | `rootfs/alpine/3.24` from `alpine:3.24.2` | `3.24.2`, `3.24` |

```sh
git tag kernel/6.18.54 && git push origin kernel/6.18.54
```

To rebuild a version, such as after changing its config, add a revision:
`kernel/6.18.54-r1` publishes `6.18.54-r1` and moves `6.18.54` and `6.18` to
it. The series tag always points to the latest push, so pushing an older
version moves it back.

A kernel release is also published as a GitHub release with `vmlinux` and the
final `.config` of each architecture.

## Kernel

The kernel is built from the kernel.org tarball, which is checked against the
`sha256sums.asc` of kernel.org (fetched over HTTPS; its signature is not
verified). The config is the architecture's `defconfig` plus
`kvm_guest.config`, then the series' fragments. The build fails if Kconfig
drops any value of the fragments, such as for an unmet dependency.

Only the kernel image is built and shipped, without modules, so everything
virtink needs is built in: the virtio devices of Cloud Hypervisor, hotplug, the
power button for graceful shutdown, the filesystems of rootfs and cloud-init
volumes, and what containers and Kubernetes need (overlayfs, bridges, VXLAN,
nftables and iptables).

The upstream kernel has no driver for the virtio watchdog of Cloud Hypervisor,
which is in the Cloud Hypervisor kernel fork. virtink doesn't use it.

### Adding a kernel series

1. Copy the latest series directory, such as `kernel/6.18` to `kernel/6.19`.
2. Build it, and fix the fragments for any value the build reports as dropped:

   ```sh
   docker buildx build kernel --build-arg KERNEL_VERSION=6.19.1 \
     --platform linux/amd64,linux/arm64 --target artifacts --output type=local,dest=out
   ```

3. Push a tag, such as `kernel/6.19.1`.

## Rootfs

### Alpine Linux

A minimal Alpine Linux with OpenRC, OpenSSH and cloud-init, which reads the
`cloudInit` volume as a NoCloud data source. Without a `cloudInit` volume,
`eth0` is configured with DHCP. A getty runs on the serial port (`ttyS0` or
`ttyAMA0`) and the virtio console (`hvc0`), and busybox acpid shuts the VM down
on the power button.

To add an Alpine series, copy the latest one, such as `rootfs/alpine/3.24` to
`rootfs/alpine/3.25`, update its default `VERSION`, and push a tag, such as
`rootfs/alpine/3.25.0`. Build one locally with:

```sh
docker buildx build rootfs/alpine/3.24 --build-arg VERSION=3.24.2 \
  --platform linux/amd64,linux/arm64 -t virtink-linux-rootfs-alpine:3.24.2
```

### Other distributions

The rootfs workflow builds any `rootfs/<distro>/<series>/Dockerfile` for a tag
`rootfs/<distro>/<version>` and publishes it as
`ghcr.io/jclab-oss/virtink-linux-rootfs-<distro>`. The Dockerfile gets the
version as the build argument `VERSION`, and must produce a bootable root
filesystem, with an init at `/sbin/init`.
