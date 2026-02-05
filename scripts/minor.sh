#!/usr/bin/env bash
# Bump minor version
exec "$(dirname "$0")/release.sh" minor "$@"
