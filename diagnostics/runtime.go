package main

import (
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
)

func bytesValue(s string) (int64, bool) {
	m := memoryPattern.FindStringSubmatch(s)
	if m == nil {
		return 0, false
	}
	v, e := strconv.ParseInt(m[1], 10, 64)
	if e != nil || v <= 0 {
		return 0, false
	}
	factor := int64(1)
	switch strings.ToLower(m[2]) {
	case "k":
		factor = 1024
	case "m":
		factor = MiB
	case "g":
		factor = GiB
	case "t":
		factor = 1024 * GiB
	}
	if v > (1<<62)/factor {
		return 0, false
	}
	return v * factor, true
}

func (c *collector) processes(jar string) []string {
	entries, e := os.ReadDir(c.proc)
	if e != nil {
		c.add("runtime.process", "unknown", "Process information is not accessible.", "", nil)
		return nil
	}
	var args []string
	count := 0
	for _, entry := range entries {
		if _, e := strconv.Atoi(entry.Name()); e != nil {
			continue
		}
		b, e := read(filepath.Join(c.proc, entry.Name(), "cmdline"), MiB)
		if e != nil {
			continue
		}
		a := strings.Split(strings.TrimRight(string(b), "\x00"), "\x00")
		if len(a) < 3 || filepath.Base(a[0]) != "java" {
			continue
		}
		for i := 1; i+1 < len(a); i++ {
			if a[i] == "-jar" {
				target := a[i+1]
				if !filepath.IsAbs(target) {
					cwd, e := os.Readlink(filepath.Join(c.proc, entry.Name(), "cwd"))
					if e != nil {
						break
					}
					target = filepath.Join(cwd, target)
				}
				if filepath.Clean(target) == filepath.Clean(jar) {
					count++
					args = a
				}
				break
			}
		}
	}
	status, message := "ok", "A Java process is running the configured server JAR."
	if count == 0 {
		status = "warning"
		message = "No matching Java server process was found in this PID namespace."
	}
	if count > 1 {
		status = "error"
		message = "Multiple matching server processes were found; check for shared-volume access."
	}
	c.add("runtime.process", status, message, "A running process alone does not prove that a world is ready or players can join.", map[string]any{"matching_processes": count})
	return args
}

func (c *collector) udp() {
	bind := c.val("HYTALE_BIND", "0.0.0.0:5520")
	portText := bind[strings.LastIndex(bind, ":")+1:]
	p, e := strconv.Atoi(portText)
	if e != nil || p < 1 || p > 65535 {
		c.add("network.bind", "error", "The configured bind port is invalid.", "Set HYTALE_BIND to an address and UDP port between 1 and 65535.", nil)
		return
	}
	seen, found := false, false
	for _, name := range []string{"udp", "udp6"} {
		b, e := read(filepath.Join(c.proc, "net", name), MiB)
		if e != nil {
			continue
		}
		seen = true
		for _, line := range strings.Split(string(b), "\n") {
			fields := strings.Fields(line)
			if len(fields) < 4 {
				continue
			}
			_, hex, ok := strings.Cut(fields[1], ":")
			n, e := strconv.ParseUint(hex, 16, 16)
			if ok && e == nil && int(n) == p && fields[3] == "07" {
				found = true
			}
		}
	}
	status, message := "warning", "No UDP listener was found on the configured port in this network namespace."
	if !seen {
		status = "unknown"
		message = "UDP socket information is not accessible."
	}
	if found {
		status = "info"
		message = "A UDP listener exists on the configured port; process ownership and the published Docker/Kubernetes port are unverified."
	}
	c.add("network.udp_listener", status, message, "", map[string]any{"port": p})
	c.add("network.external", "unknown", "Internet reachability, router forwarding, firewall rules and CGNAT are not verified.", "Test from a separate network with a Hytale client; a local UDP listener or TCP port checker is insufficient.", nil)
}

