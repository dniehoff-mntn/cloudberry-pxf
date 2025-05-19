#!/bin/bash
set -eu

# Default values
DEFAULT_OS_VERSION="rockylinux9"
DEFAULT_TIMEZONE_VAR="Asia/Shanghai"
DEFAULT_PIP_INDEX_URL_VAR="https://pypi.org/simple"

# Use environment variables if set, otherwise use default values
# Export set for some variables to be used referenced docker compose file
export OS_VERSION="${OS_VERSION:-$DEFAULT_OS_VERSION}"
export CODEBASE_VERSION="${CODEBASE_VERSION:-}"
TIMEZONE_VAR="${TIMEZONE_VAR:-$DEFAULT_TIMEZONE_VAR}"
PIP_INDEX_URL_VAR="${PIP_INDEX_URL_VAR:-$DEFAULT_PIP_INDEX_URL_VAR}"

# Function to display help message
function usage {
  echo "Usage: $0 [-o <os_version>] [-c <codebase_version>] [-b] [-m]"
  echo "  -c  Codebase version (valid values: main, or determined from release zip file name)"
  echo "  -t  Timezone (default: Asia/Shanghai, or set via TIMEZONE_VAR environment variable)"
  echo "  -p  Python Package Index (PyPI) (default: https://pypi.org/simple, or set via PIP_INDEX_URL_VAR environment variable)"
  exit 1
}

# Parse command-line options
while getopts "c:t:p:bmh" opt; do
  case "${opt}" in
  c)
    CODEBASE_VERSION=${OPTARG}
    ;;
  t)
    TIMEZONE_VAR=${OPTARG}
    ;;
  p)
    PIP_INDEX_URL_VAR=${OPTARG}
    ;;
  h)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

# If CODEBASE_VERSION is not specified, determine it from the file name
if [[ -z "$CODEBASE_VERSION" ]]; then
  BASE_CODEBASE_FILE=$(ls configs/cloudberrydb-*.zip 2>/dev/null)

  if [[ -z "$BASE_CODEBASE_FILE" ]]; then
    echo "Error: No configs/cloudberrydb-*.zip file found and codebase version not specified."
    exit 1
  fi

  CODEBASE_FILE=$(basename ${BASE_CODEBASE_FILE})

  if [[ $CODEBASE_FILE =~ cloudberrydb-([0-9]+\.[0-9]+\.[0-9]+)\.zip ]]; then
    CODEBASE_VERSION="${BASH_REMATCH[1]}"
  else
    echo "Error: Cannot extract version from file name $CODEBASE_FILE"
    exit 1
  fi
fi

# Validate OS_VERSION and map to appropriate Docker image
case "${OS_VERSION}" in
rockylinux9)
  OS_DOCKER_IMAGE="rockylinux9"
  ;;
*)
  echo "Invalid OS version: ${OS_VERSION}"
  usage
  ;;
esac

# Validate CODEBASE_VERSION
if [[ "${CODEBASE_VERSION}" != "main" && ! "${CODEBASE_VERSION}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Invalid codebase version: ${CODEBASE_VERSION}"
  usage
fi

# Build image
DOCKERFILE=Dockerfile

docker build --file ${DOCKERFILE} \
  --build-arg TIMEZONE_VAR="${TIMEZONE_VAR}" \
  --build-arg PIP_INDEX_URL_VAR="${PIP_INDEX_URL_VAR}" \
  --build-arg CODEBASE_VERSION_VAR="${CODEBASE_VERSION}" \
  --tag cbdb-pxf-${CODEBASE_VERSION}:${OS_VERSION} .

# Stop container if it is already running
docker container stop cbdb-pxf-mdw || true
docker container rm cbdb-pxf-mdw || true

# Deploy container(s)
docker run --interactive \
  --tty \
  --name cbdb-pxf-mdw \
  --detach \
  --volume /sys/fs/cgroup:/sys/fs/cgroup:ro \
  --volume $(realpath ..):/home/gpadmin/workspace/cloudberry-pxf \
  --publish 122:22 \
  --publish 15432:5432 \
  --hostname mdw \
  cbdb-pxf-${CODEBASE_VERSION}:${OS_VERSION}

docker logs -f cbdb-pxf-mdw
