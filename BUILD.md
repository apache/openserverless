# BUILD.md — Specification

> **Status: specification only.** This document describes what the build
> documentation must explain and how the build system is supposed to behave.
> It is not an implementation guide, and nothing here is to be implemented
> as part of writing this document.
>
> **The Taskfiles are expected to change to match this spec.** Where the current
> `Taskfile.yml` of a component disagrees with the contract described here, the
> spec is the target and the Taskfile is what gets updated — not the other way
> round. Section 9 lists the known divergences.

---

## 1. Summary

OpenServerless is not one build. It is a set of independently versioned
components, each living in its own submodule, each with its own `Taskfile.yml`
and its own GitHub Actions workflow. The final documentation must make the
reader understand three things, in this order:

1. **The common rules** — how tags drive every build, what a tag looks like,
   what `task tag` / `task build` / `task ci` mean, and where images are pushed.
2. **The three build cases** — which one applies to the component being worked on.
3. **The three usage scenarios** — building locally, building from a personal
   fork, and consuming what the fork produced.

### The three build cases

| Case | Components | Distinguishing feature |
|---|---|---|
| **A — single image** | `operator` (olaris-op), `admin-api`, `streamer`, `devcontainer` | One tag → one image |
| **B — multiple images** | `runtimes` | One tag → a whole family of images, tag selects which family |
| **C — binary** | `cli` (`ops`) | No image; produces release binaries |

### The three usage scenarios

| Scenario | What the reader wants | Where artifacts land |
|---|---|---|
| **Local** | Build on my machine, run it against my cluster | Local Docker daemon / kind, nothing pushed |
| **Fork** | Build my own version in CI from my fork | My registry namespace |
| **Consume** | Point an OpenServerless install at what I built | `opsroot.json` / `runtimes.json` overrides |

### The one rule that governs everything

**All CI builds are triggered by pushing a git tag.** No branch push builds an
image. Every component workflow is configured as `on: push: tags:` with
`branches-ignore: '*'`. The tag is not metadata attached to a build — the tag
*is* the build trigger, and its text *is* the image tag.

---

## 2. Common rules

These apply to every component and must be stated once, up front, in the final
documentation. The per-case sections must then only describe deviations.

### 2.1 The three tasks

Every component exposes the same conceptual trio. The documentation must
present them as a progression, because the reader will use them in this order:

| Task | Runs where | Effect | Pushes? |
|---|---|---|---|
| `task tag` | local | Creates (and force-replaces) the git tag that names this build | no |
| `task build` | local | Builds using the current tag, loads into the local Docker daemon | no |
| `task ci` | local, triggers remote | Pushes the tag, which starts the GitHub Actions build | yes, via CI |

Two points the documentation must make explicitly, because they are the two
things newcomers get wrong:

- `task tag` **deletes existing local tags** before creating the new one. This
  is deliberate — snapshot tags are disposable — but it must be flagged, not
  discovered.
- `task ci` does not itself build anything. It pushes a tag. The build happens
  in GitHub Actions on the repository that received the tag. This is why forking
  matters: the tag lands in *your* fork, so *your* Actions run, using *your*
  secrets, pushing to *your* registry.

These three names are a **contract**: every component must expose `tag`,
`build`, and `ci` with exactly these semantics, regardless of what it builds.
Components that currently use different names or a different split must be
aligned to it (see section 9).

A manual trigger path also exists: the workflow can be started from the GitHub
Actions UI, in which case it creates the tag itself. The documentation must
mention this as the alternative for people who cannot or do not want to push
tags from the command line.

### 2.2 Tag format

Tags are timestamps in a compacted, sortable form. The documentation must
explain the encoding, because the tags are otherwise unreadable:

```
26i4k36-SNAPSHOT
││││││└─ minutes
│││││└── hour,  encoded as a letter: a=00 … x=23
││││└─── day of month
││└───── month, encoded as a letter: a=January … l=December
└─────── year (two digits)
```

So `26i4k36` is 2026, September (`i` = 9th letter), day 4, hour 10 (`k` = 11th
letter, zero-based → 10), minute 36.

The `-SNAPSHOT` suffix marks a non-release build. The documentation must state
what its presence and absence mean for consumers.

Case B (runtimes) prefixes the timestamp with the runtime family:

```
<runtime>_26i4k36-SNAPSHOT
```

