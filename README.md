# translate

Translate text using Apple's on-device Translation API. Requires macOS 26 or later.

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/nuskey8/apple-translation-cli/main/install.sh | sh
```

Installs the latest release to `~/.local/bin` and configures PATH for zsh, bash, or fish.

## Usage

```sh
translate -s en -t ja 'Hello, world!'
printf 'こんにちは' | translate -s ja -t en
```

Use `-s` for the source language and `-t` for the target language.

## License

MIT licensed. See [LICENSE](LICENSE).
