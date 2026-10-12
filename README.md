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
translate -t ja 'Good morning'
```

Use `-t` for the target language. The source language is detected automatically when `-s` is omitted (or set to `auto`); use `-s` to specify it explicitly. 

> [!NOTE]
> For reliable detection, use text of at least 20 characters; 
> macOS may ask you to choose a language when it is unclear.

## License

MIT licensed. See [LICENSE](LICENSE).
