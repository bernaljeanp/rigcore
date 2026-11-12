#!/bin/sh
# Lanzador de desarrollo de Rigcore.
cd "$(dirname "$(readlink -f "$0")")" && exec .venv/bin/python -m rigcore.app "$@"
