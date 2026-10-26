#!/usr/bin/env python3
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

r"""Point oplugins/runtimes.json and oplugins/opsroot.json at the latest images.

The remote counterpart of `task sync-opsroot` / `task sync-runtimes`: those
read whatever tags happen to be **local** in the subrepos, and so hit the
gotcha documented in DEVEL.md - a freshly cloned subrepo has no tags and
you silently get a tagless `...openserverless-wsk-controller:` reference.
This reads the tags from the remotes instead, so a clone without tags and
a clone that never fetched give the same, correct answer.

The `<user>` is read from `git remote get-url origin`, which must be
`https://github.com/<user>/openserverless` (or its ssh form
`git@github.com:<user>/openserverless`); the script says where it found
it. The user selects both where to look for the tags and what registry
the images are pulled from. This mirrors the publication rule of DEVEL.md
("Where the images go"): a tag pushed to the Apache repository builds to
`docker.io/apache`, a tag pushed to any fork builds to `ghcr.io/<the fork
owner>`. So a contributor working in a clone of their fork syncs their own
published builds just with

    ./syncimages.py

Tags are read with `git ls-remote` - nothing is cloned, and no credentials
are needed for public repos.

**Nothing is written without asking.** The run lists every change it
found, as `old -> new`, and then asks for confirmation before rewriting
the files. This is deliberate: the tags come from whatever has been
published at this moment, so you want to see what you are about to pin
before you pin it. When stdin is not a terminal there is nobody to ask,
so nothing is written.

A repo that cannot be read, or that carries no publication tag, is
**warned about and skipped**, not fatal - a fork usually has only some of
the components, and the useful answer is the tags of the ones it does
have. Those images keep whatever they already reference, every warning is
repeated in a summary at the end, and the exit status is non-zero so a
script chaining this notices that the sync was partial.

# The tag format

Per DEVEL.md ("The tag format"), every component tags a publication build
with a timestamp in a compacted, sortable form:

    0.9.0-incubating.26i07r51-snapshot
    └────┬─────────┘ ││││││└┬┘└───┬───┘
       BASETAG       ││││││ │     └───── SUFFIX: -snapshot marks a non-release build
                     ││││││ └─────────── minute
                     │││││└───────────── hour,  a letter: a=00 … x=23
                     │││└┴────────────── day of month
                     ││└──────────────── month, a letter: a=January … l=December
                     └┴───────────────── year, two digits

so `26i07r51` is 2026, September (`i`, 9th letter), day 07, hour 17 (`r`,
18th letter, zero-based), minute 51.

DEVEL.md notes the encoding is lexicographically sortable, which is what
makes `--sort=-creatordate` and "the newest tag" agree. We do not rely on
that: `ls-remote` gives no dates to sort by, and the repos still carry
older tags in a plain-decimal `YYMMDDHHMM` form that does *not* sort
against the letter form. So the timestamp is decoded into its real date
before comparing, both forms are understood, and a tag that decodes as
neither is skipped rather than guessed at.

# runtimes.json

The runtimes are the exception DEVEL.md calls out: their tag carries a
prefix naming the family to build, which CI parses to decide what work to
do. They are built and published together under a single `all_<timestamp>`
tag, so one tag drives every entry. Each `image` subsection becomes

    {
        "prefix": "<registry>/<user>",
        "name": "openserverless-runtime-java",
        "tag": "<version>-<timestamp>"
    }

keeping the existing `<version>-` prefix of the tag - that is the language
version (`v1.27-`, `sys-`), it names what is inside the image and is not
ours to change.

# opsroot.json

Each image under `config.images` that we build ourselves is named by the
whole tag of its own repo - `BASETAG.<timestamp><SUFFIX>`, exactly the
string the component was tagged with, which is what `task sync-opsroot`
writes and what makes an image traceable back to its tag:

    <origin>-operator        -> operator
    <origin>-admin-api       -> systemapi
    <origin>-build           -> controller, invoker
    <origin>-streamer        -> streamer
    <origin>-devcontainer    -> devcontainer

Only the `:<tag>` part of the value is replaced, so third-party images
(couchdb, redis, ingress, ...) keep their own registry and tag - those are
not ours to retag.

Every image that changes is printed, one per line, as `old -> new`.

The top-level `version` field is synced too, from the latest **GitHub
release** of the `...-cli` repo - not its latest tag. A cli tag is only a
request to build one; the release is what carries the binaries users
install, and a tag whose build failed or was never published has none.
Drafts are ignored. The cli is tagged `v<version>`, and the version it names
is exactly what this field holds - the leading `v` is the tag's, not the
version's, so it is dropped:

    v0.9.0-incubating+26i13l12-snapshot -> 0.9.0-incubating+26i13l12-snapshot

Note the separator: the cli spells its timestamp after a `+`, where the
image repos use a `.`.
"""

