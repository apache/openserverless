# Apache OpenServerless (incubating)

Welcome to   [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org) 


- If you want to **learn** about Apache OpenServerless [check our website](https://openserverless.apache.org)
- If you want to **contribute** to the project, read [this document](DEVEL.md)  describng how to setup a **development** environment 
- If you want a simple local installation for testing things out, read on.

## Prerequisites: Install Multipass

To install a local environemt you need a PC/Mac running a recent version of Windows, Linux and Mac, with least 24GB of memory and virtualization enables. The vm requires at least 16gb of memory if you want a complete installation with all the services

There are multiple ways of installing Apache OpenServerless on a local machine, including using docker. All the options are documented [here](https://openserverless.apache.org/docs/installation/)

The simplest way and most reliable way is to use [multipass](https://canonical.com/multipass) creating a dedicated virual machine.

You should start installing multipass as follows:

- On Mac, if you already have [brew](https://brew.sh/), installing it is as easy as to type `brew install --cask multipass`.

- On Linux, if you already have [snap](https://snapcraft.io/), installing it is as easy as type `sudo snap install multipass`.

- On Windows, you need Windows 10 Pro/Enterprise/Education v1803 or later, or any Windows 10 with VirtualBox. Make sure your local network is designated as private, otherwise Windows prevents Multipass from starting.

Download the multipass installer from [here](https://multipass.run/download/windows) and run the installer. Pick Hyperv in preference, VirtualBox as an alternative.

- There are other installation options, described [here](https://multipass.run/install)

## Setup a development VM using multipass

The steps and the commands to install the development VM are the same in Linux, Windows and Mac.

Once you have `multipass` installed, open a terminal or powershell and type the following commands.


Before starting, if have an old version of the vm, remove it with:

```
# warning! this removes everything so you will lose data it not backed up
multipass delete openserverless --purge
```

Then create a new vm with:

```
multipass launch -nopenserverless -c4 -d20g -m16g --cloud-init https://raw.githubusercontent.com/sciabarracom/openserverless/main/cloud-init.yaml
```

Wait until the vm is ready and you see messages like `status: done` or `Launched: openserverless` (message can be different depending on multipass version effectively installed).

Finally wait the installation to be completed running the command:

```
multipass exec openserverless /etc/setup.status
```

and wait until you see the message `=== DONE ===`

## Optional: retrieve the kubeconfig

If you want to administer the installation and be able to create users, debug and tweak it, 
you need to [install ` kubectl`](https://kubernetes.io/docs/tasks/tools/) 
then retrieve the `.kube/config` file and store it locally with the command:

```
mkdir $HOME/.kube
# warning!!! this overwrites an existing kubeconfig
multipass exec openserverless cat .kube/config >$HOME/.kube/config
````
