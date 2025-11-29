#!/bin/bash

SCRIPT_DIR=$(readlink -f "$(dirname "$0")")
BUILD_DIR=${SCRIPT_DIR?}/../addons/gstreamer

# Change this to set the base debian image
BASE_IMAGE=debian:12

IMAGE_TAG=gstreamer:latest-debian${BASE_IMAGE//*:/}

# --cache-from "${IMAGE_TAG?}" 
(cd "${BUILD_DIR?}" && docker build \
    --build-arg=BASE_IMAGE="${BASE_IMAGE?}" \
    -t "${IMAGE_TAG?}" -f Dockerfile.debian .)

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

# Build GPL GStreamer tarball
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    ARCH=amd64
fi

NAME=gstreamer
DOCKER_TAG=latest-debian${BASE_IMAGE//*:/}
I=$(set -x; docker images "$NAME:$DOCKER_TAG" --format "{{.ID}}")
(set -x; docker run -it -v ./dist:/dist "$I" \
    sh -c "cp /opt/selkies-gstreamer-latest.tar.gz \
           /dist/gstreamer-selkies_gpl_${SELKIES_VERSION}_debian${BASE_IMAGE//*:/}_${ARCH}.tar.gz")

sudo chown "$USER:$USER" -R "$BUILD_DIR/dist/"
ls -la "$BUILD_DIR/dist/"
