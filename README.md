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

Once you have `multipass` type the following and wait util you see `status: done`

```
multipass launch -nopenserverless -c4 -d20g -m8g --cloud-init https://raw.githubusercontent.com/nuvolaris/openserverless/main/cloud-init.yaml
multipass exec "openserverless" -- sudo cloud-init status --wait
```

## Setup SSH access for VSCode

## Setup access to multipass in Mac and Linux

To access the virtual machine from VSCode you need to setup a key and a configuration. Follow those steps:

1. Check if you already have a key in `$HOME/.ssh/id_rsa`. If not, generate one with  `ssh-keygen -t rsa` (just press enter to confirm)

2. copy the key in the virtual machine:

```
cat ~/.ssh/id_rsa.pub | multipass exec openserverless -- tee -a .ssh/authorized_keys
```

3. Create a configuration named `openserverless` to easily access it.

First type `multipass list`. You will see something like this:

````
Name                    State             IPv4             Image
openserverless          Running           10.6.73.253      Ubuntu 24.04 LTS
                                          10.42.0.0
                                          10.42.0.1
```

Take note of the `<IP>` in the `openserverless line` (in this case `10.6.73.253` but yours can be different)

Add to the file `~/ssh/config` the following

```
Host openserverless
  Hostname  <IP>
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
```

4. Check you have access without password:

```
ssh openserverless
```

### Cleanup


If you do now want to keep the vm anymore,   esure you have backed up all your files. Then remove it in your cloud provider (check your cloud provider documentation). 

For multipass, use the following commands to cleanup:

```
multipass delete openserverless
multipass purge
```
