#!/bin/bash

N=selkies-js-interposer-deb

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

ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    ARCH=amd64
fi

docker build \
    --build-arg=DEBFULLNAME="Alex Diaz" \
    --build-arg=DEBEMAIL=alex@qbo.io \
    --build-arg=PKG_NAME=selkies-js-interposer \
    --build-arg=PKG_VERSION="${SELKIES_VERSION}" \
    --build-arg=DISTRIB_RELEASE="${V}" \
    -t "$N:$TAG" -f Dockerfile.debian_debpkg .

I=$(docker images "$N:$TAG" --format "{{.ID}}")
[ -d dist ] || mkdir dist

if [ "$1" = "-c" ]; then
    rm -f ./dist/*
fi

# Source files inside the image must match PKG_VERSION
(set -x; docker run -v "$PWD/dist:/dist" "$I" \
    bash -c "cp /opt/selkies-js-interposer_${SELKIES_VERSION}.tar.gz \
                 /dist/selkies-js-interposer_${SELKIES_VERSION}_debian${V}_${ARCH}.tar.gz")

(set -x; docker run -v "$PWD/dist:/dist" "$I" \
    bash -c "cp /opt/selkies-js-interposer_${SELKIES_VERSION}.deb \
                 /dist/selkies-js-interposer_${SELKIES_VERSION}_debian${V}_${ARCH}.deb")
