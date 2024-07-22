#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
git clone https://github.com/nix-community/nix-direnv $HOME/nix-direnv
mkdir -p $HOME/.config/direnv
echo 'source $HOME/nix-direnv/direnvrc' >>$HOME/.config/direnv/direnvrc
find . -name '.envrc' -execdir direnv allow . pwd  \;
find . -name '.envrc' -execdir direnv exec . pwd  \;

