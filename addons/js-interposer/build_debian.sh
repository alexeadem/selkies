#!/bin/bash

N=selkies-js-interposer-deb
COLOR=75
# Get git tag / hash
GIT_TAG=$(git describe --tags --always)

# If it's just a hash, prefix with 0.0.0+
if [[ "$GIT_TAG" =~ ^[0-9a-f]{7,}$ ]]; then
    GIT_TAG="0.0.0+${GIT_TAG}"
fi

# Strip leading v if present (v0.0.0+HASH -> 0.0.0+HASH)
if [[ "$GIT_TAG" == v* ]]; then
    GIT_TAG=${GIT_TAG#v}
fi

# Normalize dash form (v1.2.3-4-gHASH -> 1.2.3+4.gHASH, etc.)
if [[ "$GIT_TAG" == *"-"* ]]; then
    GIT_TAG=${GIT_TAG/-/+}      # first "-" -> "+"
    GIT_TAG=${GIT_TAG/-/.}      # second "-" -> "."
fi

SELKIES_VERSION="$GIT_TAG"     # e.g. 0.0.0+243fa6d

TAG=latest
V=12

# Decide native arch
NATIVE_ARCH_RAW=$(uname -m)
case "$NATIVE_ARCH_RAW" in
    x86_64|amd64) NATIVE_ARCH=amd64 ;;
    aarch64|arm64) NATIVE_ARCH=arm64 ;;
    *)
        echo "Unsupported native arch: $NATIVE_ARCH_RAW" >&2
        exit 1
        ;;
esac

# QEMU=1 -> build amd64 + arm64
# default -> only native arch
QEMU=${QEMU:-0}
if [ "$QEMU" = "1" ]; then
    ARCHES=("amd64" "arm64")
else
    ARCHES=("$NATIVE_ARCH")
fi

# Build per-arch images with buildx/qbo
for ARCH in "${ARCHES[@]}"; do
    IMAGE_TAG="${N}:${TAG}-debian${V}-${ARCH}"
    # echo "Building $IMAGE_TAG for linux/${ARCH}"
    echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies-js-interposer_${GIT_TAG#v}_debian12_$ARCH.deb\033[0m"

    TAG_ARGS=(-t "$IMAGE_TAG")
    # Also keep the old tag name pointing at the native arch image
    if [ "$ARCH" = "$NATIVE_ARCH" ]; then
        TAG_ARGS+=(-t "${N}:${TAG}")
    fi

    docker buildx build \
        --builder=qbo \
        --platform "linux/${ARCH}" \
        --build-arg=DEBFULLNAME="Alex Diaz" \
        --build-arg=DEBEMAIL=alex@qbo.io \
        --build-arg=PKG_NAME=selkies-js-interposer \
        --build-arg=PKG_VERSION="${SELKIES_VERSION}" \
        --build-arg=DISTRIB_RELEASE="${V}" \
        "${TAG_ARGS[@]}" \
        -f Dockerfile.debian_debpkg \
        --load .
done

[ -d dist ] || mkdir dist

if [ "$1" = "-c" ]; then
    rm -f ./dist/*
fi

# Copy out artifacts for each arch
for ARCH in "${ARCHES[@]}"; do
    IMAGE_TAG="${N}:${TAG}-debian${V}-${ARCH}"
    I=$(docker images "$IMAGE_TAG" --format "{{.ID}}")

    if [ -z "$I" ]; then
        echo "Missing image $IMAGE_TAG for ARCH=${ARCH}" >&2
        exit 1
    fi

    # Source files inside the image must match PKG_VERSION
    (set -x; docker run -v "$PWD/dist:/dist" "$I" \
        bash -c "cp /opt/selkies-js-interposer_${SELKIES_VERSION}.tar.gz \
                     /dist/selkies-js-interposer_${SELKIES_VERSION}_debian${V}_${ARCH}.tar.gz")

    (set -x; docker run -v "$PWD/dist:/dist" "$I" \
        bash -c "cp /opt/selkies-js-interposer_${SELKIES_VERSION}.deb \
                     /dist/selkies-js-interposer_${SELKIES_VERSION}_debian${V}_${ARCH}.deb")
done
