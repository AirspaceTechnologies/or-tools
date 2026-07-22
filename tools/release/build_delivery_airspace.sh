set -eo pipefail

function help() {
  local -r NAME=$(basename "$0")
  local -r BOLD="\e[1m"
  local -r RESET="\e[0m"
  local -r help=$(cat << EOF
${BOLD}NAME${RESET}
\t$NAME - Build delivery using a ${BOLD}manylinux_2_28 docker image${RESET}.
${BOLD}SYNOPSIS${RESET}
\t$NAME [-h|--help|help] [go|all|reset] [amd64|arm64]
${BOLD}DESCRIPTION${RESET}
\tBuild Google OR-Tools deliveries.

${BOLD}OPTIONS${RESET}
\t-h --help: display this help text
\tgo: build all Go packages (default)
\tsecond argument: target architecture, amd64 (default) or arm64
\t(arm64 on an x86_64 host runs under QEMU/binfmt and is much slower)

EOF
)
  echo -e "$help"
}

function assert_defined(){
  if [[ -z "${!1}" ]]; then
    >&2 echo "Variable '${1}' must be defined"
    exit 1
  fi
}

function build_delivery() {
  assert_defined ORTOOLS_BRANCH
  assert_defined ORTOOLS_SHA1
  assert_defined ORTOOLS_DELIVERY
  assert_defined DOCKERFILE
  assert_defined ORTOOLS_IMG
  assert_defined PLATFORM

  # Clean
  echo -n "Remove previous docker images..." | tee -a "${ROOT_DIR}/build.log"
  docker image rm -f "${ORTOOLS_IMG}":"${ORTOOLS_DELIVERY}" 2>/dev/null
  docker image rm -f "${ORTOOLS_IMG}":devel 2>/dev/null
  docker image rm -f "${ORTOOLS_IMG}":env 2>/dev/null
  echo "DONE" | tee -a "${ROOT_DIR}/build.log"

  # cd "${RELEASE_DIR}" || exit 2
  cd "${ROOT_DIR}" || exit 2

  # Build env
  echo -n "Build ${ORTOOLS_IMG}:env..." | tee -a "${ROOT_DIR}/build.log"
  docker buildx build \
    --platform "${PLATFORM}" \
    --tag "${ORTOOLS_IMG}":env \
    --build-arg ORTOOLS_GIT_BRANCH="${ORTOOLS_BRANCH}" \
    --build-arg ORTOOLS_GIT_SHA1="${ORTOOLS_SHA1}" \
    --target=env \
    -f "${RELEASE_DIR}/${DOCKERFILE}" .
  echo "DONE" | tee -a "${ROOT_DIR}/build.log"

  # Build devel
  echo -n "Build ${ORTOOLS_IMG}:devel..." | tee -a "${ROOT_DIR}/build.log"
  docker buildx build \
    --platform "${PLATFORM}" \
    --tag "${ORTOOLS_IMG}":devel \
    --build-arg ORTOOLS_GIT_BRANCH="${ORTOOLS_BRANCH}" \
    --build-arg ORTOOLS_GIT_SHA1="${ORTOOLS_SHA1}" \
    --target=devel \
    -f "${RELEASE_DIR}/${DOCKERFILE}" .
  echo "DONE" | tee -a "${ROOT_DIR}/build.log"

  # Build delivery
  echo -n "Build ${ORTOOLS_IMG}:${ORTOOLS_DELIVERY}..." | tee -a "${ROOT_DIR}/build.log"
  docker buildx build \
    --platform "${PLATFORM}" \
    --tag "${ORTOOLS_IMG}":"${ORTOOLS_DELIVERY}" \
    --build-arg ORTOOLS_GIT_BRANCH="${ORTOOLS_BRANCH}" \
    --build-arg ORTOOLS_GIT_SHA1="${ORTOOLS_SHA1}" \
    --build-arg GO_TEST_RACE="${GO_TEST_RACE}" \
    --target=delivery \
    -f "${RELEASE_DIR}/${DOCKERFILE}" .
  echo "DONE" | tee -a "${ROOT_DIR}/build.log"
}

# Go build
function build_go() {
  assert_defined ORTOOLS_IMG
  local -r ORTOOLS_DELIVERY=go
  build_delivery

  # copy to export
  docker run --rm --init \
  --platform "${PLATFORM}" \
  -w /root/or-tools \
  -v "${ROOT_DIR}/export":/export \
  -u "$(id -u "${USER}")":"$(id -g "${USER}")" \
  -t "${ORTOOLS_IMG}":"${ORTOOLS_DELIVERY}" "cp export/*.tar.gz /export/"
}

# Cleaning everything
function reset() {
  assert_defined ORTOOLS_IMG

  echo "Cleaning everything..."
  rm -rf export/
  docker image rm -f "${ORTOOLS_IMG}":go 2>/dev/null
  docker image rm -f "${ORTOOLS_IMG}":devel 2>/dev/null
  docker image rm -f "${ORTOOLS_IMG}":env 2>/dev/null
  rm -f "${ROOT_DIR}"/*.log

  echo "DONE"
}

# Main
function main() {
  case ${1} in
    -h | --help | help)
      help; exit ;;
  esac

  local -r ROOT_DIR="$(cd -P -- "$(dirname -- "$0")/../.." && pwd -P)"
  echo "ROOT_DIR: '${ROOT_DIR}'" | tee -a build.log

  local -r RELEASE_DIR="$(cd -P -- "$(dirname -- "$0")" && pwd -P)"
  echo "RELEASE_DIR: '${RELEASE_DIR}'" | tee -a build.log

  (cd "${ROOT_DIR}" && make print-OR_TOOLS_VERSION | tee -a build.log)

  local -r ORTOOLS_BRANCH=$(git rev-parse --abbrev-ref HEAD)
  local -r ORTOOLS_SHA1=$(git rev-parse --verify HEAD)

  local -r ARCH="${2:-amd64}"
  case ${ARCH} in
    amd64)
      local -r DOCKERFILE="amd64_airspace.Dockerfile" ;;
    arm64)
      local -r DOCKERFILE="aarch64_airspace.Dockerfile" ;;
    *)
      >&2 echo "Arch '${ARCH}' unknown (expected amd64 or arm64)"
      exit 1
  esac
  local -r ORTOOLS_IMG="ortools/manylinux_delivery_${ARCH}"
  local -r PLATFORM="linux/${ARCH}"
  echo "ARCH: '${ARCH}' (platform ${PLATFORM})" | tee -a build.log

  # go test -race cannot run under QEMU user emulation (needs 48-bit VMA);
  # disable it when the target arch differs from the host arch
  local HOST_ARCH
  case "$(uname -m)" in
    x86_64) HOST_ARCH="amd64" ;;
    arm64|aarch64) HOST_ARCH="arm64" ;;
    *) HOST_ARCH="$(uname -m)" ;;
  esac
  local -r GO_TEST_RACE=$([ "${HOST_ARCH}" = "${ARCH}" ] && echo ON || echo OFF)
  echo "GO_TEST_RACE: '${GO_TEST_RACE}' (host ${HOST_ARCH})" | tee -a build.log

  mkdir -p "${ROOT_DIR}/export"

  case ${1} in
    go)
      "build_$1"
      exit ;;
    reset)
      reset
      exit ;;
    all)
      build_go
      exit ;;
    *)
      >&2 echo "Target '${1}' unknown"
      exit 1
  esac
  exit 0
}

main "${1:-all}" "${2:-amd64}"

