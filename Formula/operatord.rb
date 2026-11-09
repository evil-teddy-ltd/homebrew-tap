class Operatord < Formula
  desc "Switchboard host daemon: drive coding agents in tmux and herdr from your phone over Tailscale"
  homepage "https://evil-teddy.com/switchboard"
  version "0.1.21"
  # The tarball is attached to this tap's own release: scripts/release.sh in the switchboard repository mirrors it
  # here from the (private) switchboard release, so the URL is public and plain Homebrew downloads it.
  url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}.tar.gz"
  sha256 "3291a7d29cee0c5d2ce47e90ad81855b1e6c40323dd182306ceca3c2accb9f05"

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
      Help: https://evil-teddy.com/switchboard
    EOS
  end

  test do
    assert_equal version.to_s, shell_output("#{bin}/operator --version").strip
    assert_match "hook shims:  #{opt_libexec}/scripts", shell_output("#{bin}/operator doctor", 0)
  end
end
