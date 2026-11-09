cask "unchair" do
  version "0.3.4"
  sha256 "ba433e8f657be78f435aa786b40ff5ae1b1c3b6f544718458411323467316f40"

  url "https://github.com/EtienneDeneuve/unchair/releases/download/v#{version}/Unchair-#{version}-macos.dmg"
  name "Unchair"
  desc "Local-first sit-break reminders with on-device Vision movement proof"
  homepage "https://github.com/EtienneDeneuve/unchair"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: :sonoma

  app "Unchair.app"

  zap trash: [
    "~/Library/Application Support/Unchair",
    "~/Library/Preferences/com.etiennedeneuve.unchair.plist",
  ]
end
