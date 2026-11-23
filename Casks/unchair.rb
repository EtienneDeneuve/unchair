cask "unchair" do
  version "1.0.1"
  sha256 "7af69d0db4d1a05ea4f43f4d79f178e7e47370166e933910c17b2a74bff0d55b"

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
