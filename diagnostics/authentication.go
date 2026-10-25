package main

import (
	"encoding/base64"
	"encoding/json"
	"path/filepath"
	"regexp"
	"strings"
)

func (c *collector) credential(id, path string) {
	if !exists(path) {
		status := "warning"
		if strings.HasSuffix(id, "_source") {
			status = "error"
		}
		c.add(id, status, "No downloader credential file is available at this location.", "Complete the downloader device login, or provision a current credentials Secret.", nil)
		return
	}
	b, e := read(path, MiB)
	var v map[string]json.RawMessage
	if e != nil || json.Unmarshal(b, &v) != nil || v == nil {
		c.add(id, "error", "Downloader credentials are not a readable JSON object.", "Renew the downloader login using the documented recovery flow; do not delete worlds or server credentials.", nil)
		return
	}
	var refresh string
	json.Unmarshal(v["refresh_token"], &refresh)
	status, message := "info", "Downloader credentials are present; their validity has not been checked."
	if refresh == "" {
		message = "Downloader credentials are present, but a usable refresh token was not recognized."
	}
	c.add(id, status, message, "An expired access token alone does not prove that a new login is required; refresh may still succeed.", nil)
	c.secretPermissions(id+".permissions", path)
}

func (c *collector) auth(data, server string) {
	if truth(c.env("HYTALE_AUTO_DOWNLOAD")) {
		src := c.env("HYTALE_DOWNLOADER_CREDENTIALS_SRC")
		stored := filepath.Join(data, ".hytale-downloader-credentials.json")
		if src != "" {
			c.credential("auth.downloader_source", src)
		} else {
			c.credential("auth.downloader", stored)
		}
		if src != "" && truth(c.env("HYTALE_DOWNLOADER_RESET_CREDENTIALS")) {
			c.add("auth.downloader_reset", "error", "Credential reset conflicts with mounted credential seeding.", "Replace the source Secret or unset the credentials source before a one-time reset.", nil)
		} else if truth(c.env("HYTALE_DOWNLOADER_RESET_CREDENTIALS")) {
			c.add("auth.downloader_reset", "warning", "Downloader credentials will be reset on every startup while this option is enabled.", "Remove the reset setting after completing the replacement login.", nil)
		}
	}
	mode := strings.ToLower(c.val("HYTALE_AUTH_MODE", "authenticated"))
	if mode != "authenticated" {
		status := "warning"
		if mode != "offline" && mode != "insecure" {
			status = "error"
		}
		c.add("auth.mode", status, "Authenticated player verification is not configured, or the auth mode is unrecognized.", "Use authenticated mode for normal public servers.", nil)
	}
	stored := filepath.Join(server, "auth.enc")
	localKey := filepath.Join(server, "auth.key")
	if exists(localKey) {
		if !nonempty(localKey) {
			c.add("auth.local_key", "warning", "A local auth key file is empty or unreadable.", "Check access to the existing key; do not replace it without preserving the credential store.", nil)
		}
		c.secretPermissions("auth.local_key.permissions", localKey)
	}
	if exists(stored) {
		if nonempty(stored) {
			c.add("auth.server_store", "info", "Encrypted server credentials exist; decryption and live authentication are unverified.", "Check hytale-cli auth status in the live server logs.", nil)
			c.secretPermissions("auth.server_store.permissions", stored)
		} else {
			c.add("auth.server_store", "warning", "Encrypted server credential file is empty or inaccessible.", "Inspect data permissions and use hytale-cli auth login if reauthentication is needed.", nil)
		}
	}
	if nonempty(stored) {
		b, e := read(filepath.Join(data, ".machine-id"), 128)
		valid := e == nil && regexp.MustCompile(`^[0-9a-f]{32}$`).MatchString(strings.TrimSpace(string(b)))
		if !valid && c.env("HYTALE_MACHINE_ID") == "" && c.env("HYTALE_AUTH_KEY") == "" && c.env("HYTALE_AUTH_KEY_FILE") == "" && !nonempty(localKey) {
			c.add("auth.machine_identity", "warning", "Persisted credentials exist, but no persisted machine identity or explicit auth key was found.", "Preserve the complete data volume and the same identity/key across restarts. This check cannot determine which key the store used.", nil)
		}
	}
	if key := c.env("HYTALE_AUTH_KEY_FILE"); key != "" {
		if !nonempty(key) {
			c.add("auth.key_file", "error", "Configured auth key file is empty or inaccessible.", "Check the auth key Secret mount without changing its contents.", nil)
		} else {
			c.add("auth.key_file", "info", "An auth key file is present; its contents are not included.", "", nil)
			c.secretPermissions("auth.key_file.permissions", key)
		}
	}
	tokens := 0
	for _, key := range []string{"HYTALE_SERVER_SESSION_TOKEN", "HYTALE_SERVER_IDENTITY_TOKEN"} {
		token := c.env(key)
		if token == "" {
			continue
		}
		tokens++
		id := "auth.session_token"
		if key == "HYTALE_SERVER_IDENTITY_TOKEN" {
			id = "auth.identity_token"
		}
		parts := strings.Split(token, ".")
		var exp struct {
			Exp json.Number `json:"exp"`
		}
		recognized := false
		if len(parts) == 3 {
			if b, e := base64.RawURLEncoding.DecodeString(parts[1]); e == nil && len(b) < 65536 {
				if json.Unmarshal(b, &exp) == nil {
					if n, e := exp.Exp.Int64(); e == nil && n > 0 {
						remaining := n - c.now.Unix()
						status := "info"
						if remaining <= 0 {
							status = "warning"
						}
						c.add(id, status, "Token expiry was decoded locally; signature and live acceptance are unverified.", "Use live auth status to confirm authentication. The server may refresh a session itself.", map[string]any{"expires_in_seconds": remaining})
						recognized = true
					}
				}
			}
		}
		if !recognized {
			c.add(id, "info", "A token is configured; no supported expiry value was recognized.", "Its contents are not included. Use live auth status to check acceptance.", nil)
		}
	}
	if tokens == 1 {
		c.add("auth.token_pair", "warning", "Only one of the session and identity tokens is supplied.", "Check whether the server has the matching token or another usable authentication source.", nil)
	}
	broker := truth(c.env("HYTALE_SESSION_TOKEN_BROKER_ENABLED"))
	if broker {
		if c.env("HYTALE_SESSION_TOKEN_BROKER_URL") == "" {
			c.add("auth.broker_config", "error", "Broker authentication is enabled without a broker URL.", "Configure the broker URL and any required bearer Secret.", nil)
		} else {
			c.add("auth.broker_config", "info", "Broker authentication is configured; account usability is unverified.", "An HTTP health response does not prove that an account can mint tokens.", nil)
		}
		if src := c.env("HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC"); src != "" && !nonempty(src) {
			c.add("auth.broker_secret", "error", "Broker bearer Secret is empty or inaccessible.", "Check the mounted Secret file.", nil)
		}
	}
	if mode == "authenticated" && tokens == 0 && !broker && !nonempty(stored) {
		c.add("auth.server_login", "warning", "No stored credentials, broker configuration or supplied tokens were found.", "Follow the automatic device-login prompt, or use hytale-cli auth login.", nil)
	}
	c.add("auth.live_status", "unknown", "Live server authentication cannot be established by this read-only local report.", "Use hytale-cli auth status and inspect the server logs. No console commands or token-mint requests were sent.", nil)
}
