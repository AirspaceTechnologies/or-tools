#!/usr/bin/env bash
# Copyright 2010-2025 Google LLC
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -xeuo pipefail

# Cross-compile the Mac Go delivery for a non-host architecture.
# Usage: cross.sh [arm64|x86_64]
# Defaults to whichever Mac architecture the host is not.

export PROJECT=or-tools

HOST=$(uname -m)
TARGET_ARG="${1:-}"
if [[ -z "${TARGET_ARG}" ]]; then
  case "${HOST}" in
    arm64) TARGET_ARG=x86_64 ;;
    x86_64) TARGET_ARG=arm64 ;;
    *) echo "Unsupported host '${HOST}'"; exit 1 ;;
  esac
fi
export TARGET="${TARGET_ARG}"

export GOOS=darwin
case "${TARGET}" in
  arm64) export GOARCH=arm64 ;;
  x86_64) export GOARCH=amd64 ;;
  *) echo "Unsupported TARGET '${TARGET}' (expected arm64 or x86_64)"; exit 1 ;;
esac

./tools/cross_compile.sh build

PROJECT_DIR=$(pwd -P)
BUILD_DIR=${PROJECT_DIR}/build_cross/${TARGET}

# make archive
INSTALL_GO_NAME=$(make print-INSTALL_GO_NAME 2> /dev/null | cut -d' ' -f3 | tr -d \' | sed 's/'${HOST}'/'${TARGET}'/g')
LIBS=$(cd ${BUILD_DIR} && ls lib*/libgoortools.* lib*/libortools.*)
echo -n "Archiving..."
mkdir -p "${PROJECT_DIR}/export"
tar czvf export/${INSTALL_GO_NAME}.tar.gz --no-same-owner -C ${BUILD_DIR} ${LIBS}