for example `python_26i4k36-SNAPSHOT` or `nodejs_26i4k36-SNAPSHOT`. The prefix
is not cosmetic: CI parses it to decide which subset of images to build. This
must be stated as a rule, not shown as an example.

Components carry their own base version prefix where applicable (e.g. the CLI
produces `v0.9.0-<timestamp>.SNAPSHOT`). The documentation must show one real
tag per case rather than describing the format abstractly.

### 2.3 Where images go — no configuration required

The destination registry and the credentials used to push are **derived
automatically from the repository the tag was pushed to**. Nothing has to be
configured for the normal case, and the documentation must lead with that fact
rather than with a configuration table.

The rule:

| Tag pushed to | Registry | Namespace | Credentials |
|---|---|---|---|
| the Apache repository | `docker.io` | `apache` | secrets `DOCKERHUB_USER` / `DOCKERHUB_TOKEN` |
| any fork | `ghcr.io` | the fork owner's GitHub user | the current GitHub actor + the built-in `GITHUB_TOKEN` |

So a contributor who forks and pushes a tag gets images at
`ghcr.io/<their-user>/…` with **no secrets to create and no `.env` to write** —
the workflow authenticates as the user running it, using the token GitHub
provides to every Actions run. This must be stated as the default path, not as a
fallback.

### 2.4 Overriding the registry (optional)

An explicit registry can be selected by setting `DOCKERHUB_REGISTRY` together
with the secrets `DOCKERHUB_USER` and `DOCKERHUB_TOKEN`. The documentation must
present this as an override for people who want their images somewhere other
than their own GHCR namespace — **not** as a required setup step.

### 2.5 Local builds — defaults and `MY_*_IMAGE` overrides

Everything above describes CI. When building **locally**, no registry is
involved by default: each component builds its image under the same default name
it would use in CI (section 2.3), and the result exists only in the local Docker
daemon.

That default can be overridden per component by exporting a `MY_<COMPONENT>_IMAGE`
environment variable, normally set in a local `.env` file. The variable holds the
**full image name without the tag** — registry, namespace and repository — and
the tag continues to be computed as described in section 2.2.

The variables, one per single-image component:

| Component | Variable | Example value |
|---|---|---|
| operator | `MY_OPERATOR_IMAGE` | `ghcr.io/<your-user>/openserverless-operator` |
| devcontainer | `MY_DEVCONTAINER_IMAGE` | `ghcr.io/<your-user>/openserverless-devcontainer` |
| admin-api | `MY_ADMINAPI_IMAGE` | `ghcr.io/<your-user>/openserverless-admin-api` |
| streamer | `MY_STREAMER_IMAGE` | `ghcr.io/<your-user>/openserverless-streamer` |

Each component repository must ship a `.env.dist` listing these variables with
their intended default form, so that copying it to `.env` and filling in the
GitHub user is the whole of the setup. `.env` itself is local and must stay
untracked.

The documentation must present this as the **local** counterpart of section 2.3:
the automatic rule still decides the default, and `MY_*_IMAGE` only replaces it
when someone wants their local build named for their own registry.

### 2.6 The exception: repositories publishing multiple images

Two repositories publish images that do **not** correspond to the repository
itself:

| repository | images published |
|---|---|
| `openserverless-build` | `openwhisk2/controller`, `openwhisk2/invoker`, `openwhisk2/scheduler`, `openwhisk2/standalone`, `openwhisk2/scala` |
| `openserverless-runtimes` | `openserverless-runtime-<rt>` — one per language version |

This is the single place where the automatic path of section 2.3 is not
sufficient, and the documentation must call it out explicitly rather than
leaving it to be discovered from a failed build.

The built-in `GITHUB_TOKEN` is scoped to packages **owned by the repository
running the workflow**. GHCR links a package to its creating repository on first
push and grants write access only to that repository. Because these two builds
publish under image names that do not match the repository, `GITHUB_TOKEN`
carries no permission for them and the push is refused.

Therefore, for `openserverless-build` and `openserverless-runtimes` only, when
pushing to **ghcr.io**:

- a **`GHCR_TOKEN`** secret **must** be set on the fork, and
- it must be a GitHub Personal Access Token (classic) with the
  **`write:packages`** scope — write permission on the target images, not merely
  on the packages of the current repository.

To create it:

1. Go to <https://github.com/settings/tokens> → *Generate new token (classic)*.
2. Select the **`write:packages`** scope (this implies `read:packages` and
   `repo`).
