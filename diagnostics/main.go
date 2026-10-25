package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"syscall"
	"time"
)

var imageVersion = "development"

const schemaVersion = 1
const MiB int64 = 1024 * 1024
const GiB int64 = 1024 * MiB

var versionPattern = regexp.MustCompile(`^v?[0-9]{1,4}\.[0-9]{1,4}(?:\.[0-9]{1,4})?(?:[+._-][0-9]{1,14})?$`)
var memoryPattern = regexp.MustCompile(`(?i)^([0-9]+)([kmgt]?)$`)

type Check struct {
	ID      string         `json:"id"`
	Status  string         `json:"status"`
	Message string         `json:"message"`
	Action  string         `json:"action,omitempty"`
	Details map[string]any `json:"details,omitempty"`
}
type Report struct {
	SchemaVersion           int     `json:"schema_version"`
	ImageVersion            string  `json:"image_version"`
	Architecture            string  `json:"architecture"`
	Status                  string  `json:"status"`
	NetworkChecks           bool    `json:"network_checks"`
	FullArchiveVerification bool    `json:"full_archive_verification"`
	Checks                  []Check `json:"checks"`
}
type options struct {
	json, network, verify, strict bool
	timeout                       time.Duration
}
type disk struct {
	Free, Inodes int64
	HasInodes    bool
}
type collector struct {
	env          func(string) string
	proc, cgroup string
	now          time.Time
	access       func(string) bool
	disk         func(string) (disk, error)
	client       *http.Client
	report       Report
}

func truth(s string) bool {
	switch strings.ToLower(s) {
	case "1", "true", "yes", "y", "on":
		return true
	}
	return false
}

func (c *collector) val(key, fallback string) string {
	if v := c.env(key); v != "" {
		return v
	}
	return fallback
}

func (c *collector) add(id, status, message, action string, details map[string]any) {
	c.report.Checks = append(c.report.Checks, Check{id, status, message, action, details})
}

func (c *collector) finish() Report {
	c.report.Status = "ok"
	for _, ch := range c.report.Checks {
		if ch.Status == "warning" && c.report.Status == "ok" {
			c.report.Status = "warning"
		}
		if ch.Status == "error" {
			c.report.Status = "error"
		}
	}
	return c.report
}

func (c *collector) collect(ctx context.Context, o options) Report {
	c.report = Report{SchemaVersion: schemaVersion, ImageVersion: "development", Architecture: runtime.GOARCH, NetworkChecks: o.network, FullArchiveVerification: o.verify, Checks: []Check{}}
	if versionPattern.MatchString(imageVersion) {
		c.report.ImageVersion = imageVersion
	}
	data := c.val("DATA_DIR", "/data")
	server := c.val("SERVER_DIR", filepath.Join(data, "server"))
	jar := c.val("HYTALE_SERVER_JAR", filepath.Join(server, "HytaleServer.jar"))
	assets := c.val("HYTALE_ASSETS_PATH", filepath.Join(data, "Assets.zip"))
	c.add("runtime.user", "info", "Diagnostic process user and group IDs; no account names are collected.", "Compare these IDs with your volume ownership when permission checks fail.", map[string]any{"uid": os.Geteuid(), "gid": os.Getegid()})
	c.directory("permissions.data", data, true)
	c.directory("permissions.server", server, true)
	c.directory("permissions.temporary", os.TempDir(), true)
	if truth(c.env("HYTALE_ENABLE_BACKUP")) {
		c.directory("permissions.backup", c.val("HYTALE_BACKUP_DIR", filepath.Join(data, "backups")), false)
	} else {
		c.add("backups.configuration", "warning", "Built-in backups are not enabled; external backups cannot be assessed here.", "Configure and test a backup/restore strategy for persistent worlds.", nil)
	}
	size := c.archives(jar, assets, o)
	c.configuration(server)
	c.runtimeInfo()
	c.config(server)
	c.auth(data, server)
	args := c.processes(jar)
	c.udp()
	c.limits(args)
	c.storage(data, size)
	c.update(data, jar, assets)
	if o.network {
		networkCtx, cancel := context.WithTimeout(ctx, o.timeout)
		defer cancel()
		c.network(networkCtx)
	} else {
		c.add("network.outbound", "unknown", "Outbound DNS/TLS and broker HTTP were not contacted.", "Use --network for bounded credential-free network checks.", nil)
	}
	return c.finish()
}

