package main

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"syscall"
	"testing"
	"time"
)

type roundTrip func(*http.Request) (*http.Response, error)

func (f roundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func put(t *testing.T, path, value string) {
	t.Helper()
	if e := os.MkdirAll(filepath.Dir(path), 0700); e != nil {
		t.Fatal(e)
	}
	if e := os.WriteFile(path, []byte(value), 0600); e != nil {
		t.Fatal(e)
	}
}
func makeZIP(t *testing.T, path string, entries map[string]string) {
	t.Helper()
	var b bytes.Buffer
	w := zip.NewWriter(&b)
	for name, value := range entries {
		entry, e := w.Create(name)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = io.WriteString(entry, value); e != nil {
			t.Fatal(e)
		}
	}
	if e := w.Close(); e != nil {
		t.Fatal(e)
	}
	put(t, path, b.String())
}
func jwt(exp int64) string {
	return "header." + base64.RawURLEncoding.EncodeToString([]byte(fmt.Sprintf(`{"exp":%d,"sub":"PRIVATE_ACCOUNT","email":"PRIVATE_EMAIL"}`, exp))) + ".signature"
}
func fixture(t *testing.T) (*collector, map[string]string, string) {
	t.Helper()
	root := t.TempDir()
	data := filepath.Join(root, "PRIVATE_HOST_PATH")
	server := filepath.Join(data, "server")
	proc := filepath.Join(root, "proc")
	cg := filepath.Join(root, "cgroup")
	jre := filepath.Join(root, "java")
	put(t, filepath.Join(jre, "release"), "JAVA_VERSION=\"25.0.5\"\n")
	makeZIP(t, filepath.Join(server, "HytaleServer.jar"), map[string]string{"META-INF/MANIFEST.MF": "Implementation-Version: 0.7.4\r\n", "server.class": "TEST"})
	makeZIP(t, filepath.Join(data, "Assets.zip"), map[string]string{"Server/Item.json": "{}"})
	put(t, filepath.Join(server, "config.json"), `{"MaxViewRadius":12,"Password":"CONFIG_SECRET","ServerName":"PRIVATE_NAME"}`)
	put(t, filepath.Join(server, "auth.enc"), "ENCRYPTED_CANARY")
	put(t, filepath.Join(data, ".machine-id"), strings.Repeat("a", 32))
	put(t, filepath.Join(proc, "123", "cmdline"), "/java/bin/java\x00-Xmx1G\x00-jar\x00"+filepath.Join(server, "HytaleServer.jar")+"\x00TOKEN_IN_ARGV\x00")
	put(t, filepath.Join(proc, "net", "udp"), "  sl local_address rem_address st\n0: 00000000:1590 00000000:0000 07\n")
	put(t, filepath.Join(proc, "self", "cgroup"), "0::/\n")
	put(t, filepath.Join(cg, "memory.max"), "2147483648")
	put(t, filepath.Join(cg, "cpu.max"), "100000 100000")
	env := map[string]string{"DATA_DIR": data, "SERVER_DIR": server, "JAVA_HOME": jre, "HYTALE_ENABLE_BACKUP": "true"}
	c := &collector{env: func(k string) string { return env[k] }, proc: proc, cgroup: cg, now: time.Unix(2000000000, 0), access: func(string) bool { return true }, disk: func(string) (disk, error) { return disk{64 * GiB, 10000, true}, nil }, client: &http.Client{Transport: roundTrip(func(*http.Request) (*http.Response, error) { t.Fatal("unexpected network call"); return nil, nil })}}
	return c, env, data
}
func check(t *testing.T, r Report, id string) Check {
	t.Helper()
	for _, c := range r.Checks {
		if c.ID == id {
			return c
		}
	}
	t.Fatalf("missing check %s", id)
	return Check{}
}
func assertStatus(t *testing.T, r Report, id, status string) {
	t.Helper()
	if c := check(t, r, id); c.Status != status {
		t.Fatalf("%s = %s, expected %s: %s", id, c.Status, status, c.Message)
	}
}

func TestHealthyLocalReportAndNoSecretDisclosure(t *testing.T) {
	c, env, data := fixture(t)
	env["HYTALE_SERVER_SESSION_TOKEN"] = jwt(c.now.Unix() + 3600)
	env["HYTALE_SERVER_IDENTITY_TOKEN"] = jwt(c.now.Unix() + 3600)
	env["HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN"] = "BEARER_SECRET"
	env["UNRELATED_PRIVATE_ENV"] = "UNRELATED_CANARY"
	report := c.collect(context.Background(), options{})
	if report.Status != "ok" {
		t.Fatalf("unexpected report: %+v", report)
	}
	for _, id := range []string{"files.server_jar", "files.assets", "runtime.process", "config.json"} {
		assertStatus(t, report, id, "ok")
	}
	assertStatus(t, report, "auth.live_status", "unknown")
	assertStatus(t, report, "network.external", "unknown")
	assertStatus(t, report, "network.outbound", "unknown")
	b, _ := json.Marshal(report)
	for _, secret := range []string{data, "PRIVATE_HOST_PATH", "PRIVATE_ACCOUNT", "PRIVATE_EMAIL", "PRIVATE_NAME", "CONFIG_SECRET", "ENCRYPTED_CANARY", "TOKEN_IN_ARGV", "BEARER_SECRET", "UNRELATED_CANARY", env["HYTALE_SERVER_SESSION_TOKEN"]} {
		if strings.Contains(string(b), secret) {
			t.Fatalf("report disclosed a secret or raw path: %q", secret)
		}
	}
	if check(t, report, "files.server_jar").Details["version"] != "0.7.4" {
		t.Fatal("server version missing")
	}
}
func TestMissingAndCorruptFiles(t *testing.T) {
	for _, auto := range []bool{false, true} {
		t.Run(fmt.Sprint(auto), func(t *testing.T) {
			c, env, data := fixture(t)
			os.Remove(filepath.Join(data, "Assets.zip"))
			if auto {
				env["HYTALE_AUTO_DOWNLOAD"] = "true"
			}
			r := c.collect(context.Background(), options{})
			want := "error"
			if auto {
				want = "warning"
			}
			assertStatus(t, r, "files.assets", want)
		})
	}
	c, _, data := fixture(t)
	put(t, filepath.Join(data, "Assets.zip"), "CORRUPT_SECRET")
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "files.assets", "error")
	b, _ := json.Marshal(r)
	if strings.Contains(string(b), "CORRUPT_SECRET") {
		t.Fatal("raw archive data leaked")
	}
}
func TestFullCRCVerification(t *testing.T) {
	path := filepath.Join(t.TempDir(), "archive.zip")
	var b bytes.Buffer
	w := zip.NewWriter(&b)
	entry, e := w.CreateHeader(&zip.FileHeader{Name: "file", Method: zip.Store})
	if e != nil {
		t.Fatal(e)
	}
	io.WriteString(entry, "UNIQUE_PAYLOAD")
	w.Close()
	raw := b.Bytes()
	at := bytes.Index(raw, []byte("UNIQUE_PAYLOAD"))
	if at < 0 {
		t.Fatal("payload not found")
	}
	raw[at] = 'X'
	put(t, path, string(raw))
	if _, e := archive(path, false); e != nil {
		t.Fatal("directory verification should not claim CRC verification", e)
	}
	if _, e := archive(path, true); e == nil {
		t.Fatal("corrupt payload not detected")
	}
}
func TestPermissionsCapacityAndHeap(t *testing.T) {
	c, _, data := fixture(t)
	c.access = func(path string) bool { return path != data }
	c.disk = func(string) (disk, error) { return disk{0, 0, true}, nil }
	put(t, filepath.Join(c.proc, "123", "cmdline"), "java\x00-Xmx2G\x00-jar\x00"+filepath.Join(data, "server/HytaleServer.jar")+"\x00")
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "permissions.data", "error")
	assertStatus(t, r, "storage.capacity", "error")
	assertStatus(t, r, "resources.heap", "error")
}
func TestAuthCredentialsAreNotAssumedValid(t *testing.T) {
	c, env, data := fixture(t)
	env["HYTALE_AUTO_DOWNLOAD"] = "true"
	env["HYTALE_SERVER_SESSION_TOKEN"] = jwt(c.now.Unix() - 1)
	put(t, filepath.Join(data, ".hytale-downloader-credentials.json"), `{"refresh_token":"REFRESH_SECRET","access_token":"ACCESS_SECRET","expiry":"2000-01-01T00:00:00Z"}`)
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "auth.downloader", "info")
	assertStatus(t, r, "auth.session_token", "warning")
	assertStatus(t, r, "auth.token_pair", "warning")
	b, _ := json.Marshal(r)
	if strings.Contains(string(b), "REFRESH_SECRET") || strings.Contains(string(b), "ACCESS_SECRET") {
		t.Fatal("credential leak")
	}
	env["HYTALE_DOWNLOADER_CREDENTIALS_SRC"] = "/unavailable/SECRET_SOURCE"
	env["HYTALE_DOWNLOADER_RESET_CREDENTIALS"] = "true"
	r = c.collect(context.Background(), options{})
	assertStatus(t, r, "auth.downloader_reset", "error")
}
func TestJSONErrorsAndRemovedSettings(t *testing.T) {
	c, env, data := fixture(t)
	put(t, filepath.Join(data, "server/config.json"), `{"Password":"PARSE_SECRET",`)
	env["HYTALE_SKIP_MOD_VALIDATION"] = "true"
	env["HYTALE_CONFIG_PATCH_JSON"] = "PATCH_SECRET_INVALID"
	env["HYTALE_MACHINE_ID"] = "IDENTITY_SECRET"
	r := c.collect(context.Background(), options{})
	for _, id := range []string{"config.json", "config.removed_options", "config.patch", "auth.machine_id_setting"} {
		assertStatus(t, r, id, "error")
	}
	b, _ := json.Marshal(r)
	for _, s := range []string{"PARSE_SECRET", "PATCH_SECRET_INVALID", "IDENTITY_SECRET"} {
		if strings.Contains(string(b), s) {
			t.Fatal("error leak")
		}
	}
}
func TestWrongProcessDoesNotCountAsServer(t *testing.T) {
	c, _, _ := fixture(t)
	put(t, filepath.Join(c.proc, "123/cmdline"), "sh\x00-c\x00java -jar HytaleServer.jar TOKEN\x00")
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "runtime.process", "warning")
}
func TestFIFOIsNeverRead(t *testing.T) {
	c, _, data := fixture(t)
	path := filepath.Join(data, "server/auth.enc")
	os.Remove(path)
	if e := syscall.Mkfifo(path, 0600); e != nil {
		t.Fatal(e)
	}
	done := make(chan struct{})
	go func() { defer close(done); c.collect(context.Background(), options{}) }()
	select {
	case <-done:
	case <-time.After(time.Second):
		t.Fatal("diagnostic blocked on FIFO")
	}
}
func TestNetworkOnlyReadsHealthAndDoesNotLeakErrors(t *testing.T) {
	c, env, _ := fixture(t)
	env["HYTALE_SESSION_TOKEN_BROKER_ENABLED"] = "true"
	env["HYTALE_SESSION_TOKEN_BROKER_URL"] = "http://broker.example/prefix"
	env["HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN"] = "SECRET_TOKEN"
	calls := 0
	c.client = &http.Client{Transport: roundTrip(func(r *http.Request) (*http.Response, error) {
		calls++
		if r.Header.Get("Authorization") != "" {
			t.Fatal("authorization sent")
		}
		if strings.Contains(r.URL.Host, "broker") {
			if r.Method != "GET" || r.URL.Path != "/prefix/healthz" {
				t.Fatal("unexpected broker request", r.Method, r.URL.Path)
			}
			return &http.Response{StatusCode: 200, Body: io.NopCloser(strings.NewReader("SECRET_BODY")), Header: make(http.Header)}, nil
		}
		if r.Method != "HEAD" {
			t.Fatal("unexpected external method")
		}
		return nil, fmt.Errorf("NETWORK_SECRET")
	})}
	r := c.collect(context.Background(), options{network: true, timeout: time.Second})
	if calls != 3 {
		t.Fatal("wrong request count", calls)
	}
	assertStatus(t, r, "network.broker_http", "info")
	b, _ := json.Marshal(r)
	for _, s := range []string{"SECRET_BODY", "SECRET_TOKEN", "NETWORK_SECRET", "broker.example"} {
		if strings.Contains(string(b), s) {
			t.Fatal("network leak")
		}
	}
	env["HYTALE_SESSION_TOKEN_BROKER_URL"] = "http://user:URL_SECRET@broker.example/?token=QUERY_SECRET"
	calls = 0
	r = c.collect(context.Background(), options{network: true, timeout: time.Second})
	if calls != 2 {
		t.Fatal("credential-bearing broker URL contacted")
	}
	assertStatus(t, r, "network.broker_http", "warning")
}
func TestReadOnlyReportPreservesCredentialAndStateFiles(t *testing.T) {
	c, _, data := fixture(t)
	paths := []string{filepath.Join(data, "server/auth.enc"), filepath.Join(data, "server/config.json"), filepath.Join(data, ".machine-id")}
	before := map[string]string{}
	for _, p := range paths {
		b, _ := os.ReadFile(p)
		before[p] = string(b)
	}
	c.collect(context.Background(), options{})
	for _, p := range paths {
		b, _ := os.ReadFile(p)
		if string(b) != before[p] {
			t.Fatal("file changed")
		}
	}
}
func TestInvalidOptionsDoNotEchoArguments(t *testing.T) {
	var out, err bytes.Buffer
	if code := run([]string{"--PRIVATE_TOKEN_SECRET"}, &out, &err); code != 2 {
		t.Fatal(code)
	}
	if strings.Contains(err.String(), "PRIVATE_TOKEN_SECRET") {
		t.Fatal("argument leaked")
	}
	if code := run([]string{"--help"}, &out, &err); code != 0 {
		t.Fatal(code)
	}
}
func TestMemoryValues(t *testing.T) {
	for _, s := range []string{"-1G", "0", "huge", "99999999999999999999999G", "1.5G", "SECRET"} {
		if _, ok := bytesValue(s); ok {
			t.Fatal("accepted", s)
		}
	}
	if n, ok := bytesValue("512m"); !ok || n != 512*MiB {
		t.Fatal(n, ok)
	}
}