3. Copy the generated token.
4. In your fork: *Settings → Secrets and variables → Actions → New repository
   secret*, name it exactly **`GHCR_TOKEN`**, and paste the value.

When pushing to Docker Hub instead, the equivalent requirement is a
`DOCKERHUB_TOKEN` with write permission on the target images.

The documentation must state the symptom this produces when skipped — a
`denied: permission_denied: write_package` error at push time, after a long and
otherwise successful build — so the cause is recognisable from the error alone.
The workflows fail fast with these instructions when the secret is missing,
rather than building first and failing at the push.

---

## 3. Case A — single image

Applies to: `operator` (`olaris-op`), `admin-api`, `streamer`, `devcontainer`.

One tag produces one image. This is the simplest case and should be documented
first, in full, so the later cases can be described as deltas.

The documentation must cover:

- **Prerequisites** — Docker with buildx, Task, and (for CI) a fork.
- **Local flow** — `task tag`, then `task build`. State that the resulting image
  is tagged with the timestamp and exists only in the local Docker daemon.
- **CI flow** — `task ci` pushes the tag; the `image` workflow builds multi-arch
  (`linux/amd64`, `linux/arm64`) and pushes.
- **Fork setup** — nothing to do. Per section 2.3 the images go to
  `ghcr.io/<your-user>/…` automatically, authenticated with the built-in
  `GITHUB_TOKEN`. Mention the `DOCKERHUB_REGISTRY` override only as an aside.
- **What CI does beyond building** — license check (skywalking-eyes) and unit
  tests run before the image is built. A build can fail for reasons unrelated to
  the image; the documentation must say so, so failures are not mysterious.
- **Verification** — how to confirm the image exists, locally and in the registry.

---

## 4. Case B — multiple images (runtimes)

Applies to: `runtimes`.

Structurally the same as Case A, but with three differences that the
documentation must call out as the *entire* reason this case is separate:

1. **The tag selects the work.** `task tag RT=<runtime>` requires the runtime
   family. CI parses the tag prefix and builds only the matching family —
   `python_…` builds the Python runtimes, `common-…` builds the shared base
   image. The documentation must list the recognized prefixes and state what
   happens when a tag matches none of them.

2. **One tag, many images.** A single build produces one image per language
   version in the family (e.g. several Python versions). The documentation must
   show the resulting image naming scheme:

   ```
   <registry>/<namespace>/openserverless-runtime-<rt>:<ver>-<tag>
   ```

3. **A token must be supplied.** This is the one case where the automatic
   credentials of section 2.3 are not enough: the images published are not the
   current repository's own packages, so the built-in `GITHUB_TOKEN` lacks the
   permission. Per section 2.6 a **`GHCR_TOKEN`** secret with the
   `write:packages` scope must be set in the fork (Settings → Secrets and
   variables → Actions) when pushing to ghcr.io, or a `DOCKERHUB_TOKEN` with
   write access to the target images when pushing to Docker Hub — optionally
   alongside `DOCKERHUB_REGISTRY` and `DOCKERHUB_USER` to change the
   destination. The documentation must present this as *the* prerequisite for
   Case B, and note that `openserverless-build` carries the same requirement for
   the same reason.

The documentation must also explain the relationship between the **common base
image** and the language runtimes: the base is built and tagged separately, and
language runtimes depend on it. Building a language family without a matching
base is a documented failure mode, not a bug to be discovered.

Finally, this section must explain how the built runtimes are made visible to an
installation — the generated `runtimes.json` / `runtimes.env` and how they are
consumed.

---

## 5. Case C — binary (cli)

Applies to: `cli`, which produces the `ops` binary.

No Docker image is involved. The documentation must cover:

- **Local flow** — `task build` compiles `ops` into the repository root. Note
  that `task build` alone is enough for local use; tagging is only needed when
  the embedded version string matters.
- **Tagging** — `task tag` writes `version.txt` and `branch.txt`, commits them,
  and creates the tag. The documentation must state that this **creates a
  commit**, which is a meaningful difference from the other cases.
