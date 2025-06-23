# Apache OpenServerless (incubating)

Welcome to   [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org) 

- If you want to **install** Apache OpenServerless  in cloud go [here](https://openserverless.apache.org/docs/installation/).
- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal). 
- If you want to **contribute** to the project, read on this README to setup a **development** environment.
- If you want to **chat** with us, join  [our Discord server](https://bit.ly/openserverless-discord).
- If you want to **locally install**  open serverless for test or development, read on.

## Test Environment Overview

Apache OpenServerless is a complex project with lots of dependencies. It also needs a Kubernetes cluster to be executed, tested and developed on.

To quickly create a development enviromnemt we use a virtual machine in your workstation created with  [multipass](https://multipass.run/). 

You need a virtual machine with at least 8GB of memory and 4 VCPU so your development workstation probably needs at least 16GB and 6 VCPU. Your mileage may vary.

Read on how to create a test environment.

## Install Multipass

Here we describe how to setup the development virtual machine on Linux, Mac and Windows using multipass. First, install multipass.

- On Mac, if you already have [brew](https://brew.sh/), installing it is as easy as to type `brew install --cask multipass`.

- On Linux, if you already have [snap](https://snapcraft.io/), installing it is as easy as type `sudo snap install multipass`.

- On Windows, you need Windows 10 Pro/Enterprise/Education v1803 or later, or any Windows 10 with VirtualBox. Make sure your local network is designated as private, otherwise Windows prevents Multipass from starting.

Download the multipass installer from [here](https://multipass.run/download/windows) and run the installer. Pick Hyperv in preference, VirtualBox as an alternative.

- Alternative installation options are available [here](https://multipass.run/install)

## Setup a development VM using multipass

The steps and the commands to install the development VM are the same in Linux, Windows and Mac.

Once you have `multipass` installed, open a terminal or powershell and type the following command:

```
multipass launch -nopsv -c6 -d40g -m16g --cloud-init https://raw.githubusercontent.com/apache/openserverless/main/cloud-init.yaml
```

Wait until the vm is launched and you see messages like  `Launched: openserverless` (message can be different depending on multipass version effectively installed).

Complete the installation with the following command:

```
multipass exec opsv ./waitready
```

Your VM is ready. 

## (Optional) Configure Kubectl access

If you need administrative access to the vm, copy the `.kube/config` file inside the VM locally, then check if you have access:

```
mkdir $HOME/.kube
# warning this overwrites an exiting kube config
multipass exec opsv cat .kube/config >$HOME/.kube/config
# you need kubectl installed
kubectl get nodes
```

You should see something like this:

```
NAME             STATUS   ROLES                  AGE     VERSION
opsv             Ready    control-plane,master   4h58m   v1.29.6+k3s1
```

# Development Environment Overview

If you only want to test OpenServerless, stop here. You should have a working environment.

The rest of this readme describes how to create a development enviroment within the vm.

You need to setup the test environment with multipass before going on with the Development Environment.

As an IDE we use [VSCode](https://code.visualstudio.com/) as it allows [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) within the virtual machine, and we provide a workspace for it.

You may setup the environment by yourself, but it can take a lot of time so we prepared a procedure to setup quickly a ready-to-use development environment which runs the same on Windows, Linux and Mac. 

Our development environment uses a virtual machine based on Ubuntu 24.04. The virtual environemnt is initialized with a [cloud-init](https://cloud-init.io/) script we provide. 

The script installs [k3s](https://k3s.io/) as Kubernetes engine and [nix](https://nixos.org/download/#download-nix) to setup development environments. The project includes multiple subprojects, each one with a different set of dependencies so we use [direnv](https://direnv.net/) to automatically activate the right tools when you open a terminal.

*NOTE*: of course you can operate variations. It should be relatively easy to run the development virtual machine in a cloud provider using the provided cloud-init script. Basically all the cloud providers allows to build a VM using cloud-init.
We do not provide instructions how to setup on the various cloud provider (yet).

You can even setup the development environment by yourself without using the virtual machine, and use a different IDE, but adapting the configuration for your IDE is up to you and could be very time-consuming. Our development environment is the result of a few years of fine tuning, so we do not expect it will be easy to change.

## Install openserverless and tools in the VM

By default the vm is only for testing, there is no development code inside.

If you are a developer, fefore accessing the VM use this command to dowload the soucre code and tools you need to for development:

```
multipass exec opsv ./i-am-a-developer
```

You may need to wait a little bit before everything is ready.

Once everything is ready, read on to configure access to the vm using VSCode.

## Configure SSH access for VSCode

To access the virtual machine from VSCode you need to setup a ssh key and create a configuration. Open a terminal (powershell on Windows) and follow those steps:

1. Check if you already have a key in `$HOME/.ssh/id_rsa`. If not, generate one with `ssh-keygen -t rsa` then press enter to confirm.

2. Copy the key in the virtual machine to allow no password access:

```
multipass transfer $HOME/.ssh/id_rsa.pub opsv:
multipass exec opsv -- bash -c "cat id_rsa.pub | tee -a .ssh/authorized_keys"
```

3. Create a configuration named `opsv` to easily access it.

First type `multipass list`. You will see something like this:

```
Name                    State             IPv4             Image
opsv                    Running           10.6.73.253      Ubuntu 24.04 LTS
                                          10.42.0.0
                                          10.42.0.1
```

Take note of the `<IP>` in the `opsv` line (in this example `10.6.73.253` but your value can be different)

Use an editor to add to the file `~/.ssh/config` the following:

```
Host opsv
  Hostname <IP>
  User ubuntu
  IdentityFile ~/.ssh/id_rsa
```

4. Check you have access without password:

```
ssh opsv
```

Once you accessed the VM configure git with your username and email:

```
git config --global user.name "<your-name>"
git config --global user.email "<your-email>"
```

## Access the virtual machine with VSCode

1. Install [VSCode](https://code.visualstudio.com/)

2. Type F1 then "Install Extensions" (or click on the task bar the package icon)

3. Search "remote ssh" and install the extension "Remote - SSH"

4. Type F1 then "Connect" (or click on the `><` symbol in the corner to the left at the bottom) and select "Remote-SSH: Connect Current Windows to Host"

5. Click on `opsv` then select Linux if requested

6. Click on the menu bar on `File` then `Openworkspace from file`, then select the `openserverless` folder and open one of the workspaces. Currently:

- `openserverless-cli.code-workspace`: for the CLI along with task
- `openserverless-operator.code-workspace`: for the Operator alone
- `openserverless.code-workspace`: for the root with the Operator and the site

Select `Linux` and then `Trust the authors` if requested.

## Access to the subprojects

Now you have all the repositories in your virtual machine and the subprojects. Furthermore, in the VM it is configured `nix` that will setup all the dependencies to develop the subprojects, and `direnv` that activates the right dependencies when you open the terminal in a subproject.

For example try to execute `Terminal > New Terminal` and you will see you can choose the subproject. If you select `website` for example, the system will download all the dependencies to build the web site, in this case `hugo` and `npm` and install the required tools `postcss`.

## Use Git Submodules

Apache OpenServerless uses git submodules.

This means in practice two things: you have to do Pull Requests and changes forking the subprojects individually.

Then you have from time to time to update the whole subtree to the latest releases of all the subprojects.

### Contributing to subprojects

To contribute to a subproject:

- fork a subproject: for example `github.com/apache/openserverless-website` into `github.com/<username>/openserverless-website`
- add a remote to the subproject to point to your fork: for example after opening the `website` terminal, add `git remote add <username> github.com/<username>/openserverless-website`
- now you can change the code and push in your fork: `git push <username> main`
- you can now contribute a Pull Request

### Syncronize the tree

Open a terminal in the `root` subproject and type `./update-tree.sh`. This script will update all the subprojects to the latest available version on the main repo.

Do not worry about contributing PR to update dependencies as the maintainers will periodically take care of this.

## Cleanup

If you do not want to keep the VM anymore, ensure you have backed up all your files. Then remove it from your cloud provider (check your cloud provider documentation).

For multipass, use the following commands to cleanup:

```
multipass delete opsv --purge
```

