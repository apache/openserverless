# Apache OpenServerless (incubating)

Welcome to   [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org)

- If you want to **install** Apache OpenServerless  in cloud go [here](https://openserverless.apache.org/docs/installation/).
- If you want to **understand** what this project is check the [original proposal](https://cwiki.apache.org/confluence/display/INCUBATOR/OpenServerlessProposal).
- If you want to **contribute** to the project, read on this README to setup a **development** environment.
- If you want to **discuss** with us, join  our mailing list sending an email to `dev-subscribe@openserverless.apache.org`
- If you want to **locally install**  open serverless from sources test or development, read on.

# Build from sources

## Prerequisites

- you need an Unix environment, either OSX, Linux or Windows WSL.
- you need docker availabe on the path
- you need go available on the path

## Procedure

Clone all the modules and submodules recursively:

1. `git clone https://github.com/apache/openserverless --recurse-submodules`

2. build ops running `./build.sh`

3. check ops works executing `./ops -info`

verify that  OPS_ROOT is equals to $PWD/olaris, so you can use the tasks from sources

then execute `./ops -t`

you should see somethin like this (files and version may vary)

```
ensuring prerequisite coreutils 0.0.27
ensuring prerequisite bun 1.2.5
ensuring prerequisite kubectl 1.33.1
```

4. install openserverless in docker with

`./ops setup mini`

If everything works you end up with a running openserverless in docker

