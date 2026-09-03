#!/usr/bin/env python3
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

"""Generate the [VOTE] release email for an Apache OpenServerless release.

Takes a version like `0.9.0-incubating-RC4` and prints, on stdout, the
mail to send to the mailing list, with every reference (dist URLs, git
tag, closing date, PPMC/PMC wording) filled in consistently.

The `-incubating` and `-RC<n>` parts are both optional and drive the
output:

  * `-incubating` selects the incubator dist paths
    (`dist/{dev,release}/incubator/openserverless`), adds the incubator
    disclaimer paragraph and says "Podling PMC (PPMC)". Without it the
    paths are `dist/{dev,release}/openserverless` and the project is
    treated as a top-level project (PMC).

  * `-RC<n>` makes it a release *candidate*: the artifacts live under
    `dist/dev`, the tag carries the RC suffix and the mail is a [VOTE]
    with a closing date. Without it the mail is the [ANNOUNCE] of the
    final release, whose artifacts live under `dist/release`.

Usage:

    ./releasing.py 0.9.0-incubating-RC4
    ./releasing.py 0.9.0-incubating-RC4 --hours 96
    ./releasing.py 0.9.0 --manager "Michele Sciabarra"
"""

import argparse
import re
import sys
from datetime import datetime, timedelta, timezone

VERSION_RE = re.compile(
    r"^v?(?P<base>\d+\.\d+\.\d+)"
    r"(?P<incubating>-incubating)?"
    r"(?:-(?:RC|rc)(?P<rc>\d+))?$"
)

DISCLAIMER = """\
Apache OpenServerless is an effort undergoing incubation at The Apache Software
Foundation (ASF), sponsored by the Apache Incubator. Incubation is required
of all newly accepted projects until a further review indicates that the
infrastructure, communications, and decision making process have stabilized
in a manner consistent with other successful ASF projects. While incubation
status is not necessarily a reflection of the completeness or stability of
the code, it does indicate that the project has yet to be fully endorsed by
the ASF."""

CHECKLIST = """\
[ ] Download links are valid
[ ] Checksums and signatures are valid
[ ] LICENSE/NOTICE files exist
[ ] No unexpected binary files in source
[ ] All source files have ASF headers
[ ] Can compile from source"""