func TestCgroupAncestorsAndV1Quota(t *testing.T) {
	c, _, _ := fixture(t)
	os.Remove(filepath.Join(c.cgroup, "memory.max"))
	os.Remove(filepath.Join(c.cgroup, "cpu.max"))
	put(t, filepath.Join(c.proc, "self", "cgroup"), "5:memory:/parent/child\n4:cpu:/parent/child\n")
	put(t, filepath.Join(c.cgroup, "memory", "parent", "memory.limit_in_bytes"), "1073741824")
	put(t, filepath.Join(c.cgroup, "memory", "parent", "child", "memory.limit_in_bytes"), "2147483648")
	put(t, filepath.Join(c.cgroup, "cpu", "parent", "cpu.cfs_quota_us"), "50000")
	put(t, filepath.Join(c.cgroup, "cpu", "parent", "cpu.cfs_period_us"), "100000")
	r := c.collect(context.Background(), options{})
	if check(t, r, "resources.memory_limit").Details["bytes"] != int64(GiB) {
		t.Fatal("missed stricter ancestor limit")
	}
	if check(t, r, "resources.cpu_limit").Details["cores"] != float64(0.5) {
		t.Fatal("missed v1 quota")
	}
	assertStatus(t, r, "resources.heap", "error")
}

func TestUpdateConflictsAndArchiveInventory(t *testing.T) {
	c, env, data := fixture(t)
	env["HYTALE_NATIVE_UPDATES"] = "true"
	env["HYTALE_DISABLE_UPDATES"] = "true"
	env["ENABLE_AOT"] = "true"
	put(t, filepath.Join(data, "updater", "image-transaction", "journal"), "PRIVATE_JOURNAL")
	put(t, filepath.Join(data, "server", "mods", "PRIVATE_MOD.jar"), "not a zip")
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "updates.configuration", "error")
	assertStatus(t, r, "updates.transaction", "warning")
	assertStatus(t, r, "runtime.aot", "error")
	b, _ := json.Marshal(r)
	if strings.Contains(string(b), "PRIVATE_") {
		t.Fatal("private metadata escaped")
	}
}

