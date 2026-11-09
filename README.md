# evil-teddy-ltd/homebrew-tap

Homebrew formulae for Evil Teddy tools.

```sh
brew tap evil-teddy-ltd/tap
brew install operatord
```

| Formula | What it is |
|---|---|
| `operatord` | The [Switchboard](https://evil-teddy.com/switchboard) host daemon and `operator` CLI. Set-up steps print after install. |

The release tarballs are attached to this repository's own
[releases](https://github.com/evil-teddy-ltd/homebrew-tap/releases), so Homebrew downloads them without a GitHub
login. They are built by the switchboard repository's release workflow and mirrored here by its
`scripts/release.sh <version>`, which also updates `version` and `sha256` in `Formula/operatord.rb`.

Support: ash@evil-teddy.com.
