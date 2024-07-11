#!/bin/bash
cd "$(dirname "${BASH_SOURCE[0]}")" && pwd
find . -name '.envrc' -execdir direnv allow . pwd  \;
find . -name '.envrc' -execdir direnv exec . pwd  \;

