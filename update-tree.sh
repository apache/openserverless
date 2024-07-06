#!/bin/bash
git pull origin main --rebase
git submodule update --recursive --remote
bash sync-branch.sh
