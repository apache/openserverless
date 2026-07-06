# Apache OpenServerless (incubating)

Welcome to  [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org)

- If you want to **install** Apache OpenServerless  in cloud go [here](https://openserverless.apache.org/docs/installation/).
- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal).
- If you want to **contribute** to the project, read on this README to setup a **development** environment.
- If you want to **discuss** with us, join  our mailing list sending an email to `dev-subscribe@openserverless.apache.org`
- If you want to **locally install**  open serverless from sources test or development, read on.

# Build and test from sources

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
curl -s "https://get.sdkman.io" | bash
source "/home/msciab/.sdkman/bin/sdkman-init.sh"
sdk install java 17.0.19-tem
```

## Prepare Ubuntu Linux

Setup for a plain Ubuntu Linux with an user with sudo power:

```
sudo apt-get update
sudo apt-get -y install jq
sudo snap install go --classic
sudo snap install task --classic
sudo snap install kubectl --classic
curl -sL get.docker.com | sudo bash
sudo usermod -aG docker $USER
newgrp docker
docker ps
```

## Procedure

```
git clone https://github.com/apache/openserverless --recurse-submodules
cd openserverless
task build
task setup
```

TODO: `task test`