#!/usr/bin/env bash
# Build + run the cajeta-cloud-local unit tests.
#
# The suite lives under src/test/cajeta and is driven by cajeta-unit's reflective
# @Test discovery. It compiles the library to a .cja, then the test sources into
# an executable with the library and every dependency archive on the classpath.
#
# Each dependency archive resolves in this order (the cajeta-cloud pattern):
#   1. $<NAME>_CJA       explicit path (CLOUD_CJA, CRYPTO_CJA, UNIT_CJA), used
#                        verbatim
#   2. the Olla store    $OLLA_HOME/<name>/<pin>/, at the cajeta.json pin
#   3. build/.dep-cache  an earlier fetch
#   4. Olla              /v2/resolve + /v2/blob, sha256-verified
# cajeta-unit additionally builds from a sibling checkout ($UNIT_REPO) when one
# exists, as the other libraries do.
#
# The tests write under a temp directory this script makes and removes; no
# network (cajeta-cloud-adapters spec §4.2).
#
# Env: CAJETA (compiler, default cajeta on PATH), OLLA_HOME, OLLA_URL, UNIT_REPO.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
CAJETA="${CAJETA:-cajeta}"
OLLA_HOME="${OLLA_HOME:-$HOME/.olla}"
OLLA_URL="${OLLA_URL:-https://olla.cajeta.dev}"
UNIT_REPO="${UNIT_REPO:-$here/../cajeta-unit}"

out="$(mktemp -d)"
# KEEP_OUT=1 keeps the build directory (the test binary) for a rerun or a debugger.
if [[ -n "${KEEP_OUT:-}" ]]; then echo ">> keeping $out"; else trap 'rm -rf "$out"' EXIT; fi

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1;
    else shasum -a 256 "$1" | cut -d' ' -f1; fi
}

# The version cajeta.json pins for <name>: dependencies, dev-dependencies, or
# overrides.
pin_of() {
    python3 -c 'import json,re,sys
t=re.sub(r"(?m)^\s*//.*$","",open(sys.argv[1]).read())
s=json.loads(t)["settings"]
d=dict(s.get("dependencies",{})); d.update(s.get("dev-dependencies",{}))
for k,v in s.get("overrides",{}).items(): d.setdefault(k, v if isinstance(v,str) else v.get("version",""))
print(d.get(sys.argv[2],""))' "$here/cajeta.json" "$1"
}

# resolve <name> <override-value>: print the path of the archive to use.
resolve() {
    local name="$1" override="$2"
    if [[ -n "$override" ]]; then printf '%s\n' "$override"; return; fi
    local ver; ver="$(pin_of "$name")"
    [[ -n "$ver" ]] || { echo "no $name pin in cajeta.json" >&2; exit 1; }
    local store="$OLLA_HOME/$name/$ver/$name-$ver.cja"
    local cache="$here/build/.dep-cache/$name-$ver.cja"
    if [[ -f "$store" ]]; then printf '%s\n' "$store"; return; fi
    if [[ -f "$cache" ]]; then printf '%s\n' "$cache"; return; fi
    echo ">> fetching $name $ver from $OLLA_URL" >&2
    local meta sha got
    meta="$(curl -fsS "$OLLA_URL/v2/resolve?name=$name&version=$ver")"
    sha="$(printf '%s' "$meta" | sed -n 's/.*"sha256":"sha256:\([0-9a-f]*\)".*/\1/p')"
    [[ -n "$sha" ]] || { echo "/v2/resolve gave no sha256 for $name $ver" >&2; exit 1; }
    mkdir -p "$(dirname "$cache")"
    curl -fsS -o "$cache" "$OLLA_URL/v2/blob/$sha"
    got="$(sha256_of "$cache")"
    [[ "$got" == "$sha" ]] || { rm -f "$cache"; echo "sha256 mismatch fetching $name" >&2; exit 1; }
    printf '%s\n' "$cache"
}

unit_cja="${UNIT_CJA:-}"
if [[ -z "$unit_cja" && -d "$UNIT_REPO" ]]; then
    echo ">> building cajeta-unit from checkout ($UNIT_REPO)"
    ( cd "$UNIT_REPO" && "$CAJETA" build >/dev/null )
    unit_cja="$( cd "$UNIT_REPO" && "$CAJETA" artifact-path 2>/dev/null )"
fi
unit_cja="$(resolve dev.cajeta.unit "$unit_cja")"
cloud_cja="$(resolve dev.cajeta.cloud "${CLOUD_CJA:-}")"
crypto_cja="$(resolve dev.cajeta.crypto "${CRYPTO_CJA:-}")"
for a in "$unit_cja" "$cloud_cja" "$crypto_cja"; do
    [[ -f "$a" ]] || { echo "missing archive: $a" >&2; exit 1; }
    echo ">> classpath: $a"
done
deps="$cloud_cja,$crypto_cja"

# details.version is the source of truth and Local.version() hands consumers a
# literal copy; the library cannot read its own manifest, so the check is here.
manifest_version="$( cd "$here" && "$CAJETA" info 2>/dev/null \
    | awk '/^[[:space:]]*version:/{print $2; exit}' )"
source_version="$(sed -n 's/.*version()[^"]*"\([^"]*\)".*/\1/p' \
    "$here/src/main/cajeta/dev/cajeta/cloud/local/Local.cajeta" | head -1)"
[[ -n "$manifest_version" && "$manifest_version" == "$source_version" ]] \
    || { echo "VERSION DRIFT: cajeta.json says '$manifest_version', Local.version() says '$source_version'" >&2; exit 1; }
echo ">> manifest: version $manifest_version matches Local.version()"

echo ">> building cloud-local library .cja"
"$CAJETA" --emit=cja --classpath="$deps" -o "$out/local.cja" \
    dev.cajeta.cloud.local.Local.run "$here/src/main/cajeta" "$out" >/dev/null

echo ">> building + running the test binary"
"$CAJETA" --emit=exe --profile=test \
    --classpath="$out/local.cja,$deps,$unit_cja" \
    -o "$out/localtests" \
    dev.cajeta.cloud.local.selftest.TestMain.run "$here/src/test/cajeta" "$out" >/dev/null

mkdir -p "$out/roots"
CAJETA_LOCAL_TEST_TMP="$out/roots" "$out/localtests"
