# Build Session Notes

Date: 2026-06-27

## Scope

Work was done locally only. No git push and no Docker Hub push were performed.

## Branches And Submodules

- Root repository branch: `build`
- `build` submodule branch: `build-local`
- `build/openwhisk` submodule branch: `openwhisk-build-fixes`

## OpenWhisk Source

The nested `build/openwhisk` submodule was moved to the Nuvolaris commit:

```text
a456219d35bfabe4a3458fcce82cd71497a8524e
```

`build/.gitmodules` was updated to use:

```text
https://github.com/nuvolaris/openwhisk.git
```

## Build Devcontainer

The correct build devcontainer is:

```text
build/.devcontainer/Dockerfile
```

The top-level `devcontainer` submodule was touched by mistake, then reverted. It is not part of the final build path.

The build devcontainer was updated to be multi-arch and OpenWhisk-ready:

- Java 11 via Temurin is the default `JAVA_HOME`
- GraalVM Java 17 is still available for native-image
- Docker CLI and buildx are installed
- Docker repo setup uses the Ubuntu codename instead of a hardcoded `bionic`

Verified inside the container:

```text
java 11.0.17
javac 11.0.17
native-image 17.0.9
docker CLI available
task available
```

## Gradle Fixes

`task distdocker` initially failed with dependency resolution errors in the old OpenWhisk commit.

Backported minimal Gradle fixes in `build/openwhisk`:

- `build.gradle`: use `gradle.plugin.cz.alenkacz:gradle-scalafmt`
- `settings.gradle`: `scalafmt` version `1.5.1`
- `core/standalone/build.gradle`: `gradle-git-properties` version `2.4.2`

These fixes are committed locally in:

```text
f2cba906 Fix OpenWhisk distDocker dependency resolution
```

## Java 17 Host Error

Running OpenWhisk Gradle directly on the host failed with:

```text
Unsupported class file major version 61
```

Reason: host Java was 17, but this OpenWhisk/Gradle 6.9.1 build must run with Java 11.

Fix: `build/Taskfile.yml` now wraps `distdocker` and `build-all` with `ops ide devcontainer`, so the host uses the same devcontainer path expected by OPS instead of a hand-written `docker run`.

The wrapper also sets a temporary empty `DOCKER_CONFIG` inside the devcontainer.
This avoids failures from a devcontainer-generated Docker credential helper, for
example:

```text
error getting credentials - err: exit status 255
```

## Local Docker Build Tasks

`build/Taskfile.yml` was changed so:

- `task build` is the main local flow: build images, update OPS root, load kind, roll out controller
- `task distdocker` runs through `ops ide devcontainer`
- `task build-all` runs through `ops ide devcontainer`
- `task build-all:local` checks that `openwhisk/common/scala` exists and prints a submodule init hint if it does not
- `distdocker` no longer passes a Docker registry by default
- `build-all` no longer uses `--push` for `ACT=build`
- Push remains explicit via `buildx-and-push` / `ACT=buildx-push`

Verified:

```text
cd /home/msciab/openserverless/build
task build
```

This completed successfully locally through `ops ide devcontainer`. It built the
OpenWhisk images, loaded controller/invoker/standalone into kind, and rolled out
`controller-0`.

Latest verified tag:

```text
2.0.0-incubating.2606291403
```

Latest verified pod image:

```text
controller-0 registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2606291403
```

## Images Built Locally

The OpenWhisk build produced these local Docker images:

```text
registry.hub.docker.com/apache/openserverless-wsk-scala:2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-invoker:2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-scheduler:2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-standalone:2.0.0-incubating.2506080813
```

Despite the `registry.hub.docker.com/apache` prefix, these were local tags only. They were not pushed.

## OPS Root Image Override

The installed OPS root was updated here:

```text
/home/msciab/.ops/0.1.0/olaris/opsroot.json
```

Changed keys:

```json
{
  "standalone": "registry.hub.docker.com/apache/openserverless-wsk-standalone:2.0.0-incubating.2506080813",
  "controller": "registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813",
  "invoker": "registry.hub.docker.com/apache/openserverless-wsk-invoker:2.0.0-incubating.2506080813"
}
```

Important: in the current standalone OpenWhisk deployment path, OPS/operator uses `controller.image` for the controller pod. The `standalone` key is present in `opsroot.json`, but the observed `Whisk` resource uses `spec.controller.image`.

## Kubeconfig Repair

The host kubeconfig was stale:

```text
https://127.0.0.1:35889
```

