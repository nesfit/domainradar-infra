#!/bin/bash

cd dockerfiles || exit 1

mkdir -p image_build
git clone git@github.com:nesfit/domainradar-input.git image_build/domainradar-input
git clone git@github.com:nesfit/domainradar-colext.git image_build/domainradar-colext

docker build -f prefilter.Dockerfile -t domrad/prefilter .
cd image_build/domainradar-colext || rm -rf image_build && exit 1
./build_docker_images.sh

cd ../..
rm -rf image_build
