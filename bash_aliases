## NOTE! This script should be sourced, not executed. 
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
#

alias va="vi ~/.bash_aliases ; source ~/.bash_aliases"

# prompt
parse_git_branch() {
     git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/\1/'
}
export PS1="[\h:\[\e[32m\]\w:\[\e[91m\]\$(parse_git_branch)\[\e[00m\]]\n$ "


function secrets {
    if ! which op
    then echo "download the op cli from https://developer.1password.com/docs/cli/get-started/"
         return
    fi
    if ! test -e .env.dist
    then echo "no .env.dist listing the required secrets" 
         return
    fi
    echo "reading .env.dist to generate .env and .env.src from 1password"
    echo "I OVERWRITE the existing files, type your password or interrupt now"
    eval $(op signin)
    rm -f .env .env.src
    cat .env.dist | awk '{
        if(match($1, /^(.*)=(.*):/, a)) {
            print a[1] " op://secrets/" a[2] "/" a[1]
        }
    }' | while read VAR SEC 
    do 
        VAL="$(op read $SEC)"
        echo read $VAR 
        echo "$VAR=$VAL" >>.env
        echo "echo export and config $VAR" >>.env.src
        echo "export $VAR=\"$VAL\"" >>.env.src
        echo "nuv -config \"$VAR=$VAL\""  >>.env.src
    done
    source .env.src
}

export KNS="default"
alias k='kubectl -n $KNS'
alias kg='kubectl -n $KNS get'
alias kgy='kubectl -n $KNS -o yaml get'
alias kaf='kubectl -n $KNS apply -f'
alias kde='kubectl -n $KNS describe'
alias kdel='kubectl -n $KNS delete'
alias kin="kubectl cluster-info"

function kex { 
  ME=$1
  CMD=${2:-bash} 
  kubectl -n $KNS exec -ti $(kubectl -n $KNS get po | awk "/$ME/"'{print $1}') -- $CMD
}

function klo {
  ME=$1
  shift
  kubectl -n $KNS logs $(kubectl -n $KNS get po | awk "/$ME/"'{print $1}') "$@"
} 

function kns {
  if test -z "$1"
  then kubectl get ns
       echo "*** current: $KNS ***"
  else export KNS="$1"
       kubectl config set-context --current --namespace "$1"
  fi
}

alias kwa="watch kubectl get po,deploy,sts,jobs,svc,ingress --no-headers"
alias kwp="watch kubectl get po,deploy,sts,jobs --no-headers"
alias kws="watch kubectl get svc,ingress --no-headers"
alias kwc="watch kubectl get cm,secret --no-headers"

alias kfin='kubectl patch -p {"metadata":{"finalizers":[]}} --type=merge' 

alias ga="git add"
alias gst="git status"
alias glog="git log --pretty=oneline"
alias gdf="git diff --name-only"
alias gcm="git commit -m"
alias gcam="git commit -a -m"
alias gpom="git push origin main"

function gsnap {
  if test -z "$1"
  then echo msg please
  else x=""; for i in "$@" ; do x="$x$i " ; done
       git commit -a -m "$x" 
       git push 
  fi
}

alias t=task
alias tt='task -d ..'
alias ttt='task -d ../..'
alias dtag="date +%y%m%d%H"
alias lenv='export $(xargs <.env)'
alias nssh="ssh -oStrictHostKeyChecking=no"
alias gr="grep -nr"