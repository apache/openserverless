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

F=${1:?file}

FILE=$(realpath $F)
echo $FILE

CUR="$(basename $FILE)"
CONT="$(dirname $FILE)"
while ! test -d ${CONT}.diff
do 
    echo $CUR
    CUR="$(basename $CONT)/$CUR"
    CONT=$(dirname $CONT)
    echo $CONT
done

echo  CONTAINER $CONT
echo  PATH $CUR

code -r -d ${CONT}.diff/$CUR $CONT/$CUR