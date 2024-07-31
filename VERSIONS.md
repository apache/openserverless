# Versioning in OpenServerless

This document lists the versioning scheme adopted in the OpenServerles projects.

# General schema:

We use semantic version in this format:

```
X.Y.Z-<timestamp>.<variant>
```

the `<timestamp>`  is in format `yymmddHHMM` and can be obtained easily with  `date +%y%m%d%H%M`

the `<variant>` identifies some state like `<dev>` `<alpha>` or some special cases

# Tags and branches

Whem using versions in tags (like in the CLI) the version MUST have the v in front.  This is  required by GO versioning. 

When using version in branches (like in tasks) the version MUST NOT have the v in from. This makes easier to compare.

# Image tags

We should use versions in docker image tags. We have 2 cases:

- normal tags of OpenServerless images, like the operator:

we follow the general schema: for example apache/openserverless-operator:0.1.0-alpha.2407311416

- runtimes

Runtimes are special because they depends on the language so the version is actually

```
<language-version>-<timestamp>[.<variant>]
```

where:
- `<language-version>` is the version of the language (Python 3.11, NodeJS 20.1 etc)
- `<timestamp>` is the timestamp (and it is automatically calculated and)
- `<variant>` identifies a variant of the image, like an `ai` version (3.11-2407311140.ai) or a customer specific version  (3.11-2407311140.ca).






