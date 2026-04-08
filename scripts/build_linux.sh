#!/bin/sh
#
# Mac ARM users, rosetta can be flaky, so to use a remote x86 builder
#
# docker context create amd64 --docker host=ssh://mybuildhost
# docker buildx create --name mybuilder amd64 --platform linux/amd64
# docker buildx create --name mybuilder --append desktop-linux --platform linux/arm64
# docker buildx use mybuilder


set -eu


cd $(dirname $0)/..
export VERSION=${VERSION:-$(git -C ollama describe --tags --first-parent --abbrev=7 --long --dirty --always | sed -e "s/^v//g")}
. ollama/scripts/env.sh

mkdir -p dist

# SYCL optimization flags and include paths
CGO_CFLAGS="-DGGML_SYCL -I./llama/llama.cpp/src -I./llama/llama.cpp/common"
CGO_CXXFLAGS="-DGGML_SYCL -I./llama/llama.cpp/src -I./llama/llama.cpp/common"

docker buildx build \
    --output type=local,dest=./dist/ \
    --platform=linux/amd64 \
    ${OLLAMA_COMMON_BUILD_ARGS} \
    --build-arg="CGO_CFLAGS=${CGO_CFLAGS}" \
    --build-arg="CGO_CXXFLAGS=${CGO_CXXFLAGS}" \
    --target archive \
    -f Dockerfile \
    .