- **CI flow** — `task trigger` (the CLI's equivalent of `task ci`) refuses to run
  with a dirty working tree, then tags and pushes. The release workflow builds
  and publishes binaries for all supported platforms.
- **Installation** — how to put the built `ops` on the `PATH`, and how to verify
  which version is running.

---

## 6. The Apache image

The documentation must include a dedicated section on building the Apache
OpenWhisk-derived images (controller, invoker, scheduler, standalone, scala
base), because it does not follow the pattern of the three cases above.

It must explain:

- **Why it is different** — it lives in the `build` submodule, has its own
  Taskfile, vendors an OpenWhisk source tree, and builds through a dedicated
  devcontainer rather than on the host.
- **The toolchain constraint** — the OpenWhisk Gradle build requires Java 11;
  building on a host with a newer JDK fails with `Unsupported class file major
  version`. The build therefore runs inside `ops ide devcontainer`. This must be
  stated as a rule with its symptom, so the error is self-diagnosing.
- **The local flow** — `task build` in the `build` directory, and what it does
  end to end: build images, update `opsroot.json`, load images into kind, roll
  out the controller.
- **The two-build-systems caveat** — the root `Taskfile.yml` and
  `build/Taskfile.yml` are separate. The root one builds CLI, operator,
  runtimes, streamer, admin-api and updates only `operator`, `streamer`,
  `systemapi` in `opsroot.json`. It does **not** build or update the OpenWhisk
  images. The documentation must state this explicitly; it is the single most
  common wrong assumption.
- **Verification** — how to confirm the running pod uses the freshly built
  image, not a cached upstream one.

---

## 7. Consuming your own build

A section the reader reaches after a successful build, answering: *I built it —
now how do I actually run it?*

It must cover:

- Overriding component images in `~/.ops/<version>/olaris/opsroot.json`.
- Overriding runtimes via the generated runtimes configuration.
- Loading locally built images into kind (they are not automatically visible to
  the cluster — this must be stated, with the symptom: the pod pulls the old
  upstream image instead).
- Confirming the override took effect at the pod level, not just in the custom
  resource. A change visible in the CR but not in the resulting workload is a
  known failure mode and must be documented as such.

---

## 8. Requirements for the final document

- **Summary first.** The common rules and the two 3×3 tables come before any
  component-specific instruction.
- **Cases are separated.** No section may mix Case A, B, and C instructions.
  Cases B and C are written as deltas from A, not as full restatements.
- **Every command is shown in context** — which directory it runs in, and what
  it produces.
- **Every failure mode listed above appears with its symptom**, so the reader
  can match an error message to a cause.
- **Scenario-oriented, not task-oriented.** The reader arrives with a goal
  ("build my own runtime image and test it"), not with a task name.

---

## 9. Taskfile alignment

The contract in section 2 is the target state. The Taskfiles do not all
implement it today, and updating them is in scope for the work this spec
governs. The known divergences:

| Component | Divergence | Required change |
|---|---|---|
| `cli` | The CI trigger is called `trigger`, not `ci` | Expose `ci` (keeping `trigger` as an alias if desired) |
| `streamer` | The tagging task is called `image-tag`, not `tag` | Expose `tag` |
| `streamer`, `admin-api` | `ci` is absent — the tag is pushed by hand | Add `ci`: create the tag and push it |
| `runtimes` | The CI entry point is `ci-build`, not `ci`; `tag` prints the new tag but does not create it | Expose `ci`; make `tag` actually create the tag |
| `runtimes` | `ci-build` calls `build-lang` without `task`, so the language path is broken | Fix the invocation |
| `admin-api` | Tag suffix is `-SNAPSHOT`; `streamer` has no suffix | Make the suffix consistent across single-image components |
| all single-image | Tag timestamp is `date +%y%m%d%H%M`, not the letter-encoded form of section 2.2 | Adopt one encoding everywhere, and document which |

Two decisions must be made explicitly before the Taskfiles are touched, because
the documentation cannot be written without them:

1. **One tag encoding or two.** Either every component uses the letter-encoded
   timestamp, or the plain numeric one. The current mix must not be documented
   as if it were intentional.
2. **Convergence on the automatic registry rule.** Section 2.3 is the target:
   registry, namespace, and credentials derived from the repository owner, with
   no configuration in the normal case. The single-image Taskfiles currently
   require `REGISTRY` and `NAMESPACE` in a local `.env` and fail without them;
   they must be changed to fall back to the automatic behaviour and treat
   `DOCKERHUB_REGISTRY` / `DOCKERHUB_USER` / `DOCKERHUB_TOKEN` as an override.
   The runtimes exception (2.6) stays.

Until these are settled, the documentation must not describe the current
behaviour as stable.
