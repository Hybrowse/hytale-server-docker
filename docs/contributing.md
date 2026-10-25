# Maintain and preview the docs

Documentation lives in `docs/` and is built with Zensical. Edit Markdown in the same PR as the feature it describes. Keep instructions in English, use plain punctuation and explain what a user should see after running a command.

## Local preview

From a checkout of this repository, create an isolated Python environment:

```sh
python3 -m venv .venv-docs
.venv-docs/bin/python -m pip install -r requirements-docs.txt
.venv-docs/bin/zensical serve
```

Open the local address printed by the preview server. The local URL is different from the public GitHub Pages project path; always run the built-site checks too.

On Windows, use `.venv-docs\Scripts\python` and `.venv-docs\Scripts\zensical` instead.

## Build and check

```sh
.venv-docs/bin/zensical build --clean --strict
.venv-docs/bin/python ci/check-docs.py
.venv-docs/bin/python -m unittest discover -s ci -p 'test_pages.py'
```

The checks cover navigation, rendered links and anchors, documented environment variables and shared publication of docs and Helm artifacts. PR builds upload the generated site as a workflow artifact; they do not publish it.

Examples should use `hytale` as the Compose service name, clearly mark partial snippets, quote environment values and avoid real credentials. Keep deployment examples consistent with the scripts and manifests. Do not promise a live server is authenticated based only on a process, socket or probe.

## Publication

The Documentation and Helm workflow is the only writer of the `gh-pages` branch. It runs after changes to docs and relevant configuration on `main`, on a published release, or manually. GitHub Pages keeps its existing branch-based source (`gh-pages`, root).

A docs update carries forward the existing root `index.yaml`, every published `hytale-server-*.tgz` and any `CNAME`, then replaces generated documentation. A release adds its chart from the release tag and merges its entry into the Helm index. Docs are built from current `main`, including on release runs, so publishing an older game-image release does not revert the website.

Publication jobs share a queue that does not cancel pending release jobs. Build, link and preservation checks must pass before the branch changes. Historical charts keep their names and the existing Helm repository URL remains:

```text
https://hybrowse.github.io/hytale-server-docker
```

The workflow explicitly requests a GitHub Pages build after updating the branch. This avoids relying on a push made with `GITHUB_TOKEN` to trigger another workflow. A manual workflow run can retry publication without creating a release. It never publishes a new chart unless triggered by a release.

## Compatibility and releases

These docs track `main`. Mark features that are not yet available in published images. Link to release notes for compatibility details. Keep navigation, examples and links consistent when reorganizing pages.

Refer to the official manual for upstream requirements and policies. Every documentation page must have a place in the navigation; do not keep parallel copies or placeholder pages.
