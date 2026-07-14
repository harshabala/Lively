cask "lively" do
  version "1.2.0"
  sha256 "f6942708e50d8a2339da5ed49dbfccc08ff38dc485ac0f0273ebc467962d8ecb"

  url "https://github.com/harshabala/Lively/releases/download/v1.2.0/Lively-1.2.0-macOS.zip"
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
