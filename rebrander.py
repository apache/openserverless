#!/usr/bin/env -S uv run --script
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

# /// script
# requires-python = ">=3.9"
# dependencies = []
# ///
"""Rebrand "nuvolaris" to "openserverless".

Walks all subfolders renaming every folder named with "nuvolaris" in it
(with `git mv`, so the rename is staged rather than looking like a delete
plus an untracked copy), then walks all files replacing:

    nuvolaris -> openserverless
    Nuvolaris -> OpenServerless
    NUVOLARIS -> OPENSERVERLESS

Any *other* casing (nuVolaris, NuVoLaRiS, ...) is NOT rewritten: it is
reported as a warning, in the log and on stderr, for a human to handle.
Pre-existing casings of the new name are accepted without warning when
they are one of the three common forms (openserverless, OpenServerless,
OPENSERVERLESS, plus Openserverless); anything else is warned about,
except the known "OPenServerless" spelling, whose lines are skipped.

A few files are excluded wholesale (.gitmodules anywhere, plus build-step.md
and olaris/prereq.yml, which carry upstream github URLs that must keep
resolving). Lines naming external resources that still exist under the old
name (nuvolaris-testing, registry.hub.docker.com/nuvolaris/, ghcr.io and
github.com repo references, @nuvolaris.io addresses) are left as they are.

Writes rebrander.log listing the folders renamed, every replaced line as
<file>:<line>:<newvalue>, and every line left as is by an exclusion rule
as SKIP:<file>:<line>:<oldvalue>.

By default nothing is modified: the script only reports what it would do.
Pass --do-it-for-real to actually rename folders and rewrite files.

Usage:
    ./rebrander.py [ROOT] [--do-it-for-real]
"""

import argparse
import os
import re
import subprocess
import sys

OLD = "nuvolaris"
NEW = "openserverless"

# The only two casings that get rewritten; everything else is warned about.
REPLACEMENTS = {
    "nuvolaris": "openserverless",
    "Nuvolaris": "OpenServerless",
    "NUVOLARIS": "OPENSERVERLESS",
}

# Casings of the new name accepted as common usage; anything else is warned.
ACCEPTED_NEW = {"openserverless", "OpenServerless", "OPENSERVERLESS",
                "Openserverless"}

LOG_NAME = "rebrander.log"

# Never descend into these; renaming/rewriting them corrupts the checkout.
SKIP_DIRS = {".git", ".hg", ".svn", "node_modules", "__pycache__",
             ".venv", "venv", ".mypy_cache", ".pytest_cache", ".ruff_cache"}

# Excluded files (spec): .gitmodules holds submodule URLs. Matched by base
# name, so nested submodule files are covered too.
SKIP_FILES = {".gitmodules"}

# Excluded files given as a path relative to the root: unlike the above these
# name one specific file, not every file that happens to share the base name
# (there are several prereq.yml in the tree; only olaris/ is excluded).
SKIP_PATHS = {"build-step.md", os.path.join("olaris", "prereq.yml")}

# This script and its own log must not rewrite themselves mid-run.
SELF_FILES = {LOG_NAME, os.path.basename(__file__)}

# Excluded lines (spec). These are left byte-for-byte as they are and logged
# under SKIP. The first three apply to every file; the github repo reference
# is excluded only inside .go files.
ODD_NEW_RE = re.compile(r"OPenServerless")
EMAIL_RE = re.compile(r"@nuvolaris\.io", re.IGNORECASE)
GHCR_RE = re.compile(r"ghcr\.io/nuvolaris/", re.IGNORECASE)
GO_REPO_RE = re.compile(r"github\.com/nuvolaris/", re.IGNORECASE)
# Live external resources registered under the old name: a GCP project /
# cluster and Docker Hub images. Renaming the string does not rename them.
TESTING_RE = re.compile(r"nuvolaris-testing", re.IGNORECASE)
DOCKERHUB_RE = re.compile(r"registry\.hub\.docker\.com/nuvolaris/", re.IGNORECASE)

# Go module files pin the same repo references as the .go sources do.
GO_MODULE_FILES = {"go.mod", "go.sum"}

ANY_FILE_EXCLUDES = (ODD_NEW_RE, TESTING_RE, DOCKERHUB_RE, EMAIL_RE, GHCR_RE)

MAX_BYTES = 20 * 1024 * 1024  # skip anything bigger; not source text

OLD_ANY = re.compile(OLD, re.IGNORECASE)
NEW_ANY = re.compile(NEW, re.IGNORECASE)


def substitute(text: str):
    """Replace the two accepted casings.

    Returns (new_text, [odd casings of OLD left untouched]).
    """
    odd = []

    def repl(m):
        word = m.group(0)
        if word in REPLACEMENTS:
            return REPLACEMENTS[word]
        odd.append(word)   # unknown casing: leave it alone, warn instead
        return word

    return OLD_ANY.sub(repl, text), odd


