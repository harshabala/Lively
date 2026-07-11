cask "lively" do
  version "1.1.1"
  sha256 "ad0de0817b09ae9f8a087610dcc2d90f2a5730a9dac64367663fd06467326ae0"

  url "https://github.com/harshabala/Lively/releases/download/v1.1.1/Lively-1.1.1-macOS.zip"
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