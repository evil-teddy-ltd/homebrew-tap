# evil-teddy-ltd/homebrew-tap

Homebrew formulae for Evil Teddy tools. The source repositories are private, so tap over SSH and keep `gh`
logged in: the formulae download release assets through the GitHub API with `HOMEBREW_GITHUB_API_TOKEN` or
`gh auth token`.

```sh
brew install gh && gh auth login
brew tap evil-teddy-ltd/tap git@github.com:evil-teddy-ltd/homebrew-tap.git
brew install operatord
```

| Formula | What it is |
|---|---|
| `operatord` | Switchboard host daemon and `operator` CLI. Set-up steps print after install; see docs/install.md in [switchboard](https://github.com/evil-teddy-ltd/switchboard). |

Releases are cut with `scripts/release.sh <version>` in the switchboard repo, which updates `version` and
`sha256` in `Formula/operatord.rb` here.
