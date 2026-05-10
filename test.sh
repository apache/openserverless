#!/bin/bash

set -euo pipefail

echo Checking prerequisites
test -e ./ops
which docker

echo Cleaning everything
docker rm -f nuvolaris-control-plane

echo Creating Kind Cluster
./ops setup docker create

echo Checking Images
./ops util fr kind-list | grep apache/openserverless

echo Deploying the operator

./ops setup kubernetes permission
./ops setup kubernetes pre-deploy
./ops setup kubernetes operator

echo Wait until the operator is up-and-running
./ops setup kubernetes wait OBJECT=po/nuvolaris-operator-0 COND=true
