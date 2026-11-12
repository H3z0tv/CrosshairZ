---------------------------------------------------------------------------------------
--                      SETTINGS: HUD, SMART CROSSHAIR, CAMERA, PROFILES             --
---------------------------------------------------------------------------------------
-- Option tables for the settings window. Values live in the active profile (CZ.P).
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local ipairs = _G.ipairs

CZ.Config = CZ.Config or {}
local Features = {}
CZ.Config.Features = Features

local function Changed()
  CZ.Profiles.Changed()
end

local function Merge(target, extra)
  if extra then
    for k, v in pairs(extra) do
      target[k] = v
    end
  end
  return target
end

local function Toggle(key, name, desc, order, extra)
  return Merge({
    type = "toggle",
    name = name,
    desc = desc,
    order = order,
    get = function()
      return CZ.P[key]
    end,
    set = function(_, value)
      CZ.P[key] = value
      Changed()
    end
  }, extra)
end

local function Range(key, name, desc, order, min, max, step, extra)
  return Merge({
    type = "range",
    name = name,
    desc = desc,
    order = order,
    min = min,
    max = max,
    step = step,
    get = function()
      return CZ.P[key]
    end,
    set = function(_, value)
      CZ.P[key] = value
      Changed()
    end
  }, extra)
end

local function Color(key, name, desc, order, extra)
  return Merge({
    type = "color",
    name = name,
    desc = desc,
    order = order,
    get = function()
      local c = CZ.P[key]
      return c[1], c[2], c[3], 1
    end,
    set = function(_, r, g, b)
      CZ.P[key] = {r, g, b}
      Changed()
    end
  }, extra)
end

local function Note(text, order)
  return {type = "description", name = text, order = order, width = "full"}
end

local function Header(text, order)
  return {type = "header", name = text, order = order}
end

local function Button(name, desc, order, func, extra)
  return Merge({type = "execute", name = name, desc = desc, order = order, func = func}, extra)
end

---------------------------------------------------------------------------------------
--                                    RETICLE HUD                                    --
---------------------------------------------------------------------------------------
local function OrbSelect(key, name, desc, order, values)
  return {
    type = "select",
    name = name,
    desc = desc,
    order = order,
    width = 1.8,
    values = values,
    get = function()
      return CZ.P[key]
    end,
    set = function(_, value)
      CZ.P[key] = value
      Changed()
    end
  }
end

local function HudOff()
  return not CZ.P.hudEnabled
end

