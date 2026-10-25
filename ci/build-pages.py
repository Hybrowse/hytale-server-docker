#!/usr/bin/env python3
"""Assemble documentation and the existing Helm repository without publishing."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

import yaml

REPOSITORY_URL = "https://hybrowse.github.io/hytale-server-docker"
CHART = re.compile(r"hytale-server-[0-9][0-9A-Za-z.+_-]*\.tgz$")
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z.-]+)?$")


def regular(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError(f"Expected a regular file: {path.name}")
    return path


def digest(path):
    return hashlib.sha256(regular(path).read_bytes()).hexdigest()


def indexed_packages(index):
    if not index.exists():
        return []
    data = yaml.safe_load(regular(index).read_text())
    if not isinstance(data, dict) or not isinstance(data.get("entries"), dict):
        raise ValueError("Existing Helm index is invalid")
    names = []
    for entry in data["entries"].get("hytale-server", []):
        for url in entry.get("urls", []):
            # Historical repository URLs must remain unchanged. Check local
            # packages as well as preserving the existing index entries.
            name = url.rsplit("/", 1)[-1]
            if not CHART.fullmatch(name):
                raise ValueError("Unexpected chart URL in Helm index")
            names.append(name)
    return names


def assemble(site, previous, output, chart=None, version=None):
    if (chart is None) != (version is None):
        raise ValueError("Release chart and version must be supplied together")
    if version is not None:
        version = version.removeprefix("v")
        if not VERSION.fullmatch(version):
            raise ValueError("Expected a semantic release tag such as v1.2.1")
    regular(site / "index.html")
    # Refuse accidental copying over the input tree or an existing deployment.
    if output.exists():
        raise ValueError("Output directory must not already exist")
    if output.resolve().is_relative_to(site.resolve()) or output.resolve().is_relative_to(previous.resolve()):
        raise ValueError("Output must be separate from its inputs")
    for path in site.rglob("*"):
        if path.is_symlink():
            raise ValueError("Generated site contains a symlink")
    reserved = [p for p in site.iterdir() if p.name in ("index.yaml", "CNAME") or p.suffix == ".tgz"]
    if reserved:
        raise ValueError("Generated docs collide with Helm or domain files")
    old_files = [p for p in previous.glob("*") if p.name in ("index.yaml", "CNAME") or CHART.fullmatch(p.name)]
    old_hashes = {p.name: digest(p) for p in old_files}
    for name in indexed_packages(previous / "index.yaml"):
        regular(previous / name)
    shutil.copytree(site, output)
    for path in old_files:
        shutil.copy2(path, output / path.name)
    if version is not None:
        package = output / f"hytale-server-{version}.tgz"
        # Re-running a release must not replace its immutable existing archive.
        if not package.exists():
            subprocess.run(["helm", "package", str(chart), "--version", version,
                            "--app-version", version, "--destination", str(output)], check=True)
            regular(package)
            with tempfile.TemporaryDirectory() as tmp:
                shutil.copy2(package, Path(tmp) / package.name)
                args = ["helm", "repo", "index", tmp, "--url", REPOSITORY_URL]
                if (output / "index.yaml").exists():
                    old_index = Path(tmp) / "previous-index.yaml"
                    shutil.copy2(output / "index.yaml", old_index)
                    args += ["--merge", str(old_index)]
                subprocess.run(args, check=True)
                shutil.copy2(Path(tmp) / "index.yaml", output / "index.yaml")
    for name, checksum in old_hashes.items():
        if name != "index.yaml" and digest(output / name) != checksum:
            raise ValueError("Publication changed a historical chart or domain file")
    if version is None and "index.yaml" in old_hashes and digest(output / "index.yaml") != old_hashes["index.yaml"]:
        raise ValueError("Docs-only publication changed the Helm index")
    for name in indexed_packages(output / "index.yaml"):
        regular(output / name)
    (output / ".nojekyll").touch()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("site", "previous", "output"):
        parser.add_argument(f"--{name}", type=Path, required=True)
    parser.add_argument("--chart", type=Path)
    parser.add_argument("--version")
    args = parser.parse_args()
    assemble(args.site, args.previous, args.output, args.chart, args.version)


if __name__ == "__main__":
    main()
