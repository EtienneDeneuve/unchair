cask "unchair" do
  version "1.0.0"
  sha256 "ed57c01aa6b49f73561c136dd3684e3498cd82ea7aaf2d7bf1f1acc569e1604b"

  url "https://github.com/EtienneDeneuve/unchair/releases/download/v#{version}/Unchair-#{version}-macos.dmg"
  name "Unchair"
  desc "Local-first sit-break reminders with on-device Vision movement proof"
  homepage "https://etienne.deneuve.xyz/unchair/"

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
