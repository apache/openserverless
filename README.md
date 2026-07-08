# Apache OpenServerless (incubating)

Welcome to  [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org)

- If you want to **install** Apache OpenServerless  in cloud go [here](https://openserverless.apache.org/docs/installation/).
- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal).
- If you want to **discuss** with us, join  our mailing list sending an email to `dev-subscribe@openserverless.apache.org`

- If you want to **contribute** to the project, building from the sources or  setting up a   **development** environment, read on this README.

# Build and test from sources

Download a releases tarbal or clone all the latest sources with

```
git clone https://github.com/apache/openserverless --recurse-submodules
```

You can then build and test

# Linux

You need Ubuntu 22+ or Debian 11+.  Execute:

`./build-and-test-ubuntu.sh`

It can work on other distros but you have to adapt the scripts.

# Windows

You need Windows 10/11 with WSL. Execute from PowerShell:

`.\build-and-test-windos.ps1`

# Mac OSX

You have to install [lima](https://limma-vm.io) (example: brew install lima). Execute:

`./build-and-test-mac.sh`


# Development setup

## Prerequisites

- you need an Unix environment, either OSX, Linux or Windows WSL.
- you need docker on the path
- you need go available on the path
- you need task (https://taskfile.dev) available in the path

Here the procedures for MacOS, Windows 11 and Ubuntu Linux

##  Prepare Mac

On Mac, install brew and Docker Desktop. then do

- `brew install task`
- `brew install go`

## Prepare Windows

On windows,
- install Docker Desktop then
- `wsl --install Ubuntu-24.04`

then enable docker to be used in the distro `Ubuntu-24.04`

Access the distro (`wsl -d Ubuntu-24.04` ), configure a new user,  then execute:

```
sudo apt-get update
sudo apt-get -y install jq unzip zip
sudo snap install go --classic
sudo snap install task --classic
sudo snap install kubectl --classic
```

## Prepare Ubuntu or Debian Linux

Setup for a plain Ubuntu Linux with an user with sudo power:

```
sudo apt-get update
sudo apt-get -y install jq
sudo snap install go --classic
sudo snap install task --classic
sudo snap install kubectl --classic
curl -sL get.docker.com | sudo bash
go install github.com/apache/skywalking-eyes/cmd/license-eye@latest
export PATH="$PATH:$(go env GOPATH)/bin"
sudo usermod -aG docker $USER
newgrp docker
docker ps
```

## Procedure

```
git clone https://github.com/apache/openserverless --recurse-submodules
cd openserverless
```

You can build with:  `task build`

You can run the test suite with:  `task test`

You can check all the files have the license header: `task license`

Read the task files (that are basically shell scripts wrapped in an yaml environment) to learn all the build procedures.