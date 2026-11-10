#!/bin/sh
# Lanzador de desarrollo de Vórtice.
cd "$(dirname "$(readlink -f "$0")")" && exec .venv/bin/python -m vortice.app "$@"
