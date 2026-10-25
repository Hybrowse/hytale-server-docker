"""Render and check deployment behavior without accessing a cluster."""
import os
from pathlib import Path
import subprocess
import tempfile

import yaml

ROOT = Path(__file__).resolve().parents[1]
CHART = ROOT / "deploy/helm/hytale-server"
IMAGES = {
    "helm": "alpine/helm:4.3.1",
    "kustomize": "registry.k8s.io/kustomize/kustomize:v5.8.3",
    "kubeconform": "ghcr.io/yannh/kubeconform:v0.8.0",
}


def run(tool, *args, data=None, ok=True):
    cmd = [tool, *map(str, args)]
    if os.getenv("K8S_TEST_TOOLS") != "local":
        cmd = ["docker", "run", "--rm", "-i", "-v", f"{ROOT}:{ROOT}:ro",
               "-v", f"{TMP}:{TMP}", "-w", str(ROOT), IMAGES[tool], *map(str, args)]
    result = subprocess.run(cmd, input=data, text=True, capture_output=True)
    if ok and result.returncode:
        raise AssertionError(f"{' '.join(cmd)}\n{result.stdout}\n{result.stderr}")
    return result


def validate(text):
    run("kubeconform", "-strict", "-summary", "-kubernetes-version", "1.37.1", data=text)
    return [x for x in yaml.safe_load_all(text) if x]


def render(values=None, chart=CHART):
    args = ["template", "test", chart]
    if values:
        path = Path(TMP) / "values.yaml"
        path.write_text(yaml.safe_dump(values))
        args += ["-f", path]
    return validate(run("helm", *args).stdout)


def workload(docs):
    return next(d for d in docs if d["kind"] in ("StatefulSet", "Deployment"))


def assert_pod(w):
    pod = w["spec"]["template"]["spec"]
    c = pod["containers"][0]
    assert pod["automountServiceAccountToken"] is False
    assert pod["securityContext"]["runAsNonRoot"] is True
    assert c["securityContext"]["allowPrivilegeEscalation"] is False
    assert c["ports"][0]["protocol"] == "UDP"
    assert len({e["name"] for e in c["env"]}) == len(c["env"])
    assert len({v["name"] for v in pod["volumes"]}) == len(pod["volumes"])
    assert next(v for v in c["volumeMounts"] if v["name"] == "data")["mountPath"] == "/data"
    assert next(v for v in pod["volumes"] if v["name"] == "tmp")["emptyDir"].get("medium", "") != "Memory"
    return pod, c


def readiness_only(c):
    assert "readinessProbe" in c
    assert "startupProbe" not in c and "livenessProbe" not in c


