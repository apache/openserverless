# Apache OpenServerless (incubating)

Welcome to   [Apache OpenServerless](https://openserverless.apache.org), an incubating project at the [Apache Software Foundation](https://www.apache.org)

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

## Procedure

### 1. Get the sources

Clone all the modules and submodules recursively

`git clone https://github.com/apache/openserverless --recurse-submodules`

### 2. Build

First clean everything

`task clean`

then build:

`task build`

This will
- build the cli
- build the operator image
TODO: build the runtimes

3. Smoke test

Execute a basic smoke test

`bash smoke.sh`

4. More tests

TODO: execute locally the full test suite under ./testing