class Release:
    """The pieces of a version string, and everything derived from them."""

    def __init__(self, version, hours=72, now=None):
        match = VERSION_RE.match(version.strip())
        if not match:
            raise ValueError(
                "not a valid version: %r "
                "(expected something like 0.9.0-incubating-RC4)" % version
            )
        self.base = match.group("base")
        self.incubating = match.group("incubating") is not None
        self.rc = int(match.group("rc")) if match.group("rc") else None
        self.hours = hours
        self.now = now or datetime.now(timezone.utc)

    # -- naming ----------------------------------------------------------

    @property
    def name(self):
        """Product name as it appears in prose."""
        return "Apache OpenServerless (Incubating)" if self.incubating \
            else "Apache OpenServerless"

    @property
    def version(self):
        """Version without the RC suffix: what is actually being released."""
        return self.base + ("-incubating" if self.incubating else "")

    @property
    def full_version(self):
        """Version including the RC suffix, if any."""
        return self.version + ("-RC%d" % self.rc if self.rc else "")

    @property
    def tag(self):
        return "v" + self.full_version

    @property
    def is_candidate(self):
        return self.rc is not None

    @property
    def pmc(self):
        return "Apache OpenServerless Podling PMC (PPMC)" if self.incubating \
            else "Apache OpenServerless PMC"

    # -- locations -------------------------------------------------------

    @property
    def dist_root(self):
        """Base of the dist repo: dev for candidates, release for finals."""
        area = "dev" if self.is_candidate else "release"
        project = "incubator/openserverless" if self.incubating \
            else "openserverless"
        return "https://dist.apache.org/repos/dist/%s/%s" % (area, project)

    @property
    def artifacts_url(self):
        return "%s/%s" % (self.dist_root, self.full_version)

    @property
    def keys_url(self):
        return "%s/KEYS" % self.dist_root

    @property
    def downloads_url(self):
        project = "incubator/openserverless" if self.incubating \
            else "openserverless"
        return "https://downloads.apache.org/%s/%s" % (project, self.version)

    @property
    def tag_url(self):
        return "https://github.com/apache/openserverless/releases/tag/%s" \
            % self.tag

    @property
    def deadline(self):
        return self.now + timedelta(hours=self.hours)

    # -- rendering -------------------------------------------------------

    def vote_mail(self, manager=None):
        signer = manager or "the release manager"
        paragraphs = [
            "[VOTE] Release %s %s RC%d"
            % (self.name, self.version, self.rc),
            "Hi all,",
            "I propose the following RC to be released as the official\n"
            "Apache OpenServerless %s release." % self.version,
        ]
        if self.incubating:
            paragraphs.append(DISCLAIMER)
        paragraphs += [
            "The artifacts for this release candidate can be found at:\n\n%s"
            % self.artifacts_url,
            "The Git tag to be voted upon is:\n\n%s\n\n%s"
            % (self.tag, self.tag_url),
            "Release artifacts are signed with the GPG key of %s." % signer,
            "The KEYS file is available at:\n\n%s" % self.keys_url,
            "Please download, verify, and test the release candidate.",
            "For detailed step-by-step instructions on how to verify this\n"
            "release, please see the file VERIFY.md within the source archive.",
            "The vote will run for a minimum of %d hours and close no earlier\n"
            "than:\n\n%s"
            % (self.hours, self.deadline.strftime("%Y-%m-%d %H:%M UTC")),
            "Please vote:\n\n"
            "[ ] +1 Release this package as Apache OpenServerless %s\n"
            "[ ] +0\n"
            "[ ] -1 Do not release this package because... (reason required)"
            % self.version,
            "Only %s members have binding votes, but community votes are\n"
            "encouraged."
            % ("PPMC" if self.incubating else "PMC"),
            "Checklist for reference:\n%s" % CHECKLIST,
            "On behalf of the %s," % self.pmc,
        ]
        if manager:
            paragraphs.append(manager)
        return "\n\n".join(paragraphs) + "\n"

    def announce_mail(self, manager=None):
        paragraphs = [
            "[ANNOUNCE] Release %s %s" % (self.name, self.version),
            "Hi all,",
            "The %s is pleased to announce the release of\n"
            "Apache OpenServerless %s." % (self.pmc, self.version),
            "The release is available for download at:\n\n%s"
            % self.downloads_url,
            "The Git tag for this release is:\n\n%s\n\n%s"
            % (self.tag, self.tag_url),
            "The KEYS file used to sign the artifacts is available at:\n\n%s"
            % self.keys_url,
            "For instructions on how to verify the release, please see the\n"
            "file VERIFY.md within the source archive.",
        ]
        if self.incubating:
            paragraphs.append(DISCLAIMER)
        paragraphs.append("On behalf of the %s," % self.pmc)
        if manager:
            paragraphs.append(manager)
        return "\n\n".join(paragraphs) + "\n"

    def mail(self, manager=None):
        return self.vote_mail(manager) if self.is_candidate \
            else self.announce_mail(manager)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate the release email for an Apache "
                    "OpenServerless release."
    )
    parser.add_argument(
        "version",
        help="version to release, e.g. 0.9.0-incubating-RC4; the "
             "-incubating and -RC<n> parts are both optional",
    )
    parser.add_argument(
        "--hours", type=int, default=72,
        help="minimum duration of the vote, in hours (default: 72)",
    )
    parser.add_argument(
        "--manager",
        help="name of the release manager, used to sign off the mail",
    )
    args = parser.parse_args(argv)

    try:
        release = Release(args.version, hours=args.hours)
    except ValueError as err:
        parser.error(str(err))

    sys.stdout.write(release.mail(args.manager))
    return 0


if __name__ == "__main__":
    sys.exit(main())
