set -e
cd /Users/msciab/Projects/Workspace/incubator/0.9.0-incubating-RC5/openserverless

MODS="admin-api build cli devcontainer oplugins oplugins-op runtimes streamer testing"

desc() {
  case "$1" in
    admin-api)   echo "Admin API service (docker.io/apache/openserverless-admin-api)";;
    build)       echo "Build tree, including the vendored Apache OpenWhisk sources";;
    cli)         echo "The 'ops' command-line interface";;
    devcontainer) echo "Developer container image (docker.io/apache/openserverless-devcontainer)";;
    oplugins)    echo "Taskfile plugins (ops task definitions)";;
    oplugins-op) echo "Kubernetes operator (docker.io/apache/openserverless-operator)";;
    runtimes)    echo "Action runtime container images";;
    streamer)    echo "Streamer service (docker.io/apache/openserverless-streamer)";;
    testing)     echo "Integration test suite";;
  esac
}

banner() { # $1=char $2..=text lines
  local c="$1"; shift
  printf '%.0s'"$c" $(seq 1 78); echo
  for l in "$@"; do echo "$l"; done
  printf '%.0s'"$c" $(seq 1 78); echo
}

################## LICENSE ##################
{
  # Apache 2.0 text, taken once from the canonical copy
  sed -n '1,202p' oplugins/LICENSE

  cat <<'HDR'

==============================================================================
APACHE OPENSERVERLESS (INCUBATING) -- AGGREGATED LICENSE
==============================================================================

The Apache source release of Apache OpenServerless consists of Apache-2.0
licensed files only, including the vendored Apache OpenWhisk sources under
build/openwhisk, and the Apache License, Version 2.0 reproduced above
applies to all of it.

The sections below aggregate, verbatim, the third-party license terms
recorded in the LICENSE file of each submodule of this distribution. They
apply to the convenience binaries built from this source -- the statically
linked `ops` command-line interface and the container images assembled at
build time -- not to the Apache source release itself.

See the WARN file for the ASF category classification of each license. The
LICENSE file of each submodule remains authoritative for that component.

Submodules aggregated here:

HDR

  for m in $MODS; do printf '  %-14s %s\n' "$m" "$(desc $m)"; done

  for m in $MODS; do
    body_lines=$(( $(wc -l < $m/LICENSE) - 202 ))
    echo
    echo
    banner '=' "LICENSE -- $m" "$(desc $m)" "Source: $m/LICENSE"
    if [ "$body_lines" -le 0 ]; then
      echo
      echo "This component bundles no third-party software; it is covered in"
      echo "its entirety by the Apache License, Version 2.0 reproduced above."
    else
      sed -n '203,$p' $m/LICENSE
    fi
  done

  echo
  echo
  banner '=' "END OF AGGREGATED LICENSE"
} > LICENSE.new

################## NOTICE ##################
{
  cat <<'HDR'
Apache OpenServerless (Incubating)
Copyright 2024-2026 The Apache Software Foundation

This product includes software developed at
The Apache Software Foundation (https://www.apache.org/).

Apache OpenServerless is an effort undergoing incubation at The Apache
Software Foundation (ASF), sponsored by the Apache Incubator. See the
DISCLAIMER file distributed with this work.

This product is an aggregate distribution. The sections below aggregate,
verbatim, the notices recorded in the NOTICE file of each submodule. The
Apache source release contains only Apache-2.0 licensed files; the notices
that refer to container images and to statically linked binaries apply to
the convenience binaries assembled at build time. See the WARN file beside
this NOTICE.

The NOTICE file of each submodule remains authoritative for that component.

Submodules aggregated here:

HDR

  for m in $MODS; do printf '  %-14s %s\n' "$m" "$(desc $m)"; done

  for m in $MODS; do
    body_lines=$(( $(wc -l < $m/NOTICE) - 5 ))
    echo
    echo
    banner '=' "NOTICE -- $m" "$(desc $m)" "Source: $m/NOTICE"
    if [ "$body_lines" -le 0 ]; then
      echo
      echo "This component records no notices beyond the ASF notice above."
    else
      sed -n '6,$p' $m/NOTICE
    fi
  done

  echo
  echo
  banner '=' "END OF AGGREGATED NOTICE"
} > NOTICE.new
