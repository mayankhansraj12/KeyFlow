#!/usr/bin/env python3

import os
import sys

from ds_store import DSStore
from mac_alias import Alias


def paths_for(mount_point: str):
    background_path = os.path.join(
        mount_point, ".background", "DMGBackground.png"
    )
    ds_store_path = os.path.join(mount_point, ".DS_Store")
    return background_path, ds_store_path


def write_metadata(mount_point: str) -> int:
    background_path, ds_store_path = paths_for(mount_point)
    if not os.path.isfile(background_path):
        print(f"Background not found: {background_path}", file=sys.stderr)
        return 1

    background_alias = Alias.for_file(background_path)
    window_bounds = "{{120, 120}, {760, 460}}"

    browser_window_settings = {
        "ContainerShowSidebar": False,
        "ShowPathbar": False,
        "ShowSidebar": False,
        "ShowStatusBar": False,
        "ShowTabView": False,
        "ShowToolbar": False,
        "SidebarWidth": 0,
        "WindowBounds": window_bounds,
    }
    icon_view_settings = {
        "backgroundType": 2,
        "backgroundColorRed": 1.0,
        "backgroundColorGreen": 1.0,
        "backgroundColorBlue": 1.0,
        "showIconPreview": True,
        "showItemInfo": False,
        "textSize": 14.0,
        "iconSize": 128.0,
        "viewOptionsVersion": 1,
        "gridSpacing": 100.0,
        "gridOffsetX": 0.0,
        "gridOffsetY": 0.0,
        "labelOnBottom": True,
        "arrangeBy": "none",
        "backgroundImageAlias": background_alias.to_bytes(),
    }

    if os.path.exists(ds_store_path):
        os.remove(ds_store_path)

    with DSStore.open(ds_store_path, "w+") as store:
        store["."]["vSrn"] = ("long", 1)
        store["."]["bwsp"] = browser_window_settings
        store["."]["icvp"] = icon_view_settings
        store["KeyFlow.app"]["Iloc"] = (205, 265)
        store["Applications"]["Iloc"] = (555, 265)

    return 0


def verify_metadata(mount_point: str) -> int:
    background_path, ds_store_path = paths_for(mount_point)
    if not os.path.isfile(background_path) or not os.path.isfile(ds_store_path):
        print("DMG background or Finder metadata is missing.", file=sys.stderr)
        return 1

    with DSStore.open(ds_store_path, "r") as store:
        icon_view_settings = store["."]["icvp"]
        app_location = store["KeyFlow.app"]["Iloc"]
        applications_location = store["Applications"]["Iloc"]

    if icon_view_settings["backgroundType"] != 2:
        print("DMG background is not configured as an image.", file=sys.stderr)
        return 1
    if app_location != (205, 265) or applications_location != (555, 265):
        print("DMG icons are not at their expected locations.", file=sys.stderr)
        return 1
    return 0


def main() -> int:
    if len(sys.argv) == 2:
        return write_metadata(os.path.abspath(sys.argv[1]))
    if len(sys.argv) == 3 and sys.argv[1] == "--verify":
        return verify_metadata(os.path.abspath(sys.argv[2]))

    print(
        "Usage: write-dmg-metadata.py [--verify] <mounted-volume>",
        file=sys.stderr,
    )
    return 64


if __name__ == "__main__":
    raise SystemExit(main())