func (c *collector) limits(args []string) {
	bases := []string{c.cgroup, filepath.Join(c.cgroup, "memory"), filepath.Join(c.cgroup, "cpu")}
	roots := append([]string{}, bases...)
	if b, e := read(filepath.Join(c.proc, "self", "cgroup"), 65536); e == nil {
		for _, line := range strings.Split(string(b), "\n") {
			p := strings.SplitN(line, ":", 3)
			if len(p) != 3 {
				continue
			}
			rel := strings.TrimPrefix(filepath.Clean("/"+p[2]), "/")
			for rel != "" && rel != "." {
				for _, base := range bases {
					roots = append(roots, filepath.Join(base, rel))
				}
				rel = filepath.Dir(rel)
			}
		}
	}
	limit := int64(0)
	for _, root := range roots {
		for _, name := range []string{"memory.max", "memory.limit_in_bytes"} {
			b, e := read(filepath.Join(root, name), 128)
			if e != nil {
				continue
			}
			n, e := strconv.ParseInt(strings.TrimSpace(string(b)), 10, 64)
			if e == nil && n > 0 && n < 1<<60 && (limit == 0 || n < limit) {
				limit = n
			}
		}
	}
	if limit == 0 {
		c.add("resources.memory_limit", "unknown", "No finite cgroup memory limit was detected.", "Configure a container memory limit and a heap size that leaves room for native memory and filesystem cache.", nil)
	} else {
		c.add("resources.memory_limit", "info", "Finite cgroup memory limit detected.", "", map[string]any{"bytes": limit})
	}
	heapText := c.env("JVM_XMX")
	fromProcess := false
	for _, a := range args {
		if strings.HasPrefix(a, "-Xmx") {
			heapText = strings.TrimPrefix(a, "-Xmx")
			fromProcess = true
		}
	}
	if heapText != "" {
		heap, valid := bytesValue(heapText)
		if !valid {
			c.add("resources.heap", "warning", "An explicit heap size could not be interpreted.", "Use a supported -Xmx size; the raw argument is not included.", nil)
		} else {
			details := map[string]any{"max_heap_bytes": heap, "from_running_process": fromProcess}
			status, message := "info", "Explicit heap limit detected."
			if limit > 0 {
				reserve := limit / 6
				if reserve < 512*MiB {
					reserve = 512 * MiB
				}
				if heap >= limit {
					status = "error"
					message = "Maximum Java heap meets or exceeds the container memory limit."
				} else if limit-heap < reserve {
					status = "warning"
					message = "Little memory remains outside the Java heap; native allocations can exceed the container limit."
				}
				details["outside_heap_bytes"] = limit - heap
			}
			c.add("resources.heap", status, message, "Allow space for native memory, threads and cache. Headroom recommendations are estimates, not workload guarantees.", details)
		}
	} else {
		c.add("resources.heap", "info", "No explicit -Xmx was recognized; JVM defaults or percentage-based settings may apply.", "This report does not execute JVM attach tools or infer actual heap usage.", nil)
	}
	cores := float64(0)
	for _, root := range roots {
		quota, period := "", ""
		if b, e := read(filepath.Join(root, "cpu.max"), 128); e == nil {
			v := strings.Fields(string(b))
			if len(v) == 2 {
				quota, period = v[0], v[1]
			}
		} else {
			q, _ := read(filepath.Join(root, "cpu.cfs_quota_us"), 128)
			p, _ := read(filepath.Join(root, "cpu.cfs_period_us"), 128)
			quota, period = strings.TrimSpace(string(q)), strings.TrimSpace(string(p))
		}
		q, e := strconv.ParseInt(quota, 10, 64)
		p, e2 := strconv.ParseInt(period, 10, 64)
		if e == nil && e2 == nil && q > 0 && p > 0 {
			value := float64(q) / float64(p)
			if cores == 0 || value < cores {
				cores = value
			}
		}
	}
	if cores > 0 {
		c.add("resources.cpu_limit", "info", "Finite cgroup CPU quota detected.", "CPU affinity and competing workloads can further restrict available CPU time.", map[string]any{"cores": cores})
	} else {
		c.add("resources.cpu_limit", "unknown", "No finite cgroup CPU quota was detected.", "CPU affinity and host contention are not measured.", nil)
	}
}

