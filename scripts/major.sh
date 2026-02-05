#!/usr/bin/env bash
# Bump major version
exec "$(dirname "$0")/release.sh" major "$@"
