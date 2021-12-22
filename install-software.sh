#!/bin/bash

# set -e
set -o pipefail

echo "Uninstalling Docker Desktop if installed…"
brew uninstall --cask --zap docker >/dev/null 2>&1
brew uninstall --zap docker-completion >/dev/null 2>&1

echo "Installing Multipass…"
brew install multipass >/dev/null 2>&1

if [[ $1 = "--virtualbox" ]]; then
  echo "Installing VirtualBox…"
  brew install --cask virtualbox virtualbox-extension-pack >/dev/null 2>&1
fi

echo "Installing Docker CLI…"
brew install docker >/dev/null 2>&1

echo "Done!"
