#!/bin/bash
set -eu

# Default values
DEFAULT_OS_VERSION="rocky8"

# Use environment variables if set, otherwise use default values
# Export set for some variables to be used referenced docker compose file
export OS_VERSION="${OS_VERSION:-$DEFAULT_OS_VERSION}"
export CODEBASE_VERSION="${CODEBASE_VERSION:-1.6.1}"

# Function to display help message
function usage {
  echo "Usage: $0 [-o <os_version>] [-c <codebase_version>] [-h]"
  echo "  -o  OS version (valid values: rocky8, rocky9)"
  echo "  -c  Codebase version (valid values: main, any valid git tags)"
  exit 1
}

# Parse command-line options
while getopts "o:c:h" opt; do
  case "${opt}" in
  o)
    OS_VERSION=${OPTARG}
    ;;
  c)
    CODEBASE_VERSION=${OPTARG}
    ;;
  h)
    usage
    ;;
  *)
    usage
    ;;
  esac
done

# Validate OS_VERSION and map to appropriate Docker image
case "${OS_VERSION}" in
rocky9)
  DOCKERFILE=rocky9/Dockerfile
  ;;
rocky8)
  DOCKERFILE=rocky8/Dockerfile
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

docker build --file ${DOCKERFILE} \
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
