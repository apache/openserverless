#!/bin/bash
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

me="$(realpath $0)"
if test -z "$1"
then
    cd "$(dirname $0)"
    git submodule --quiet foreach --recursive "$me \$toplevel/.gitmodules \$name" 
    #>_submodules
    #cat _submodules
else 
    #echo "*** $1 - $2 ***"
    #pwd
    BRANCH=$(git config -f "$1" "submodule.$2.branch")
    if test -z "$BRANCH"
    then echo "??? $(pwd) no branch: $2"
    else 
        CUR=$(git rev-parse --abbrev-ref HEAD)
        if test "$CUR" = "HEAD"
        then git checkout "origin/$BRANCH" -B "$BRANCH"
        else 
	     if test "$CUR" = "$BRANCH"
	     then echo "ok: $2@$CUR "
	     else echo "!!! $2: found: $CUR expected: $BRANCH"
             fi 
        fi
    fi
fi