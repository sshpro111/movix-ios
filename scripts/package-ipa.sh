#!/bin/bash
set -euo pipefail

app_input="${1:-build/DerivedData/Build/Products/Release-iphoneos/Movix.app}"
output_input="${2:-dist}"
if [ ! -d "$app_input" ]; then
  printf 'Compiled application missing: %s\n' "$app_input" >&2
  exit 1
fi
app_path="$(cd "$(dirname "$app_input")" && pwd)/$(basename "$app_input")"
mkdir -p "$output_input"
output_path="$(cd "$output_input" && pwd)"
plist_path="$app_path/Info.plist"
executable_name="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist_path")"
executable_path="$app_path/$executable_name"

if [ ! -f "$executable_path" ]; then
  printf 'Application executable is missing.\n' >&2
  exit 1
fi
architecture="$(xcrun lipo -archs "$executable_path")"
if [ "$architecture" != arm64 ]; then
  printf 'Expected arm64 iPhone executable; found: %s\n' "$architecture" >&2
  exit 1
fi
xcrun vtool -show-build "$executable_path" | tee "$output_path/macho-platform.txt"
if ! grep -Eq '^[[:space:]]*platform IOS[[:space:]]*$' "$output_path/macho-platform.txt"; then
  printf 'Mach-O is not built for iPhoneOS.\n' >&2
  exit 1
fi
if codesign --display "$app_path" >/dev/null 2>&1; then
  printf 'Expected an unsigned application.\n' >&2
  exit 1
fi
xcrun otool -l "$executable_path" > "$output_path/macho-load-commands.txt"
if grep -q 'cmd LC_CODE_SIGNATURE' "$output_path/macho-load-commands.txt"; then
  printf 'Unexpected code-signature load command.\n' >&2
  exit 1
fi
if [ -d "$app_path/_CodeSignature" ]; then
  printf 'Unexpected bundle code signature.\n' >&2
  exit 1
fi
if [ -f "$app_path/embedded.mobileprovision" ]; then
  printf 'Unexpected embedded signing profile.\n' >&2
  exit 1
fi

export MOVIX_APP_PATH="$app_path"
export MOVIX_OUTPUT_PATH="$output_path"
python3 - <<'PY'
import json, os, plistlib, subprocess
from pathlib import Path

app = Path(os.environ['MOVIX_APP_PATH'])
plist = plistlib.loads((app / 'Info.plist').read_bytes())
assert plist.get('CFBundleSupportedPlatforms') == ['iPhoneOS'], 'Not an iPhoneOS bundle'
assert plist.get('DTPlatformName') == 'iphoneos', 'Incorrect SDK platform'
assert plist.get('MinimumOSVersion') == '16.0', 'Expected iOS 16 deployment target'
assert plist.get('UIDeviceFamily') == [1], 'Expected an iPhone application'
ats = plist.get('NSAppTransportSecurity', {})
assert not ats.get('NSAllowsArbitraryLoads'), 'HTTPS protections must stay enabled'
assert not ats.get('NSAllowsArbitraryLoadsInWebContent'), 'WKWebView HTTPS protections must stay enabled'
assert not ats.get('NSExceptionDomains'), 'Unexpected ATS domain exceptions'
info = {
    'application': plist.get('CFBundleDisplayName', 'Movix'),
    'bundle_identifier': plist['CFBundleIdentifier'],
    'version': plist['CFBundleShortVersionString'],
    'build': plist['CFBundleVersion'],
    'minimum_ios': plist['MinimumOSVersion'],
    'architecture': 'arm64',
    'platform': 'iPhoneOS',
    'signed': False,
    'source_commit': os.environ.get('MOVIX_COMMIT', ''),
    'workflow_url': os.environ.get('MOVIX_RUN_URL', ''),
    'xcode': subprocess.check_output(['xcodebuild', '-version'], text=True).strip(),
    'iphoneos_sdk': subprocess.check_output(['xcrun', '--sdk', 'iphoneos', '--show-sdk-version'], text=True).strip(),
}
(Path(os.environ['MOVIX_OUTPUT_PATH']) / 'build-info.json').write_text(
    json.dumps(info, ensure_ascii=False, indent=2) + '\n', encoding='utf-8'
)
print(json.dumps(info, ensure_ascii=False, indent=2))
PY

staging_path="$(mktemp -d "${TMPDIR:-/tmp}/movix-ipa.XXXXXX")"
trap 'rm -rf "$staging_path"' EXIT
mkdir -p "$staging_path/Payload"
ditto "$app_path" "$staging_path/Payload/Movix.app"
ipa_path="$output_path/Movix-unsigned.ipa"
if [ -e "$ipa_path" ]; then
  rm -f "$ipa_path"
fi
(
  cd "$staging_path"
  /usr/bin/zip -q -r -y "$ipa_path" Payload
)
/usr/bin/unzip -t "$ipa_path"
(
  cd "$output_path"
  shasum -a 256 Movix-unsigned.ipa > Movix-unsigned.ipa.sha256
)
printf 'Unsigned iPhone IPA created: %s\n' "$ipa_path"
