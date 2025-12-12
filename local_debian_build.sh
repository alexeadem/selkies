#!/bin/bash
COLOR=75
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    ARCH=amd64
fi

# QEMU=1 -> build amd64 + arm64 for js-interposer + gstreamer
# default -> only native ARCH
QEMU="${QEMU:-0}"

if [ -d dist ] && [ "$(ls -A dist)" ]; then
    echo "Existing dist/ contents:"
    ls -1 dist/
    echo
    read -r -p "Archive current dist/ contents under a timestamp folder? [y/N] " ans
    case "$ans" in
        [yY])
            TS=$(date +%Y%m%d%H%M%S)
            ARCHIVE_DIR="dist/$TS"
            mkdir -p "$ARCHIVE_DIR"
            mv dist/* "$ARCHIVE_DIR"/
            echo "Archived to $ARCHIVE_DIR"
            ;;
        *)
            echo "Skipping archive, keeping existing dist/ as is"
            ;;
    esac
fi


# py3-none-any
NAME=selkies-gstreamer
#GIT_TAG=$(git describe --tag)
GIT_TAG=$(git describe --tags --always)

if [[ "$GIT_TAG" =~ ^[0-9a-f]{7,}$ ]]; then
    GIT_TAG="0.0.0+${GIT_TAG}"
fi

if [[ "$GIT_TAG" == *"-"* ]]; then
    GIT_TAG=${GIT_TAG/-/+}      # Replace first "-" with "+"
    GIT_TAG=${GIT_TAG/-/.}      # Replace second "-" with "."
fi

echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies_gstreamer-${GIT_TAG#v}-py3-none-any.whl\033[0m"

docker build --no-cache --build-arg PACKAGE_VERSION=${GIT_TAG#v} . -t $NAME
DOCKER_TAG=latest
I=$(set -x; docker images $NAME:$DOCKER_TAG --format "{{.ID}}")
if [ ! -d dist ]; then
    mkdir dist
fi
(set -x; docker run -v $PWD/dist:/dist $I bash -c "cp /opt/pypi/dist/* /dist/")

# selkies-js-interposer
# if [ "$QEMU" = "1" ]; then
#     # We will build both amd64 and arm64
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies-js-interposer_${GIT_TAG#v}_debian12_amd64.deb\033[0m"
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies-js-interposer_${GIT_TAG#v}_debian12_arm64.deb\033[0m"
# else
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies-js-interposer_${GIT_TAG#v}_debian12_$ARCH.deb\033[0m"
# fi

cd addons/js-interposer/

if [ ! -f ./build_debian.sh ]; then
    echo "$PWD/build_debian.sh not found"
    exit 1
fi

# Pass QEMU down so build_debian.sh can do single-arch or multi-arch
QEMU="$QEMU" ./build_debian.sh
cd -
ls -1 addons/js-interposer/


# web
echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m selkies-gstreamer-web_${GIT_TAG#v}.tar.gz\033[0m"

# gpl gstreamer
# if [ "$QEMU" = "1" ]; then
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m gstreamer-selkies_gpl_${GIT_TAG#v}_debian12_amd64.tar.gz\033[0m"
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m gstreamer-selkies_gpl_${GIT_TAG#v}_debian12_arm64.tar.gz\033[0m"
# else
#     echo -e "\033[1;38;5;${COLOR}m>>>\033[0m \033[1;38;5;${COLOR}m gstreamer-selkies_gpl_${GIT_TAG#v}_debian12_$ARCH.tar.gz\033[0m"
# fi

cd dev

if [ ! -f ./build-gstreamer-debian12.sh ]; then
    echo "$PWD/build-gstreamer-debian12.sh not found"
    exit 1
fi

# Pass QEMU down so gstreamer script can do single-arch or multi-arch
QEMU="$QEMU" ./build-gstreamer-debian12.sh

cd ..
[ "$(ls -A ./addons/gstreamer/dist)" ] && mv addons/gstreamer/dist/* dist/
[ "$(ls -A ./addons/js-interposer/dist)" ] && mv addons/js-interposer/dist/* dist/
ls -1 dist/