Features.hud = {
  type = "group",
  args = {
    intro = Note(
      "Arcs around the crosshair show your health and power on the left, your target's health and cast on the right. Class resources (combo points, holy power, runes...) show as animated orbs under it.",
      1),
    hudEnabled = Toggle("hudEnabled", "Enable Reticle HUD", "Shows the arcs and pips around the crosshair.", 2,
      {width = "full"}),
    hudShow = {
      type = "select",
      name = "Show HUD",
      desc = "Only in combat: arcs appear when combat starts and fade out after.\n\nIn combat or with a target: also while you aim at something or are hurt.\n\nAlways: whenever the crosshair is visible.",
      order = 3,
      width = 1.8,
      values = {combat = "Only in combat", active = "In combat or with a target", always = "Always"},
      get = function()
        return CZ.P.hudShow
      end,
      set = function(_, value)
        CZ.P.hudShow = value
        Changed()
      end,
      disabled = HudOff
    },
    look = {
      type = "group",
      name = "Size & Position",
      inline = true,
      order = 5,
      disabled = HudOff,
      args = {
        preview = {
          type = "custom",
          order = 0,
          create = function(parent, width)
            return CZ.Features.CreatePreview(parent, width)
          end
        },
        hudScale = Range("hudScale", "HUD Size", "Size of the arcs around the crosshair.", 1, 0.25, 2, 0.05,
          {isPercent = true}),
        arcThickness = {
          type = "select",
          name = "Arc Thickness",
          desc = "How thick the arcs are.",
          order = 2,
          width = 1.5,
          values = {thin = "Thin", normal = "Normal", thick = "Thick"},
          get = function()
            return CZ.P.arcThickness
          end,
          set = function(_, value)
            CZ.P.arcThickness = value
            Changed()
          end
        },
        hudOpacity = Range("hudOpacity", "HUD Opacity", "How visible the arcs are.", 3, 0.1, 1, 0.05,
          {isPercent = true}),
        hudTrackOpacity = Range("hudTrackOpacity", "Background Ring",
          "How dark the empty part of each arc is. 0% hides it.", 4, 0, 1, 0.05, {isPercent = true}),
        hudOffsetX = Range("hudOffsetX", "Horizontal Offset", "Moves the arcs left or right of the crosshair.", 5,
          -200, 200, 1),
        hudOffsetY = Range("hudOffsetY", "Vertical Offset", "Moves the arcs up or down from the crosshair.", 6, -200,
          200, 1),
        resetLook = Button("Reset Size & Position", "Puts the settings in this box back to default.", 7, function()
          local d = CZ.FeatureDefaults
          for _, key in ipairs({"hudScale", "arcThickness", "hudOpacity", "hudTrackOpacity", "hudOffsetX", "hudOffsetY"}) do
            CZ.P[key] = d[key]
          end
          Changed()
        end)
      }
    },
    arcs = {
      type = "group",
      name = "Arcs",
      inline = true,
      order = 10,
      disabled = HudOff,
      args = {
        arcPlayerHealth = Toggle("arcPlayerHealth", "Your Health", "Left outer arc.", 1),
        arcHealthColor = Color("arcHealthColor", "Health Color", "Color of your health arc.", 2, {width = 1}),
        arcPlayerPower = Toggle("arcPlayerPower", "Your Power", "Left inner arc, in your power type's color.", 3),
        arcTargetHealth = Toggle("arcTargetHealth", "Target Health",
          "Right outer arc: red for enemies, green for friendlies.", 4),
        arcTargetCast = Toggle("arcTargetCast", "Target Cast",
          "Right inner arc fills while your target casts. Grey means it can't be interrupted.", 5),
        arcExecuteGlow = Toggle("arcExecuteGlow", "Execute Glow",
          "The target arc glows when the enemy is below the execute threshold.\n\n|cff909090Only where the game lets addons read target health (not in every dungeon or raid fight).|r",
          6),
        executeThreshold = Range("executeThreshold", "Execute Threshold", "Target health that triggers the glow.", 7,
          0.05, 0.35, 0.01, {isPercent = true})
      }
    },
    pips = {
      type = "group",
      name = "Class Resources",
      inline = true,
      order = 20,
      disabled = HudOff,
      args = {
        pipsEnabled = Toggle("pipsEnabled", "Show Class Resources",
          "Combo points, holy power, soul shards, chi, arcane charges, essence or runes around the crosshair.", 1,
          {width = "full"}),
        orbsEnabled = Toggle("orbsEnabled", "Orb Style",
          "Draws them as animated gold-ringed orbs: a new point pops in with a flash, spent points shrink away, essence shows the next point charging and a full set glows. Off uses small dots. They show, fade and dim with the Reticle HUD (Show HUD, HUD Opacity).", 1.5,
          {width = "full"}),
        pipPlacement = {
          type = "select",
          name = "Placement",
          desc = "Which side of the crosshair they sit on.",
          order = 2,
          width = 1.5,
          values = {below = "Below", above = "Above", left = "Left", right = "Right"},
          get = function()
            return CZ.P.pipPlacement
          end,
          set = function(_, value)
            CZ.P.pipPlacement = value
            Changed()
          end
        },
        pipDistance = Range("pipDistance", "Distance", "How far from the crosshair center they sit. Grows with HUD Size.", 3, 10, 150, 1),
        pipSpread = Range("pipSpread", "Spacing", "Space between them (degrees along the circle).", 4, 4, 40, 1),
        pipSize = Range("pipSize", "Size", "Size of each orb or dot.", 5, 4, 40, 1),
        orbsColor = OrbSelect("orbsColor", "Orb Color", "Red matches the classic combo point look. Resource uses a color per class resource.",
          6, {red = "Red", resource = "Match the resource"}),
        orbsAnimate = Toggle("orbsAnimate", "Orb Animations",
          "New points pop in with a flash and spent points shrink away.", 7),
        orbsGlow = Toggle("orbsGlow", "Glow When Full", "A soft glow runs across the orbs when every point is filled.", 8)
      }
    },
    feedback = {
      type = "group",
      name = "Hit & Kill Feedback",
      inline = true,
      order = 30,
      args = {
        hitConfirm = Toggle("hitConfirm", "Hit Marker", "A quick marker flashes on the crosshair when your target takes damage. Crits are bigger and gold.", 1),
        hitAllSources = Toggle("hitAllSources", "Show For All Damage",
          "Also flash for damage from other players and pets, not only right after your own attacks.", 2),
        killConfirm = Toggle("killConfirm", "Kill Marker", "A red marker when the enemy you're fighting dies.", 3),
        killBloom = Toggle("killBloom", "Kill Glow", "A glow bursts from the crosshair on a kill.", 4),
        killBloomSize = Range("killBloomSize", "Kill Glow Size", "Size of the kill glow.", 5, 0.5, 2, 0.05,
          {isPercent = true})
      }
    },
    test = {
      type = "group",
      name = "Preview",
      inline = true,
      order = 40,
      args = {
        testHUD = Button("Preview HUD", "Shows the arcs and class resources with sample values for 5 seconds.", 1, function()
          CZ.UI.Hide()
          CZ.Features.TestHUD()
          CZ.Orbs.Test()
        end),
        testHit = Button("Hit", "Plays the hit marker.", 2, function()
          CZ.Features.TestHit(false)
        end),
        testCrit = Button("Crit", "Plays the crit marker.", 3, function()
          CZ.Features.TestHit(true)
        end),
        testKill = Button("Kill", "Plays the kill marker.", 4, function()
          CZ.Features.TestKill()
        end)
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                    ASSIST HUD                                     --
---------------------------------------------------------------------------------------
local function AssistOff()
  return not CZ.P.assistEnabled
end

Features.assist = {
  type = "group",
  args = {
    intro = Note(
      "Shows the next spell the game suggests for your rotation (Assisted Combat) and an interaction prompt with your Interact key when the crosshair is on an NPC or object.",
      1),
    assistEnabled = Toggle("assistEnabled", "Enable Assist HUD", "Turns both prompts on or off.", 2, {width = "full"}),
    preview = {
      type = "custom",
      order = 2.5,
      create = function(parent, width)
        return CZ.Features.CreatePreview(parent, width)
      end
    },
    general = {
      type = "group",
      name = "General",
      inline = true,
      order = 5,
      disabled = AssistOff,
      args = {
        assistKeybind = Toggle("assistKeybind", "Show Keybinds",
          "Shows the key next to each prompt. While Free Look is on, mouse clicks from Click Casting are shown.", 1),
        assistOpacity = Range("assistOpacity", "Opacity", "How visible the prompts are.", 2, 0.2, 1, 0.05,
          {isPercent = true}),
        preview = Button("Preview", "Shows both prompts with sample values for 5 seconds.", 3, function()
          CZ.UI.Hide()
          CZ.Assist.Test()
        end),
        move = Button("Move Prompts", "Unlocks both prompts so you can drag them anywhere. Also: /cz move", 4,
          function()
            CZ.Assist.SetUnlocked(true)
          end)
      }
    },
    spellGroup = {
      type = "group",
      name = "Next Suggested Cast",
      inline = true,
      order = 10,
      disabled = AssistOff,
      args = {
        noSuggestions = {
          type = "description",
          name = "|cffE37527This game client doesn't offer cast suggestions, so this part stays hidden.|r",
          order = 0,
          width = "full",
          hidden = function()
            return CZ.Assist.HasSuggestions()
          end
        },
        assistSpell = Toggle("assistSpell", "Show Suggested Cast",
          "The spell icon the game's Assisted Combat recommends next. Greyed out when you can't cast it yet.", 1),
        assistSpellOnlyCombat = Toggle("assistSpellOnlyCombat", "Only In Combat", "Hide the suggestion out of combat.",
          2),
        assistSpellSize = Range("assistSpellSize", "Icon Size", "Size of the spell icon.", 3, 16, 64, 1),
        assistSpellX = Range("assistSpellX", "Horizontal Position", "Left or right of the crosshair.", 4, -300, 300, 1),
        assistSpellY = Range("assistSpellY", "Vertical Position", "Above or below the crosshair.", 5, -300, 300, 1)
      }
    },
    interactGroup = {
      type = "group",
      name = "Interaction Prompt",
      inline = true,
      order = 20,
      disabled = AssistOff,
      args = {
        assistInteract = Toggle("assistInteract", "Show Interaction Prompt",
          "When the crosshair is on something you can talk to or use, shows your Interact key and its name.", 1),
        assistInteractName = Toggle("assistInteractName", "Show Name", "Shows the NPC or object name next to the prompt.",
          2),
        assistInteractHint = Toggle("assistInteractHint", "Show \"Press Key\" Hint",
          "Adds \"Press F to interact\" (with your key) under the name.", 3),
        assistInteractGlow = Toggle("assistInteractGlow", "Glow", "A soft pulsing glow behind the prompt icon.", 3.1),
        assistInteractNameplate = Toggle("assistInteractNameplate", "Name Above Target",
          "Shows the game's name above the NPC or object you can interact with.", 3.2),
        assistInteractHideCombat = Toggle("assistInteractHideCombat", "Hide In Combat",
          "Hide the prompt during combat.", 3.3),
        assistInteractSize = Range("assistInteractSize", "Badge Size", "Size of the prompt badge.", 4, 16, 56, 1),
        assistInteractX = Range("assistInteractX", "Horizontal Position", "Left or right of the crosshair.", 5, -300,
          300, 1),
        assistInteractY = Range("assistInteractY", "Vertical Position", "Above or below the crosshair.", 6, -300, 300,
          1)
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                  SMART CROSSHAIR                                  --
---------------------------------------------------------------------------------------
local function SmartOff()
  return not CZ.P.smartEnabled
end

Features.smart = {
  type = "group",
  args = {
    intro = Note(
      "Makes the crosshair react to what's happening: range colors, hiding it when you don't need it, following your character's head as you zoom, and screen effects.",
      1),
    smartEnabled = Toggle("smartEnabled", "Enable Smart Crosshair", "Turns all features on this page on or off.", 2,
      {width = "full"}),
    preview = {
      type = "custom",
      order = 2.5,
      create = function(parent, width)
        return CZ.Features.CreatePreview(parent, width)
      end
    },
    visibilityGroup = {
      type = "group",
      name = "When To Show The Crosshair",
      inline = true,
      order = 10,
      disabled = SmartOff,
      args = {
        visibility = {
          type = "select",
          name = "Show Crosshair",
          desc = "Always, only in combat, or only while you aim at an enemy.",
          order = 1,
          width = 1.6,
          values = {always = "Always", combat = "Only in combat", target = "Only with an enemy target"},
          get = function()
            return CZ.P.visibility
          end,
          set = function(_, value)
            CZ.P.visibility = value
            Changed()
          end
        },
        hideFlightForm = Toggle("hideFlightForm", "Hide In Flight Form", "Druids: hide while flying in flight form.", 2),
        hideNoTarget = Toggle("hideNoTarget", "Hide Without Target", "Hide when nothing is targeted.", 3),
        hideFriendly = Toggle("hideFriendly", "Hide On Friendly Target", "Hide while targeting a friendly unit.", 4),
        hideDead = Toggle("hideDead", "Hide On Dead Target", "Hide while your target is dead.", 5),
        hideOutOfRange = Toggle("hideOutOfRange", "Hide When Out Of Range",
          "Hide while your enemy target is out of range of your abilities.", 6),
        hideIdle = Toggle("hideIdle", "Hide When Idle",
          "Fade out after you stop moving, turning and zooming for a while (never in combat).", 7),
        idleSeconds = Range("idleSeconds", "Idle Time", "Seconds without input before the crosshair fades.", 8, 2, 15,
          1, {
            disabled = function()
              return SmartOff() or not CZ.P.hideIdle
            end
          }),
        combatOpacity = Toggle("combatOpacity", "Combat Opacity", "Use a different opacity in and out of combat.", 9,
          {width = "full"}),
        opacityInCombat = Range("opacityInCombat", "In Combat", "Crosshair opacity in combat.", 10, 0, 1, 0.05, {
          isPercent = true,
          disabled = function()
            return SmartOff() or not CZ.P.combatOpacity
          end
        }),
        opacityOutCombat = Range("opacityOutCombat", "Out Of Combat", "Crosshair opacity out of combat.", 11, 0, 1,
          0.05, {
            isPercent = true,
            disabled = function()
              return SmartOff() or not CZ.P.combatOpacity
            end
          })
      }
    },
    rangeGroup = {
      type = "group",
      name = "Range Colors",
      inline = true,
      order = 20,
      disabled = SmartOff,
      args = {
        rangeColors = Toggle("rangeColors", "Color By Range",
          "On enemies, the crosshair shows whether you're in melee range, in ranged range or out of range.", 1,
          {width = "full"}),
        colorMelee = Color("colorMelee", "Melee Range", "Color while in melee range.", 2, {width = 1.2}),
        colorRanged = Color("colorRanged", "Ranged Range", "Color while in range of your ranged abilities.", 3,
          {width = 1.2}),
        colorOutOfRange = Color("colorOutOfRange", "Out Of Range", "Color when nothing reaches.", 4, {width = 1.2}),
        rangeSpellMelee = {
          type = "input",
          name = "Melee Check Spell (optional)",
          desc = "Spell name or ID used to check melee range. Leave empty to pick one from your spellbook automatically.",
          order = 5,
          width = 1.8,
          get = function()
            return CZ.P.rangeSpellMelee
          end,
          set = function(_, value)
            CZ.P.rangeSpellMelee = value
            Changed()
          end
        },
        rangeSpellRanged = {
          type = "input",
          name = "Ranged Check Spell (optional)",
          desc = "Spell name or ID used to check ranged range. Leave empty to pick one from your spellbook automatically.",
          order = 6,
          width = 1.8,
          get = function()
            return CZ.P.rangeSpellRanged
          end,
          set = function(_, value)
            CZ.P.rangeSpellRanged = value
            Changed()
          end
        }
      }
    },
    headGroup = {
      type = "group",
      name = "Head Tracking",
      inline = true,
      order = 30,
      disabled = SmartOff,
      args = {
        headTracking = Toggle("headTracking", "Follow Head Height",
          "Moves the crosshair up when you zoom in and down when you zoom out, so it stays near your character's head line. The targeting point moves with it.",
          1, {width = "full"}),
        headFactor = Range("headFactor", "Strength", "How far the crosshair moves with zoom.", 2, 200, 3000, 50, {
          disabled = function()
            return SmartOff() or not CZ.P.headTracking
          end
        })
      }
    },
    screenGroup = {
      type = "group",
      name = "Screen Effects",
      inline = true,
      order = 40,
      args = {
        stealthVignette = Toggle("stealthVignette", "Stealth Vignette",
          "Darkens the screen edges in purple while you're stealthed.", 1),
        stealthOpacity = Range("stealthOpacity", "Stealth Strength", "How dark the stealth vignette is.", 2, 0.1, 1,
          0.05, {
            isPercent = true,
            disabled = function()
              return not CZ.P.stealthVignette
            end
          }),
        lowHealthVignette = Toggle("lowHealthVignette", "Low Health Vignette",
          "Red, pulsing screen edges when your health is low.\n\n|cff909090Only where the game lets addons read your health.|r",
          3),
        lowHealthThreshold = Range("lowHealthThreshold", "Low Health At", "Health below which the effect starts.", 4,
          0.1, 0.6, 0.05, {
            isPercent = true,
            disabled = function()
              return not CZ.P.lowHealthVignette
            end
          }),
        lowHealthOpacity = Range("lowHealthOpacity", "Low Health Strength", "How strong the red edges get.", 5, 0.1,
          1, 0.05, {
            isPercent = true,
            disabled = function()
              return not CZ.P.lowHealthVignette
            end
          }),
        testVignette = Button("Preview", "Shows the low health effect for 4 seconds.", 6, function()
          CZ.UI.Hide()
          CZ.Features.TestVignette()
        end)
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                SITUATIONAL CAMERA                                 --
---------------------------------------------------------------------------------------
local function CamOff()
  return not CZ.P.camEnabled or CZ.DynamicCam
end

local function CamChanged()
  Changed()
  if CZ.Camera then
    CZ.Camera.Reapply()
  end
end

local function SituationGroup(sit, order)
  local key = sit.key
  local function S()
    return CZ.P.situations[key]
  end
  local function Field(field, name, desc, fieldOrder, min, max, step, extra)
    return Merge({
      type = "range",
      name = name,
      desc = desc,
      order = fieldOrder,
      min = min,
      max = max,
      step = step,
      width = 1.8,
      get = function()
        return S()[field]
      end,
      set = function(_, value)
        S()[field] = value
        CamChanged()
      end,
      disabled = function()
        return CamOff() or not S().enabled
      end
    }, extra)
  end
  return {
    type = "group",
    name = sit.name,
    order = order,
    args = {
      desc = Note("|cff909090" .. sit.desc .. "|r", 0),
      enabled = {
        type = "toggle",
        name = "Use This Situation",
        desc = "When off, the next situation in the list is used instead.",
        order = 1,
        width = 1.8,
        get = function()
          return S().enabled
        end,
        set = function(_, value)
          S().enabled = value
          CamChanged()
        end,
        disabled = CamOff
      },
      preview = Button("Preview Zoom", "Zooms the camera to this situation's distance now.", 2, function()
        CZ.Camera.Preview(key)
      end, {
        width = 1.8,
        disabled = function()
          return CamOff() or not S().enabled
        end
      }),
      zoom = Field("zoom", "Zoom Distance", "Camera distance in yards.", 3, 1, 39, 0.5),
      shoulder = Field("shoulder", "Shoulder Offset",
        "Moves the camera beside your character. Negative is left, positive is right.", 4, -2, 2, 0.1),
      head = Field("head", "Head Movement", "How much the camera follows your character's head bobbing.", 5, 0, 2,
        0.1),
      fov = Field("fov", "Field Of View", "Only used when Field Of View is turned on above.", 6, 50, 90, 1)
    }
  }
end

local cameraArgs = {
  intro = Note(
    "The camera changes distance, shoulder offset, head movement and field of view depending on what you're doing. Situations higher in the list win. Scrolling the mouse wheel still works; your zoom is kept until the situation changes.",
    1),
  dynamicCamNote = {
    type = "description",
    name = "|cffE37527A camera addon is running, so Crosshair Z leaves the camera alone.|r",
    order = 1.5,
    width = "full",
    hidden = function()
      return not CZ.DynamicCam
    end
  },
  camEnabled = Toggle("camEnabled", "Enable Situational Camera",
    "Lets Crosshair Z move the camera per situation. Turning it off restores your camera settings.", 2, {
      width = "full",
      set = function(_, value)
        CZ.P.camEnabled = value
        CamChanged()
      end,
      disabled = function()
        return CZ.DynamicCam
      end
    }),
  general = {
    type = "group",
    name = "General",
    inline = true,
    order = 10,
    disabled = CamOff,
    args = {
      camTransition = Range("camTransition", "Transition Speed", "How fast the camera moves to a new distance.", 1,
        0.5, 3, 0.1, {set = function(_, v)
          CZ.P.camTransition = v
          CamChanged()
        end}),
      camShoulder = Toggle("camShoulder", "Control Shoulder Offset", "Use each situation's shoulder offset.", 2),
      camShoulderMountedZero = Toggle("camShoulderMountedZero", "Center Camera When Mounted",
        "No shoulder offset while mounted.", 3),
      camHead = Toggle("camHead", "Control Head Movement", "Use each situation's head movement setting.", 4),
      camFov = Toggle("camFov", "Control Field Of View", "Use each situation's field of view.", 5),
      camSkyridingDynamic = Toggle("camSkyridingDynamic", "Dynamic Skyriding Zoom",
        "While skyriding, the camera zooms out as you speed up.", 6),
      camRestingOrbit = Toggle("camRestingOrbit", "Orbit While Sitting",
        "When you /sit, /kneel or /sleep, the camera slowly circles around your character.", 7),
      camOrbitSpeed = Range("camOrbitSpeed", "Orbit Speed", "How fast the camera circles.", 8, 0.25, 3, 0.05)
    }
  }
}
for i, sit in ipairs(CZ.CameraSituations) do
  cameraArgs["sit_" .. sit.key] = SituationGroup(sit, 100 + i)
end

Features.camera = {type = "group", args = cameraArgs}

---------------------------------------------------------------------------------------
--                                     PROFILES                                      --
---------------------------------------------------------------------------------------
local function ProfileValues()
  local values = {}
  for _, name in ipairs(CZ.Profiles.List()) do
    values[name] = name
  end
  return values
end

local function OtherProfileValues()
  local values = {}
  local active = CZ.Profiles.ActiveName()
  for _, name in ipairs(CZ.Profiles.List()) do
    if name ~= active then
      values[name] = name
    end
  end
  return values
end

local function Print(msg)
  print(CZ.Constants.BasePrintMsg .. "|cff909090: " .. msg .. "|r")
end

function Features.BuildProfiles()
  local args = {
    intro = Note(
      "Profiles store the Reticle HUD, Smart Crosshair and Situational Camera settings. Keybinds, click casting and reticle targeting are shared by all profiles.",
      1),
    active = {
      type = "select",
      name = "Active Profile",
      desc = "The profile this character (or this specialization) uses.",
      order = 2,
      width = 1.8,
      values = ProfileValues,
      get = function()
        return CZ.Profiles.ActiveName()
      end,
      set = function(_, value)
        CZ.Profiles.SetActive(value)
      end
    },
    newProfile = {
      type = "input",
      name = "New Profile (copy of active)",
      enterOnly = true,
      desc = "Type a name and press Enter. The new profile starts as a copy of the active one and becomes active.",
      order = 3,
      width = 1.8,
      get = function()
        return ""
      end,
      set = function(_, value)
        local ok, err = CZ.Profiles.Create(value, CZ.Profiles.ActiveName())
        if not ok and err then
          Print(err)
        end
      end
    },
    copyFrom = {
      type = "select",
      name = "Copy Settings From",
      desc = "Overwrites the active profile with another profile's settings.",
      order = 4,
      width = 1.8,
      values = OtherProfileValues,
      confirm = true,
      confirmText = CZ.METADATA["TITLE"] .. "\n\nOverwrite the active profile with the selected one?",
      get = function()
        return nil
      end,
      set = function(_, value)
        CZ.Profiles.CopyInto(value)
      end
    },
    delete = {
      type = "select",
      name = "Delete Profile",
      desc = "Deletes a profile. Characters using it go back to Default.",
      order = 5,
      width = 1.8,
      values = function()
        local values = OtherProfileValues()
        values.Default = nil
        return values
      end,
      confirm = true,
      confirmText = CZ.METADATA["TITLE"] .. "\n\nDelete the selected profile?",
      get = function()
        return nil
      end,
      set = function(_, value)
        CZ.Profiles.Delete(value)
      end
    },
    reset = Button("Reset Active Profile", "Puts every HUD, Smart Crosshair and Camera setting of the active profile back to default.",
      6, function()
        CZ.Profiles.ResetActive()
      end, {
        confirm = true,
        confirmText = CZ.METADATA["TITLE"] .. "\n\nReset the active profile to default settings?"
      })
  }

  local specs = CZ.Profiles.GetSpecs()
  if #specs > 0 then
    args.specHeader = Header("Specializations", 10)
    args.useSpec = {
      type = "toggle",
      name = "Use A Profile Per Specialization",
      desc = "Switches profile automatically when you change specialization.",
      order = 11,
      width = "full",
      get = function()
        return CZ.Profiles.UsesSpecProfiles()
      end,
      set = function(_, value)
        CZ.Profiles.SetUseSpecProfiles(value)
      end
    }
    for i, spec in ipairs(specs) do
      args["spec" .. spec.id] = {
        type = "select",
        name = spec.name,
        desc = "Profile used in " .. spec.name .. ".",
        order = 11 + i,
        width = 1.8,
        values = ProfileValues,
        get = function()
          local char = CZ.DB.char
          return char.czSpecProfiles and char.czSpecProfiles[spec.id] or char.czProfile
        end,
        set = function(_, value)
          CZ.Profiles.SetSpecProfile(spec.id, value)
        end,
        disabled = function()
          return not CZ.Profiles.UsesSpecProfiles()
        end
      }
    end
  end
  return args
end

---------------------------------------------------------------------------------------
--                        0.1.5: EXTRA OPTIONS ON EXISTING PAGES                     --
---------------------------------------------------------------------------------------
local function GlobalToggle(key, name, desc, order, extra, after)
  return Merge({
    type = "toggle",
    name = name,
    desc = desc,
    order = order,
    get = function()
      return CZ.DB.global[key]
    end,
    set = function(_, value)
      CZ.DB.global[key] = value
      if after then
        after(value)
      end
    end
  }, extra)
end

local function GlobalSelect(key, name, desc, order, values, extra, after)
  return Merge({
    type = "select",
    name = name,
    desc = desc,
    order = order,
    width = 1.8,
    values = values,
    get = function()
      return CZ.DB.global[key]
    end,
    set = function(_, value)
      CZ.DB.global[key] = value
      if after then
        after(value)
      end
    end
  }, extra)
end

local function KeyOption(action, name, desc, order)
  return {
    type = "keybinding",
    name = name,
    desc = desc,
    order = order,
    width = 1.8,
    get = function()
      return (_G.GetBindingKey(action))
    end,
    set = function(_, key)
      local old = _G.GetBindingKey(action)
      if old then
        _G.SetBinding(old)
      end
      _G.SetBinding(key, action)
      _G.SaveBindings(_G.GetCurrentBindingSet())
    end
  }
end

-- Mouse Look page
Features.freeLookExtra = {
  type = "group",
  name = "More Free Look Options",
  inline = true,
  order = 50,
  args = {
    lockKey = KeyOption("CROSSHAIRZ_LOCK", "Target Lock Key",
      "Locks your current target so the reticle stops replacing it. Unlocks when the target is gone.", 1),
    targetLockBehavior = GlobalSelect("targetLockBehavior", "Target Lock Key Does",
      "Toggle: press to lock, press again to unlock.\n\nSwitch Target: while locked, press to lock onto the enemy you're aiming at; press with nothing under the crosshair to unlock.",
      2, {toggle = "Toggle lock", switch = "Switch target"}),
    flipKey = KeyOption("CROSSHAIRZ_FLIP", "Flip Camera Key",
      "Moves the camera to your other shoulder (when a shoulder offset is in use).", 3),
    sheatheWithFreeLook = GlobalToggle("sheatheWithFreeLook", "Weapons Follow Free Look",
      "Draws your weapons when Free Look turns on and puts them away when it turns off (out of combat only).", 4),
    freelookVignette = Toggle("freelookVignette", "Free Look Vignette",
      "Darkens the edges of the screen while Free Look is on, to keep your eyes on the center.", 5),
    freelookVignetteOpacity = Range("freelookVignetteOpacity", "Vignette Strength", "How dark the edges get.", 6, 0.1,
      0.8, 0.05, {
        isPercent = true,
        disabled = function()
          return not CZ.P.freelookVignette
        end
      })
  }
}

-- Crosshair page
Features.crosshairExtra = {
  type = "group",
  name = "States & Feedback",
  inline = true,
  order = 50,
  args = {
    crosshairMountedStyle = GlobalSelect("crosshairMountedStyle", "While Mounted",
      "What the crosshair does while mounted (when Hide While Mounted is on).", 1,
      {hide = "Hide", dim = "Dim"}, nil, function()
        if CZ.CreateCrosshair then
          CZ.CreateCrosshair()
        end
      end),
    crosshairDisabledStyle = GlobalSelect("crosshairDisabledStyle", "While Free Look Is Off",
      "Hide the crosshair when Free Look is off, or keep a faint one on screen.", 2, {hide = "Hide", dim = "Dim"},
      nil, function()
        CZ.DisplayCrosshair(CZ.crosshairWanted)
      end),
    castFeedback = Toggle("castFeedback", "Cast Feedback",
      "The crosshair reacts to your own casts: grows while casting, pulses when the cast lands, shakes when it's interrupted.",
      3, {width = "full"}),
    castGrow = Toggle("castGrow", "Grow While Casting", "Slowly grows during casts and channels.", 4, {
      disabled = function()
        return not CZ.P.castFeedback
      end
    }),
    castPulse = Toggle("castPulse", "Pulse On Success", "A quick pulse when a cast finishes.", 5, {
      disabled = function()
        return not CZ.P.castFeedback
      end
    }),
    castShake = Toggle("castShake", "Shake On Interrupt", "A short shake when your cast is interrupted.", 6, {
      disabled = function()
        return not CZ.P.castFeedback
      end
    }),
    castTest = Button("Preview Feedback", "Plays the pulse and the shake.", 7, function()
      CZ.UI.Hide()
      CZ.Extras.TestFeedback()
    end),
    targetOutline = GlobalSelect("targetOutline", "Unit Outlines",
      "The game's outline around units. Game Default leaves your setting alone.", 8,
      {default = "Game default", off = "Off", hover = "Mouseover only", target = "Mouseover and target",
       all = "Mouseover, target and group"}, nil, function()
        CZ.Extras.ApplyTargetOutline()
      end)
  }
}

-- Camera page: base camera + comfort, shown above the situational settings
local function BaseOff()
  return not CZ.P.baseCamEnabled or CZ.DynamicCam
end
local function BaseChanged()
  Changed()
  if CZ.Camera and CZ.Camera.ApplyBase then
    CZ.Camera.ApplyBase()
  end
end
local function BaseRange(key, name, desc, order, min, max, step)
  return Range(key, name, desc, order, min, max, step, {
    disabled = BaseOff,
    set = function(_, value)
      CZ.P[key] = value
      BaseChanged()
    end
  })
end

Features.camera.args.comfort = {
  type = "group",
  name = "Comfort",
  inline = true,
  order = 3,
  args = {
    motionSickness = GlobalToggle("motionSickness", "Motion Sickness Protection",
      "Crosshair Z never moves the camera off-center or makes it follow head movement. Shoulder offset, head movement and the Action Camera preset are skipped. Field of view and zoom still work.",
      1, {width = "full"}, function()
        if CZ.Camera then
          CZ.Camera.ApplyBase()
          CZ.Camera.Reapply()
        end
        if not CZ.MotionSafe() and CZ.DB.global.actionCamera then
          CZ.ConfigActionCamera("crosshairz")
        end
      end)
  }
}

Features.camera.args.base = {
  type = "group",
  name = "Base Camera",
  inline = true,
  order = 4,
  args = {
    baseCamEnabled = Toggle("baseCamEnabled", "Use These Camera Settings",
      "Applies the field of view, max zoom, zoom speed and head tracking below. Turning it off restores your previous camera settings.",
      1, {
        width = "full",
        set = function(_, value)
          CZ.P.baseCamEnabled = value
          BaseChanged()
        end
      }),
    baseFov = BaseRange("baseFov", "Field Of View", "How wide the camera sees (degrees).", 2, 50, 90, 1),
    baseMaxZoom = BaseRange("baseMaxZoom", "Max Zoom Distance", "How far the camera can zoom out (yards).", 3, 15, 39, 0.5),
    baseZoomSpeed = BaseRange("baseZoomSpeed", "Zoom Scroll Speed", "How fast the mouse wheel zooms.", 4, 1, 50, 1),
    baseHead = BaseRange("baseHead", "Head Tracking Strength",
      "How much the camera follows your character's head movement. Skipped with Motion Sickness Protection.", 5, 0, 2,
      0.1)
  }
}

---------------------------------------------------------------------------------------
--                                  MACRO COMPOSER                                   --
---------------------------------------------------------------------------------------
-- Builds a /cast macro aimed the way you choose and saves it to your macro list.
local TARGETS = {
  crosshair = {"Crosshair (reticle) target", "[@softenemy,exists,harm,nodead][@target,harm,nodead][]"},
  mouseover = {"Mouseover", "[@mouseover,exists,nodead][]"},
  cursor = {"Cursor (ground spells)", "[@cursor]"},
  heal = {"Friendly: mouseover, target, then you", "[@mouseover,help,nodead][@target,help,nodead][@player]"},
  focus = {"Focus", "[@focus,exists,nodead][]"},
  player = {"Yourself", "[@player]"},
  target = {"Normal target", ""}
}

local function Composer()
  local c = CZ.DB.global.composer
  if not c then
    c = {name = "CZ_Macro", spell = "", target = "crosshair", tooltip = true, stopcasting = false, perChar = false}
    CZ.DB.global.composer = c
  end
  return c
end

function Features.ComposeMacroText()
  local c = Composer()
  local spell = (c.spell or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if spell == "" then
    return ""
  end
  local lines = {}
  if c.tooltip then
    lines[#lines + 1] = "#showtooltip"
  end
  if c.stopcasting then
    lines[#lines + 1] = "/stopcasting"
  end
  local cond = TARGETS[c.target] and TARGETS[c.target][2] or ""
  lines[#lines + 1] = "/cast " .. (cond ~= "" and (cond .. " ") or "") .. spell
  return table.concat(lines, "\n")
end

local function SaveMacro()
  local c = Composer()
  local body = Features.ComposeMacroText()
  if body == "" then
    Print("type a spell name first.")
    return
  end
  if _G.InCombatLockdown() then
    Print("macros can't be saved in combat.")
    return
  end
  local name = (c.name or "CZ_Macro"):sub(1, 16)
  local index = _G.GetMacroIndexByName and _G.GetMacroIndexByName(name) or 0
  local ok, err
  if index and index > 0 then
    ok, err = pcall(_G.EditMacro, index, name, nil, body)
  else
    ok, err = pcall(_G.CreateMacro, name, "INV_MISC_QUESTIONMARK", body, c.perChar and true or nil)
  end
  if ok then
    Print("macro |r" .. name .. "|cff909090 saved. Drag it from the macro window (/macro) to your action bar.|r")
  else
    Print("couldn't save the macro: " .. tostring(err))
  end
end

local function ComposerInput(key, name, desc, order, width)
  return {
    type = "input",
    name = name,
    desc = desc,
    order = order,
    width = width or 1.8,
    get = function()
      return Composer()[key]
    end,
    set = function(_, value)
      Composer()[key] = value
    end
  }
end

local function ComposerToggle(key, name, desc, order)
  return {
    type = "toggle",
    name = name,
    desc = desc,
    order = order,
    get = function()
      return Composer()[key]
    end,
    set = function(_, value)
      Composer()[key] = value
    end
  }
end

local targetValues = {}
for key, v in pairs(TARGETS) do
  targetValues[key] = v[1]
end

Features.composer = {
  type = "group",
  args = {
    intro = Note(
      "Make a macro that casts a spell at the unit you choose: the enemy under your crosshair, your mouseover, the ground at your cursor, and more. Save it, then drag it from the macro window to your bars.",
      1),
    spell = ComposerInput("spell", "Spell", "Spell name exactly as in your spellbook.", 2),
    name = ComposerInput("name", "Macro Name", "Up to 16 characters. Saving again with the same name updates the macro.", 3),
    target = {
      type = "select",
      name = "Cast At",
      desc = "Who or where the spell goes.",
      order = 4,
      width = 1.8,
      values = targetValues,
      get = function()
        return Composer().target
      end,
      set = function(_, value)
        Composer().target = value
      end
    },
    tooltip = ComposerToggle("tooltip", "Show Spell Icon", "Adds #showtooltip so the macro shows the spell's icon and cooldown.", 5),
    stopcasting = ComposerToggle("stopcasting", "Stop Current Cast First",
      "Adds /stopcasting so this spell interrupts whatever you're casting.", 6),
    perChar = ComposerToggle("perChar", "Character Macro", "Save it to this character's macros instead of the general ones.", 7),
    preview = {
      type = "custom",
      order = 8,
      create = function(parent, width)
        return CZ.UI.CreateMacroPreview(parent, width)
      end
    },
    save = Button("Save Macro", "Creates the macro, or updates it if one with this name exists.", 9, SaveMacro,
      {width = "full"})
  }
}
