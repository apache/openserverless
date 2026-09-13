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

# Third-party license / notice coverage audit

Apache OpenServerless 0.9.0-incubating (RC5)

This file records, per ecosystem, whether every third-party library actually
shipped in this distribution has its license terms recorded in a LICENSE file
and its required attributions recorded in a NOTICE file.

Method: the dependency inventories in this directory (`go.txt`, `python.txt`,
`nodejs.txt`, `scala.txt`) were cross-checked against the aggregated root
LICENSE/NOTICE and the per-submodule LICENSE/NOTICE files.

For Go, the inventory lists the full `go.sum` closure (268 modules), which is
NOT the set that is redistributed. The shipped set is what the linker actually
pulls in, resolved with `go list -deps ./...` per module:

    cli            93 modules
    streamer/src   12 modules
    runtimes        2 modules
    -----------------------------------
    union           97 external modules

## Summary

| Ecosystem     | Shipped libs checked | Uncovered | Status                     |
|---------------|----------------------|-----------|----------------------------|
| Go            | 97 (linked)          | 9         | needs NOTICE attribution   |
| Python        | 143 (declared)       | 0         | covered                    |
| Node.js       | 22 (declared)        | 0         | covered                    |
| Scala / JVM   | 77 (declared)        | 0         | covered                    |

## Go — libraries with no LICENSE/NOTICE entry

All nine are linked into the `ops` CLI binary. Every one of them is licensed
**Apache-2.0**, so no new license text is required: the Apache License 2.0 is
already reproduced at the top of each LICENSE file. What is missing is the
attribution entry.

None of the nine ships a NOTICE file of its own, so there is no upstream NOTICE
text that must be propagated verbatim.

| Module                        | Version                          | License    | Copyright |
|-------------------------------|----------------------------------|------------|-----------|
| github.com/dominikbraun/graph | v0.23.0                          | Apache-2.0 | no explicit copyright statement upstream |
| github.com/go-git/go-billy/v5 | v5.5.0                           | Apache-2.0 | Copyright 2017 Sourced Technologies S.L. |
| github.com/go-git/go-git/v5   | v5.12.0                          | Apache-2.0 | Copyright 2018 Sourced Technologies, S.L. |
| github.com/go-task/template   | v0.0.0-20240602015157-960e6f576656 | BSD-3-Clause | Copyright 2011 The Go Authors. All rights reserved. |
| github.com/golang/groupcache  | v0.0.0-20210331224755-41bb18bfe9da | Apache-2.0 | Copyright 2012 Google Inc. |
| github.com/Masterminds/goutils| v1.1.1                           | Apache-2.0 | no explicit copyright statement upstream |
| github.com/pjbgf/sha1cd       | v0.3.0                           | Apache-2.0 | Copyright 2009 The Go Authors (portions) |
| github.com/spf13/cobra        | v1.1.3                           | Apache-2.0 | Copyright 2013 Steve Francia; Copyright 2015 Red Hat Inc. |
| github.com/xanzy/ssh-agent    | v0.3.3                           | Apache-2.0 | Copyright (c) 2014 David Mzareulyan; Copyright 2015 Sander van Harmelen |

Note on `github.com/go-task/template`: this module ships **no LICENSE file**. It
is a fork of the Go standard library `text/template` package and its sources
carry the Go Authors BSD-3-Clause header. It must therefore be recorded under
BSD-3-Clause, not Apache-2.0 — the Go BSD-3-Clause text is already reproduced in
`cli/LICENSE` for the `golang.org/x/*` modules, so that entry can be reused.

## Python — no gaps

Two inventory entries matched nothing, both correctly excluded from the shipped
set:

  - `setuptools` — appears only inside `oplugins-op/poetry.lock` as a `doc`/`qa`
    extra of a transitive package; not installed at runtime.
  - `htmlgenerator` — declared in
    `runtimes/packages/python/withreqs/requirements.txt`, a test fixture used to
    exercise requirements handling, not a runtime dependency.

## Node.js — no gaps

Three inventory entries matched nothing; all three are `devDependencies`
(`@types/bun`, `@types/docopt`, `@types/minio`). TypeScript type packages are
erased at build time and are not present in any published artifact.

## Scala / JVM — no gaps

Sixteen artifact IDs did not match on an exact-artifact basis, but all are
accounted for in `build/LICENSE` and `build/NOTICE`, which group Akka-family
artifacts under umbrella project entries rather than listing each artifact:

  - Akka, Akka HTTP, Akka Management, Akka Discovery, Alpakka, Alpakka Kafka —
    covered by the grouped entries at `build/LICENSE:239-250` and the Lightbend
    attribution at `build/NOTICE:79-83`.
  - `akka-*-testkit`, `scalatest`, `junit`, `embedded-kafka`,
    `gradle-scalafmt`, `akka-grpc-gradle-plugin` — test-scope and build-scope
    only; not redistributed in any published artifact.
  - `io.prometheus:simpleclient*`, `org.scala-lang:scala-reflect` — covered via
    the Prometheus and Scala entries respectively.

Akka is pinned at **2.6.12**, the last Akka release under Apache-2.0, before the
BSL relicensing. This is intentional and must not be bumped.
