# Developer guide

OpenServerless is a complete serverless development environment.

It allows you to build full stack, scalable, cloud-native applications with backend and
frontend, using services like PostgreSQL (SQL), FerretDB (NoSQL) and Milvus (vector)
databases, Redis cache and S3-compatible object storage, with minimum effort. Check the
tutorial on <https://openserverless.apache.org> for a complete guide on how to use it.

**This guide focuses on how to develop the system itself, not on how to use it.**

## TL;DR

The short version, for the impatient. Everything below this section explains *why* each
step is what it is; this is the sequence that gets you to a running local build.

**1. Clone with submodules.** Most of the code is in submodules, so this is not optional:

```bash
git clone --recurse-submodules https://github.com/apache/openserverless
cd openserverless
```

**2. Build the CLI first.** Nothing else works until `./ops` exists:

```bash
task cli        # compiles cli/ into ./ops
```

The task files it runs are the ones in [`oplugins/`](oplugins/) — plain YAML, editable in
place.

> [!WARNING]
> **`./ops` behaves differently depending on where you are.** Run it from this directory
> and it uses your local [`oplugins/`](oplugins/). Run it from anywhere else and it
> **downloads** the task files from GitHub and uses those instead — your local edits are
> silently ignored. Always check with `./ops -info` that `OPS_ROOT` points inside your
> working copy. See [How `ops` finds its tasks](#how-ops-finds-its-tasks).

**3. Know where the images come from.** [`oplugins/opsroot.json`](oplugins/opsroot.json)
holds, under `.config.images`, the pointer to every image that gets deployed. Read it
before you wonder why the cluster is running something other than what you built — see
[`opsroot.json`](#opsrootjson).

**4. Build only what you need, then load it into kind.** Each component has its own task,
and each one builds the image *and* saves it so kind can pick it up:

```bash
task operator     # or: task openwhisk, task admin-api, task streamer, task runtimes
task opsroot      # rewrite opsroot.json to point at what you just built
ops setup docker  # create the kind cluster and load your local images into it
```

`task build` does all of them at once — useful the first time, rarely what you want after.
Nothing is pulled from a registry: the images are saved to disk and imported straight into
the kind node. See [The development loop, end to end](#the-development-loop-end-to-end).

**5. Pick the submodules you actually work on.** You generally do not need to build
everything. Work inside a single subrepo, rebuild just that component, redeploy — see
[Iterating on a single component](#iterating-on-a-single-component).

**6. To publish images, fork and push a tag.** CI builds are triggered by tags, and they
run in whichever repository received the tag — so the tag must land in *your* fork:

```bash
# fork the repo on GitHub, then, in the component's directory:
git remote set-url origin https://github.com/<your-org>/<the-fork>
task tag          # create the timestamp tag (this deletes existing local tags)
task ci           # push the tag → GitHub Actions builds and pushes the image
```

See [Publishing images](#publishing-images).

## Components

The key components, each one a separate git repository checked out as a subdirectory of
this one:

| Directory       | Repository                          | Role |
|-----------------|-------------------------------------|------|
| `cli`           | `apache/openserverless-cli`         | the `ops` CLI: controls the operator and implements the development environment |
| `oplugins-op`   | `apache/openserverless-operator`    | the operator, installing all the components including the integrated services |
| `admin-api`     | `apache/openserverless-admin-api`   | the admin API, complementing the operator |
| `streamer`      | `apache/openserverless-streamer`    | streaming support for AI applications |
| `runtimes`      | `apache/openserverless-runtimes`    | the runtimes to run applications in Python/Node.js/Go/Java using the integrated services |
| `build`         | `apache/openserverless-build`       | the OpenWhisk fork: controller and invoker images |
| `devcontainer`  | `apache/openserverless-devcontainer`| the development container image |
| `oplugins`      | `apache/openserverless-task`        | the task files (the "plugins") that `ops` executes |
| `testing`       | —                                   | the end-to-end test suite |

## Start here: build the CLI

Everything else in this guide goes through `ops`, so build it first. From the root of this
repository:

```
task cli
```

That compiles the Go sources in [`cli/`](cli/) and leaves the binary in the repository root
as `./ops`. Nothing else is needed to start — no prerequisites to install, no configuration
to write.

Now ask it where it is:

```
./ops -info
```

This prints the environment the CLI resolved for itself — which task files it will run,
where it caches things, which version it is. It is the first thing to check whenever
something behaves unexpectedly, and it is explained field by field in
[How `ops` finds its tasks](#how-ops-finds-its-tasks).

Then ask it what it can do:

```
./ops -t
```

**The first run does real work.** `ops` ships with no task files and no external tools, so
before it can list anything it:

1. **downloads the tasks** — a git clone of `$OPS_REPO`
   (default `apache/openserverless-task`) into `~/.ops/$OPS_BRANCH/oplugins`, unless it
   finds them locally first. You will see `Cloning tasks...` / `Tasks downloaded
   successfully`. In this repository the checked-out [`oplugins/`](oplugins/) is used
   instead, so nothing is downloaded.
2. **downloads the prerequisites** — the external binaries the tasks declare in
   `prereq.yml`, cached under `~/.ops/<os>-<arch>/bin`: `kubectl`, `helm`, `kind`, `k3sup`,
   `yq`, `rg`, `uv`, `bun`, `7zz`, `coreutils`. They are fetched once, on demand, and pinned
   by version.

Expect the first `ops -t` to pause while that happens; later runs are immediate. When it
finishes you get the banner and the list of top-level tasks:

```
$ ./ops -t
Welcome to ops, the all-mighty, extensibile apache OPenServerless CLI Tool.
...
*****
Tasks
*****

Type ops <task> to see usage and subtasks.

-----------------------------------
OpenServerless Administration Tasks
-----------------------------------

 admin       Manage additional users in OpenServerless
 config      Manage the Apache OpenServerless configuration
 setup       Setup the Apache OpenServerless platform on multiple environments
 debug       Debug utilities for the Apache OpenServerless platform
 cloud       OpenServerless setup utilities for supported Deployment models on Cloud Providers
 util        Utilities
 ...
```

`ops <task>` with no arguments shows that task's own usage and subtasks, so you can explore
downwards from here.

If a download goes wrong, `ops -update` re-fetches the tasks and prerequisites, and
`ops -reset` clears `~/.ops` entirely so the next run starts from scratch.

## The CLI

The system is controlled by `ops`, a single self-contained Go binary. It is essentially a
**task executor**: it is based on [Task](https://taskfile.dev) but extends it in ways that
turn it into a complete portable scripting environment.

### It is Task, extended

1. **It downloads prerequisite binaries.** Task files declare what they need in a
   `prereq.yml`; `ops` fetches and caches the missing binaries on first use (see
   [`cli/prereq.go`](cli/prereq.go)). You do not have to install them yourself.

2. **It embeds tools.** `wsk`, `wskdeploy`, `jq`, `sh`, `awk`, `envsubst`, `task` and a set
   of small purpose-built helpers are compiled into the binary itself (see
   [`cli/_patches/`](cli/_patches/) and [`cli/tools/`](cli/tools/)). They are invoked with a
   `-` prefix and need no download:

   ```
   ops -wsk action list
   ops -jq . file.json
   ops -h              # list all the embedded tools
   ```

The result is that a single binary gives you a complete, portable scripting environment —
the same on Linux, macOS and Windows.

### General syntax

```
ops -<tool>  <args>...     # run an embedded tool
ops <task>   <args>...     # run a task from the task files
```

Essential flags:

```
-h | -help      list embedded tools
-v | -version   current version (always mention it when asking for help)
-t | -tasks     list top level tasks (downloads them if needed)
-i | -info      show the CLI environment
-u | -update    download the latest tasks and prerequisites
-c | -config    manage the server configuration
-l | -login     access the system
-reset          clean the downloads (if nothing works, try this)
```

### How `ops` finds its tasks

When you run a task, `ops` locates its **root** — the directory holding `opsfile.yml` and
`opsroot.json` — in this order (see `locateOpsRoot` in
[`cli/prepare.go:171`](cli/prepare.go#L171)):

1. `$OPS_ROOT`, if set.
2. Searching **upwards** from the current directory for a folder containing both
   `opsfile.yml` and `opsroot.json`.
3. A `oplugins` (or `olaris`) subfolder **of the current directory**. This is what happens
   when you work in this repository: the checked-out [`oplugins/`](oplugins/) is used
   directly.
4. `~/.ops/$OPS_BRANCH/oplugins`. If it is not there, `ops` **downloads** it with a git
   clone from `$OPS_REPO` (default `http://github.com/apache/openserverless-task`) at the
   current branch.

So in normal use `ops` self-provisions its task files; in development it picks up your
local `oplugins` instead. Use `ops -info` to know which values are actually in effect:

```
$ ops -info
OPS & OPS_CMD: /Users/me/Projects/openserverless/ops
OPS_VERSION: 0.9.0-2609031223.SNAPSHOT
OPS_BRANCH:
OPS_BIN: /Users/me/.ops/darwin-arm64/bin
OPS_TMP: /Users/me/.ops/tmp
OPS_HOME: /Users/me/.ops
OPS_ROOT: /Users/me/Projects/openserverless/oplugins
OPS_REPO: http://github.com/apache/openserverless-task
OPS_PWD: /Users/me/Projects/openserverless
OPS_TASKS: 7e523adb9af3f17ae221220e9c17bce31fd92090
OPS_ROOT_PLUGIN: /Users/me/Projects/openserverless
```

`OPS_ROOT` pointing inside your working copy is the sign that you are running against your
local task files.

## The configuration files

### `opsroot.json`

[`oplugins/opsroot.json`](oplugins/opsroot.json) is **the glue of the whole system**. It
declares which images to deploy and other information; `.config.images` is the part that
matters most during development:

```json
{
  "config": {
    "images": {
      "operator":    "docker.io/apache/openserverless-operator:0.9.0-incubating.26i08j16-snapshot",
      "controller":  "docker.io/apache/openserverless-wsk-controller:0.9.0-incubating.26i07r51-snapshot",
      "invoker":     "docker.io/apache/openserverless-wsk-invoker:0.9.0-incubating.26i07r51-snapshot",
      "streamer":    "docker.io/apache/openserverless-streamer:...",
      "systemapi":   "docker.io/apache/openserverless-admin-api:...",
      "devcontainer":"docker.io/apache/openserverless-devcontainer:...",
      "couchdb":     "docker.io/apache/couchdb:2.3",
      "redis":       "docker.io/bitnamilegacy/redis:8.2.1",
      "...":         "... third-party service images ..."
    },
    "ops": { }
  },
  "version": "..."
}
```

#### `.config` is a source of environment variables

The `config` object is not read by the tasks as JSON. **It is flattened into environment
variables** that are then passed to every task. The rule (see `flatten` in
[`cli/config/config_map.go:156`](cli/config/config_map.go#L156)) is: walk the tree, join the
keys with `_`, uppercase the result. So

```
.config.images.operator   →   IMAGES_OPERATOR
```

and a task can simply use `$IMAGES_OPERATOR`. `ops -config -d` shows the whole set — see
[Inspecting and editing the configuration](#inspecting-and-editing-the-configuration-ops--config)
below.

This is why `opsroot.json` is the glue: changing an image there changes what every task
deploys, with no code change anywhere.

The flattening merges three sources, in increasing order of precedence
([`cli/main.go:460`](cli/main.go#L460)):

1. `opsroot.json` from the task root — the defaults shipped with the release;
2. `config.json` — the user's own configuration, written by `ops -config`;
3. the `opsroot.json` of any installed plugin, under its own key (a plugin whose name
   collides with an existing key is ignored, with a warning).

#### Inspecting and editing the configuration: `ops -config`

`ops -config` is how you read and change that merged configuration without editing JSON by
hand ([`cli/config/config_tool.go`](cli/config/config_tool.go)).

**Dump every variable** — `-d` (or `--dump`) prints the whole flattened set, exactly as the
tasks will see it. This is the quickest way to answer "what is this task actually going to
use?":

```
$ ops -config -d
IMAGES_OPERATOR=docker.io/apache/openserverless-operator:0.9.0-incubating.26i08j16-snapshot
IMAGES_CONTROLLER=docker.io/apache/openserverless-wsk-controller:0.9.0-incubating.26i07r51-snapshot
OPERATOR_CONFIG_APIHOST=miniops.me
OPERATOR_COMPONENT_POSTGRES=true
POSTGRES_CONFIG_REPLICAS=1
...
```

> The dump includes the generated passwords and API keys (`SECRET_*`,
> `REGISTRY_CONFIG_SECRET_*`). Redact it before pasting into a bug report.

**Read one value** — pass a bare key, with no `=`. Several keys print several values:

```
$ ops -config IMAGES_OPERATOR
docker.io/apache/openserverless-operator:0.9.0-incubating.26i08j16-snapshot
```

**Set a value** — pass `KEY=VALUE`. Several pairs at once are fine:

```
ops -config OPERATOR_CONFIG_APIHOST=my.host.example
ops -config IMAGES_STREAMER=ghcr.io/me/openserverless-streamer:mytag POSTGRES_CONFIG_REPLICAS=3
```

**Remove a value** — `-r` (or `--remove`) with the keys to drop:

```
ops -config -r POSTGRES_CONFIG_REPLICAS
```

All writes go to `config.json` in `$OPS_HOME` (`~/.ops/config.json`), which is layer 2 of
the merge above — so a value you set there **overrides** `opsroot.json` and survives the
task files being re-downloaded.

That layering has two consequences worth knowing:

- **`-r` removes a key from `config.json` only.** It cannot delete anything that came from
  `opsroot.json`; removing your override just lets the underlying default show through
  again. Removing a key that only exists in `opsroot.json` fails with
  `invalid key: '<KEY>' - key does not exist in config.json`.
- **You cannot blank a value.** `ops -config -h` claims that `KEY=""` disables an
  `opsroot.json` value, but the parser rejects an empty right-hand side
  ([`cli/config/config_tool.go:161`](cli/config/config_tool.go#L161)) and the command fails
  with `invalid key-value pair: "KEY="`. To neutralise an inherited value today, set it to
  something the task treats as off (`false`, `0`) — or edit `oplugins/opsroot.json`
  directly, as described under [Overriding a single image](#overriding-a-single-image).

#### `.version` is the required CLI version

The top-level `version` field is **the version of `ops` that these task files require**. On
every run the CLI compares its own version against it as semver
([`cli/prepare.go:129`](cli/prepare.go#L129)). If `ops` is older, it says so and updates
itself automatically:

```
Your ops version (0.9.0) is older than the required version (0.9.1).
```

In development your CLI version is usually not valid semver (e.g.
`0.9.0-2609031223.SNAPSHOT`), so the check is skipped with a warning and you are never
force-updated out of your own build.

### `runtimes.json`

[`oplugins/runtimes.json`](oplugins/runtimes.json) points to the runtime images to use. It
is **a standard OpenWhisk runtimes manifest** — the same format OpenWhisk itself consumes,
with `runtimes`, `blackboxes` and `description` at the top level:

```json
{
  "runtimes": {
    "nodejs": [
      {
        "kind": "nodejs:24",
        "default": false,
        "image": {
          "prefix": "docker.io/apache",
          "name": "openserverless-runtime-nodejs",
          "tag": "v24-26i07r17-snapshot"
        },
        "deprecated": false,
        "attached": { "attachmentName": "codefile", "attachmentType": "text/plain" }
      }
    ],
    "python": [ ], "go": [ ], "java": [ ]
  },
  "blackboxes": [ ],
  "description": "..."
}
```

It is generated in the [`runtimes/`](runtimes/) repository and copied over by
`task sync-runtimes`. Because it is the standard format, the CLI also hands it to the
embedded `wsk` through `WSK_RUNTIMES_JSON` ([`cli/main.go:291`](cli/main.go#L291)).

## How to build

The system runs on Kubernetes and can be deployed in many environments — most notably k3s,
microk8s, and cloud offerings like Amazon EKS, Azure AKS and Google GKE. For development
you can use Docker, and OpenServerless will install `kind` for you.

Build everything locally with:

```
task build
```

This builds all the required images. It runs, in order (see
[`Taskfile.yml:231`](Taskfile.yml#L231)):

| Step | What it does |
|------|--------------|
| `gitinit` | initializes git in the subrepos if missing (tags are the build's currency, so a repo without git cannot be built) |
| `opslink` | builds `ops`, symlinks it into `~/.local/bin`, links `oplugins` into `~/.ops/$OPS_BRANCH` |
| `openwhisk` | builds the controller and invoker images |
| `operator` | builds the operator image |
| `runtimes` | builds `runtimes.json` |
| `streamer` | builds the streamer image |
| `admin-api` | builds the admin-api image |
| `opsroot` | **rewrites `oplugins/opsroot.json` with the tags just built** |

You compile `ops` first, then `ops` builds the system.

### Everything is driven by tags

**All the compilations are driven by the git tag** of each component repository. A build
does not take a version from a variable — it reads the tag out of git, tags the image with
it, and writes that same tag into `opsroot.json`. There are two kinds of tag, for two
different purposes.

**There is no way around this, not even the manual runs.** Starting a workflow by hand from
the GitHub Actions UI (`workflow_dispatch`) looks like it bypasses tagging, but under the
hood it does exactly what you would have done locally: the job runs `task tag` and
`task ci` on the runner, and the following step reads the tag back with
`git describe --tags --abbrev=0` to name the image
([`oplugins-op/.github/workflows/image.yml:54`](oplugins-op/.github/workflows/image.yml#L54)).
So **every image that exists corresponds to a tag** — there is no such thing as an untagged
build, and given an image tag you can always find the commit it was built from.

#### Development tags: the operator ref

The main build derives its tag from the **git ref of the operator**
([`Taskfile.yml:25`](Taskfile.yml#L25)):

```yaml
RELEASE:
  sh: git -C oplugins-op rev-parse --short HEAD
OPERATOR_TAG: "{{.RELEASE}}"
```

Every other component inherits it — `STREAMER_TAG`, `ADMIN_API_TAG`, `OPENWHISK_TAG`,
`DEVCONTAINER_TAG` and `OPS_BRANCH` are all `{{.OPERATOR_TAG}}`. One short commit hash
labels the whole build, so a local build is always internally consistent.

**These tags are meant for private development.** They never leave your machine: the images
are saved locally (under `~/.ops/<os>-<arch>/images/kind/`) and loaded into `kind`.

#### Publication tags: the timestamp

To publish images you define a tag explicitly with `task tag`, in the component's own
directory. These are the tags meant to publish images, and they are covered in full in
[Publishing images](#publishing-images) below.

### Keeping `opsroot.json` in sync

Two tasks write `opsroot.json`, and it is worth knowing which one you are running:

- **`task opsroot`** (part of `task build`) writes the tags of the images **you just built
  locally** — the operator-ref tags.
- **`task sync-opsroot`** writes the **latest published tag of each component**, read from
  git:

  ```yaml
  OPENWHISK_TAG:
    sh: git -C build for-each-ref --sort=-creatordate --count=1 --format='%(refname:short)' refs/tags
  ```

Both keep a pristine copy in `opsroot.orig` on first run and regenerate from it, so
repeated runs are idempotent. `task sync-images` runs the runtimes and opsroot syncs
together.

> **Gotcha.** `sync-opsroot` reads whatever tags are **local**. A freshly cloned subrepo has
> no tags, `for-each-ref` returns the empty string, and you silently get a tagless image
> reference such as `docker.io/apache/openserverless-wsk-controller:`. If images fail to
> pull with an empty tag, run `git fetch --tags` in the offending subdirectory and re-run
> the task.

## Developing against a local build

In development you set `OPS_ROOT` temporarily to your local task files, so that `ops` uses
the `oplugins` in your working copy rather than the downloaded ones. This is what
[`Taskfile.yml`](Taskfile.yml) does when running the tests:

```bash
export PATH="$PWD:$PATH"
export OPS_ROOT="$PWD/oplugins"
export OPS_BRANCH="<the branch>"
which ops
ops -info
```

Always confirm with `ops -info` that `OPS_ROOT` and `OPS_BIN` are what you expect before
concluding that a change did not work.

`task opslink` makes this semi-permanent: it symlinks `./ops` into `~/.local/bin` and your
`oplugins` into `~/.ops/$OPS_BRANCH/oplugins`, and appends `OPS_BRANCH` and the `PATH`
entry to `~/.profile`.

### The development loop, end to end

Building for development means producing images that exist **only on your machine**, tagged
with your operator ref, and pointing a local `kind` cluster at them. The full cycle:

```bash
# 1. build everything: ops, the images, and a matching opsroot.json
task build

# 2. make ops and your local task files the ones in use
export PATH="$PWD:$PATH"
export OPS_ROOT="$PWD/oplugins"

# 3. verify you are running against your own build
ops -info          # OPS_ROOT must point inside your working copy
ops -t             # list the tasks that will run

# 4. create the cluster and deploy
ops setup docker
```

The step that ties it together is invisible unless you go looking for it. Because these
images are never pushed to a registry, `task build` **saves each one to disk** as it is
built — `task image-save` writes it to
`~/.ops/<os>-<arch>/images/kind/<base64-of-the-image-name>`
([`Taskfile.yml:75`](Taskfile.yml#L75)). Later, `ops setup docker` calls
`ops util freeze kind-load`, which walks that directory, decodes each filename back into an
image name, and imports the layers straight into the kind node's containerd
([`oplugins/util/freeze/opsfile.yml:176`](oplugins/util/freeze/opsfile.yml#L176)).

So the chain from a code change to a running pod is:

```
your commit  →  operator ref = the tag  →  images built with that tag
             →  saved under ~/.ops/.../images/kind/
             →  opsroot.json rewritten with that tag   (task opsroot)
             →  IMAGES_* env vars                       (the CLI, on every run)
             →  kind-load imports them into the cluster (ops setup docker)
             →  the manifests reference exactly those images
```

Nothing is pulled from Docker Hub, because the tag in `opsroot.json` matches an image
already present in the node.

### Iterating on a single component

A full `task build` is rarely what you want after the first one. Each component has its own
task, so rebuild just the one you touched and redeploy:

```bash
task streamer      # or: operator, admin-api, openwhisk, cli, runtimes
task opsroot       # rewrite opsroot.json with the new tags
ops setup docker   # reload the images and roll out
```

Two things to keep in mind:

- **`task cli` is a no-op once `./ops` exists** — it carries `status: ! test -e ../ops`
  ([`Taskfile.yml:95`](Taskfile.yml#L95)), and `task opslink` and `task build` both depend
  on it, so neither will rebuild the binary either. After changing the CLI, `rm ./ops` (or
  `task clean`) before rebuilding, or you will keep running the old one. `ops -info`
  showing a stale `OPS_VERSION` is the tell.
- **The tag only changes when the operator ref changes.** `RELEASE` is
  `git -C oplugins-op rev-parse --short HEAD`, so rebuilding the streamer without
  committing in `oplugins-op` produces an image with the *same* tag as before. That is
  usually what you want — but it means kind may keep the previously imported layers, so
  delete the cluster (`ops setup docker delete`) if a change stubbornly refuses to appear.

### Overriding a single image

You do not have to rebuild anything to try a different image. Because `.config` is just a
source of env vars, editing `oplugins/opsroot.json` is enough:

```bash
jq '.config.images.streamer = "docker.io/apache/openserverless-streamer:some-other-tag"' \
   oplugins/opsroot.json > tmp && mv tmp oplugins/opsroot.json
ops setup docker
```

`task opsroot` and `task sync-opsroot` will overwrite this on their next run — they
regenerate from `opsroot.orig` — so treat it as a temporary probe, not a durable change.

### Starting from a clean slate

When the state gets confusing, the reset ladder, from cheapest to most drastic:

```bash
ops setup docker delete   # destroy the kind cluster
task clean                # remove ./ops and the cached kind images
ops -reset                # remove ~/.ops entirely (asks for confirmation)
ops -update               # re-download tasks and prerequisites
```

## Publishing images

Everything above builds on your machine and stays there. Publishing is a different flow,
and it is governed by one rule:

> **All CI builds are triggered by pushing a git tag.** No branch push ever builds an
> image. Every component workflow is declared `on: push: tags:` with `branches-ignore: '*'`
> — the tag is not metadata attached to a build, the tag **is** the trigger, and its text
> **is** the image tag.

### The three tasks

Every component — the operator, admin-api, streamer, devcontainer, the OpenWhisk build, the
runtimes and the CLI — exposes the same trio, with the same meaning. You use them in this
order:

| Task | Runs where | Effect | Pushes? |
|------|------------|--------|---------|
| `task tag` | local | creates (force-replacing) the git tag that names this build | no |
| `task build` | local | builds using the current tag, into the local Docker daemon | no |
| `task ci` | local, triggers remote | pushes the tag, which starts the GitHub Actions build | yes, via CI |

Run them **in the component's own directory**, not in the root — each subrepo has its own
`Taskfile.yml` and its own workflow.

Two things newcomers consistently get wrong, so they are worth stating outright:

- **`task tag` deletes the existing local tags** before creating the new one. This is
  deliberate — snapshot tags are disposable — but it is destructive, and it is not what
  `git tag` normally does.
- **`task ci` does not build anything.** It runs `git push --tags`. The build happens in
  GitHub Actions *on the repository that received the tag*. This is the whole reason
  forking matters: the tag lands in **your** fork, so **your** Actions run, with **your**
  credentials, pushing to **your** registry.

There is also a manual path: every workflow declares `workflow_dispatch`, so it can be
started from the GitHub Actions UI, where it creates the tag itself. Use it when you cannot
or do not want to push tags from the command line.

The CLI is the one component with a wrinkle: `task ci` (alias `task trigger`) refuses to
run on a dirty tree (`git diff --exit-code`), and its `task tag` **creates a commit** — it
writes `version.txt` and `branch.txt` and commits them, because the CLI embeds its own
version string. Every other component only moves a tag.

### The tag format

Tags are timestamps in a compacted, sortable form. The encoding is uniform across all
components, and it is worth learning because the tags are otherwise unreadable:

```
0.9.0-incubating.26i07r51-snapshot
└────┬─────────┘ ││││││└┬┘└───┬───┘
   BASETAG       ││││││ │     └───── SUFFIX: -snapshot marks a non-release build
                 ││││││ └─────────── minute
                 │││││└───────────── hour,  a letter: a=00 … x=23
                 │││└┴────────────── day of month
                 ││└──────────────── month, a letter: a=January … l=December
                 └┴───────────────── year, two digits
```

So `26i07r51` is 2026, September (`i` = 9th letter), day 07, hour 17 (`r` = 18th letter,
zero-based → 17), minute 51.

Because the encoding is lexicographically sortable and the tags are created in order,
"the newest tag" and "the latest build" are the same thing — which is exactly what
`task sync-opsroot` relies on when it picks a tag with
`git for-each-ref --sort=-creatordate --count=1`.

The **runtimes** are the exception: their tag carries a prefix naming the family to build,
and CI parses it to decide what work to do (see below).

### Where the images go

The destination registry and the credentials are **derived automatically from the
repository the tag was pushed to**. In the normal case there is nothing to configure:

| Tag pushed to | Registry | Namespace | Credentials |
|---------------|----------|-----------|-------------|
| the Apache repository | `docker.io` | `apache` | secrets `DOCKERHUB_USER` / `DOCKERHUB_TOKEN` |
| any fork | `ghcr.io` | the fork owner's GitHub user | the current GitHub actor + the built-in `GITHUB_TOKEN` |

So a contributor who forks and pushes a tag gets images at `ghcr.io/<their-user>/…` with
**no secrets to create and no `.env` to write** — the workflow authenticates as the user
running it, with the token GitHub hands to every Actions run.

To send images somewhere else, set the `DOCKERHUB_REGISTRY` secret together with
`DOCKERHUB_USER` and `DOCKERHUB_TOKEN`. That is an override for people who want a specific
destination, not a setup step.

#### The exception: repositories that publish other repositories' images

Two repositories publish images whose names do **not** match the repository itself:

| Repository | Images published |
|------------|------------------|
| `openserverless-build` | `openwhisk2/controller`, `openwhisk2/invoker`, `openwhisk2/scheduler`, `openwhisk2/standalone`, `openwhisk2/scala` |
| `openserverless-runtimes` | `openserverless-runtime-<rt>` — one per language version |

The built-in `GITHUB_TOKEN` is scoped to packages **owned by the repository running the
workflow**: GHCR links a package to its creating repository on first push and grants write
access only to that repository. Since these two publish under names that do not match,
`GITHUB_TOKEN` carries no permission and the push is refused.

For these two repositories only, when pushing to ghcr.io, a **`GHCR_TOKEN`** secret must be
set on the fork — a classic Personal Access Token with the **`write:packages`** scope:

1. <https://github.com/settings/tokens> → *Generate new token (classic)*.
2. Select **`write:packages`** (this implies `read:packages` and `repo`).
3. In your fork: *Settings → Secrets and variables → Actions → New repository secret*,
   named exactly **`GHCR_TOKEN`**.

When pushing to Docker Hub instead, the equivalent is a `DOCKERHUB_TOKEN` with write
permission on the target images.

The symptom when this is missing is `denied: permission_denied: write_package` at push
time, after a long and otherwise successful build. Both workflows now **fail fast** with
these instructions in the job summary rather than building first and failing at the end.

### Naming your local build

Locally no registry is involved: each component builds under the same default image name it
would use in CI, and the result exists only in your Docker daemon. To name it for your own
registry instead, export `MY_<COMPONENT>_IMAGE` — the **full image name without the tag**;
the tag is still computed as above. Each component ships a `.env.dist` to copy to `.env`
(which stays untracked):

| Component | Variable |
|-----------|----------|
| operator | `MY_OPERATOR_IMAGE` |
| streamer | `MY_STREAMER_IMAGE` |
| admin-api | `MY_ADMINAPI_IMAGE` |
| devcontainer | `MY_DEVCONTAINER_IMAGE` |
| OpenWhisk build | `MY_CONTROLLER_IMAGE`, `MY_INVOKER_IMAGE`, `MY_SCHEDULER_IMAGE`, `MY_STANDALONE_IMAGE` |

### What each component publishes

The trio above is identical everywhere; what differs is what one tag produces.

**One tag → one image** — `operator`, `admin-api`, `streamer`, `devcontainer`. The plain
case:

```bash
cd streamer
task tag        # 0.9.0-incubating.26i07r51-snapshot
task build      # local image, nothing pushed
task ci         # push the tag → CI builds linux/amd64 + linux/arm64 and pushes
```

CI also runs the license check (skywalking-eyes) and the unit tests **before** building the
image, so a red build is not necessarily an image problem.

**One tag → a family of images** — `runtimes`. The tag selects the work:

```bash
cd runtimes
task tag RT=python     # python_26i07r51-snapshot
task tag               # RT defaults to "all"
```

CI parses the prefix (`all`, `common`, `experimental`, or a single language) and builds
only that family, producing one image per language version:

```
<registry>/<namespace>/openserverless-runtime-<rt>:<ver>-<tag>
```

Every runtime image is `FROM` the **common base**, so the common job runs first and the
language matrix depends on it; building a language family against a missing or mismatched
base is a failure mode, not a bug. This repository needs `GHCR_TOKEN` (see above). The
resulting `runtimes.json` is what reaches an installation, via `task sync-runtimes`.

**One tag → binaries, no image** — `cli`. `task build` compiles `ops` into the repository
root and is all you need locally; tagging matters only when the embedded version string
does. `task ci` tags, commits, and pushes, and the release workflow publishes binaries for
every supported platform.

**The OpenWhisk images** — `build`. This one does not follow the pattern of the others and
deserves its own note:

- It vendors an OpenWhisk source tree and builds through a devcontainer rather than on the
  host, because the OpenWhisk Gradle build **requires Java 11**. On a host with a newer JDK
  it fails with `Unsupported class file major version`. Run it inside
  `ops ide devcontainer`.
- Its `task build` does the whole local round trip: build the images, update
  `opsroot.json`, load into kind, roll out the controller.
- **The root `Taskfile.yml` and `build/Taskfile.yml` are separate build systems.** This is
  the single most common wrong assumption. The root `task build` does invoke `task
  openwhisk`, but the two Taskfiles maintain their own tags and their own `opsroot.json`
  edits — when in doubt about which controller image is deployed, read
  `.config.images.controller` rather than inferring it.

### Consuming a build you published

Once CI has pushed your images, point an installation at them by editing the image
references in `opsroot.json` — either your working copy's `oplugins/opsroot.json`, or
`~/.ops/$OPS_BRANCH/oplugins/opsroot.json` for an installed CLI:

```bash
jq '.config.images.streamer = "ghcr.io/<your-user>/openserverless-streamer:<your-tag>"' \
   oplugins/opsroot.json > tmp && mv tmp oplugins/opsroot.json
ops setup docker
```

Runtimes are overridden the same way through `runtimes.json`.

Two failure modes worth recognising:

- **Locally built images are not automatically visible to kind.** If you skip the
  `kind-load` step described earlier, the pod silently pulls the old upstream image
  instead. The symptom is a deployment that succeeds while running the wrong code.
- **A change visible in the custom resource is not proof it reached the workload.** Confirm
  at the pod level:

  ```bash
  kubectl -n openserverless get pods -o jsonpath='{.items[*].spec.containers[*].image}'
  ```

## Testing

Run the whole suite (defaults to `kind`):

```
task test
```

Run a single test — with an empty or unknown `TEST` it lists the available ones:

```
task test-one TEST=<name>.sh
task test-one TEST=
```

Both live in [`testing/tests/`](testing/tests/) and export `OPS_ROOT` to the local
`oplugins`, so they always exercise your working copy.

## Other useful tasks

| Task | Purpose |
|------|---------|
| `task` | list all the tasks and print the current release |
| `task clean` | remove `./ops` and the cached kind images |
| `task license` | check the license headers with `license-eye` (`CMD=fix` to fix them) |
| `task sync-images` | refresh `runtimes.json` and `opsroot.json` from the latest published tags |
| `task release VER=<v> KEY=<gpg-key>` | build the signed source release tarball; the source must be in a version folder and you need a GPG key to sign |

See also [VERIFY.md](VERIFY.md) for verifying a release, and
[CONTRIBUTING.md](CONTRIBUTING.md).
