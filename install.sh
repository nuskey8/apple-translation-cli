#!/bin/sh
set -eu

fail() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

[ "$(uname -s)" = Darwin ] || fail 'macOS 26 or later is required.'
os_version=$(sw_vers -productVersion)
[ "${os_version%%.*}" -ge 26 ] || fail 'macOS 26 or later is required.'
case "$(uname -m)" in
    arm64|x86_64) ;;
    *) fail 'Unsupported architecture.' ;;
esac

repo_url=https://github.com/nuskey8/apple-translation-cli
asset=translate-macos-universal.tar.gz
install_dir="$HOME/.local/bin"
temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/translate-install.XXXXXX")
trap 'rm -rf "$temp_dir"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

printf 'Finding the latest release…\n'
# Resolve once so both files come from the same release, even during a new publish.
release_url=$(curl --fail --silent --show-error --location --head \
    --proto '=https' --proto-redir '=https' \
    --output /dev/null --write-out '%{url_effective}' "$repo_url/releases/latest")
case "$release_url" in
    "$repo_url/releases/tag/"*) ;;
    *) fail 'Could not find the latest release.' ;;
esac
tag=${release_url##*/}
download_url="$repo_url/releases/download/$tag"

for file in "$asset" SHA256SUMS; do
    curl --fail --silent --show-error --location \
        --proto '=https' --proto-redir '=https' \
        "$download_url/$file" --output "$temp_dir/$file"
done

checksum=$(awk -v asset="$asset" '$2 == asset { print $1 }' "$temp_dir/SHA256SUMS")
[ "${#checksum}" -eq 64 ] || fail 'Invalid SHA-256 checksum.'
case "$checksum" in
    *[!0-9a-fA-F]*) fail 'Invalid SHA-256 checksum.' ;;
esac
(
    cd "$temp_dir"
    printf '%s  %s\n' "$checksum" "$asset" | shasum -a 256 --check --status
) || fail 'Checksum verification failed.'

tar -xzf "$temp_dir/$asset" -C "$temp_dir" translate
[ -f "$temp_dir/translate" ] && [ ! -L "$temp_dir/translate" ] \
    || fail 'Release archive does not contain a regular translate binary.'
mkdir -p "$install_dir"
install -m 755 "$temp_dir/translate" "$install_dir/translate"
printf 'Installed translate %s to %s/translate\n' "$tag" "$install_dir"

case ":$PATH:" in
    *":$install_dir:"*) exit 0 ;;
esac

shell_name=${SHELL:-}
case "${shell_name##*/}" in
    zsh)
        config_file="${ZDOTDIR:-$HOME}/.zshrc"
        path_line='export PATH="$HOME/.local/bin:$PATH"'
        ;;
    bash)
        config_file="$HOME/.bash_profile"
        path_line='export PATH="$HOME/.local/bin:$PATH"'
        ;;
    fish)
        config_file="${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
        path_line='fish_add_path --path "$HOME/.local/bin"'
        ;;
    *)
        printf 'Add %s to your PATH to use translate.\n' "$install_dir"
        exit 0
        ;;
esac

mkdir -p "$(dirname "$config_file")"
if ! grep -Fqx "$path_line" "$config_file" 2>/dev/null; then
    printf '\n%s\n' "$path_line" >> "$config_file"
fi
printf 'PATH configured in %s. Open a new terminal to use translate.\n' "$config_file"
