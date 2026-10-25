package main

import (
	"context"
	"net/http"
	"net/url"
	"strings"
)

func (c *collector) network(ctx context.Context) {
	for _, endpoint := range []struct{ id, url string }{{"network.hytale_oauth", "https://oauth.accounts.hytale.com/"}, {"network.hytale_downloader", "https://downloader.hytale.com/hytale-downloader.zip"}} {
		if ctx.Err() != nil {
			c.add(endpoint.id, "unknown", "Network check skipped because the shared time budget was exhausted.", "Retry with a larger --timeout (maximum 30s).", nil)
			continue
		}
		request, e := http.NewRequestWithContext(ctx, http.MethodHead, endpoint.url, nil)
		if e != nil {
			continue
		}
		response, e := c.client.Do(request)
		if e != nil {
			c.add(endpoint.id, "warning", "HTTPS endpoint could not be reached within the diagnostic network budget.", "Check DNS, proxy settings, TLS trust and outbound connectivity; no credentials were sent.", nil)
			continue
		}
		response.Body.Close()
		status := "info"
		if response.StatusCode >= 500 || (endpoint.id == "network.hytale_downloader" && response.StatusCode >= 400) {
			status = "warning"
		}
		c.add(endpoint.id, status, "HTTPS response received; this verifies transport, not authentication or download authorization.", "", map[string]any{"http_status": response.StatusCode})
	}
	if truth(c.env("HYTALE_SESSION_TOKEN_BROKER_ENABLED")) && c.env("HYTALE_SESSION_TOKEN_BROKER_URL") != "" {
		u, e := url.Parse(c.env("HYTALE_SESSION_TOKEN_BROKER_URL"))
		if e != nil || u.Host == "" || (u.Scheme != "http" && u.Scheme != "https") || u.User != nil || u.RawQuery != "" || u.Fragment != "" {
			c.add("network.broker_http", "warning", "Broker URL is unsuitable for a credential-free health check.", "Use an HTTP(S) URL without embedded credentials, query or fragment. The URL is not included in this report.", nil)
			return
		}
		u.Path = strings.TrimRight(u.Path, "/") + "/healthz"
		request, e := http.NewRequestWithContext(ctx, http.MethodGet, u.String(), nil)
		if e != nil {
			return
		}
		response, e := c.client.Do(request)
		if e != nil {
			c.add("network.broker_http", "warning", "Broker health endpoint could not be reached.", "Check service discovery, network policy and broker availability.", nil)
			return
		}
		response.Body.Close()
		status := "info"
		if response.StatusCode != 200 {
			status = "warning"
		}
		c.add("network.broker_http", status, "Broker HTTP health was checked without sending a bearer token or minting a game session.", "HTTP health does not establish that an authenticated account can mint tokens.", map[string]any{"http_status": response.StatusCode})
	}
}
