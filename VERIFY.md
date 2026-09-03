# Apache Release Verification Checklist

This markdown file serves as a local checklist for verifying the authenticity and integrity of Apache Software Foundation releases.

## 1. Source & Infrastructure
- [ ] **Official Download Domain**: Verify the file was downloaded from `*.apache.org` (e.g., `downloads.apache.org` or `archive.apache.org`) and not a third-party mirror.
- [ ] **Secure Protocol**: Ensure the download URL uses HTTPS (`https://`).

## 2. Cryptographic Key Import
- [ ] **Fetch KEYS File**: Download the official `KEYS` file from the main Apache project site.
- [ ] **Import to GPG keyring**: Run the command:
  ```bash
  gpg --import KEYS
  ```
- [ ] **Verify Key Fingerprint**: (Optional but recommended) Cross-reference the key's fingerprint with known release managers listed on the official project page.

## 3. Cryptographic Signature Verification
- [ ] **Fetch ASC File**: Download the detached signature file (`.asc`) for your exact release version.
- [ ] **Execute Signature Check**: Run the verification command:
  ```bash
  gpg --verify <filename>.<extension>.asc <filename>.<extension>
  ```
- [ ] **Confirm 'Good Signature'**: Ensure the output states `"Good signature from..."`. (Ignore the "not certified with a trusted signature" warning if you haven't explicitly set trust levels, provided the name matches the release manager).

## 4. Checksum Integrity Validation
- [ ] **Fetch Checksum File**: Download the `.sha512` or `.sha256` file corresponding to the release.
- [ ] **Generate Local Hash**: Compute the hash locally based on your OS:
  - Linux: `sha512sum <filename>.<extension>`
  - macOS: `shasum -a 512 <filename>.<extension>`
  - Windows: `CertUtil -hashfile <filename>.<extension> SHA512`
- [ ] **Match Checksums**: Verify that your locally generated string matches the content of the downloaded checksum file exactly.

## 5. Archive Content & Compliance Auditing
- [ ] **Mandatory Root Files**: Unpack the archive and verify the root contains the required metadata files:
  - `LICENSE`
  - `NOTICE`
- [ ] **Informational Files**: Verify the presence of setup and project notes:
  - `README` or `README.md`
  - `RELEASE_NOTES` or `CHANGES`
- [ ] **Source Cleanliness**: For source distributions, check that no compiled binaries (`.jar`, `.class`, `.so`, `.dll`, or target/build folders) are accidentally bundled inside the package.


## 6.Build and Test the Sources
Execute:

  - Linux: `./build-and-test-ubuntu.sh`
  - macOS: `./build-and-test-mac.sh` (you need [Lima](https://lima-vm.io/))
  - Windows: `.\build-and-test-windows.ps1` (you need a recent WSL )

Ensure it builds cleanly and all the test passes.

