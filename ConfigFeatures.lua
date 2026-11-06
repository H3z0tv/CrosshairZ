---------------------------------------------------------------------------------------
--                      SETTINGS: HUD, SMART CROSSHAIR, CAMERA, PROFILES             --
---------------------------------------------------------------------------------------
-- Option tables for the settings window. Values live in the active profile (TR.P).
local _G = _G
local TR = _G.LibStub("AceAddon-3.0"):GetAddon("TrueReticle")

local ipairs = _G.ipairs

TR.Config = TR.Config or {}
local Features = {}
TR.Config.Features = Features

local function Changed()
  TR.Profiles.Changed()
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
      return TR.P[key]
    end,
    set = function(_, value)
      TR.P[key] = value
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
      return TR.P[key]
    end,
    set = function(_, value)
      TR.P[key] = value
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
      local c = TR.P[key]
      return c[1], c[2], c[3], 1
    end,
    set = function(_, r, g, b)
      TR.P[key] = {r, g, b}
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
local function HudOff()
  return not TR.P.hudEnabled
end

Features.hud = {
  type = "group",
  args = {
    intro = Note(
      "Arcs around the crosshair show your health and power on the left, your target's health and cast on the right. Class resources (combo points, holy power, runes...) show as pips under it.",
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
        return TR.P.hudShow
      end,
      set = function(_, value)
        TR.P.hudShow = value
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
            return TR.Features.CreatePreview(parent, width)
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
            return TR.P.arcThickness
          end,
          set = function(_, value)
            TR.P.arcThickness = value
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
          local d = TR.FeatureDefaults
          for _, key in ipairs({"hudScale", "arcThickness", "hudOpacity", "hudTrackOpacity", "hudOffsetX", "hudOffsetY"}) do
            TR.P[key] = d[key]
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
      name = "Class Resource Pips",
      inline = true,
      order = 20,
      disabled = HudOff,
      args = {
        pipsEnabled = Toggle("pipsEnabled", "Show Resource Pips",
          "Combo points, holy power, soul shards, chi, arcane charges, essence or runes under the crosshair.", 1,
          {width = "full"}),
        pipPlacement = {
          type = "select",
          name = "Placement",
          desc = "Which side of the crosshair the pips sit on.",
          order = 2,
          width = 1.5,
          values = {below = "Below", above = "Above", left = "Left", right = "Right"},
          get = function()
            return TR.P.pipPlacement
          end,
          set = function(_, value)
            TR.P.pipPlacement = value
            Changed()
          end
        },
        pipDistance = Range("pipDistance", "Distance", "How far from the crosshair center the pips sit. Grows with HUD Size.", 3, 10, 150, 1),
        pipSpread = Range("pipSpread", "Spacing", "Space between pips (degrees along the circle).", 4, 4, 40, 1),
        pipSize = Range("pipSize", "Pip Size", "Size of each pip.", 5, 4, 30, 1)
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
        testHUD = Button("Preview HUD", "Shows the arcs and pips with sample values for 5 seconds.", 1, function()
          TR.UI.Hide()
          TR.Features.TestHUD()
        end),
        testHit = Button("Hit", "Plays the hit marker.", 2, function()
          TR.Features.TestHit(false)
        end),
        testCrit = Button("Crit", "Plays the crit marker.", 3, function()
          TR.Features.TestHit(true)
        end),
        testKill = Button("Kill", "Plays the kill marker.", 4, function()
          TR.Features.TestKill()
        end)
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                  SMART CROSSHAIR                                  --
---------------------------------------------------------------------------------------
local function SmartOff()
  return not TR.P.smartEnabled
end

Features.smart = {
  type = "group",
  args = {
    intro = Note(
      "Makes the crosshair react to what's happening: range colors, hiding it when you don't need it, following your character's head as you zoom, and screen effects.",
      1),
    smartEnabled = Toggle("smartEnabled", "Enable Smart Crosshair", "Turns all features on this page on or off.", 2,
      {width = "full"}),
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
            return TR.P.visibility
          end,
          set = function(_, value)
            TR.P.visibility = value
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
              return SmartOff() or not TR.P.hideIdle
            end
          }),
        combatOpacity = Toggle("combatOpacity", "Combat Opacity", "Use a different opacity in and out of combat.", 9,
          {width = "full"}),
        opacityInCombat = Range("opacityInCombat", "In Combat", "Crosshair opacity in combat.", 10, 0, 1, 0.05, {
          isPercent = true,
          disabled = function()
            return SmartOff() or not TR.P.combatOpacity
          end
        }),
        opacityOutCombat = Range("opacityOutCombat", "Out Of Combat", "Crosshair opacity out of combat.", 11, 0, 1,
          0.05, {
            isPercent = true,
            disabled = function()
              return SmartOff() or not TR.P.combatOpacity
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
            return TR.P.rangeSpellMelee
          end,
          set = function(_, value)
            TR.P.rangeSpellMelee = value
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
            return TR.P.rangeSpellRanged
          end,
          set = function(_, value)
            TR.P.rangeSpellRanged = value
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
            return SmartOff() or not TR.P.headTracking
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
              return not TR.P.stealthVignette
            end
          }),
        lowHealthVignette = Toggle("lowHealthVignette", "Low Health Vignette",
          "Red, pulsing screen edges when your health is low.\n\n|cff909090Only where the game lets addons read your health.|r",
          3),
        lowHealthThreshold = Range("lowHealthThreshold", "Low Health At", "Health below which the effect starts.", 4,
          0.1, 0.6, 0.05, {
            isPercent = true,
            disabled = function()
              return not TR.P.lowHealthVignette
            end
          }),
        lowHealthOpacity = Range("lowHealthOpacity", "Low Health Strength", "How strong the red edges get.", 5, 0.1,
          1, 0.05, {
            isPercent = true,
            disabled = function()
              return not TR.P.lowHealthVignette
            end
          }),
        testVignette = Button("Preview", "Shows the low health effect for 4 seconds.", 6, function()
          TR.UI.Hide()
          TR.Features.TestVignette()
        end)
      }
    }
  }
}

