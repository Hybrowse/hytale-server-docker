#!/usr/bin/env python3
"""Check the rendered project-path site and documentation contract offline."""
from html.parser import HTMLParser
from pathlib import Path
import json
import re
import sys
import tomllib
from urllib.parse import unquote, urljoin, urlsplit

ROOT = Path(__file__).resolve().parents[1]
SITE = ROOT / "site"
BASE = "https://hybrowse.github.io/hytale-server-docker/"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.ids = set()
        self.links = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            self.ids.add(attrs["id"])
        if tag == "a" and "name" in attrs:
            self.ids.add(attrs["name"])
        for key in ("href", "src"):
            if attrs.get(key):
                self.links.append(attrs[key])


def check():
    errors = []
    pages = {p.relative_to(SITE).as_posix(): Page(p.read_text()) for p in SITE.rglob("*.html")}
    if "index.html" not in pages:
        return ["Build the documentation before checking links"]
    for name, page in pages.items():
        url = BASE + (name[:-10] if name.endswith("index.html") else name)
        for link in page.links:
            target = urlsplit(urljoin(url, link))
            if target.netloc != urlsplit(BASE).netloc or target.scheme not in ("http", "https"):
                continue
            if not target.path.startswith(urlsplit(BASE).path):
                errors.append(f"{name}: link leaves the GitHub Pages project path: {link}")
                continue
            relative = unquote(target.path[len(urlsplit(BASE).path):])
            if not relative or relative.endswith("/"):
                relative += "index.html"
            if not (SITE / relative).is_file():
                errors.append(f"{name}: missing target {link}")
            elif target.fragment and relative in pages and unquote(target.fragment) not in pages[relative].ids:
                errors.append(f"{name}: missing anchor {link}")
    config = tomllib.loads((ROOT / "zensical.toml").read_text())["project"]
    def nav_paths(items):
        for item in items:
            for value in item.values():
                if isinstance(value, str):
                    yield value
                else:
                    yield from nav_paths(value)
    nav = list(nav_paths(config["nav"]))
    if len(nav) != len(set(nav)):
        errors.append("Navigation repeats a page")
    for path in nav:
        if not (ROOT / "docs" / path).is_file():
            errors.append(f"Missing navigation source: {path}")
    sources = {p.relative_to(ROOT / "docs").as_posix() for p in (ROOT / "docs").rglob("*.md")}
    for source in sorted(sources - set(nav)):
        errors.append(f"Unlisted or obsolete documentation page: {source}")
    expected = {source[:-3] + "/index.html" if not source.endswith("index.md") else source[:-8] + "index.html" for source in sources}
    for path in sorted(set(pages) - expected - {"404.html"}):
        errors.append(f"Stale generated documentation page: {path}")
    references = "\n".join(p.read_text() for p in (ROOT / "docs/reference").glob("*.md"))
    # Public shell inputs, plus JVM/server switches whose names lack HYTALE_.
    inputs = set()
    for script in (ROOT / "scripts").glob("*.sh"):
        inputs.update(re.findall(r'\$\{((?:HYTALE_|JVM_)[A-Z0-9_]+)(?::[-+?=][^}]*)?\}', script.read_text()))
    inputs.update(["ENABLE_AOT", "EXTRA_SERVER_ARGS", "TZ"])
    # Internal synthetic-architecture and reference-parser test hooks.
    inputs.difference_update({"HYTALE_TEST_ARCH", "HYTALE_CURSEFORGE_EXPAND_REFS_ONLY"})
    for key in sorted(inputs):
        if f"`{key}`" not in references:
            errors.append(f"Undocumented public setting: {key}")
    for path in (ROOT / "docs").rglob("*.md"):
        text = path.read_text()
        if re.search(r'https?://(?:www\.)?hybrowse\.gg(?!/discord(?:[)\s#]|$))', text):
            errors.append(f"Retired website link: {path.relative_to(ROOT)}")
        if "—" in text or "–" in text:
            errors.append(f"Use plain punctuation: {path.relative_to(ROOT)}")
    search = json.loads((SITE / "search.json").read_text())
    items = search.get("items", [])
    if not any("Doctor" in item.get("title", "") for item in items):
        errors.append("Doctor is missing from the search index")
    if "Hytale Server on Docker" not in (SITE / "index.html").read_text():
        errors.append("Unexpected documentation homepage")
    print(f"Checked {len(pages)} rendered pages and {len(inputs)} public settings")
    return sorted(set(errors))


if __name__ == "__main__":
    errors = check()
    for error in errors:
        print(error, file=sys.stderr)
    raise SystemExit(bool(errors))
