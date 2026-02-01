# Contributing
 
Thanks for contributing!
 
## Ground rules
 
- Keep changes **secure**, **performance-aware**, and **easy to operate**.
- Favor **clear UX** (good defaults, helpful errors, predictable behavior).
- Do not commit secrets or credentials.
 
## What we accept
 
- improvements to container behavior (startup checks, better defaults)
- documentation improvements
- bug fixes
- new features aligned with `ROADMAP.md`
 
## What we do not accept
 
- redistributing proprietary Hytale server binaries or assets
- contributions that embed credentials/tokens
 
## Issues
 
Please include:
 
- the image tag you used
- how you ran it (Compose snippet or `docker run`)
- logs (redact tokens/credentials)
- host OS and architecture
 
## Pull requests
 
- keep PRs focused
- update docs if behavior changes
- be explicit about security implications

### CLA

If your pull request is accepted, you may be asked to agree to the Contributor License Agreement (CLA):

- [`CLA.md`](CLA.md)

We may close pull requests unmerged if they are out of scope or would increase operational/security risk.

### DCO (sign-off required)

We require a Developer Certificate of Origin (DCO) sign-off on all commits.

Add a sign-off line to each commit using:

```bash
git commit -s
```

This adds a line like:

```text
Signed-off-by: Your Name <your.email@example.com>
```

By signing off, you certify that you have the right to submit the work and that it can be licensed under the repository license.

Please also complete the checklist in `.github/pull_request_template.md`.

## Local development
 
Repository-local planning and scratch work lives in `local/` and is intentionally ignored by git.
 
## Security
 
For vulnerabilities, see `SECURITY.md`.
