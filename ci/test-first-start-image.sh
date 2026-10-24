#!/bin/sh
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
workdir="$(mktemp -d)"
name="hytale-first-start-test-$$"
cleanup() { docker rm -f "${name}" >/dev/null 2>&1 || true; rm -rf "${workdir}"; }
trap cleanup EXIT INT TERM
chmod 0777 "${workdir}"
mkdir "${workdir}/server"
chmod 0777 "${workdir}/server"
: > "${workdir}/server/HytaleServer.jar"
: > "${workdir}/Assets.zip"
cat > "${workdir}/java" <<'JAVA'
#!/bin/sh
set -eu
IFS= read -r first
IFS= read -r second
[ "$first" = '/auth persistence Encrypted' ]
[ "$second" = '/auth login device' ]
: > /data/received-login-commands
JAVA
chmod 0755 "${workdir}/java"
docker run -d --name "${name}" -e ENABLE_AOT=false \
  -v "${workdir}:/data" -v "${workdir}/java:/opt/java/openjdk/bin/java:ro" "${IMAGE_NAME}" >/dev/null
for i in 1 2 3 4 5 6 7 8 9 10; do
  [ "$(docker inspect -f '{{.State.Running}}' "${name}")" = true ] || break
  sleep 1
done
[ "$(docker inspect -f '{{.State.Running}}' "${name}")" = false ] || { echo 'First-start commands were not delivered' >&2; exit 1; }
[ "$(docker inspect -f '{{.State.ExitCode}}' "${name}")" = 0 ]
[ -f "${workdir}/received-login-commands" ]
echo 'PASS: automatic login commands reach Java without a terminal'
