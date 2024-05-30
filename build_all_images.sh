#!/bin/bash

BUILD_DIR=image_build
COLEXT_DIR="domainradar-colext"
INPUT_DIR="domainradar-input"
CLF_DIR="domainradar-clf"

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

if [ -d "$CLF_DIR" ]; then
  echo "Pulling latest domainradar-clf"
  cd "$CLF_DIR" || exit 1
  git pull
  cd ..
else
  git clone git@github.com:nesfit/domainradar-clf.git "$CLF_DIR"
fi

cd ..

echo "Building the prefilter image"
docker build -f prefilter.Dockerfile -t domrad/prefilter .

echo "Building the pipeline images"
cd "$BUILD_DIR/$COLEXT_DIR" || exit 1
./build_docker_images.sh

cd ../..

echo "Copying models"
rm -rf ../clf_models
mkdir -p ../clf_models
cp -r "$BUILD_DIR/$CLF_DIR/classifiers/models" ../clf_models/models
cp -r "$BUILD_DIR/$CLF_DIR/classifiers/boundaries" ../clf_models/boundaries

if [ "${DELETE_CLONED:-0}" = "1" ]; then
  rm -rf image_build
fi
