cask "unchair" do
  version "1.0.0"
  sha256 "00bd60b8bc5f573e9cd75c80004fcff486a4d098129ef1cd774fd6eaa8d26c1f"

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
