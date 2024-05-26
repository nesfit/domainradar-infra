#!/bin/bash

BUILD_DIR=image_build
COLEXT_DIR="domainradar-colext"
INPUT_DIR="domainradar-input"

cd dockerfiles || exit 1

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || exit 1

if [ -d "$INPUT_DIR" ]; then
  echo "Pulling latest domainradar-input"
  cd "$INPUT_DIR" || exit 1
  git pull
  cd ..
else
  git clone git@github.com:nesfit/domainradar-input.git "$INPUT_DIR"
fi

if [ -d "$COLEXT_DIR" ]; then
  echo "Pulling latest domainradar-colext"
  cd "$COLEXT_DIR" || exit 1
  git pull
  cd ..
else
  git clone git@github.com:nesfit/domainradar-colext.git "$COLEXT_DIR"
fi

cd ..

echo "Building the prefilter image"
docker build -f prefilter.Dockerfile -t domrad/prefilter .

echo "Building the pipeline images"
cd "$BUILD_DIR/$COLEXT_DIR" || (rm -rf image_build && exit 1)
./build_docker_images.sh

cd ../..
rm -rf image_build
