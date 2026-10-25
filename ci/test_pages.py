"""Publication regressions: a docs build must never remove released charts."""
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml

spec = importlib.util.spec_from_file_location("build_pages", Path(__file__).with_name("build-pages.py"))
pages = importlib.util.module_from_spec(spec)
spec.loader.exec_module(pages)
CHART = Path(__file__).resolve().parents[1] / "deploy/helm/hytale-server"


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        root = Path(self.tmp.name)
        self.site, self.previous, self.output = [root / name for name in ("site", "previous", "output")]
        self.site.mkdir()
        self.previous.mkdir()
        (self.site / "index.html").write_text("Current docs")
        (self.previous / "index.html").write_text("Old docs")
        (self.previous / "obsolete-page.html").write_text("Remove stale generated pages")
        (self.previous / "CNAME").write_text("docs.example.com\n")
        self.helm("package", str(CHART), "--version", "1.2.1", "--app-version", "1.2.1", "--destination", str(self.previous))
        self.helm("repo", "index", str(self.previous), "--url", pages.REPOSITORY_URL)
        self.old_index = (self.previous / "index.yaml").read_bytes()
        self.old_archive = (self.previous / "hytale-server-1.2.1.tgz").read_bytes()

    def helm(self, *args):
        return subprocess.check_output(["helm", *args], text=True)

    def test_docs_update_preserves_index_charts_and_domain(self):
        # Unindexed historical packages must not disappear either.
        (self.previous / "hytale-server-0.4.0.tgz").write_bytes(b"legacy archive")
        pages.assemble(self.site, self.previous, self.output)
        self.assertEqual((self.output / "index.yaml").read_bytes(), self.old_index)
        self.assertEqual((self.output / "hytale-server-1.2.1.tgz").read_bytes(), self.old_archive)
        self.assertEqual((self.output / "hytale-server-0.4.0.tgz").read_bytes(), b"legacy archive")
        self.assertEqual((self.output / "CNAME").read_text(), "docs.example.com\n")
        self.assertEqual((self.output / "index.html").read_text(), "Current docs")
        self.assertFalse((self.output / "obsolete-page.html").exists())
        self.assertTrue((self.output / ".nojekyll").is_file())

    def test_release_adds_chart_without_rewriting_old_entries(self):
        pages.assemble(self.site, self.previous, self.output, CHART, "v1.2.2")
        entries = yaml.safe_load((self.output / "index.yaml").read_text())["entries"]["hytale-server"]
        self.assertEqual([e["version"] for e in entries], ["1.2.2", "1.2.1"])
        old = yaml.safe_load(self.old_index)["entries"]["hytale-server"][0]
        self.assertEqual(entries[1], old)
        self.assertEqual((self.output / "hytale-server-1.2.1.tgz").read_bytes(), self.old_archive)
        metadata = yaml.safe_load(self.helm("show", "chart", str(self.output / "hytale-server-1.2.2.tgz")))
        self.assertEqual(metadata["version"], "1.2.2")
        self.assertEqual(metadata["appVersion"], "1.2.2")
        # Retry the same release after a docs edit: immutable package and index.
        retry = self.output.parent / "retry"
        pages.assemble(self.site, self.output, retry, CHART, "v1.2.2")
        self.assertEqual((retry / "hytale-server-1.2.2.tgz").read_bytes(), (self.output / "hytale-server-1.2.2.tgz").read_bytes())
        self.assertEqual((retry / "index.yaml").read_bytes(), (self.output / "index.yaml").read_bytes())

    def test_missing_historical_archive_fails_before_output(self):
        (self.previous / "hytale-server-1.2.1.tgz").unlink()
        with self.assertRaises(ValueError):
            pages.assemble(self.site, self.previous, self.output)
        self.assertFalse(self.output.exists())

    def test_reserved_paths_and_symlinks_are_rejected(self):
        (self.site / "index.yaml").write_text("collision")
        with self.assertRaises(ValueError):
            pages.assemble(self.site, self.previous, self.output)
        (self.site / "index.yaml").unlink()
        archive = self.previous / "hytale-server-1.2.1.tgz"
        archive.unlink()
        archive.symlink_to(self.site / "index.html")
        with self.assertRaises(ValueError):
            pages.assemble(self.site, self.previous, self.output)

    def test_invalid_tag_or_existing_output_is_rejected(self):
        for version in ("../other", "v1.2.1; echo nope", "latest"):
            with self.assertRaises(ValueError):
                pages.assemble(self.site, self.previous, self.output, CHART, version)
        self.output.mkdir()
        with self.assertRaises(ValueError):
            pages.assemble(self.site, self.previous, self.output)

    def test_first_publication_without_chart_history(self):
        empty = self.previous.parent / "empty"
        empty.mkdir()
        pages.assemble(self.site, empty, self.output)
        self.assertTrue((self.output / "index.html").is_file())
        self.assertFalse((self.output / "index.yaml").exists())


if __name__ == "__main__":
    unittest.main()