The running kind control plane was exposed on:

```text
https://127.0.0.1:34101
```

Backed up kubeconfig:

```text
/home/msciab/.kube/config.bak.20260627085813
```

Updated context:

```text
kind-nuvolaris
```

Verified:

```text
kubectl cluster-info
kubectl get nodes
```

## Loading Images Into Kind

This is now automated by the build repository task:

```bash
cd /home/msciab/openserverless/build
task build
```

That task runs:

1. `task build-all`
2. update of `/home/msciab/.ops/0.1.0/olaris/opsroot.json`
3. import of local OpenWhisk images into the kind node
4. rollout of the local OpenWhisk controller StatefulSet
5. final status output

The locally built images were not automatically present in the kind node.

The underlying import command is:

```bash
for img in \
  registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813 \
  registry.hub.docker.com/apache/openserverless-wsk-invoker:2.0.0-incubating.2506080813 \
  registry.hub.docker.com/apache/openserverless-wsk-standalone:2.0.0-incubating.2506080813
do
  docker save "$img" | docker exec -i nuvolaris-control-plane ctr --namespace=k8s.io images import -
done
```

Verified in kind:

```text
registry.hub.docker.com/apache/openserverless-wsk-controller   2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-invoker      2.0.0-incubating.2506080813
registry.hub.docker.com/apache/openserverless-wsk-standalone   2.0.0-incubating.2506080813
```

## Current Pod Image

The `Whisk` CR had the new image:

```text
spec.controller.image = registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813
```

But the actual StatefulSet/pod initially still used:

```text
ghcr.io/nuvolaris/openwhisk-controller:0.3.0-morpheus.22122609
```

This is now automated by:

```bash
cd /home/msciab/openserverless/build
task build
```

The underlying patch command is:

```bash
kubectl -n nuvolaris set image statefulset/controller \
  controller=registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813
```

Rollout completed and `controller-0` now uses:

```text
registry.hub.docker.com/apache/openserverless-wsk-controller:2.0.0-incubating.2506080813
```

## Why `task build` / `task setup` Did Not Do This Automatically

There are two separate build systems:

1. Root `Taskfile.yml`
   - Builds CLI, operator, runtimes, streamer, admin-api.
   - Its `opsroot` task updates only:
     - `operator`
     - `streamer`
     - `systemapi`
   - It does not build or update OpenWhisk `controller` / `invoker` / `standalone`.
   - It saves some images into `~/.ops/<os>-<arch>/images/kind`, but not the OpenWhisk images produced by `build/Taskfile.yml`.

2. `build/Taskfile.yml`
   - Builds OpenWhisk images:
     - controller
     - invoker
     - scheduler
     - standalone
     - scala base
   - Before this session, it did not update OPS `opsroot.json`.
   - Before manual loading, it did not load these images into kind.

Also, the operator/standalone image replacement appears to miss the new image when rendering the StatefulSet.

Observed behavior:

- The `Whisk` CR contains `spec.controller.image` with the new image.
- The generated StatefulSet still had the old template image.

Likely technical cause:

- `olaris-op/nuvolaris/openwhisk_standalone.py` calls `kus.image(whisk_image, newTag=whisk_tag)`.
- Kustomize image replacement matches the image name already present in the template.
- The template contains `ghcr.io/nuvolaris/openwhisk-controller`.
- The generated kustomization uses the new image as the match name, so it does not match the old template image.

Proper code-level fix should replace the template image name with `newName`, for example:

```text
name: ghcr.io/nuvolaris/openwhisk-controller
newName: registry.hub.docker.com/apache/openserverless-wsk-controller
newTag: 2.0.0-incubating.2506080813
```

## Local Commits Created

Root repo:

```text
bd8b2b4 Update build-all local workflow
1796e13 Update build distdocker container wrapper
35ae719 Update build distdocker local workflow
d4d269d Update build submodule devcontainer toolchain
d781ddb Update build submodule for Nuvolaris openwhisk source
d758eab Point build submodule to local openwhisk update
```

Build submodule:

```text
3326ff6 Make build-all local and containerized
f591434 Run distdocker through build container
13ef155 Make distdocker local-only by default
3492964 Make build devcontainer multi-arch OpenWhisk ready
2c53f0f Use Nuvolaris openwhisk submodule source
2fd1cf8 Point openwhisk to Nuvolaris action size change
```

OpenWhisk submodule:

```text
f2cba906 Fix OpenWhisk distDocker dependency resolution
```