func (c *collector) update(data, jar, assets string) {
	if truth(c.env("HYTALE_NATIVE_UPDATES")) {
		if truth(c.env("HYTALE_DISABLE_UPDATES")) || (truth(c.env("HYTALE_AUTO_DOWNLOAD")) && truth(c.val("HYTALE_AUTO_UPDATE", "true"))) {
			c.add("updates.configuration", "error", "Native updates conflict with the configured startup updater or disabled Hytale updater.", "Use HYTALE_AUTO_UPDATE=false with native updates; do not set HYTALE_DISABLE_UPDATES=true.", nil)
		}
		if jar != "/data/server/HytaleServer.jar" || assets != "/data/Assets.zip" || c.val("HYTALE_AOT_PATH", "/data/server/HytaleServer.aot") != "/data/server/HytaleServer.aot" {
			c.add("updates.paths", "error", "Native updates require the standard writable JAR, assets and AOT paths.", "Use the standard data layout and mount the full data volume.", nil)
		}
		if truth(c.env("HYTALE_SESSION_TOKEN_BROKER_ENABLED")) {
			c.add("updates.authentication", "warning", "Broker sessions alone do not authorize native update downloads.", "Use a direct persisted server OAuth login for Hytale update checks/downloads.", nil)
		}
		for _, path := range []string{jar, assets} {
			if exists(path) && !c.access(path) {
				c.add("updates.files_writable", "error", "A native-update target is not writable.", "Remove individual read-only file mounts; mount the writable data volume.", nil)
				break
			}
		}
	}
	for _, item := range []struct{ id, rel string }{{"updates.staging", "updater/staging"}, {"updates.transaction", "updater/image-transaction"}, {"downloads.lock", ".hytale-download-lock"}} {
		if exists(filepath.Join(data, item.rel)) {
			c.add(item.id, "warning", "Pending update/download state exists; active and interrupted work cannot be distinguished by presence alone.", "Inspect the current server activity. Do not delete update journals or locks blindly.", nil)
		}
	}
	if strings.EqualFold(c.env("ENABLE_AOT"), "true") && !nonempty(c.val("HYTALE_AOT_PATH", filepath.Join(data, "server/HytaleServer.aot"))) {
		c.add("runtime.aot", "error", "Strict AOT mode is configured without an accessible cache.", "Provide a matching cache or use ENABLE_AOT=auto/false.", nil)
	}
}

func (c *collector) runtimeInfo() {
	b, e := read(filepath.Join(c.val("JAVA_HOME", "/opt/java/openjdk"), "release"), 65536)
	version := ""
	if e == nil {
		for _, line := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(line, "JAVA_VERSION=") {
				version = strings.Trim(strings.TrimPrefix(line, "JAVA_VERSION="), "\"")
			}
		}
	}
	if !versionPattern.MatchString(version) {
		c.add("runtime.java", "unknown", "Java release metadata could not be read; no JVM was executed.", "Check the runtime included in the image.", nil)
	} else {
		major, _ := strconv.Atoi(strings.Split(version, ".")[0])
		status := "info"
		message := "Java runtime version read from JAVA_HOME release metadata; the running process may use another runtime."
		if major < 25 {
			status = "error"
			message = "The configured Java runtime is older than Java 25."
		}
		c.add("runtime.java", status, message, "", map[string]any{"version": version})
	}
	if truth(c.env("HYTALE_AUTO_DOWNLOAD")) && runtime.GOARCH == "arm64" {
		if !nonempty("/usr/bin/qemu-x86_64-static") {
			c.add("runtime.downloader_emulator", "error", "ARM64 auto-download is enabled but the bundled downloader emulator is absent.", "Use the current native ARM64 image.", nil)
		}
	}
}