func usage(w io.Writer) {
	fmt.Fprintln(w, "Usage: hytale-cli doctor [--json] [--strict] [--network] [--timeout 10s] [--verify-archives]\n       hytale-cli status [doctor options]\n       hytale-cli report [doctor options]\n\nRead-only local checks by default. No credentials, raw paths, environment dump or logs are included.\n--network contacts Hytale HTTPS endpoints and the configured broker health endpoint without credentials.\n--timeout bounds the total network-check duration (default 10s, maximum 30s).\n--verify-archives streams all archive contents to verify CRCs; this can take several minutes.\nExit: 0 no errors, 1 errors (or warnings with --strict), 2 invalid options. Unknown checks are not errors.")
}

func run(args []string, out, errOut io.Writer) int {
	fs := flag.NewFlagSet("doctor", flag.ContinueOnError)
	fs.SetOutput(io.Discard)
	o := options{}
	help := false
	fs.BoolVar(&o.json, "json", false, "")
	fs.BoolVar(&o.strict, "strict", false, "")
	fs.BoolVar(&o.network, "network", false, "")
	fs.BoolVar(&o.verify, "verify-archives", false, "")
	fs.BoolVar(&help, "help", false, "")
	fs.DurationVar(&o.timeout, "timeout", 10*time.Second, "")
	if e := fs.Parse(args); e != nil || fs.NArg() != 0 || o.timeout <= 0 || o.timeout > 30*time.Second {
		usage(errOut)
		return 2
	}
	if help {
		usage(out)
		return 0
	}
	transport := http.DefaultTransport.(*http.Transport).Clone()
	transport.MaxResponseHeaderBytes = 64 * 1024
	c := collector{env: os.Getenv, proc: "/proc", cgroup: "/sys/fs/cgroup", now: time.Now(), access: func(path string) bool {
		mode := uint32(2) // W_OK for replacement files; directories also need X_OK.
		if s, e := os.Stat(path); e == nil && s.IsDir() {
			mode |= 1
		}
		return syscall.Access(path, mode) == nil
	}, disk: func(path string) (disk, error) {
		var s syscall.Statfs_t
		e := syscall.Statfs(path, &s)
		return disk{int64(s.Bavail) * int64(s.Bsize), int64(s.Ffree), s.Files > 0}, e
	}, client: &http.Client{Transport: transport, CheckRedirect: func(*http.Request, []*http.Request) error { return http.ErrUseLastResponse }}}
	r := c.collect(context.Background(), o)
	if o.json {
		encoder := json.NewEncoder(out)
		encoder.SetIndent("", "  ")
		if encoder.Encode(r) != nil {
			return 1
		}
	} else {
		fmt.Fprintln(out, "Hytale diagnostics (read-only) — "+r.Status)
		for _, ch := range r.Checks {
			fmt.Fprintf(out, "[%s] %s: %s\n", strings.ToUpper(ch.Status), ch.ID, ch.Message)
			if len(ch.Details) > 0 {
				b, _ := json.Marshal(ch.Details)
				fmt.Fprintln(out, "  "+string(b))
			}
			if ch.Action != "" {
				fmt.Fprintln(out, "  Next: "+ch.Action)
			}
		}
		fmt.Fprintln(out, "Local results are not a guarantee that players can connect. Use --json for a shareable allowlisted report.")
	}
	if r.Status == "error" || (o.strict && r.Status == "warning") {
		return 1
	}
	return 0
}

func main() { os.Exit(run(os.Args[1:], os.Stdout, os.Stderr)) }
