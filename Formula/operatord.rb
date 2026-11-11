class Operatord < Formula
  desc "Host daemon for Switchboard: drive your coding agents from your phone"
  homepage "https://evil-teddy.com/switchboard"
  version "0.1.23"

  # One self-contained executable per platform, attached to this tap's own releases by scripts/release.sh in the
  # switchboard repository. It carries its own Node, the hook shims and the browser client; nothing else is needed.
  on_macos do
    on_arm do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-darwin-arm64.tar.gz"
      sha256 "5e823d2ce3f1466057552f10601f54e6c0bf97f160c9f3f61a4afabeb73a047f" # darwin-arm64
    end
    on_intel do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-darwin-x64.tar.gz"
      sha256 "7ca7b5de6acd256a1f5e394e93d15127a0da66119eeb9692ab7453c10a64dcaf" # darwin-x64
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-linux-arm64.tar.gz"
      sha256 "9584caf7aafe82778c4fe48d852f44f333e6d146962aa6ab85f219625cb55025" # linux-arm64
    end
    on_intel do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-linux-x64.tar.gz"
      sha256 "2d2869665ceecbf84ad2e18da9725b7527585444d598b696baeb5ce0e6af18b6" # linux-x64
    end
  end

  def install
    libexec.install "operator"
    # The hook installers write the shim path into ~/.claude/settings.json, so the shims live at a path that
    # survives upgrades: opt_libexec, not the versioned Cellar. The executable writes them out of itself.
    system libexec/"operator", "shims", "export", libexec/"scripts"
    (bin/"operator").write <<~SH
      #!/bin/sh
      export OPERATOR_SCRIPTS_DIR="${OPERATOR_SCRIPTS_DIR:-#{opt_libexec}/scripts}"
      exec "#{opt_libexec}/operator" "$@"
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
    # Not `operator doctor`: it asks tmux for its panes, and the test sandbox denies the tmux socket.
    assert_equal version.to_s, shell_output("#{bin}/operator --version").strip
    system bin/"operator", "shims", "export", testpath/"shims"
    assert_predicate testpath/"shims/operator-hook.sh", :executable?
    assert_path_exists opt_libexec/"scripts/operator-gemini-hook.sh"
  end
end
