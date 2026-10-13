Freeride - SkateGM 9.0 compatibility build
===========================================

This build rebases Freeride on SkateGM 9.0's keyboard behavior instead of the
older 8.x keyboard file.

INSTALL
-------
Copy the included "lua" folder into your SkateGM add-on folder:

    garrysmod/addons/skategm/

Allow these two files to be replaced:

    lua/skategm/cl_keyboard.lua
    lua/skategm/cl_flickit_hud.lua

This new file is added:

    lua/autorun/client/freeride_settings.lua

Restart Garry's Mod after installing.

IMPORTANT
---------
SkateGM updates may restore the original cl_keyboard.lua and cl_flickit_hud.lua.
If that happens, reinstall this Freeride build after updating SkateGM.

WHAT CHANGED FOR SKATEGM 9.0
----------------------------
- Restores Freeride keyboard movement instead of SkateGM 9.0 riding controls:
  W / S     = left-stick forward / backward
  A / D     = left-stick left / right
  Space     = Jump / A action
  Shift     = Controller Y action
- Mouse Flickit restored (hold Mouse 1).
- Mouse Flickit deadzone restored.
- Optional circular stick limit restored.
- Original Flick-it HUD kept, with optional trail and deadzone ring toggles.
- Stabilized and realistic first-person cameras restored.
- Free mouse camera restored; L is the default toggle.
- Camera cycle is B by default and is now visible in the keybind menu.
- Keyboard controls remain configurable in Settings > Keyboard Only.
- Freeride no longer replaces SkateGM 9.0's full settings file. Instead, a
  runtime patch adds Freeride pages to the current 9.0 menu.

MENU
----
Settings > Mouse Flickit
    Enable Mouse Flickit
    Mouse sensitivity
    Mouse deadzone
    Circular stick limit
    Flick-it HUD / trail / deadzone ring
    Freecam

Settings > Camera > Freeride
    Camera mode
    Stabilized motion
    First-person mouse look
    Look sensitivity and limits
    Auto-center

Settings > Keyboard Only
    All Freeride keyboard binds

DEFAULT FREERIDE KEYS
---------------------
Mouse 1  Mouse Flickit (hold)
B        Cycle Third Person / Stabilized FP / Realistic FP
L        Toggle free mouse camera
R        Respawn

NOTES
-----
- Controller support for the Freeride-specific first-person features has not
  been fully tested.
- First-person FOV uses SkateGM's normal Camera > Field of view option because
  SkateGM 9.0's keyboard camera hook only overrides position and angles.
- This package contains Lua source only and does not include Skate 3 game data.

Freeride modifies GPL-3.0 SkateGM Lua code and should be distributed under the
same GPL-3.0 terms.
