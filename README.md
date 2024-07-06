# Apache OpenServerless

Welcome to [Apache OpenServerless](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal) (also referenced as **AOS**), an incubating project at the [Apache Software Foundation](https://www.apache.org).

This readme provides  informations for developers of the project. For user informations refer to the [website](https://openserverless.apache.org) (not yet available).

## Development Enviroment Overview

AOS is a complex projects with lots of dependencies. It also needs a Kubernetes to be executed, tested and developed.

You may setup the environment by yourself but it can take a lot of time. If you want to do it quickly read on.

In order to bootstrap easily the development environment for the project, we use a virtual machines based on Ubuntu (currently version 24) initialized with [cloud-init](https://cloud-init.io/). This virtual machine can be run either in your local machine or in a cloud provider.

As an IDE we use [VSCode](https://code.visualstudio.com/)] as it allows [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) within the virtual machine. You can also use a different IDE but the configuration for VSCode is ready and documented.

You need a virtual machine with at least 8 giga of memory and 4 VCPU so your development workstation probably needs at least 16GB and 6VCPU. Your mileage may vary.

## Setup the Development Virtual Machine

Here we describe how to setup the development virtual machine in variuos scenarios.

- Linux and Mac with Multipass
- Windows with WSL2
- TODO: AWS, Azure, etc

### Setup a development VM in Linux and Mac

The method we recomment to setup a VM in Linux and Mac is using [multipass](https://multipass.run/). 

- On Mac, if you already have [brew](https://brew.sh/), installing it is as easy as to type `brew install multipass`.

- On Linux, if you already have [snap](https://snapcraft.io/), installing it is as easy as type `sudo snap install multipass`

- Otherwise follow [those instructions](https://multipass.run/install)

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

```
Name                    State             IPv4             Image
openserverless          Running           10.6.73.253      Ubuntu 24.04 LTS
                                          10.42.0.0
                                          10.42.0.1
```

Take note of the `<IP>` in the `openserverless line` (in this case `10.6.73.253` but your value can be different)

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

5. Add your git username and email

```
git config --global user.name "<your-name>"
git config --global user.email "<your-email>
```

### Cleanup

If you do now want to keep the vm anymore,   esure you have backed up all your files. Then remove it in your cloud provider (check your cloud provider documentation). 

For multipass, use the following commands to cleanup:

```
multipass delete openserverless
multipass purge
```
