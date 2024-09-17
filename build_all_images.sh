#!/bin/bash

BUILD_DIR=image_build
COLEXT_DIR="domainradar-colext"
INPUT_DIR="domainradar-input"
CLF_DIR="domainradar-clf"
UI_DIR="domainradar-ui"

cd dockerfiles || exit 1

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR" || exit 1

clone_or_pull() {
  if [ -d "$1" ]; then
    echo "Pulling latest $2"
    cd "$1" || exit 1
    git pull
    cd ..
  else
    git clone "git@github.com:nesfit/$2.git" "$1"
  fi
}

clone_or_pull "$COLEXT_DIR" "domainradar-colext"
cd "$COLEXT_DIR"/python_pipeline
clone_or_pull "$CLF_DIR" "domainradar-clf"
cd ../..

clone_or_pull "$INPUT_DIR" "domainradar-input"
clone_or_pull "$UI_DIR" "domainradar-ui"
cd ..

echo "Building the domrad/prefilter image"
docker build -f prefilter.Dockerfile -t domrad/prefilter .

echo "Building the pipeline images"
cd "$BUILD_DIR/$COLEXT_DIR" || exit 1
./build_images.sh
cd ../..

echo "Building the domrad/webui image"
cd "$BUILD_DIR/$UI_DIR" || exit 1
docker build -t domrad/webui .
cd ../..

if [ "${DELETE_CLONED:-0}" = "1" ]; then
  rm -rf image_build
fi
