#!/bin/zsh

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 /path/to/sox /path/to/App.app/Contents/Resources" >&2
    exit 64
fi

SOX_SOURCE="$1"
RESOURCES_DIR="$2"
SOX_DEST="$RESOURCES_DIR/sox"
LIB_DIR="$RESOURCES_DIR/lib"
LICENSE_DIR="$RESOURCES_DIR/licenses"

if [[ ! -x "$SOX_SOURCE" ]]; then
    echo "SoX is not executable: $SOX_SOURCE" >&2
    exit 1
fi

mkdir -p "$LIB_DIR" "$LICENSE_DIR"
cp -L "$SOX_SOURCE" "$SOX_DEST"
chmod 755 "$SOX_DEST"

copy_dependencies() {
    local binary="$1"
    local dependency basename destination

    while IFS= read -r dependency; do
        case "$dependency" in
            /System/*|/usr/lib/*|@loader_path/*|@rpath/*|@executable_path/*) continue ;;
        esac

        basename="${dependency:t}"
        destination="$LIB_DIR/$basename"
        if [[ ! -e "$destination" ]]; then
            cp -L "$dependency" "$destination"
            chmod 755 "$destination"
            copy_dependencies "$destination"
        fi
    done < <(otool -L "$binary" | tail -n +2 | awk '{print $1}')
}

rewrite_dependencies() {
    local binary="$1"
    local prefix="$2"
    local dependency basename

    while IFS= read -r dependency; do
        case "$dependency" in
            /System/*|/usr/lib/*|@loader_path/*|@rpath/*|@executable_path/*) continue ;;
        esac
        basename="${dependency:t}"
        install_name_tool -change "$dependency" "$prefix/$basename" "$binary"
    done < <(otool -L "$binary" | tail -n +2 | awk '{print $1}')
}

copy_dependencies "$SOX_DEST"
rewrite_dependencies "$SOX_DEST" "@loader_path/lib"

for library in "$LIB_DIR"/*.dylib(N); do
    install_name_tool -id "@loader_path/${library:t}" "$library"
    rewrite_dependencies "$library" "@loader_path"
done

# These files are copied for third-party attribution. Release packaging should
# retain them alongside the bundled executable and libraries.
if command -v brew >/dev/null 2>&1; then
    formulas=(sox ${(f)"$(brew deps --formula sox 2>/dev/null || true)"})
    for formula in $formulas; do
        prefix="$(brew --prefix "$formula" 2>/dev/null || true)"
        [[ -d "$prefix" ]] || continue
        prefix="$(cd "$prefix" && pwd -P)"
        formula_license_dir="$LICENSE_DIR/$formula"
        mkdir -p "$formula_license_dir"
        while IFS= read -r license; do
            cp "$license" "$formula_license_dir/${license:t}"
        done < <(find "$prefix" -maxdepth 2 -type f \
            \( -iname 'license*' -o -iname 'copying*' -o -iname 'notice*' \) 2>/dev/null)
        rmdir "$formula_license_dir" 2>/dev/null || true
    done
fi

# install_name_tool invalidates any existing signatures.
for library in "$LIB_DIR"/*.dylib(N); do
    codesign --force --sign - "$library"
done
codesign --force --sign - "$SOX_DEST"

echo "Bundled SoX and $(find "$LIB_DIR" -type f | wc -l | tr -d ' ') libraries."
