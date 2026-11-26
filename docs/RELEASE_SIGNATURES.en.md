# Release checksum signatures

[Русский](RELEASE_SIGNATURES.md) · [Releasing](RELEASING.en.md)

Use the existing Ed25519 signing key through Windows OpenSSH/its agent. No new key is generated and no private key enters WSL, CI or the release. Signature format: SSHSIG, namespace and identity `schoolbell-release`, output `SHA256SUMS.sig`.

The [public key](../packaging/release/signing-key.pub) fingerprint is `SHA256:ekq3AjehBO2o+e63uOrpGLLKjmHc7kjnPZhIkgzLT88`. [User verification instructions](../packaging/release/VERIFY.md) and allowed-signers ship with the artifacts. Confirm this fingerprint through a trusted repository copy; downloading a key alongside an archive alone does not authenticate the publisher.

After downloading the exact accepted Actions pair, check provenance and all files. From the repository in Windows, run (Python 3, or the extracted wizard's `python/python.exe`):

```powershell
python scripts/release-signatures.py sign --directory 'PATH-TO-RELEASE-FILES' --signing-key (git config user.signingkey)
python scripts/release-signatures.py verify --directory 'PATH-TO-RELEASE-FILES'
```

The command accepts the configured `.pub` key only if it matches the project key, verifies hashes before signing and then verifies the generated signature. Existing signatures are never overwritten. If the agent cannot sign, fix access to the existing key; do not create a replacement. These commands do not upload files or create a tag/release.

Sign once the exact downloaded artifacts are accepted. A local rehearsal signature is not the final GitHub release signature. Attach SHA256SUMS.sig separately alongside all files from the Actions archive. Record final hashes and acceptance separately; signatures do not imply hardware validation or Authenticode.
