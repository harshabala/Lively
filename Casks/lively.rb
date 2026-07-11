cask "lively" do
  version "1.1.0"
  sha256 "98f14b07e6f00330ae7b60e4d94c1185a5dd24e3152c24200472766ffc89716f"

  url "https://github.com/harshabala/Lively/releases/download/v1.1.0/Lively-1.1.0-macOS.zip"
  name "Lively"
  desc "Native video wallpapers for every macOS Space and display"
  homepage "https://github.com/harshabala/Lively"

  depends_on macos: :sonoma

  app "Lively.app"

  # Lively is ad-hoc signed (no Apple Developer ID). Clear download quarantine
  # so Gatekeeper allows first launch without notarization.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{staged_path}/Lively.app"],
                   print_stderr: false
  end

  zap trash: [
    "~/Library/Application Support/Lively",
  ]
end