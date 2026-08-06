#!/bin/zsh

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
QUIET=0
unset CPATH C_INCLUDE_PATH CPLUS_INCLUDE_PATH LIBRARY_PATH SDKROOT SWIFT_EXEC
if [[ "${1:-}" == "--quiet" ]]; then
  QUIET=1
fi

DEVELOPER_PATH="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null)}"
SDK_PATH="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --sdk macosx --show-sdk-path 2>/dev/null)"
SWIFT_COMPILER="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --find swiftc 2>/dev/null)"
SWIFT_DRIVER="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --find swift 2>/dev/null)"

# Some internal Xcode installations keep the SDK-matching macOS compiler in a
# separate OSX*.xctoolchain while SwiftPM remains in the default toolchain.
matching_compilers=("$DEVELOPER_PATH"/Toolchains/OSX*.xctoolchain/usr/bin/swiftc(N))
if (( ${#matching_compilers} > 0 )); then
  SWIFT_COMPILER="${matching_compilers[-1]}"
fi

CHECK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/audio-delay-toolchain-check.XXXXXX")"
CHECK_LOG="$CHECK_DIR/compiler.log"
MODULE_CACHE_DIR="${CLANG_MODULE_CACHE_PATH:-$PROJECT_DIR/.build-cache/clang}"
cleanup() {
  rm -rf "$CHECK_DIR"
}
trap cleanup EXIT

mkdir -p "$MODULE_CACHE_DIR"
TARGET="$(uname -m)-apple-macos14.2"

if printf '%s\n' 'import Foundation' | \
  "$SWIFT_COMPILER" \
    -typecheck \
    -sdk "$SDK_PATH" \
    -target "$TARGET" \
    -module-cache-path "$MODULE_CACHE_DIR" \
    - >/dev/null 2>"$CHECK_LOG"; then
  exit 0
fi

diagnostic="$(/usr/bin/grep -m 1 -E \
  "this SDK is not supported by the compiler|redefinition of module 'SwiftBridging'" \
  "$CHECK_LOG" || true)"
failure_status=1
if [[ -n "$diagnostic" ]]; then
  failure_status=20
fi

if (( QUIET == 1 )); then
  exit "$failure_status"
fi

compiler_line="$("$SWIFT_COMPILER" --version 2>/dev/null | \
  /usr/bin/grep -m 1 'Apple Swift version' || true)"
compiler_identity="$(printf '%s\n' "$compiler_line" | /usr/bin/sed -E \
  's/.*Apple Swift version ([^ ]+).*swiftlang-([^ ]+).*/Apple Swift \1 (swiftlang-\2)/')"
if [[ -z "$compiler_identity" ]]; then
  compiler_identity="Unavailable"
fi

sdk_version="$(DEVELOPER_DIR="$DEVELOPER_PATH" xcrun --sdk macosx \
  --show-sdk-version 2>/dev/null || true)"
foundation_interfaces=(
  "$SDK_PATH"/System/Library/Frameworks/Foundation.framework/Modules/Foundation.swiftmodule/*-apple-macos.swiftinterface(N)
)
sdk_compiler_identity=""
if (( ${#foundation_interfaces} > 0 )); then
  sdk_compiler_line="$(/usr/bin/grep -m 1 'swift-compiler-version:' \
    "${foundation_interfaces[1]}" 2>/dev/null || true)"
  sdk_compiler_identity="$(printf '%s\n' "$sdk_compiler_line" | /usr/bin/sed -E \
    's/.*Apple Swift version ([^ ]+).*swiftlang-([^ ]+).*/Apple Swift \1 (swiftlang-\2)/')"
fi

package_manager_version="$(DEVELOPER_DIR="$DEVELOPER_PATH" \
  "$SWIFT_DRIVER" package --version 2>/dev/null || true)"
package_manager_version="${package_manager_version#Swift Package Manager - }"
if [[ -z "$package_manager_version" ]]; then
  package_manager_version="Unavailable"
fi
macos_version="$(sw_vers -productVersion 2>/dev/null || true)"
macos_build="$(sw_vers -buildVersion 2>/dev/null || true)"
machine_architecture="$(uname -m)"

echo >&2
echo "Apple Command Line Tools are incomplete or contain mixed versions." >&2
echo "The Swift compiler cannot use the macOS SDK installed beside it." >&2
echo "This is an Apple tools installation problem, not an Audio Delay problem." >&2
echo "Audio Delay build cannot proceed because the Apple build tools do not match." >&2
echo >&2
echo "macOS: ${macos_version:-Unknown} (build ${macos_build:-Unknown}, $machine_architecture)" >&2
echo "Swift compiler: $compiler_identity" >&2
if [[ -n "$sdk_compiler_identity" ]]; then
  echo "macOS SDK: ${sdk_version:-Unknown}, built with $sdk_compiler_identity" >&2
else
  echo "macOS SDK: ${sdk_version:-Unknown}" >&2
fi
echo "Swift Package Manager: $package_manager_version" >&2
echo >&2
if [[ -n "$diagnostic" ]]; then
  echo "Guided repair: available" >&2
  echo >&2
  echo "To replace the broken Apple Command Line Tools, run:" >&2
  echo "  sudo rm -rf /Library/Developer/CommandLineTools" >&2
  echo "  xcode-select --install" >&2
  echo >&2
  echo "Finish Apple's installer, then run the Audio Delay installer again." >&2
  echo >&2
  echo "Technical detail: $diagnostic" >&2
else
  fallback_diagnostic="$(/usr/bin/sed -n '1p' "$CHECK_LOG")"
  echo "Guided repair was not offered because this compiler failure was not recognized." >&2
  if [[ -n "$fallback_diagnostic" ]]; then
    echo "Technical detail: $fallback_diagnostic" >&2
  fi
fi

exit "$failure_status"