with tempfile.TemporaryDirectory() as TMP:
    run("helm", "lint", CHART)
    default = workload(render())
    pod, c = assert_pod(default)
    assert c["image"] == "hybrowse/hytale-server:1.2.0"
    assert default["spec"]["volumeClaimTemplates"][0]["spec"]["resources"]["requests"]["storage"] == "20Gi"
    assert "readinessProbe" not in c
    print("PASS: Helm default image, security, storage and disk-backed temporary files")

    for kind in ["StatefulSet", "Deployment"]:
        for example in sorted((CHART / "examples").glob("*.yaml")):
            values = yaml.safe_load(example.read_text())
            values["workload"] = {"kind": kind}
            w = workload(render(values))
            pod, c = assert_pod(w)
            readiness_only(c)
            env = {e["name"]: e for e in c["env"]}
            assert env["HYTALE_AUTO_DOWNLOAD"]["value"] == "true"
            if example.stem == "native-updates":
                assert env["HYTALE_NATIVE_UPDATES"]["value"] == "true"
                assert env["HYTALE_AUTO_UPDATE"]["value"] == "false"
                assert env["HYTALE_ENABLE_BACKUP"]["value"] == "true"
            if example.stem == "broker":
                assert env["HYTALE_SESSION_TOKEN_BROKER_BEARER_TOKEN_SRC"]["value"] == "/run/broker-secret/token"
                assert env["HYTALE_DOWNLOADER_CREDENTIALS_SRC"]["value"] == "/run/secrets/hytale-downloader-credentials.json"
                assert next(v for v in c["volumeMounts"] if v["name"] == "downloader-credentials")["readOnly"]
            if kind == "Deployment":
                assert w["spec"]["strategy"] == {"type": "Recreate"}
                assert any(d["kind"] == "PersistentVolumeClaim" for d in render(values))
        print(f"PASS: {kind} first-start, native-update and broker examples")

    for kind in ["StatefulSet", "Deployment"]:
        docs = render({"workload": {"kind": kind}, "persistence": {"existingClaim": "existing-data"},
                       "secrets": {"serverAuth": {"name": "server-auth", "sessionTokenKey": "session", "identityTokenKey": "identity"},
                                   "curseforge": {"name": "curseforge", "apiKeyKey": "api-key"}}})
        w = workload(docs)
        pod, c = assert_pod(w)
        assert next(v for v in pod["volumes"] if v["name"] == "data")["persistentVolumeClaim"]["claimName"] == "existing-data"
        assert not any(d["kind"] == "PersistentVolumeClaim" for d in docs)
        assert "volumeClaimTemplates" not in w["spec"]
        env = {e["name"]: e for e in c["env"]}
        assert env["HYTALE_SERVER_SESSION_TOKEN"]["valueFrom"]["secretKeyRef"] == {"name": "server-auth", "key": "session"}
        assert env["HYTALE_SERVER_IDENTITY_TOKEN"]["valueFrom"]["secretKeyRef"]["key"] == "identity"
        assert next(v for v in c["volumeMounts"] if v["name"] == "curseforge-api-key")["readOnly"]
        ephemeral = workload(render({"workload": {"kind": kind}, "persistence": {"enabled": False}}))
        assert next(v for v in ephemeral["spec"]["template"]["spec"]["volumes"] if v["name"] == "data")["emptyDir"] == {}
    print("PASS: both workloads preserve existing claims, map secrets and support explicit ephemeral data")

    for args in [
        ["--set", "workload.kind=Deployment", "--set", "replicaCount=2"],
        ["--set", "persistence.existingClaim=shared-data", "--set", "replicaCount=2"],
    ]:
        result = run("helm", "template", "test", CHART, *args, ok=False)
        assert result.returncode and "shared persistent data volume" in result.stderr
    assert workload(render({"replicaCount": 2}))["spec"]["replicas"] == 2
    explicit = workload(render({"probes": {"enabled": True, "startup": {"enabled": True}, "liveness": {"enabled": True}}}))
    assert explicit["spec"]["template"]["spec"]["containers"][0]["startupProbe"]["failureThreshold"] == 180
    assert "livenessProbe" in explicit["spec"]["template"]["spec"]["containers"][0]
    invalid = run("helm", "template", "test", CHART, "--set", "probes.startup.failureThreshold=0", ok=False)
    assert invalid.returncode
    notes = run("helm", "install", "notes-test", CHART, "--dry-run=client",
                "--set", "workload.kind=Deployment", "--set", "persistence.enabled=false").stdout.split("NOTES:")[-1]
    assert "Deployment:" in notes and "WARNING: /data uses emptyDir" in notes
    assert "amd64-only" not in notes and "only the official downloader is emulated" in notes
    print("PASS: shared-volume replica guard, probe validation and workload-specific install notes")

    run("helm", "package", CHART, "--version", "9.8.7", "--app-version", "9.8.7", "--destination", TMP)
    package = workload(render(chart=Path(TMP) / "hytale-server-9.8.7.tgz"))
    assert package["spec"]["template"]["spec"]["containers"][0]["image"].endswith(":9.8.7")
    print("PASS: release packaging still pins the image to the release version")

    for path in [ROOT / "deploy/kustomize/base", *sorted((ROOT / "deploy/kustomize/overlays").iterdir())]:
        docs = validate(run("kustomize", "build", path).stdout)
        w = workload(docs)
        _, c = assert_pod(w)
        assert c["image"] == "hybrowse/hytale-server:1.2.0"
        if path.name in ["production", "probes"]:
            readiness_only(c)
        if path.name == "production":
            assert w["spec"]["volumeClaimTemplates"][0]["spec"]["resources"]["requests"]["storage"] == "20Gi"
        print(f"PASS: Kustomize {path.name}")

    for path in sorted((ROOT / "deploy/kubernetes/jobs").glob("*.yaml")):
        job = validate(path.read_text())[0]
        assert job["spec"]["backoffLimit"] == 0
        pod = job["spec"]["template"]["spec"]
        assert pod["restartPolicy"] == "Never"
        c = pod["containers"][0]
        assert c["command"] == ["/usr/local/bin/hytale-auto-download"]
        assert {e["name"]: e["value"] for e in c["env"]}["HYTALE_DOWNLOADER_RESET_CREDENTIALS"] == "true"
        assert not any("secret" in v for v in pod["volumes"])
        print(f"PASS: recovery Job {path.name}")
