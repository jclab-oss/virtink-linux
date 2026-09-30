# syntax=docker/dockerfile:1

# Builds a bootable Alpine Linux rootfs for virtink imageRootfs volumes, with
# OpenRC, OpenSSH and cloud-init for cloudInit volumes. The build context is
# this directory.
#
#   docker buildx build rootfs/alpine/3.24 --build-arg VERSION=3.24.2 \
#     --platform linux/amd64,linux/arm64 -t virtink-rootfs-alpine:3.24.2

# The Alpine Linux version, such as 3.24.2, or 3.24 for its latest release
ARG VERSION=3.24

FROM alpine:${VERSION} AS rootfs

RUN apk add --no-cache alpine-base busybox-mdev-openrc cloud-init doas openssh sudo

COPY files/ /

RUN set -eux; \
    setup-cloud-init; \
    for service in devfs dmesg mdev; do rc-update add "$service" sysinit; done; \
    for service in bootmisc hostname networking osclock seedrng sysctl syslog; do rc-update add "$service" boot; done; \
    for service in acpid sshd; do rc-update add "$service" default; done; \
    for service in killprocs mount-ro savecache; do rc-update add "$service" shutdown; done

# Squash the rootfs into a single layer, without the image config of Alpine.
FROM scratch

COPY --from=rootfs / /
