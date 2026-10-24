#!/bin/sh
set -eu
workdir="$(mktemp -d)"
trap 'rm -rf "${workdir}"' EXIT INT TERM
export DATA_DIR="${workdir}/data"
apply=/usr/local/bin/hytale-apply-update
reset_data() {
  rm -rf "${DATA_DIR}"
  mkdir -p "${DATA_DIR}/server/universe" "${DATA_DIR}/server/mods" "${DATA_DIR}/updater/staging/Server/Licenses"
  cp /fixture/old.jar "${DATA_DIR}/server/HytaleServer.jar"
  cp /fixture/old-assets.zip "${DATA_DIR}/Assets.zip"
  printf 'saved-login' > "${DATA_DIR}/server/auth.enc"
  printf 'saved-config' > "${DATA_DIR}/server/config.json"
  printf 'world' > "${DATA_DIR}/server/universe/marker"
  printf 'mod' > "${DATA_DIR}/server/mods/marker"
  printf 'cache' > "${DATA_DIR}/server/HytaleServer.aot"
  cp /fixture/new.jar "${DATA_DIR}/updater/staging/Server/HytaleServer.jar"
  cp /fixture/new-assets.zip "${DATA_DIR}/updater/staging/Assets.zip"
  printf 'new license' > "${DATA_DIR}/updater/staging/Server/Licenses/license.txt"
  printf 'new AOT input' > "${DATA_DIR}/updater/staging/Server/HytaleServer.aot.config"
  printf 'must not install' > "${DATA_DIR}/updater/staging/Server/config.json"
  printf 'must not install' > "${DATA_DIR}/updater/staging/Server/auth.enc"
}
assert_old() {
  cmp /fixture/old.jar "${DATA_DIR}/server/HytaleServer.jar"
  cmp /fixture/old-assets.zip "${DATA_DIR}/Assets.zip"
  [ "$(cat "${DATA_DIR}/server/auth.enc")" = saved-login ]
  [ "$(cat "${DATA_DIR}/server/universe/marker")" = world ]
}
reset_data
"${apply}"
cmp /fixture/new.jar "${DATA_DIR}/server/HytaleServer.jar"
cmp /fixture/new-assets.zip "${DATA_DIR}/Assets.zip"
[ ! -e "${DATA_DIR}/server/HytaleServer.aot" ]
[ "$(cat "${DATA_DIR}/server/HytaleServer.aot.config")" = 'new AOT input' ]
[ "$(cat "${DATA_DIR}/server/Licenses/license.txt")" = 'new license' ]
[ "$(cat "${DATA_DIR}/server/auth.enc")" = saved-login ]
[ "$(cat "${DATA_DIR}/server/config.json")" = saved-config ]
[ "$(cat "${DATA_DIR}/server/universe/marker")" = world ]
[ "$(cat "${DATA_DIR}/server/mods/marker")" = mod ]
[ ! -e "${DATA_DIR}/updater/staging" ]
cmp /fixture/old.jar "${DATA_DIR}/updater/image-backup/previous/jar"
cmp /fixture/old-assets.zip "${DATA_DIR}/updater/image-backup/previous/assets"

for invalid in missing-jar corrupt-jar corrupt-assets link special; do
  reset_data
  case "$invalid" in
    missing-jar) rm "${DATA_DIR}/updater/staging/Server/HytaleServer.jar" ;;
    corrupt-jar) echo broken > "${DATA_DIR}/updater/staging/Server/HytaleServer.jar" ;;
    corrupt-assets) echo broken > "${DATA_DIR}/updater/staging/Assets.zip" ;;
    link) ln -s "${DATA_DIR}/server/auth.enc" "${DATA_DIR}/updater/staging/Server/link" ;;
    special) mkfifo "${DATA_DIR}/updater/staging/pipe" ;;
  esac
  if "${apply}" >/dev/null 2>&1; then echo "Invalid staging accepted: $invalid" >&2; exit 1; fi
  assert_old
done

# Fail a replacement after the JAR has already changed. The whole old pair must return.
reset_data
mkdir "${workdir}/bin"
cat > "${workdir}/bin/mv" <<'MV'
#!/bin/sh
for last do :; done
if [ "$last" = "${DATA_DIR}/Assets.zip" ] && [ ! -f "${DATA_DIR}/failed-once" ]; then
  : > "${DATA_DIR}/failed-once"
  exit 39
fi
exec /usr/bin/mv "$@"
MV
chmod +x "${workdir}/bin/mv"
if PATH="${workdir}/bin:${PATH}" "${apply}" >/dev/null 2>&1; then exit 1; fi
assert_old
[ -d "${DATA_DIR}/updater/staging" ]
[ ! -d "${DATA_DIR}/updater/image-transaction" ]

# Simulate a killed process after replacing the JAR, with the transaction still present.
reset_data
mkdir -p "${DATA_DIR}/updater/image-transaction/previous"
cp /fixture/old.jar "${DATA_DIR}/updater/image-transaction/previous/jar"
cp /fixture/old-assets.zip "${DATA_DIR}/updater/image-transaction/previous/assets"
printf 'installing\n' > "${DATA_DIR}/updater/image-transaction/phase"
cp /fixture/new.jar "${DATA_DIR}/server/HytaleServer.jar"
printf 'incomplete next download' > "${DATA_DIR}/updater/staging/Server/HytaleServer.jar"
if "${apply}" >/dev/null 2>&1; then exit 1; fi
assert_old
[ ! -d "${DATA_DIR}/updater/image-transaction" ]
echo 'PASS: update validation, managed files, cache invalidation, failure rollback and interrupted transaction recovery'