import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

# month, a=January ... l=December - and hour, a=00 ... x=23
MONTHS = "abcdefghijkl"
HOURS = "abcdefghijklmnopqrstuvwx"

# 26i07r51, the form documented in DEVEL.md
LETTER_TS_RE = re.compile(
    r"^(?P<yy>\d\d)(?P<month>[a-l])(?P<dd>\d\d)(?P<hour>[a-x])(?P<mm>\d\d)$"
)
# 2409121919, the plain-decimal form of the older tags
DIGIT_TS_RE = re.compile(r"^(?P<yy>\d\d)(?P<month>\d\d)(?P<dd>\d\d)(?P<hour>\d\d)(?P<mm>\d\d)$")

# everything skipped, to be summarised at the end: a warning scrolled past
# half an hour ago is a warning nobody acts on
WARNINGS = []

# every change found, as (path, what, old, new), shown before asking
CHANGES = []

# the origin forms we understand, both naming the same github repo
ORIGIN_RES = [
    re.compile(r"^https://github\.com/(?P<user>[^/]+)/openserverless(\.git)?/?$"),
    re.compile(r"^git@github\.com:(?P<user>[^/]+)/openserverless(\.git)?$"),
]

# the repos we build ourselves, and the opsroot.json keys they feed
OPSROOT_REPOS = [
    ("operator", ["operator"]),
    ("admin-api", ["systemapi"]),
    ("build", ["controller", "invoker"]),
    ("streamer", ["streamer"]),
    ("devcontainer", ["devcontainer"]),
]


def change(path, what, old, new):
    """Record a change, to be shown before asking whether to write it."""
    if old != new:
        CHANGES.append((path, what, old, new))


def origin_user():
    """The github user of `origin`, and the url it was read from.

    Read from the clone this script lives in, not the current directory,
    so that running it from elsewhere still syncs this checkout.
    """
    try:
        url = subprocess.run(
            ["git", "remote", "get-url", "origin"],
            cwd=os.path.dirname(os.path.abspath(__file__)),
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except FileNotFoundError:
        raise SystemExit("git not found in PATH: it is needed to read the origin")
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr.strip().splitlines() or ["?"])[-1]
        raise SystemExit(f"cannot read git remote origin: {detail}")

    for regex in ORIGIN_RES:
        match = regex.match(url)
        if match:
            return match.group("user"), url
    raise SystemExit(
        f"git remote origin is {url}, not https://github.com/<user>/openserverless: "
        "cannot tell whose images to sync"
    )


def confirm(question):
    """Ask a yes/no question; anything but yes, or no terminal, is no."""
    if not sys.stdin.isatty():
        print("not a terminal, nobody to ask: nothing written", file=sys.stderr)
        return False
    try:
        answer = input(f"{question} [y/N] ")
    except EOFError:
        return False
    return answer.strip().lower() in ("y", "yes")


def warn(message):
    """Report something we are skipping, on stderr so stdout stays pipeable."""
    print(f"warning: {message}", file=sys.stderr)
    WARNINGS.append(message)


def decode_timestamp(stamp):
    """Return the date a build timestamp encodes, or None if it is not one.

    The result is a tuple, to be compared rather than read: it is the real
    (year, month, day, hour, minute) of the build, so tags in the letter
    form and in the older decimal form order correctly against each other.

    The SUFFIX (`-snapshot`, `-RC`, ...) is not part of the timestamp but
    does distinguish two tags of the same minute, so it is kept as the
    last element to make the order total rather than arbitrary.
    """
    base, _, suffix = stamp.partition("-")

    match = LETTER_TS_RE.match(base)
    if match:
        month = MONTHS.index(match.group("month")) + 1
        hour = HOURS.index(match.group("hour"))
    else:
        match = DIGIT_TS_RE.match(base)
        if not match:
            return None
        month = int(match.group("month"))
        hour = int(match.group("hour"))

    return (
        int(match.group("yy")),
        month,
        int(match.group("dd")),
        hour,
        int(match.group("mm")),
        suffix,
    )


