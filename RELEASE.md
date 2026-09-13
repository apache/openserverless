<!--
  ~ Licensed to the Apache Software Foundation (ASF) under one
  ~ or more contributor license agreements.  See the NOTICE file
  ~ distributed with this work for additional information
  ~ regarding copyright ownership.  The ASF licenses this file
  ~ to you under the Apache License, Version 2.0 (the
  ~ "License"); you may not use this file except in compliance
  ~ with the License.  You may obtain a copy of the License at
  ~
  ~   http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~ Unless required by applicable law or agreed to in writing,
  ~ software distributed under the License is distributed on an
  ~ "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
  ~ KIND, either express or implied.  See the License for the
  ~ specific language governing permissions and limitations
  ~ under the License.
-->

# Releasing Apache OpenServerless (Incubating)

This document is the checklist for the **release manager**. It produces a signed
source release candidate, publishes it to the ASF dist *dev* area, and starts the
vote. Everything after a successful vote is in [After a successful vote](#after-a-successful-vote).

If you only want to *verify* a candidate someone else produced, read
[VERIFY.md](VERIFY.md) instead.

## How the repository is laid out

The project is a set of **git submodules** developed in branches; `main` is
updated from development. Everything is wired together with submodules: the
OpenServerless version branch (e.g. `0.9.0`) points at the `0.9.0` branch of
`oplugins`, `oplugins-op`, `streamer`, `admin-api`, `devcontainer`, `runtimes`
and `build`.

So checking out the version branch recursively gives you the exact set of
sources that make up that release.

## Prerequisites

- A GPG key, published in the `KEYS` file (see [step 1](#1-add-your-key-to-keys)).
- `svn`, `git`, `gpg`, `java` 17+, `python3`, `jq`, `wget`,
  and [Task](https://taskfile.dev).
- On macOS: `gtar` (`brew install gnu-tar`) — the `targz` task requires GNU tar,
  and [Lima](https://lima-vm.io/) to run the build/test script.
- On Windows: a recent WSL.
- Docker, and enough disk space to build and save all the images.

## Set the variables

Every command below assumes these are exported in your shell. Set them once and
keep the same shell for the whole procedure.

```bash
# the version branch we want to publish
export VER=0.9.0
# the release candidate suffix (use RC1 for the first attempt)
export RC=-RC5
# your GPG fingerprint
export KEY=E64863824BDA2495CBAA57FDCEBE1A0116BE6665
```

Sanity check that the key is actually available for signing:

```bash
gpg --list-secret-keys $KEY
```

## 1. Add your key to KEYS

The `KEYS` file lives in the **release** area (not the dev area) and is shared by
all releases, so it only needs updating when a new release manager signs.

Check whether your key is already there:

```bash
curl -s https://dist.apache.org/repos/dist/release/incubator/openserverless/KEYS | grep -i $KEY
```

If it is missing, append it and commit:

```bash
svn co https://dist.apache.org/repos/dist/release/incubator/openserverless release-keys
cd release-keys
(gpg --list-sigs $KEY; gpg --armor --export $KEY) >> KEYS
svn commit -m "add GPG key for release manager"
cd ..
```

## 2. Prepare the staging area

Start from your workspace or home directory. The layout matters: the `release`
task checks that the sources sit in a directory named `$VER-incubating$RC`, and
writes the artifacts and the vote email next to it.

```bash
svn co https://dist.apache.org/repos/dist/dev/incubator/openserverless incubator
cd incubator
mkdir ${VER}-incubating${RC}
svn add ${VER}-incubating${RC}
cd ${VER}-incubating${RC}
```

## 3. Check out the sources

Check out the version branch **recursively**, so all submodules come along:

```bash
git clone --branch=$VER https://github.com/apache/openserverless --recurse-submodules
cd openserverless
```

The resulting tree must be exactly `incubator/$VER-incubating$RC/openserverless`.

## 4. Build, tag and sign

```bash
task release RC=$RC VER=$VER KEY=$KEY
```

This tags the tree as `v$VER-incubating$RC`, creates
`apache-openserverless-$VER-incubating-src.tar.gz` (excluding everything listed
in `no-release.txt`), signs it, writes the `.sha512` checksum, and generates the
`[VOTE]` email in `../../$VER-incubating$RC.txt`.

## 5. Verify the candidate yourself

Never send the vote email without running this first — you are the first
verifier. See [VERIFY.md](VERIFY.md) for the full checklist.

```bash
cd ..
sha512sum -c apache-openserverless-$VER-incubating-src.tar.gz.sha512
# expect: OK   (on macOS: shasum -a 512 -c ...)

gpg --verify apache-openserverless-$VER-incubating-src.tar.gz.asc \
             apache-openserverless-$VER-incubating-src.tar.gz
# expect: Good signature

tar xzvf apache-openserverless-$VER-incubating-src.tar.gz
cd apache-openserverless-$VER-incubating

cat LICENSE   # check the license
cat NOTICE    # check the notice (year and project name must be right)

task find-binaries
# expect: no output

task rat-check
# expect: Unapproved: 0     (use `task rat-list` to see the offending files)

./build-and-test-ubuntu.sh
## or ./build-and-test-mac.sh          (needs Lima)
## or .\build-and-test-windows.ps1     (needs WSL)
# expect: all tests passing
```

If anything fails, fix it on the version branch, bump `RC` and start again from
[step 2](#2-prepare-the-staging-area).

## 6. Upload and push the tag

Only once verification passed:

```bash
cd ..
svn add apache-openserverless-$VER-incubating-src.tar.gz*
svn commit -m "Apache OpenServerless $VER-incubating$RC"
git -C openserverless push origin --tags
```

Check that the artifacts are visible at
<https://dist.apache.org/repos/dist/dev/incubator/openserverless/>.

## 7. Send the vote email

The email was generated by the `release` task:

```bash
cat ../$VER-incubating$RC.txt
```

Send it to `dev@openserverless.apache.org`, subject line as in the file. The vote
runs for a minimum of 72 hours.

You can regenerate it — for instance with a longer window or your name as the
signer — with:

```bash
python3 releasing.py $VER-incubating$RC --hours 96 --manager "Your Name"
```

## After a successful vote

The podling vote (`dev@openserverless.apache.org`) needs at least 3 binding +1
from PPMC members and more +1 than -1. Then:

1. Send the `[RESULT][VOTE]` email to `dev@openserverless.apache.org`.
2. Start the IPMC vote on `general@incubator.apache.org`, forwarding the podling
   vote result. It also needs 3 binding +1 (from IPMC members) and runs 72 hours.
3. Send the `[RESULT][VOTE]` email to `general@incubator.apache.org`.
4. Promote the artifacts from the *dev* area to the *release* area, dropping the
   RC suffix:

   ```bash
   svn mv https://dist.apache.org/repos/dist/dev/incubator/openserverless/$VER-incubating$RC \
          https://dist.apache.org/repos/dist/release/incubator/openserverless/$VER-incubating \
          -m "Apache OpenServerless $VER-incubating release"
   ```

5. Tag the final release (without the RC suffix) and push it:

   ```bash
   git -C openserverless tag v$VER-incubating
   git -C openserverless push origin v$VER-incubating
   ```

6. Wait for the mirrors (up to 24h), then send the `[ANNOUNCE]` email — generate
   it by dropping the RC from the version:

   ```bash
   python3 releasing.py $VER-incubating
   ```

   Send it to `announce@apache.org`, `dev@openserverless.apache.org` and
   `general@incubator.apache.org`.

7. Remove older releases from the *release* area (the ASF keeps only the current
   release there; older ones stay in `archive.apache.org`).

## If the vote fails

Cancel it with a `[CANCEL][VOTE]` email explaining why, fix the problem on the
version branch, increment `RC`, and restart from
[step 2](#2-prepare-the-staging-area). Leave the failed candidate in the dev
area or `svn rm` it — it must never be promoted to the release area.