def odd_new_casings(text: str):
    """Occurrences of the new name in a casing we don't consider canonical."""
    return [m.group(0) for m in NEW_ANY.finditer(text)
            if m.group(0) not in ACCEPTED_NEW]


def line_excluded(path: str, line: str) -> bool:
    """Spec: skip lines carrying "OPenServerless", a nuvolaris-testing or
    registry.hub.docker.com/nuvolaris/ reference, a @nuvolaris.io address or
    a ghcr.io/nuvolaris/ reference, plus github.com/nuvolaris/ inside the go
    sources and the module files that pin them."""
    if any(rx.search(line) for rx in ANY_FILE_EXCLUDES):
        return True
    base = os.path.basename(path)
    if not (path.endswith(".go") or base in GO_MODULE_FILES):
        return False
    return GO_REPO_RE.search(line) is not None


def is_binary(path: str) -> bool:
    try:
        with open(path, "rb") as f:
            chunk = f.read(8000)
    except OSError:
        return True
    return b"\0" in chunk


def prune(dirnames):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]


def git_toplevel(path: str):
    """Repo that tracks `path`, or None if it is not under git control.

    Submodules are separate repositories: a `git mv` has to run inside the one
    that actually tracks the directory, not the outermost checkout.
    """
    try:
        out = subprocess.run(["git", "-C", path, "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return None
    return out.stdout.strip() or None


def git_mv(old_path: str, new_path: str):
    """Move with `git mv` so the rename is staged, not seen as delete+untracked.

    Returns None on success, else a message. This matters because the run also
    rewrites .gitignore rules that name the very directories being renamed: an
    unstaged destination can be swallowed by the rewritten rule and silently
    dropped from the tree.
    """
    repo = git_toplevel(os.path.dirname(old_path))
    if repo is None:
        return "not a git repository"
    try:
        r = subprocess.run(["git", "-C", repo, "mv", old_path, new_path],
                           capture_output=True, text=True)
    except OSError as e:
        return str(e)
    if r.returncode == 0:
        return None
    return (r.stderr or r.stdout).strip() or f"git mv exited {r.returncode}"


def rename_folders(root: str, dry_run: bool, warnings):
    """Rename matching directories with `git mv`, deepest-first.

    Deepest-first keeps every stored path valid: renaming a parent before its
    child would invalidate the child's path.
    """
    renamed = []
    targets = []
    for dirpath, dirnames, _ in os.walk(root):
        prune(dirnames)
        for d in dirnames:
            if OLD_ANY.search(d):
                targets.append(os.path.join(dirpath, d))

    for old_path in sorted(targets, key=lambda p: p.count(os.sep), reverse=True):
        parent, name = os.path.split(old_path)
        new_name, odd = substitute(name)
        rel_old = os.path.relpath(old_path, root)
        for w in odd:
            warnings.append((rel_old, 0, f"folder name has unhandled casing {w!r}"))
        if new_name == name:
            continue
        new_path = os.path.join(parent, new_name)
        if os.path.exists(new_path):
            warnings.append((rel_old, 0, f"rename target already exists: {new_name!r}"))
            continue
        if not dry_run:
            err = git_mv(old_path, new_path)
            if err:
                warnings.append((rel_old, 0, f"git mv failed: {err}"))
                continue
        renamed.append((rel_old, os.path.relpath(new_path, root)))
    return renamed


def rewrite_files(root: str, dry_run: bool, warnings):
    """Replace occurrences inside files; return per-file changed line pairs."""
    changes = []  # (relpath, [(lineno, newvalue), ...])
    skipped = []  # (relpath, [(lineno, oldvalue), ...]) - excluded by a rule
    for dirpath, dirnames, filenames in os.walk(root):
        prune(dirnames)
        for fn in filenames:
            if fn in SELF_FILES or fn in SKIP_FILES:
                continue
            path = os.path.join(dirpath, fn)
            rel = os.path.relpath(path, root)
            if rel in SKIP_PATHS:
                continue
            if os.path.islink(path):
                continue
            try:
                if os.path.getsize(path) > MAX_BYTES:
                    continue
            except OSError:
                continue
            if is_binary(path):
                continue
            try:
                with open(path, "r", encoding="utf-8", newline="") as f:
                    lines = f.readlines()
            except (UnicodeDecodeError, OSError):
                continue

            hits = []
            skips = []
            out = []
            for i, line in enumerate(lines, 1):
                if line_excluded(rel, line):
                    out.append(line)
                    # Only worth reporting if the rule actually held something
                    # back; an excluded line with nothing to replace is noise.
                    if substitute(line)[0] != line:
                        skips.append((i, line.rstrip("\r\n")))
                    continue

                new_line, odd = substitute(line)
                out.append(new_line)

                for w in odd:
                    warnings.append((rel, i, f"unhandled casing {w!r} left as-is"))
                for w in odd_new_casings(line):
                    warnings.append((rel, i, f"non-canonical {NEW!r} casing {w!r}"))

                if new_line != line:
                    hits.append((i, new_line.rstrip("\r\n")))

            if skips:
                skipped.append((rel, skips))
            if not hits:
                continue
            if not dry_run:
                try:
                    with open(path, "w", encoding="utf-8", newline="") as f:
                        f.writelines(out)
                except OSError as e:
                    warnings.append((rel, 0, f"write failed: {e}"))
                    continue
            changes.append((rel, hits))
    return changes, skipped


def write_log(root: str, renamed, changes, skipped, warnings, dry_run: bool):
    log_path = os.path.join(root, LOG_NAME)
    total_lines = sum(len(h) for _, h in changes)
    total_skipped = sum(len(h) for _, h in skipped)
    bar = "=" * 70
    with open(log_path, "w", encoding="utf-8") as log:
        log.write(f"rebrander: {OLD} -> {NEW}\n")
        log.write(f"root: {os.path.abspath(root)}\n")
        if dry_run:
            log.write("mode: DRY RUN - nothing modified "
                      "(pass --do-it-for-real to apply)\n")
        else:
            log.write("mode: APPLIED - changes written to disk\n")
        log.write(f"folders renamed: {len(renamed)}\n")
        log.write(f"files changed:   {len(changes)}\n")
        log.write(f"lines replaced:  {total_lines}\n")
        log.write(f"lines left as is:{total_skipped}\n")
        log.write(f"warnings:        {len(warnings)}\n")

        log.write(f"\n{bar}\nFOLDERS RENAMED\n{bar}\n")
        if renamed:
            for old, new in renamed:
                log.write(f"  {old}\n-> {new}\n")
        else:
            log.write("  (none)\n")

        log.write(f"\n{bar}\nWARNINGS\n{bar}\n")
        if warnings:
            for rel, lineno, msg in sorted(warnings):
                where = f"{rel}:{lineno}" if lineno else rel
                log.write(f"  {where}: {msg}\n")
        else:
            log.write("  (none)\n")

        log.write(f"\n{bar}\nLINES REPLACED\n{bar}\n")
        if changes:
            for relpath, hits in sorted(changes):
                for lineno, after in hits:
                    log.write(f"{relpath}:{lineno}:{after}\n")
        else:
            log.write("  (none)\n")

        log.write(f"\n{bar}\nLINES LEFT AS IS (excluded)\n{bar}\n")
        if skipped:
            for relpath, hits in sorted(skipped):
                for lineno, before in hits:
                    log.write(f"SKIP:{relpath}:{lineno}:{before}\n")
        else:
            log.write("  (none)\n")
    return log_path, total_lines, total_skipped


def main():
    ap = argparse.ArgumentParser(description=f"Rebrand {OLD} -> {NEW}")
    ap.add_argument("root", nargs="?", default=".", help="root folder (default: .)")
    ap.add_argument("--do-it-for-real", action="store_true", dest="for_real",
                    help="actually rename and rewrite; without it nothing is "
                         "modified and only the log is produced")
    args = ap.parse_args()
    dry_run = not args.for_real

    root = os.path.abspath(args.root)
    if not os.path.isdir(root):
        sys.exit(f"not a directory: {root}")

    warnings = []
    # Folders first, so the file walk sees the final paths in the log.
    renamed = rename_folders(root, dry_run, warnings)
    changes, skipped = rewrite_files(root, dry_run, warnings)
    log_path, total_lines, total_skipped = write_log(
        root, renamed, changes, skipped, warnings, dry_run)

    for rel, lineno, msg in sorted(warnings)[:20]:
        where = f"{rel}:{lineno}" if lineno else rel
        print(f"WARN {where}: {msg}", file=sys.stderr)
    if len(warnings) > 20:
        print(f"WARN ... and {len(warnings) - 20} more (see {LOG_NAME})",
              file=sys.stderr)

    print(f"folders renamed: {len(renamed)}")
    print(f"files changed:   {len(changes)}")
    print(f"lines replaced:  {total_lines}")
    print(f"lines left as is:{total_skipped}")
    print(f"warnings:        {len(warnings)}")
    print(f"log: {log_path}")
    if dry_run:
        print("(dry run - nothing was modified; "
              "pass --do-it-for-real to apply)")


if __name__ == "__main__":
    main()
