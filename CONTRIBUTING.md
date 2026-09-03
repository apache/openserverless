<!--
#
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
-->
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](http://www.apache.org/licenses/LICENSE-2.0)

# Contributing to Apache OpenServerless (incubating)

Anyone can contribute to the OpenServerless project and we welcome your contributions.

There are multiple ways to contribute: report bugs, improve the docs, and
contribute code. Whichever you choose, please follow the prerequisites and
guidelines below.

## Contributor License Agreement

Contributors of significant changes must sign and submit an Apache ICLA
(Individual Contributor License Agreement). Small contributions, such as
documentation fixes, can be accepted at the discretion of the PMC without one,
so do not let this stop you from opening your first pull request.

Instructions on how to sign can be found here:
[https://www.apache.org/licenses/contributor-agreements.html](https://www.apache.org/licenses/contributor-agreements.html)

Sign the appropriate agreement and submit it to the Apache Software Foundation
(ASF) secretary. You will receive a confirmation email from the ASF once it has
been recorded. Project committers verify that pull requests come from
contributors covered by an ICLA where one is required.

We look forward to your contributions!

## Raising issues

Please raise any bug reports or enhancement requests on the main project repository's GitHub [issue tracker](https://github.com/apache/openserverless/issues). Be sure to search the
list to see if your issue has already been raised.

A good bug report is one that makes it easy for us to understand what you were trying to do and what went wrong.
Provide as much context as possible so we can try to recreate the issue.

A good enhancement request comes with an explanation of what you are trying to do and how that enhancement would help you.

### Discussion

Please use the project's developer mailing list to engage our community:
[dev@openserverless.apache.org](mailto:dev@openserverless.apache.org)

The mailing list is the preferred contact medium. Subscribe by sending an email to
[dev-subscribe@openserverless.apache.org](mailto:dev-subscribe@openserverless.apache.org)
and then replying to the confirmation message.

You can also find us on the `#openserverless` channel on the
[ASF Slack](https://infra.apache.org/slack.html), but please prefer the mailing
list: at Apache, project decisions must be discussed and recorded there.

## Building and testing

Before opening a pull request, please build and test your changes locally.
See the [README](README.md) for how to set up a development environment and for
the per-platform build and test scripts.

## Coding standards

Please ensure you follow the coding standards used throughout the existing
code base. Some basic rules include:

 - all files must have the Apache license in the header. Check this with
   `task license` before opening a pull request (it requires
   [license-eye](https://github.com/apache/skywalking-eyes)).
 - you need always to provide a test - there are plenty of testing in the source around: unit, integration, a test suite and so on
 - all PRs must have passing builds.

## Pull requests

We work in releavse branches and then move up the changes to the main

 - open pull requests against the higher version branch (example if there is 0.1.0, 0.9.0 and 0.9.1 use 0.9.1) unless a committer directs you otherwise
 - keep each pull request focused on a single change, and describe what it does and why.
 - reference the related GitHub issue in the description, if there is one.
 - be prepared to address review comments; committers may ask you to rebase before merging.
