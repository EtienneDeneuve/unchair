cask "unchair" do
  version "1.0.2"
  sha256 "f051d86a11257d227bf29e35d2c8c99dc450d38ecb35df9f54c7f9c0a0897017"

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
