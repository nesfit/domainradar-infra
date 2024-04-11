#!/bin/bash

mkdir -p image_build/

git clone git@github.com:nesfit/domainradar-input.git image_build/domainradar-input

docker build -f prefilter.Dockerfile -t prefilter .
