#!/usr/bin/env bash
set -eu

user="$(whoami)"
sudo chown -R "${user}" "/home/${user}/.vscode-server"

exec "$@"
