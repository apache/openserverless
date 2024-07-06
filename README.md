# Apache OpenServerless

Welcome to [Apache OpenServerless](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal), shortened **AOS**, an incubating project at the [Apache Software Foundation](https://www.apache.org).

This readme provides development information. For user informations refer to the [website](https://openserverless.apache.org) (not yet available).

## Development Enviroment Overview

AOS is a complex projects with lots of dependencies. It also needs a Kubernetes to be executed, hence tested  and developed.

In order to bootstrap easily the development environment for the project, we use virtual machines initialized with [cloud-init](https://cloud-init.io/) to setup a development environment.

As an IDE we use  [VSCode](https://code.visualstudio.com/)] as it allows [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) within the virtual machine.

You can setup your development virtual machine in cloud or you can configure it locally in your workstation. 

You need a virtual machine with at least 8g of memory and 4 VCPU so your development workstation probably needs 16GB and 8VCPU of memory at least.

## Setup the Development Virtual Machine

Here we see how to setup the development environment in variuos scenarios.

### Setup a development environment in Linux and Mac

The method we use to setup a VM in Linux and Mac is using [multipass](https://multipass.run/). 

- On Mac, if you already have [brew](https://brew.sh/), installing it is as easy as to type `brew install multipass`.

- On Linux, if you already have [snap](https://snapcraft.io/), installing it is as easy as type `sudo snap install multipass`

-  Otherwise follow [those instructions](https://multipass.run/install)

Once you have `multipass` type the following 

```
multipass launch -nopenserverless -c4 -d20g -m8g --cloud-init https://raw.githubusercontent.com/nuvolaris/openserverless/main/cloud-init.yaml
multipass exec "openserverless" -- sudo cloud-init status --wait
```

#### Removal
If you do now want to keep the vm anymore,   ensure you have backed up all your files. Then use the following commands to cleanup:

```
multipass delete openserverless
multipass purge
```
