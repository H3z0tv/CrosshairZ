-- Crosshair Z
-- Patch notes shown in the settings window and the What's New popup.

local _, Z = ...

Z.NOTES = {
  {
    version = "1.0.0",
    date = "2026-11-13",
    lines = {
      "Crosshair Z is rebuilt from the ground up: all new code, a new settings window and new images.",
      "Uses the Ace3 libraries (AceAddon, AceEvent, AceDB, AceConsole) for start-up, events, saved settings and slash commands. Settings are saved in a new file, so they start fresh once more.",
      "Fresh start: settings from earlier versions are not carried over, and the Setup Wizard runs on your first login. Your keys carry over.",
      "New names: Aim Mode (camera follows the mouse), Crosshair Aim (target what you aim at), Mouse Actions (clicks cast while Aim Mode is on), Auto Cursor (cursor comes back for game windows), Target Hold (keep a target while you aim elsewhere).",
      "Aim Mode is on when you log in. Turn that off with Aim Mode On At Login on the Aim Mode page.",
      "Turning Aim Mode off now also turns off aiming: the crosshair hides and aiming stops picking targets until you turn it back on.",
      "Camera works like before: over the shoulder with a strong pitch so your character sits below the crosshair, and the camera turns toward your target. All of it is on the Camera page, and Motion Sickness Protection turns it off.",
      "Class resource orbs fill from left to right, sit outside the arcs, and shrink together with the HUD so a small HUD stays tidy.",
      "DynamicCam: when it is installed, Crosshair Z leaves the whole camera to it (shoulder, pitch, zoom, scenes and turn speed) and says so once in chat.",
      "Tooltips during Aim Mode are rebuilt: no flicker, the chosen key shows and hides them right away, and they sit next to the crosshair.",
      "Move Prompts works again: the prompts stay under your mouse while you drag, sample prompts show while moving, and the saved place is right at any prompt size.",
      "Interaction prompt redone: a hopping bag when you can loot, a speech bubble with typing dots when you can talk, a turning gear for objects, and just your interact key on a key cap under it. The name is optional (Show Name).",
      "Arc Thickness is now a slider with six steps.",
      "Interaction prompt: a brush-stroke circle sweeps in around the icon and slowly turns while the prompt is up.",
      "When Aim Mode turns off, the cursor comes back where you left it instead of the middle of the screen.",
      "Crosshair HUD redesigned: two crescents on each side close almost into a circle around the crosshair, thickest in the middle and tapering at the ends, with a dark rim so they read on any ground and a soft neon glow. Your health and power on the left, your target's health and cast on the right, health percent beside each side. Options: Arc Style (smooth or with quarter marks), Neon Glow, Show Percent, Arc Thickness.",
      "24 new crosshair styles with a dark rim so they stay visible on any background. The crosshair now sits above your character by default.",
      "New settings window: groups along the top, pages under them, one column of settings, smooth scrolling, animated switches and sliders, five color themes and a window scale.",
      "New Target Hold page: hold key, switch target, cycle keys, auto hold, marker and optional sounds.",
      "New Camera Scenes page: pick a scene and edit its zoom, shoulder, head tracking and field of view in one place.",
      "New installs start with a ready-made setup: Aim Mode on, Bead crosshair a bit above your character, compact smooth HUD at 60% size with thick arcs, red orbs, tooltips beside the crosshair, vignette on, hit and kill markers off. Left Click runs a macro named TARGET when you have one, otherwise Action Button 1.",
      "Profiles can be shared: Export Profile shows a text string to copy, Import Profile reads one back as a new profile (Profiles page, or /cz export and /cz import).",
      "Every setting lives in a profile, including mouse actions, and profiles can follow your specialization.",
      "Undo All Changes puts back the game settings Crosshair Z changed, as they were before it first changed them.",
      "Type /cz status to see the version, whether Aim Mode is on, what paused it, and where the crosshair is."
    }
  }
}
