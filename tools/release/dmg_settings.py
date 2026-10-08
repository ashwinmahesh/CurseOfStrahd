# The Mac disk image's layout, for dmgbuild (https://dmgbuild.readthedocs.io), run on macOS:
#   dmgbuild -s tools/release/dmg_settings.py -D app="<Curse of Strahd.app>" -D release=tools/release \
#       "Curse of Strahd" CurseOfStrahd-macos.dmg
# A window with the game's icon on the left, a gilt arrow, and the Applications folder on the right
# (owner, 2026-10-08). The positions match the arrow drawn by tools/release/make_dmg_background.py.
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild provides it)
release = defines["release"]  # noqa: F821

format = "UDZO"
compression_level = 9
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = os.path.join(release, "app_icon.icns")
background = os.path.join(release, "dmg_background.tiff")

window_rect = ((200, 140), (660, 400))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {os.path.basename(app): (170, 170), "Applications": (490, 170)}
hide_extensions = [os.path.basename(app)]