def remote_tags(origin):
    """The tag names of a remote repo, or None if it cannot be read.

    A repo we cannot reach is reported and skipped rather than fatal: a
    fork typically has only some of the components, and the useful answer
    is the tags of the ones it does have, not nothing at all.
    """
    try:
        out = subprocess.run(
            ["git", "ls-remote", "--tags", origin],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
    except FileNotFoundError:
        raise SystemExit("git not found in PATH: it is needed to read the remote tags")
    except subprocess.CalledProcessError as exc:
        # git is chatty on failure and the last line is the useful one
        detail = (exc.stderr.strip().splitlines() or ["?"])[-1]
        warn(f"cannot list the tags of {origin}: {detail}")
        return None

    tags = set()
    for line in out.splitlines():
        _, _, ref = line.partition("\t")
        if ref.startswith("refs/tags/"):
            # annotated tags are listed twice, the second as <tag>^{}
            tags.add(ref[len("refs/tags/"):].removesuffix("^{}"))
    return tags


def remote_releases(origin):
    """The tag names of the published GitHub releases of a repo, or None.

    Read from the GitHub API, which needs no credentials for a public repo;
    GITHUB_TOKEN is used when set, only to lift the anonymous rate limit.
    Drafts are skipped: they are not published, and anonymously are not
    even listed.
    """
    repo = origin.removeprefix("https://github.com/")
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/releases?per_page=100",
        headers={"Accept": "application/vnd.github+json"},
    )
    if os.environ.get("GITHUB_TOKEN"):
        request.add_header("Authorization", f"Bearer {os.environ['GITHUB_TOKEN']}")
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            releases = json.load(response)
    except (urllib.error.URLError, ValueError) as exc:
        warn(f"cannot list the releases of {origin}: {exc}")
        return None

    return {release["tag_name"] for release in releases if not release.get("draft")}


def latest_tag(origin, timestamp_of, list_tags=remote_tags):
    """The most recent publication tag of `origin`, and its timestamp.

    `timestamp_of` locates the timestamp inside a tag name, and returns
    None for the tags that are not publication tags at all - the runtimes
    repo also carries `common1.18.4`, `experimental-...` and friends.

    Returns the tag whose timestamp is the latest, paired with that
    timestamp: opsroot.json wants the whole tag, runtimes.json rebuilds
    its own tags around the timestamp. Returns None, after warning, when
    the repo cannot be read or carries no publication tag - the image
    then keeps whatever it already references.

    `list_tags` is where the tag names come from: the git tags by default,
    or `remote_releases` for the tags that were actually released.
    """
    tags = list_tags(origin)
    if tags is None:
        return None

    candidates = {}
    for tag in tags:
        stamp = timestamp_of(tag)
        if stamp and decode_timestamp(stamp):
            candidates[tag] = stamp

    if not candidates:
        warn(
            f"no publication tag found in {origin}"
            + (f" (it has {len(tags)} tag(s), none timestamped)" if tags else " (it has no tags)")
        )
        return None

    tag = max(candidates, key=lambda tag: decode_timestamp(candidates[tag]))
    return tag, candidates[tag]


def sync_runtimes(path, prefix, timestamp):
    """Retag every runtime image in runtimes.json, keeping its version prefix.

    Returns the updated json, or None when there is nothing to sync to.
    """
    if timestamp is None:
        warn(f"{path} left alone: no runtimes tag to sync to")
        return None

    with open(path) as file:
        runtimes = json.load(file)

    for kinds in runtimes["runtimes"].values():
        for kind in kinds:
            image = kind["image"]
            # the tag is <language version>-<timestamp>: keep the version
            version, sep, _ = image["tag"].partition("-")
            if not sep:
                warn(
                    f"{path}: the tag of {image['name']} ({image['tag']}) has no "
                    "<version>- prefix to keep, leaving it alone"
                )
                continue
            old = f"{image['prefix']}/{image['name']}:{image['tag']}"
            image["prefix"] = prefix
            image["tag"] = f"{version}-{timestamp}"
            change(path, image["name"], old, f"{prefix}/{image['name']}:{image['tag']}")

    return runtimes


