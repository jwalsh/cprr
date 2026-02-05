#!/usr/bin/env bash
# Bump patch version
exec "$(dirname "$0")/release.sh" patch "$@"
