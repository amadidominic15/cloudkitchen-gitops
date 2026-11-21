#!/usr/bin/env bash
set -Eeuo pipefail

# Build every microservice Docker image under ./services.
# Run this script from the project root, or pass the project root as an argument.

PROJECT_ROOT="${1:-.}"
SERVICES_DIR="$PROJECT_ROOT/services"

if [[ ! -d "$SERVICES_DIR" ]]; then
  echo "ERROR: Services directory not found: $SERVICES_DIR" >&2
  exit 1
fi

built=0

for service_dir in "$SERVICES_DIR"/*/; do
  [[ -d "$service_dir" ]] || continue

  service_name="$(basename "$service_dir")"
  dockerfile="$service_dir/Dockerfile"

  if [[ ! -f "$dockerfile" ]]; then
    echo "SKIPPING $service_name: no Dockerfile found"
    continue
  fi

  echo
  echo "Building cloudkitchen/$service_name:local ..."

  docker build \
    --tag "cloudkitchen/$service_name:local" \
    --file "$dockerfile" \
    "$service_dir"

  built=$((built + 1))
done

if (( built == 0 )); then
  echo "ERROR: No Dockerfiles found under $SERVICES_DIR" >&2
  exit 1
fi

echo
echo "Successfully built $built microservice image(s)."
echo "Verify with: docker images | grep cloudkitchen"