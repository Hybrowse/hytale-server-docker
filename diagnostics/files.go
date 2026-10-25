package main

import (
	"archive/zip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"syscall"
)

func regular(path string) (*os.File, error) {
	// O_NONBLOCK prevents a replaced/mistaken FIFO from hanging the diagnosis.
	fd, e := syscall.Open(path, syscall.O_RDONLY|syscall.O_NONBLOCK|syscall.O_CLOEXEC, 0)
	if e != nil {
		return nil, e
	}
	f := os.NewFile(uintptr(fd), "diagnostic-input")
	s, e := f.Stat()
	if e != nil || !s.Mode().IsRegular() {
		f.Close()
		return nil, fmt.Errorf("not a regular file")
	}
	return f, nil
}

func read(path string, limit int64) ([]byte, error) {
	f, e := regular(path)
	if e != nil {
		return nil, e
	}
	defer f.Close()
	b, e := io.ReadAll(io.LimitReader(f, limit+1))
	if int64(len(b)) > limit {
		return nil, fmt.Errorf("input too large")
	}
	return b, e
}

func exists(path string) bool { _, e := os.Stat(path); return e == nil }

func nonempty(path string) bool {
	f, e := regular(path)
	if e != nil {
		return false
	}
	defer f.Close()
	var b [1]byte
	n, e := f.Read(b[:])
	return n == 1 && (e == nil || e == io.EOF)
}

func nearest(path string) string {
	for !exists(path) {
		p := filepath.Dir(path)
		if p == path {
			break
		}
		path = p
	}
	return path
}

func (c *collector) directory(id, path string, required bool) {
	s, e := os.Stat(path)
	if os.IsNotExist(e) {
		p := nearest(path)
		status := "info"
		if required {
			status = "warning"
		}
		if !c.access(p) {
			status = "error"
		}
		c.add(id, status, "Directory is absent; checked its nearest existing parent.", "Provision the directory with ownership matching the container UID/GID if needed.", nil)
		return
	}
	if e != nil || !s.IsDir() {
		c.add(id, "error", "Directory cannot be inspected or is not a directory.", "Check the volume mount, directory type and access permissions.", nil)
		return
	}
	if !c.access(path) {
		c.add(id, "error", "Directory is not writable by this process.", "Check volume mount flags, filesystem capacity and ownership; do not delete the data volume.", nil)
		return
	}
	c.add(id, "ok", "Directory is accessible and writable according to filesystem access checks.", "", nil)
}

func (c *collector) secretPermissions(id, path string) {
	s, e := os.Stat(path)
	if e != nil {
		return
	}
	if s.Mode().Perm()&0077 != 0 {
		c.add(id, "warning", "Credential file is accessible to its group or other users.", "Restrict credential access to the intended container user; check read-only Secret mounts separately.", nil)
	}
}

func archive(path string, verify bool) (map[string]string, error) {
	f, e := regular(path)
	if e != nil {
		return nil, e
	}
	defer f.Close()
	s, e := f.Stat()
	if e != nil {
		return nil, e
	}
	r, e := zip.NewReader(f, s.Size())
	if e != nil {
		return nil, e
	}
	if len(r.File) == 0 {
		return nil, fmt.Errorf("empty archive")
	}
	manifest := map[string]string{}
	for _, entry := range r.File {
		if entry.Name == "META-INF/MANIFEST.MF" {
			rc, e := entry.Open()
			if e != nil {
				return nil, e
			}
			b, e := io.ReadAll(io.LimitReader(rc, 65537))
			rc.Close()
			if e != nil || len(b) > 65536 {
				return nil, fmt.Errorf("invalid manifest")
			}
			for _, line := range strings.Split(strings.ReplaceAll(string(b), "\r", ""), "\n") {
				k, v, ok := strings.Cut(line, ": ")
				if ok {
					manifest[k] = v
				}
			}
		}
		if verify && !entry.FileInfo().IsDir() {
			rc, e := entry.Open()
			if e != nil {
				return nil, e
			}
			_, e = io.Copy(io.Discard, rc)
			rc.Close()
			if e != nil {
				return nil, e
			}
		}
	}
	return manifest, nil
}

func (c *collector) archives(jar, assets string, o options) int64 {
	size := int64(0)
	for _, item := range []struct{ id, path string }{{"files.server_jar", jar}, {"files.assets", assets}} {
		s, e := os.Stat(item.path)
		if e != nil || !s.Mode().IsRegular() || s.Size() == 0 {
			status := "error"
			if truth(c.env("HYTALE_AUTO_DOWNLOAD")) {
				status = "warning"
			}
			c.add(item.id, status, "Server file is missing, empty or inaccessible.", "Provision matching server files or complete the downloader login with auto-download enabled.", nil)
			continue
		}
		size += s.Size()
		m, e := archive(item.path, o.verify)
		if e != nil {
			c.add(item.id, "error", "Archive could not be read or failed the requested verification.", "Keep the data volume. Restore or download matching server files after stopping the server.", nil)
			continue
		}
		details := map[string]any{"bytes": s.Size(), "verification": "zip_directory"}
		if o.verify {
			details["verification"] = "full_crc"
		}
		if v := m["Implementation-Version"]; versionPattern.MatchString(v) {
			details["version"] = v
		}
		c.add(item.id, "ok", "Archive is readable; this does not establish JAR/assets version compatibility.", "", details)
	}
	return size
}

func (c *collector) config(server string) {
	path := filepath.Join(server, "config.json")
	if !exists(path) {
		c.add("config.json", "info", "Server configuration has not been created yet.", "", nil)
		return
	}
	b, e := read(path, MiB)
	var cfg map[string]any
	if e != nil || json.Unmarshal(b, &cfg) != nil || cfg == nil {
		c.add("config.json", "error", "Server configuration is not a readable JSON object.", "Validate config.json without posting passwords or complete configuration files.", nil)
		return
	}
	c.add("config.json", "ok", "Server configuration is a readable JSON object.", "", nil)
	if v, ok := cfg["MaxViewRadius"].(float64); ok && v > 12 {
		c.add("config.view_radius", "warning", "Configured view radius exceeds the official general recommendation of 12 chunks.", "Consider reducing view distance if memory or tick performance is poor; workload needs vary.", map[string]any{"chunks": v})
	}
}

func (c *collector) storage(data string, size int64) {
	d, e := c.disk(nearest(data))
	if e != nil {
		c.add("storage.capacity", "unknown", "Filesystem capacity could not be inspected.", "Check free space and inodes on the data volume.", nil)
		return
	}
	budget := GiB
	if truth(c.env("HYTALE_AUTO_DOWNLOAD")) && size == 0 {
		budget = 6 * GiB
	}
	if truth(c.env("HYTALE_NATIVE_UPDATES")) {
		budget = 3*size + 2*GiB
		if budget < 12*GiB {
			budget = 12 * GiB
		}
	}
	status, message := "info", "Free data-volume space detected; required capacity depends on worlds, mods and backups."
	if d.Free == 0 {
		status = "error"
		message = "The data filesystem has no free space available to this user."
	} else if d.Free < budget {
		status = "warning"
		message = "Free space is below the diagnostic budget for the configured operation."
	}
	details := map[string]any{"free_bytes": d.Free, "estimated_operation_budget_bytes": budget}
	if d.HasInodes {
		details["free_inodes"] = d.Inodes
		if d.Inodes == 0 {
			status = "error"
			message = "The data filesystem has no free inodes."
		}
	}
	c.add("storage.capacity", status, message, "Leave additional space for worlds and backups; native update estimates include staged, backup and replacement server files.", details)
}
