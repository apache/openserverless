# Apache OpenServerless (incubating)

Welcome to   [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org) 


- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal). 
- If you want to **install** Apache OpenServerless in your servers go [here](https://openserverless.apache.org/docs/installation/)
- If you want to **contribute** to the project, read [the  doc to setup a **development** environment)[DEVEL.md].
- If you want to **chat** with us, join  [our Discord server](https://bit.ly/openserverless-discord).
- If you want a simple local installation for testing things out, read on.


## Prerequisites: Install Multipass

To install a local environemt, you need [multipass](https://canonical.com/multipass)

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
multipass launch -nopenserverless -c4 -d20g -m8g --cloud-init https://raw.githubusercontent.com/apache/openserverless/main/cloud-init.yaml
```

Now wait until the installation is complete and you see messages like `status: done` or `Launched: openserverless` (message can be different depending on multipass version effectively installed).


TODO: change command for installing openserverless

```
multipass exec "openserverless" -- sudo cloud-init status --wait
```

## Get your Local VM API HOST


First type `multipass list`. You will see something like this:

```
Name                    State             IPv4             Image
openserverless          Running           10.6.73.253      Ubuntu 24.04 LTS
                                          10.42.0.0
                                          10.42.0.1
```

Take note of the `<IP>` in the `openserverless line` (in this case `10.6.73.253` but your value can be different)


yours instance is http://10.6.73.253.nip.io

**NOTE** this is a transient instance and if your reboot your Laptop, your IP may change

TODO: update the internal ips...

