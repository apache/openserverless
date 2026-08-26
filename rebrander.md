Write a rebrander.py python script with uv embedded deps.

The goal is rebrand openserverless in openserverless

It walks all the subfolders renaming with `git mv` all the folder openserverless in openserverless

Then it will rename with `git mv` the files including "openserverless" in the name with the name including "openserverless"

This file rename is mandatory, not optional: file names written inside other
files are rebranded as plain text, so if the files themselves are not renamed
the references point at paths that no longer exist. Rename folders first, then
files, so each `git mv` targets a path that still exists. Dispatch each
`git mv` to the repository that actually tracks the path, as with folders, and
record a failure as a warning and skip that path.

Log the renamed files the same way as the renamed folders.

Then walks all the files replacing all the occurrenciens of
- "openserverless" in "opensverveless"
- "OpenServerless" in "OpenServerless"
- "OPENSERVERLESS" to "OPENSERVERLESS"

warn any usage of OpenServerless with other cases

accept existing
- OPENSERVERLESS
- openserverless
- Openserverless

as common usages within the codebase,

warn of differenct casing of openserverless and openserverless

Leave a rebrander.log listing:

- all the folders renamed
- all the lines replaced
- all the lines left as is

show in the log for the lines: <file>:<line>:<newvalue>

include in the log the excluded lines with prefix SKIP:<file>:<line>:<oldvalue>

By default is it in dry run model.

Execute with "--do-it-for-real"

Exclusion rules:

All the files:
- .gitmodules

All the lines:

- lines  matching  "OPenServerless"
- lines matchins nuvolaris-testing
- lines matching registry.hub.docker.com/nuvolaris/
- lines with @nuvolaris.io (email)
- lines with ghcr.io/nuvolaris/ (ghcr.io references)
- .go, go.mod and go.sum files matching "github.com/openserverless/*" (github repo references)
- lines with assets-global.website-files.com (hosted CDN asset keys: renaming
  the URL does not rename the remote object). Only the URL is protected; the
  surrounding text on the same line, such as alt text, must still be rebranded.
- file build-step.md
- file olaris/prereq.yml

The same exclusion rules apply when the script is run inside a submodule
(olaris-op, olaris, testing), which the top-level walk does not enter.

