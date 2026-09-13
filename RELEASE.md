RELEASE.md


We use git submodules, and develop in branches.
The `main` is updated from the developemnt

Everything is connected with submodules.
For example the oepnserverless branch (0.9.0) connects to the submodules
oplugins, oplugins-op, streamer, admin-api, devcontainer with branch 0.9.0

# set vars

# the branch we want to export
export VER=0.9.0
# the RC
export RC=-RC5
# your GPG Fingerprint
KEY=E64863824BDA2495CBAA57FDCEBE1A0116BE6665

# 1. Add your key to KEYS

The `KEYS` file lives in the *release* area (not the dev area), and it is shared
by all releases, so it only needs updating when a new release manager signs.
Check whether your key is already there:

```
curl -s https://dist.apache.org/repos/dist/release/incubator/openserverless/KEYS | grep -i $KEY
```

If it is missing, append it and commit:

```
svn co https://dist.apache.org/repos/dist/release/incubator/openserverless release-keys
cd release-keys
(gpg --list-sigs $KEY; gpg --armor --export $KEY) >> KEYS
svn commit -m "add GPG key for release manager"
cd ..
```

# 2. Prepare the stage area

Start from your workspace or home

```
svn co https://dist.apache.org/repos/dist/dev/incubator/openserverless incubator
cd incubator
mkdir ${BRANCH}-incubating${RC}
svn add ${BRANCH}-incubating${RC}
cd ${BRANCH}-incubating${RC}
```

# 3. Checkout Sources

Select the branch you want to release (for example, 0.9.0) and checkout recursively, then cd in it

```
git clone --branch=$BRANCH https://github.com/apache/openserverless --recurse-submodules
cd openserverless
```

# 4. Build and tag the task

```
task release RC=$RC VER=$VER KEY=$KEY
```

# 5. Proceed to a verify

```
cd ..
tar xzvf apache-openserverless-$VER-src.tar.gz



