#!/bin/bash
COLOR=75
SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
BUILD_DIR=${SCRIPT_DIR?}/../addons/gstreamer

# Change this to set the base debian image
BASE_IMAGE=debian:12

IMAGE_TAG=gstreamer:latest-debian${BASE_IMAGE//*:/}

# Decide which architectures to build
# QEMU=1 -> amd64 + arm64
# default -> only native arch
NATIVE_ARCH_RAW=$(uname -m)
case "$NATIVE_ARCH_RAW" in
    x86_64|amd64) NATIVE_ARCH=amd64 ;;
    aarch64|arm64) NATIVE_ARCH=arm64 ;;
    *)
        echo "Unsupported native arch: $NATIVE_ARCH_RAW" >&2
        exit 1
        ;;
esac

QEMU=${QEMU:-0}

if [ "$QEMU" = "1" ]; then
    ARCHES=("amd64" "arm64")
else
    ARCHES=("$NATIVE_ARCH")
fi

# Build gstreamer base image(s) with buildx/qbo
# Always tag per-arch; also tag IMAGE_TAG for the native arch
(
    cd "${BUILD_DIR?}" || exit 1
    for ARCH in "${ARCHES[@]}"; do
        PER_ARCH_TAG="gstreamer:latest-debian${BASE_IMAGE//*:/}-${ARCH}"
        # echo "Building $PER_ARCH_TAG for linux/${ARCH}"
        echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m gstreamer-selkies_gpl_${GIT_TAG#v}_debian12_$ARCH.tar.gz\033[0m"

        TAG_ARGS=(-t "${PER_ARCH_TAG?}")
        if [ "$ARCH" = "$NATIVE_ARCH" ]; then
            TAG_ARGS+=(-t "${IMAGE_TAG?}")
        fi

        docker buildx build \
            --builder=qbo \
            --platform "linux/${ARCH}" \
            --build-arg=BASE_IMAGE="${BASE_IMAGE?}" \
            "${TAG_ARGS[@]}" \
            -f Dockerfile.debian \
            --load .
    done
)

(
    cd "${SCRIPT_DIR?}/.." || exit 1
    for image in dist web; do
        echo "image = $image"
        echo "$PWD"
        GSTREAMER_BASE_IMAGE=gstreamer \
        GSTREAMER_BASE_IMAGE_RELEASE=latest \
        TEST_IMAGE=selkies-gstreamer-example:${IMAGE_TAG//*:/} \
        DISTRIB_RELEASE=${BASE_IMAGE//*:/} \
        docker compose build "${image}"
    done
)

cd "$BUILD_DIR" || exit 1
if [ "$1" = "-c" ]; then
    sudo rm -f ./dist/*
fi

# Compute a single SELKIES_VERSION for all artifacts
GIT_TAG=$(git describe --tags --always)

# If it is just a hash, prefix with 0.0.0+
if [[ "$GIT_TAG" =~ ^[0-9a-f]{7,}$ ]]; then
    GIT_TAG="0.0.0+${GIT_TAG}"
fi

# Normalize dash form (v1.2.3-4-gHASH) to PEP 440-ish
if [[ "$GIT_TAG" == *"-"* ]]; then
    GIT_TAG=${GIT_TAG/-/+}      # first "-" -> "+"
    GIT_TAG=${GIT_TAG/-/.}      # second "-" -> "."
fi

SELKIES_VERSION="${GIT_TAG#v}"

# Build web tarball
NAME=gst-web
DOCKER_TAG=latest
I=$(set -x; docker images "$NAME:$DOCKER_TAG" --format "{{.ID}}")
(set -x; docker run -it -v ./dist:/dist "$I" \
    sh -c "cp /opt/gst-web.tar.gz /dist/selkies-gstreamer-web_${SELKIES_VERSION}.tar.gz")

# Build GPL GStreamer tarball(s) for all requested ARCHES
NAME=gstreamer
for ARCH in "${ARCHES[@]}"; do
    DOCKER_TAG="latest-debian${BASE_IMAGE//*:/}-${ARCH}"
    I=$(set -x; docker images "$NAME:$DOCKER_TAG" --format "{{.ID}}")
    (set -x; docker run -it -v ./dist:/dist "$I" \
        sh -c "cp /opt/selkies-gstreamer-latest.tar.gz \
               /dist/gstreamer-selkies_gpl_${SELKIES_VERSION}_debian${BASE_IMAGE//*:/}_${ARCH}.tar.gz")
done

sudo chown "$USER:$USER" -R "$BUILD_DIR/dist/"
ls -la "$BUILD_DIR/dist/"
