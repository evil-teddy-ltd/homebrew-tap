require "json"
require "utils/curl"

# evil-teddy-ltd/switchboard is private, so a plain Homebrew URL gets a 404 for its release assets. This strategy
# resolves the asset through the GitHub API and downloads it with a token: HOMEBREW_GITHUB_API_TOKEN when set,
# otherwise whatever `gh auth login` stored. See docs/install.md in the switchboard repo.
class GitHubPrivateReleaseDownloadStrategy < CurlDownloadStrategy
  def initialize(url, name, version, **meta)
    super
    m = url.match(%r{\Ahttps://github\.com/([^/]+)/([^/]+)/releases/download/([^/]+)/(.+)\z})
    raise CurlDownloadStrategyError, "not a GitHub release asset URL: #{url}" unless m

    @owner, @repo, @tag, @asset_name = m.captures
  end

  private

  def github_token
    @github_token ||= begin
      token = ENV["HOMEBREW_GITHUB_API_TOKEN"].to_s.strip
      # Homebrew strips PATH while it downloads, so look for gh by full path.
      if token.empty?
        gh = ["#{HOMEBREW_PREFIX}/bin/gh", "/opt/homebrew/bin/gh", "/usr/local/bin/gh", which("gh").to_s].find { |g| File.executable?(g) }
        token = Utils.popen_read(gh, "auth", "token").strip if gh
      end
      raise CurlDownloadStrategyError, "no GitHub token for #{@owner}/#{@repo}: set HOMEBREW_GITHUB_API_TOKEN or run `gh auth login`" if token.empty?

      token
    end
  end

  def asset_id
    @asset_id ||= begin
      out = Utils::Curl.curl_output(
        "--silent", "--show-error", "--fail",
        "--header", "Authorization: Bearer #{github_token}",
        "--header", "Accept: application/vnd.github+json",
        "https://api.github.com/repos/#{@owner}/#{@repo}/releases/tags/#{@tag}",
      )
      raise CurlDownloadStrategyError, "cannot read release #{@tag} of #{@owner}/#{@repo}: #{out.stderr.strip}" unless out.success?

      asset = JSON.parse(out.stdout).fetch("assets", []).find { |a| a["name"] == @asset_name }
      raise CurlDownloadStrategyError, "release #{@tag} of #{@owner}/#{@repo} has no asset #{@asset_name}" unless asset

      asset["id"]
    end
  end

  def _fetch(url:, resolved_url:, timeout:)
    curl_download "https://api.github.com/repos/#{@owner}/#{@repo}/releases/assets/#{asset_id}",
                  "--header", "Authorization: Bearer #{github_token}",
                  "--header", "Accept: application/octet-stream",
                  to: temporary_path, timeout: timeout
  end
end

class Operatord < Formula
  desc "Switchboard host daemon: drive coding agents in tmux and herdr from your phone over Tailscale"
  homepage "https://github.com/evil-teddy-ltd/switchboard"
  version "0.1.20"
  url "https://github.com/evil-teddy-ltd/switchboard/releases/download/v#{version}/operatord-#{version}.tar.gz",
      using: GitHubPrivateReleaseDownloadStrategy
  sha256 "c496188904d710c4329dbda08817e9766427068357c96d1af835cb5d2bb67d70"

  depends_on "node"

  def install
    libexec.install "lib", "scripts"
    libexec.install "web" if File.directory?("web") # the browser client, from 0.1.1 on (docs/web.md)
    # opt_libexec, not libexec: the hook installers write the shim path into ~/.claude/settings.json, and the opt
    # link stays valid across upgrades where the versioned Cellar path would not.
    (bin/"operator").write <<~SH
      #!/bin/sh
      export OPERATOR_SCRIPTS_DIR="${OPERATOR_SCRIPTS_DIR:-#{opt_libexec}/scripts}"
      exec "#{Formula["node"].opt_bin}/node" "#{opt_libexec}/lib/operator.mjs" "$@"
    SH
  end

  service do
    run [opt_bin/"operator", "start"]
    keep_alive true
    working_dir HOMEBREW_PREFIX
    log_path var/"log/operatord.log"
    error_log_path var/"log/operatord.log"
    # tmux, herdr and tailscale from Homebrew; claude from ~/.local/bin; the Tailscale app's CLI when it is not from brew.
    environment_variables PATH:               "#{std_service_path_env}:/usr/local/bin:#{Dir.home}/.local/bin:/Applications/Tailscale.app/Contents/MacOS",
                          NODE_ENV:           "production",
                          # A filesystem call macOS holds open (a Files and Folders consent prompt) pins a libuv thread; keep spares.
                          UV_THREADPOOL_SIZE: "16"
  end

  def caveats
    <<~EOS
      First time on this host:
        operator init                          master token and ~/.operator
        brew services start operatord          launchd user agent, starts at login
        operator pair                          QR code to add this host in Switchboard
        operator hooks install --agent claude  also --agent gemini, --agent opencode
        operator doctor

      Switchboard in a browser, on this or any tailnet machine: http://<this host>:7777/
      Options for the service (OPERATOR_PORT, OPERATOR_BROWSE_ROOTS, ...) go in ~/.operator/env.
      Logs: #{var}/log/operatord.log
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/operator --version").strip
    assert_match "hook shims:  #{opt_libexec}/scripts", shell_output("#{bin}/operator doctor", 0)
  end
end
