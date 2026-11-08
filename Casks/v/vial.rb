cask "vial" do
  version "0.7.5"
  sha256 "b0df22fcc38f85a2d9e2224d2b3fcc76944819365557f1b9a83ee8f880fc7403"

  url "https://github.com/vial-kb/vial-gui/releases/download/v#{version}/Vial-v#{version}-x86_64.AppImage"
  name "Vial"
  desc "Configure QMK keyboards in real time"
  homepage "https://get.vial.today/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on arch: :x86_64

  binary "Vial-v#{version}-x86_64.AppImage", target: "vial"
  artifact "vial.desktop",
           target: "#{Dir.home}/.local/share/applications/vial.desktop"
  artifact "Vial.png",
           target: "#{Dir.home}/.local/share/icons/hicolor/512x512/apps/vial.png"

  # The icon lives inside the AppImage's squashfs; the AppImage extracts
  # single paths itself, so no FUSE is needed.
  preflight_steps do
    set_permissions "Vial-v#{version}-x86_64.AppImage", "0755"
    run "./Vial-v#{version}-x86_64.AppImage",
        args:           ["--appimage-extract", "usr/share/icons/hicolor/512x512/apps/Vial.png"],
        chdir:          ".",
        writable_paths: ["."]
    move "squashfs-root/usr/share/icons/hicolor/512x512/apps/Vial.png", "Vial.png"
    write_file "vial.desktop", <<~DESKTOP
      [Desktop Entry]
      Name=Vial
      Comment=Configure QMK keyboards in real time
      Exec={{HOMEBREW_PREFIX}}/bin/vial
      Terminal=false
      Type=Application
      Icon=vial
      Categories=Utility;
    DESKTOP
  end

  zap trash: "~/.config/Vial"

  caveats <<~EOS
    Vial talks to the keyboard over hidraw, so Linux needs a udev rule that a
    cask cannot install. Once, as root (59-vial.rules, not 99-):

      echo 'KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"' \\
        | sudo tee /etc/udev/rules.d/59-vial.rules
      sudo udevadm control --reload-rules && sudo udevadm trigger

    Replug the keyboard afterwards. Details: https://get.vial.today/manual/linux-udev.html

    If the AppImage refuses to start for lack of FUSE, set
    APPIMAGE_EXTRACT_AND_RUN=1 before running vial.
  EOS
end
