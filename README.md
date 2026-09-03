# Apache OpenServerless (incubating)

Welcome to [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org).

- If you want to **install** Apache OpenServerless in the cloud go [here](https://openserverless.apache.org/docs/installation/).
- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal).
- If you want to **discuss** with us, join our mailing list by sending an email to `dev-subscribe@openserverless.apache.org`
- If you want to **contribute** to the project, read [this guide](CONTRIBUTING.md)

## Build and test from sources

> [!WARNING]
> Building from the latest sources in git is **not recommended for production use**. The `main` branch may contain unstable, untested, or incomplete changes. For production deployments, use an official release tarball instead.

Download a release tarball from the Apache distribution area, untar and cd to it:

```
curl -O https://dist.apache.org/repos/dist/dev/incubator/openserverless/<version>/openserverless-<version>-incubating-src.tar.gz
tar xzvf openserverless-<version>-incubating-src.tar.gz
cd openserverless-<version>-incubating-src
```

where `<version>` is the release you want, for example `v0.9.0`. Browse
[the distribution area](https://dist.apache.org/repos/dist/dev/incubator/openserverless/)
to see the available versions.

Release artifacts are signed. Before building, verify the tarball against the
project [KEYS](https://dist.apache.org/repos/dist/dev/incubator/openserverless/KEYS)
file:

```
curl -O https://dist.apache.org/repos/dist/dev/incubator/openserverless/<version>/openserverless-<version>-incubating-src.tar.gz.asc
curl -O https://dist.apache.org/repos/dist/dev/incubator/openserverless/KEYS
gpg --import KEYS
gpg --verify openserverless-<version>-incubating-src.tar.gz.asc
```

or clone the latest sources from the `main` branch or a release branch:

```
git clone --branch <branch> https://github.com/apache/openserverless --recurse-submodules
cd openserverless
```

> [!IMPORTANT]
> Most of the code lives in git submodules, so `--recurse-submodules` is required.
> If you already cloned without it, run `git submodule update --init --recursive`
> before building, otherwise the submodule directories are empty and the build
> fails in confusing ways.

You can then build and test as follows.

### Linux

You need Ubuntu 22+ or Debian 11+. Execute:

`./build-and-test-ubuntu.sh`

It can work on other distros but you have to adapt the scripts.

### Windows

You need Windows 10/11 with WSL. Execute from PowerShell:

`.\build-and-test-windows.ps1`

### macOS

You have to install [lima](https://lima-vm.io) (example: `brew install lima`). Execute:

`./build-and-test-mac.sh`

## Development setup

### Prerequisites

- you need a Unix environment, either macOS, Linux or Windows WSL.
- you need docker on the path
- you need go available on the path
- you need task (https://taskfile.dev) available in the path
- you need jq, zip, unzip and kubectl available on the path
- you need license-eye on the path, to check the license headers

The per-platform sections below install all of these. Here are the procedures
for macOS, Windows 11 and Ubuntu Linux.

### Prepare Mac

On Mac, install brew and Docker Desktop, then do

```
brew install task go jq kubernetes-cli
go install github.com/apache/skywalking-eyes/cmd/license-eye@latest
export PATH="$PATH:$(go env GOPATH)/bin"
```

### Prepare Windows

On Windows,
- install Docker Desktop, then
- `wsl --install Ubuntu-24.04`

then enable docker to be used in the distro `Ubuntu-24.04`

Access the distro (`wsl -d Ubuntu-24.04`), configure a new user, then execute:

```
sudo apt-get update
sudo apt-get -y install jq unzip zip
sudo snap install go --classic
sudo snap install task --classic
sudo snap install kubectl --classic
go install github.com/apache/skywalking-eyes/cmd/license-eye@latest
export PATH="$PATH:$(go env GOPATH)/bin"
```

### Prepare Ubuntu or Debian Linux

Setup for a plain Ubuntu Linux with a user with sudo power:

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

### Procedure

```
git clone https://github.com/apache/openserverless --recurse-submodules
cd openserverless
```

To work on a release branch instead of `main`, add `--branch <branch>`.

You can build with: `task build`

You can run the test suite with: `task test`

You can check all the files have the license header: `task license`

Read the task files (that are basically shell scripts wrapped in a yaml environment) to learn all the build procedures.

## License

Apache OpenServerless is licensed under the [Apache License, Version 2.0](LICENSE).
See also the [NOTICE](NOTICE) file.

## Disclaimer

Apache OpenServerless (Incubating) is an effort undergoing incubation at the Apache
Software Foundation (ASF), sponsored by the Apache Incubator PMC.

Incubation is required of all newly accepted projects until a further review
indicates that the infrastructure, communications, and decision making process
have stabilized in a manner consistent with other successful ASF projects.

While incubation status is not necessarily a reflection of the completeness
or stability of the code, it does indicate that the project has yet to be
fully endorsed by the ASF.