---------------------------------------------------------------------------------------
--                                SITUATIONAL CAMERA                                 --
---------------------------------------------------------------------------------------
local function CamOff()
  return not TR.P.camEnabled or TR.DynamicCam
end

local function CamChanged()
  Changed()
  if TR.Camera then
    TR.Camera.Reapply()
  end
end

local function SituationGroup(sit, order)
  local key = sit.key
  local function S()
    return TR.P.situations[key]
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
        TR.Camera.Preview(key)
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
    name = "|cffE37527A camera addon is running, so True Reticle leaves the camera alone.|r",
    order = 1.5,
    width = "full",
    hidden = function()
      return not TR.DynamicCam
    end
  },
  camEnabled = Toggle("camEnabled", "Enable Situational Camera",
    "Lets True Reticle move the camera per situation. Turning it off restores your camera settings.", 2, {
      width = "full",
      set = function(_, value)
        TR.P.camEnabled = value
        CamChanged()
      end,
      disabled = function()
        return TR.DynamicCam
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
          TR.P.camTransition = v
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
for i, sit in ipairs(TR.CameraSituations) do
  cameraArgs["sit_" .. sit.key] = SituationGroup(sit, 100 + i)
end

Features.camera = {type = "group", args = cameraArgs}

---------------------------------------------------------------------------------------
--                                     PROFILES                                      --
---------------------------------------------------------------------------------------
local function ProfileValues()
  local values = {}
  for _, name in ipairs(TR.Profiles.List()) do
    values[name] = name
  end
  return values
end

local function OtherProfileValues()
  local values = {}
  local active = TR.Profiles.ActiveName()
  for _, name in ipairs(TR.Profiles.List()) do
    if name ~= active then
      values[name] = name
    end
  end
  return values
end

local function Print(msg)
  print(TR.Constants.BasePrintMsg .. "|cff909090: " .. msg .. "|r")
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
        return TR.Profiles.ActiveName()
      end,
      set = function(_, value)
        TR.Profiles.SetActive(value)
      end
    },
    newProfile = {
      type = "input",
      name = "New Profile (copy of active)",
      desc = "Type a name and press Enter. The new profile starts as a copy of the active one and becomes active.",
      order = 3,
      width = 1.8,
      get = function()
        return ""
      end,
      set = function(_, value)
        local ok, err = TR.Profiles.Create(value, TR.Profiles.ActiveName())
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
      confirmText = TR.METADATA["TITLE"] .. "\n\nOverwrite the active profile with the selected one?",
      get = function()
        return nil
      end,
      set = function(_, value)
        TR.Profiles.CopyInto(value)
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
      confirmText = TR.METADATA["TITLE"] .. "\n\nDelete the selected profile?",
      get = function()
        return nil
      end,
      set = function(_, value)
        TR.Profiles.Delete(value)
      end
    },
    reset = Button("Reset Active Profile", "Puts every HUD, Smart Crosshair and Camera setting of the active profile back to default.",
      6, function()
        TR.Profiles.ResetActive()
      end, {
        confirm = true,
        confirmText = TR.METADATA["TITLE"] .. "\n\nReset the active profile to default settings?"
      })
  }

  local specs = TR.Profiles.GetSpecs()
  if #specs > 0 then
    args.specHeader = Header("Specializations", 10)
    args.useSpec = {
      type = "toggle",
      name = "Use A Profile Per Specialization",
      desc = "Switches profile automatically when you change specialization.",
      order = 11,
      width = "full",
      get = function()
        return TR.Profiles.UsesSpecProfiles()
      end,
      set = function(_, value)
        TR.Profiles.SetUseSpecProfiles(value)
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
          local char = TR.DB.char
          return char.trSpecProfiles and char.trSpecProfiles[spec.id] or char.trProfile
        end,
        set = function(_, value)
          TR.Profiles.SetSpecProfile(spec.id, value)
        end,
        disabled = function()
          return not TR.Profiles.UsesSpecProfiles()
        end
      }
    end
  end
  return args
end