func TestNetworkBudgetAndServerErrors(t *testing.T) {
	c, _, _ := fixture(t)
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	c.network(ctx)
	assertStatus(t, c.report, "network.hytale_oauth", "unknown")
	assertStatus(t, c.report, "network.hytale_downloader", "unknown")
	c.report = Report{}
	c.client.Transport = roundTrip(func(*http.Request) (*http.Response, error) {
		return &http.Response{StatusCode: 503, Body: io.NopCloser(strings.NewReader("PRIVATE_RESPONSE"))}, nil
	})
	c.network(context.Background())
	assertStatus(t, c.report, "network.hytale_oauth", "warning")
	assertStatus(t, c.report, "network.hytale_downloader", "warning")
}

func TestPersistentLocalKeyAndPatchConflict(t *testing.T) {
	c, env, data := fixture(t)
	os.Remove(filepath.Join(data, ".machine-id"))
	put(t, filepath.Join(data, "server", "auth.key"), "PRIVATE_KEY_CANARY")
	env["HYTALE_CONFIG_PATCH_JSON"] = "{}"
	env["HYTALE_CONFIG_PATCH_JSON_SRC"] = filepath.Join(data, "patch.json")
	put(t, env["HYTALE_CONFIG_PATCH_JSON_SRC"], "{}")
	r := c.collect(context.Background(), options{})
	assertStatus(t, r, "config.patch_conflict", "error")
	for _, ch := range r.Checks {
		if ch.ID == "auth.machine_identity" {
			t.Fatal("missed persisted local key")
		}
	}
	b, _ := json.Marshal(r)
	if strings.Contains(string(b), "PRIVATE_KEY_CANARY") {
		t.Fatal("key escaped")
	}
}
