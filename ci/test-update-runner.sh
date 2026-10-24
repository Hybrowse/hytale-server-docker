#!/bin/sh
set -eu
IMAGE_NAME="${IMAGE_NAME:-hytale-server:test}"
workdir="$(mktemp -d)"
name="hytale-update-runner-test-$$"
clean_container_files() {
 if [ -d "${workdir}/data/updater" ]; then
  docker run --rm --entrypoint sh -v "${workdir}/data:/data" "${IMAGE_NAME}" -c 'rm -rf /data/updater' >/dev/null
 fi
}
cleanup() {
 docker rm -f "${name}" >/dev/null 2>&1 || true
 clean_container_files || true
 rm -rf "${workdir}"
}
trap cleanup EXIT INT TERM
chmod 0777 "${workdir}"
mkdir "${workdir}/fixture"
printf 'version' > "${workdir}/fixture/version"
(cd "${workdir}/fixture" && zip -q "${workdir}/server.jar" version)
cat > "${workdir}/java" <<'JAVA'
#!/bin/sh
set -eu
printf 'started\n' >> /data/starts
case "${TEST_MODE}" in
 update)
  if [ ! -f /data/requested ]; then
   mkdir -p /data/updater/staging/Server
   cp /fixture/server.jar /data/updater/staging/Server/HytaleServer.jar
   cp /fixture/server.jar /data/updater/staging/Assets.zip
   : > /data/requested
   exit 8
  fi
  [ ! -d /data/updater/staging ]
  [ ! -f /data/server/HytaleServer.aot ]
  [ -f /data/updater/image-backup/previous/jar ]
  exit 0
  ;;
 no-stage) exit 8 ;;
 crash) exit 37 ;;
 signal)
  trap 'sleep 1; touch /data/saved; exit 0' TERM
  touch /data/ready
  while :; do sleep 1; done
  ;;
 *) exit 0 ;;
esac
JAVA
chmod 0755 "${workdir}/java"
prepare_data() {
 clean_container_files
 rm -rf "${workdir}/data"
 mkdir -p "${workdir}/data/server"
 chmod 0777 "${workdir}/data" "${workdir}/data/server"
 cp "${workdir}/server.jar" "${workdir}/data/server/HytaleServer.jar"
 cp "${workdir}/server.jar" "${workdir}/data/Assets.zip"
 chmod 0666 "${workdir}/data/server/HytaleServer.jar" "${workdir}/data/Assets.zip"
 printf 'old cache' > "${workdir}/data/server/HytaleServer.aot"
 chmod 0666 "${workdir}/data/server/HytaleServer.aot"
}
start_test() {
 docker run -d --name "${name}" -e HYTALE_NATIVE_UPDATES=true -e ENABLE_AOT=false -e TEST_MODE="$1" \
  -v "${workdir}/data:/data" -v "${workdir}/java:/opt/java/openjdk/bin/java:ro" \
  -v "${workdir}/server.jar:/fixture/server.jar:ro" "${IMAGE_NAME}" >/dev/null
}
wait_test() {
 for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15; do
  [ "$(docker inspect -f '{{.State.Running}}' "${name}")" = true ] || return 0
  sleep 1
 done
 echo 'Update runner did not terminate' >&2; docker logs "${name}" >&2; exit 1
}
for mode in update no-stage crash; do
 prepare_data
 start_test "${mode}"
 wait_test
 docker logs "${name}" >&2
 status="$(docker inspect -f '{{.State.ExitCode}}' "${name}")"
 case "${mode}" in
  update) [ "${status}" = 0 ]; [ "$(wc -l < "${workdir}/data/starts" | tr -d ' ')" = 2 ] ;;
  no-stage) [ "${status}" != 0 ]; [ "$(wc -l < "${workdir}/data/starts" | tr -d ' ')" = 1 ] ;;
  crash) [ "${status}" = 37 ]; [ "$(wc -l < "${workdir}/data/starts" | tr -d ' ')" = 1 ] ;;
 esac
 docker rm "${name}" >/dev/null
done
prepare_data
start_test signal
for i in 1 2 3 4 5 6 7 8 9 10; do [ -f "${workdir}/data/ready" ] && break; sleep 1; done
[ -f "${workdir}/data/ready" ]
# A second runner must fail before starting Java on the shared volume.
if docker run --rm -e HYTALE_NATIVE_UPDATES=true -v "${workdir}/data:/data" "${IMAGE_NAME}" > "${workdir}/second" 2>&1; then exit 1; fi
grep -q 'Another native-update runner' "${workdir}/second"
docker stop -t 10 "${name}" >/dev/null
[ -f "${workdir}/data/saved" ]
[ "$(docker inspect -f '{{.State.ExitCode}}' "${name}")" = 143 ]
[ "$(wc -l < "${workdir}/data/starts" | tr -d ' ')" = 1 ]
echo 'PASS: exit-8 update restart, crash exit status, volume lock and graceful termination'
