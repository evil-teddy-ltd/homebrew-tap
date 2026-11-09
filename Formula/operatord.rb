class Operatord < Formula
  desc "Host daemon for Switchboard: drive your coding agents from your phone"
  homepage "https://evil-teddy.com/switchboard"
  version "0.1.22"

  # One self-contained executable per platform, attached to this tap's own releases by scripts/release.sh in the
  # switchboard repository. It carries its own Node, the hook shims and the browser client; nothing else is needed.
  on_macos do
    on_arm do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-darwin-arm64.tar.gz"
      sha256 "43ea9cce1d1dd5ece56471575688fbb5aea0b72c71d6e842619804df52f9bece" # darwin-arm64
    end
    on_intel do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-darwin-x64.tar.gz"
      sha256 "e60f81da891c4e7209e10e70a680f7465cff2a152dc6149b251637742b98c4f4" # darwin-x64
    end
  end
  on_linux do
    on_arm do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-linux-arm64.tar.gz"
      sha256 "34394e4c3e26689371c0a6a138956b188895e05ade0ac23bc118b32fd1a65fa5" # linux-arm64
    end
    on_intel do
      url "https://github.com/evil-teddy-ltd/homebrew-tap/releases/download/v#{version}/operatord-#{version}-linux-x64.tar.gz"
      sha256 "ad8dfb8692f0c32dd2232b9efc80948f991b4d77cc1c26a68319b32bc6542202" # linux-x64
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