def sync_opsroot(path, prefix, tags, version):
    """Repoint, in opsroot.json, each image we build ourselves, and the version.

    Both halves of an image move: the tag, and the `<registry>/<user>` it
    is pulled from. A fork publishes to its own registry, so pinning its
    tag onto `docker.io/apache` would name an image that does not exist.
    Third-party images (couchdb, redis, ...) are not in OPSROOT_REPOS and
    so keep both their registry and their tag.

    `version` is the cli release this opsroot goes with; None (the cli
    repo unreadable or untagged) leaves the field as it is.

    Returns the updated json.
    """
    with open(path) as file:
        opsroot = json.load(file)

    if version is None:
        warn(f"{path}: version left at {opsroot.get('version', '?')}")
    else:
        change(path, "version", opsroot.get("version"), version)
        opsroot["version"] = version

    images = opsroot["config"]["images"]
    for repo, keys in OPSROOT_REPOS:
        tag = tags[repo]
        for key in keys:
            if tag is None:
                # the warning naming the repo has already been issued
                warn(f"{path}: config.images.{key} left at {images.get(key, '?')}")
                continue
            if key not in images:
                warn(f"{path}: no config.images.{key} to update, skipping")
                continue
            image, sep, _ = images[key].rpartition(":")
            if not sep:
                warn(
                    f"{path}: config.images.{key} ({images[key]}) has no :<tag> "
                    "to replace, leaving it alone"
                )
                continue
            new = f"{prefix}/{image.rpartition('/')[2]}:{tag}"
            change(path, f"config.images.{key}", images[key], new)
            images[key] = new

    return opsroot


def write_json(path, data):
    """Rewrite a json file in place, preserving its indentation."""
    with open(path) as file:
        # the two files do not agree on the indent, and reindenting one of
        # them would bury the retag in a diff nobody can review
        indent = 4 if file.read().startswith("{\n    ") else 2

    with open(path, "w") as file:
        json.dump(data, file, indent=indent)
        file.write("\n")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description=__doc__.splitlines()[0],
        epilog="The github user is read from git remote origin. The changes found "
        "are listed, and written only after you confirm.",
    )
    parser.add_argument(
        "--runtimes-json",
        default="oplugins/runtimes.json",
        help="path to runtimes.json (default: %(default)s)",
    )
    parser.add_argument(
        "--opsroot-json",
        default="oplugins/opsroot.json",
        help="path to opsroot.json (default: %(default)s)",
    )
    args = parser.parse_args(argv)

    user, url = origin_user()
    registry = "docker.io" if user == "apache" else "ghcr.io"
    origin = f"https://github.com/{user}/openserverless"
    prefix = f"{registry}/{user}"
    print(f"user {user}: from git remote origin {url}")
    print(f"images from {prefix}, tags from {origin}-*\n")

    # every tag is resolved before anything is written, so that a repo we
    # cannot reach cannot leave the files half synced
    #
    # the runtimes tag is the family prefix plus the timestamp, and only
    # the timestamp is reused - each entry rebuilds its own tag around it
    runtimes = latest_tag(
        f"{origin}-runtimes",
        lambda tag: tag[len("all_"):] if tag.startswith("all_") else None,
    )
    # the cli is tagged `v<version>`, with the timestamp after a `+`, and
    # the version it names is the whole tag without that leading `v`; only
    # released tags count, a tag alone may never have produced a cli
    cli = latest_tag(
        f"{origin}-cli",
        lambda tag: (tag.rpartition("+")[2] or None) if tag.startswith("v") else None,
        list_tags=remote_releases,
    )
    version = cli[0][1:] if cli else None
    # the others are tagged BASETAG.<timestamp><SUFFIX>, and the whole tag
    # is what names the image
    tags = {}
    for repo, _ in OPSROOT_REPOS:
        found = latest_tag(
            f"{origin}-{repo}", lambda tag: tag.rpartition(".")[2] or None
        )
        tags[repo] = found[0] if found else None

    updated = {
        args.runtimes_json: sync_runtimes(
            args.runtimes_json, prefix, runtimes[1] if runtimes else None
        ),
        args.opsroot_json: sync_opsroot(args.opsroot_json, prefix, tags, version),
    }

    for path, what, old, new in CHANGES:
        print(f"{path}: {what}\n    {old}\n -> {new}")

    # stdout is block-buffered when piped, so without this the stderr
    # summary below would appear *before* the lines it summarises
    sys.stdout.flush()

    if WARNINGS:
        print(
            f"\n{len(WARNINGS)} warning(s), the changes above are all that could be "
            "resolved:",
            file=sys.stderr,
        )
        for message in WARNINGS:
            print(f"  - {message}", file=sys.stderr)

    if not CHANGES:
        print("\nalready up to date: nothing to write")
    else:
        paths = sorted({path for path, *_ in CHANGES})
        print()
        if confirm(f"Write {len(CHANGES)} change(s) to {', '.join(paths)}?"):
            for path in paths:
                write_json(path, updated[path])
            print(f"written: {', '.join(paths)}")
        else:
            print("nothing written")

    # something unresolved is a real failure even though we carried on, so
    # a caller chaining this in a script notices
    return 1 if WARNINGS else 0


if __name__ == "__main__":
    sys.exit(main())
