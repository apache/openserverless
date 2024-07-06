# Apache OpenServerless

Welcome to [Apache OpenServerless](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal) (also referenced as **AOS**), an incubating project at the [Apache Software Foundation](https://www.apache.org).

This README provides information for developers of the project. For user information refer to the [website](https://openserverless.apache.org) (not yet available).

## Development Enviroment Overview

Apache OpenServerless is a complex project with lots of dependencies. It also needs a Kubernetes cluster to be executed, tested and developed on.

You may setup the environment by yourself but it can take a lot of time so we prepared a ready-to-use development environment which runs the same on Windows, Linux and Mac.

In order to bootstrap easily the development environment for the project, we use a virtual machine based on Ubuntu (currently version 24) initialized with [cloud-init](https://cloud-init.io/).

To create a virtual machine in your workstation we use [multipass](https://multipass.run/). You can also setup the virtual machine in a cloud provider and access it in the same way as in your local machine. We provide here instructions how to install in your local machine only.

As an IDE we use [VSCode](https://code.visualstudio.com/) as it allows [Remote Development](https://code.visualstudio.com/docs/remote/remote-overview) within the virtual machine. You can also use a different IDE but the configuration for VSCode is documented.

You need a virtual machine with at least 8GB of memory and 4 VCPU so your development workstation probably needs at least 16GB and 6 VCPU. Your mileage may vary.

## Setup the Development Virtual Machine

Here we describe how to setup the development virtual machine on Linux, Mac and Windows using multipass. First, install multipass.

- On Mac, if you already have [brew](https://brew.sh/), installing it is as easy as to type `brew install multipass`.

- On Linux, if you already have [snap](https://snapcraft.io/), installing it is as easy as type `sudo snap install multipass`.

- On Windows, you need Windows 10 Pro/Enterprise/Education v1803 or later, or any Windows 10 with VirtualBox. Make sure your local network is designated as private, otherwise Windows prevents Multipass from starting.

Download the multipass installer from [here](https://multipass.run/download/windows) and run the installer. Pick Hyperv in preference, VirtualBox as an alternative.

- Alternative options are available [here](https://multipass.run/install)

### Setup a development VM using multipass

The steps and the commands to install the development VM are the same in Linux, Windows and Mac.

Once you have `multipass` installed, open a terminal or powershell and type the following command:

```
multipass launch -nopenserverless -c4 -d20g -m8g --cloud-init https://raw.githubusercontent.com/apache/openserverless/main/cloud-init.yaml
```

Now wait until the installation is complete and you see `status: done`

```
multipass exec "openserverless" -- sudo cloud-init status --wait
```

Finally check if Kubernetes (k3s) is up and running in the VM:

```
multipass exec openserverless sudo k3s kubectl get nodes
```

You should see something like this:

```
NAME             STATUS   ROLES                  AGE     VERSION
openserverless   Ready    control-plane,master   4h58m   v1.29.6+k3s1
```

## Configure SSH access for VSCode

To access the virtual machine from VSCode you need to setup a ssh key and create a configuration. Open a terminal (powershell on Windows) and follow those steps:

1. Check if you already have a key in `$HOME/.ssh/id_rsa`. If not, generate one with `ssh-keygen -t rsa` then press enter to confirm.

2. copy the key in the virtual machine to allow no password access:

```
muultipass transfer $HOME/.ssh/id_rsa.pub openserverless:
multipass exec openserverless -- bash -c "cat id_rsa.pub | tee -a .ssh/authorized_keys"
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

Use an editor to add to the file `~/ssh/config` the following:

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

Now you are in the virtual machine, setup your name and email for git use.

```
git config --global user.name "<your-name>"
git config --global user.email "<your-email>
```

## Access the virtual machine with VSCode

1. Install [VSCode](https://code.visualstudio.com/)

2. Type F1 then "Install Extensions" (or click on the task bar the package icon)

3. Search "remote ssh" and install the extension "Remote - SSH"

4. Type F1 then "Connect" (or click on the `><` symbol in the corner to the left at the bottom) and select "Remote-SSH: Connect Current Windows to Host"

5. Click on `openserverless` then select Linux if requested

6. Click on the menu bar on `File` then `Openworkspace from file`, then select the `openserverless` folder and open the `openserverless.code-workspace`. Select `Linux` and then `Trust the authors` if requested.

### Access to the subprojects

Now you have all the repositories in your virtual madchine and the subprojects. Furthermore, in the VM it is configured `nix` that will setup all the dependencies to develop the subprojects, and `direnv` that will activate the right dependencies when you open the terminal on a subproject.

For example try to execute `Terminal > New Terminal` and you will see you can choose the sub project. If you select `website` for example, the system will download all the dependencies to build the web site, in this case `hugo` and `npm` and install the required tools `postcss`.

## Submodules

Apache OpenServerless uses git submodules.

This means in practice two things: you have to do Pull Requests and changes forking the subprojects individually.

Then you have from time to time to update the whole subtree to the latest releases.

### Contributing to subprojects

To contribute to a subproject:

- fork a subproject: for example `github.com/apache/openserverless-website` into `github.com/sciabarracom/openserverless-website`
- add a remote to the subproject to point to your fork: for example after opening the `website` terminal, add `git remote add sciabarracom github.com/sciabarracom/openserverless-website`
- now you can change the code and push in your fork: `git push sciabarracom main`
- you can now contribute a Pull Request

### Syncronize the tree

Open a terminal in the `root` subproject and type `./update-tree.sh`. This script will update all the suprojects to the latest available version on the main repo.

Do not worry about contributing PR to update dependencies as the maintainers will periodically take care of this.

### Cleanup

If you do not want to keep the VM anymore, esure you have backed up all your files. Then remove it in your cloud provider (check your cloud provider documentation).

For multipass, use the following commands to cleanup:

```
multipass delete openserverless --purge
```
