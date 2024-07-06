#!/bin/bash
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