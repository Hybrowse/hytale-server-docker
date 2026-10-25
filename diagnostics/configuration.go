package main

import (
	"archive/zip"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"
)

// This reports selected numeric facts, never arbitrary configuration values,
// mod names, filenames, URLs, account/profile identifiers or parsing errors.
func (c *collector) configuration(server string) {
	for _, key := range []string{"HYTALE_GENERATE_SCHEMA", "HYTALE_SKIP_MOD_VALIDATION"} {
		if truth(c.env(key)) {
			c.add("config.removed_options", "error", "A removed Hytale server option is enabled.", "Replace HYTALE_GENERATE_SCHEMA with an explicit schema output path; replace HYTALE_SKIP_MOD_VALIDATION only after considering HYTALE_IGNORE_BROKEN_MODS.", nil)
			break
		}
	}
	if mode := c.env("HYTALE_RECOVERY_MODE"); mode != "" {
		if !truth(c.env("HYTALE_VERIFY_WORLDS")) || (mode != "FROM_BACKUP_OR_REGENERATE" && mode != "REGENERATE") {
			c.add("config.recovery", "error", "World recovery mode is invalid or world verification is not enabled.", "Use a supported recovery mode together with HYTALE_VERIFY_WORLDS=true, and back up the world first.", nil)
		}
	}
	if id := c.env("HYTALE_MACHINE_ID"); id != "" && !regexp.MustCompile(`^[0-9a-f]{32}$`).MatchString(id) {
		c.add("auth.machine_id_setting", "error", "The configured machine identity is invalid.", "Use exactly 32 lowercase hexadecimal characters and preserve the identity used for stored credentials.", nil)
	}
	if patch := c.env("HYTALE_CONFIG_PATCH_JSON"); patch != "" {
		var value any
		if json.Unmarshal([]byte(patch), &value) != nil {
			c.add("config.patch", "error", "The configured JSON patch is invalid JSON.", "Validate the patch locally without posting secrets or complete configuration values.", nil)
		}
	}
	for id, key := range map[string]string{"config.patch_source": "HYTALE_CONFIG_PATCH_JSON_SRC", "config.curseforge_key_source": "HYTALE_CURSEFORGE_API_KEY_SRC"} {
		if path := c.env(key); path != "" && !nonempty(path) {
			c.add(id, "error", "A configured patch or CurseForge Secret source is empty or inaccessible.", "Check the configured source file mounts; their paths and values are not included.", nil)
		}
	}
	directories := []string{filepath.Join(server, "mods")}
	extra := c.env("HYTALE_MODS_PATH")
	if extra == "" && c.env("HYTALE_CURSEFORGE_MODS") != "" {
		extra = filepath.Join(server, "mods-curseforge")
	}
	if extra != "" && filepath.Clean(extra) != filepath.Clean(directories[0]) {
		directories = append(directories, extra)
	}
	count, unreadable := 0, 0
	for _, path := range directories {
		entries, e := os.ReadDir(path)
		if os.IsNotExist(e) {
			continue
		}
		if e != nil {
			unreadable++
			continue
		}
		for _, entry := range entries {
			if entry.IsDir() {
				continue
			}
			ext := strings.ToLower(filepath.Ext(entry.Name()))
			if ext != ".jar" && ext != ".zip" {
				continue
			}
			count++
			f, e := regular(filepath.Join(path, entry.Name()))
			if e != nil {
				unreadable++
				continue
			}
			s, e := f.Stat()
			if e != nil {
				f.Close()
				unreadable++
				continue
			}
			r, e := zip.NewReader(f, s.Size())
			if e != nil {
				f.Close()
				unreadable++
				continue
			}
			// Reading all mod manifests is not a compatibility or security audit. Only
			// count structurally unreadable packages here; never execute plugin code.
			if len(r.File) == 0 {
				unreadable++
			}
			f.Close()
		}
	}
	status := "info"
	if unreadable > 0 {
		status = "warning"
	}
	c.add("mods.inventory", status, "Local mod packages were counted without executing code or checking API compatibility.", "Review server startup errors and declared mod requirements before updating. A readable package does not prove compatibility.", map[string]any{"packages": count, "unreadable_packages_or_directories": unreadable})
}
