-- Crosshair Z
-- Every settings page, described as cards of controls.

local _, Z = ...
local W = Z.W
local C = W.C

---------------------------------------------------------------------------
-- Shorthands
---------------------------------------------------------------------------
local function Merge(t, extra)
  for k, v in pairs(extra or {}) do
    t[k] = v
  end
  return t
end
local function T(label, path, desc, extra)
  return Merge({type = "toggle", label = label, path = path, desc = desc}, extra)
end
local function S(label, path, min, max, step, desc, extra)
  return Merge({type = "slider", label = label, path = path, min = min, max = max, step = step, desc = desc}, extra)
end
local function D(label, path, choices, desc, extra)
  return Merge({type = "select", label = label, path = path, choices = choices, desc = desc}, extra)
end
local function Col(label, path, desc, extra)
  return Merge({type = "color", label = label, path = path, desc = desc}, extra)
end
local function Key(label, binding, desc, extra)
  return Merge({type = "key", label = label, binding = binding, desc = desc}, extra)
end
local function B(label, func, desc, extra)
  return Merge({type = "button", label = label, func = func, desc = desc}, extra)
end
local function I(label, path, desc, extra)
  return Merge({type = "input", label = label, path = path, desc = desc}, extra)
end
local function Txt(label, extra)
  return Merge({type = "text", label = label}, extra)
end
local function Off(path)
  return function()
    return not Z.Get(path)
  end
end

---------------------------------------------------------------------------
-- Preview box (crosshair, HUD and orbs with sample values)
---------------------------------------------------------------------------
local function Preview(parent, width)
  local h = 200
  local box = CreateFrame("Frame", nil, parent)
  box:SetHeight(h)
  W.Fill(box, {0.03, 0.035, 0.045, 1})
  W.Outline(box, C.line)
  local stage = CreateFrame("Frame", nil, box)
  stage:SetSize(1, 1)
  stage:SetPoint("CENTER", 0, 10)
  local cross = stage:CreateTexture(nil, "OVERLAY")
  cross:SetPoint("CENTER")
  local hud = Z.HUD.New(stage)
  hud:SetPoint("CENTER")
  local label = W.Text(box, 10, {1, 0.82, 0.2})
  label:SetPoint("BOTTOMLEFT", 8, 6)
  label:SetText("PREVIEW")
  local clock = 0
  box:SetScript("OnUpdate", function(_, e)
    clock = clock + e
    local p = Z.P.hud
    hud:SetShown(p.enabled)
    local function Feed(bar, v)
      bar:SetMinMaxValues(0, 1)
      bar:SetValue(v)
    end
    Feed(hud.healthOuter, 0.75 + 0.2 * math.sin(clock * 0.7))
    Feed(hud.power, 0.55 + 0.3 * math.sin(clock * 0.9))
    Feed(hud.targetOuter, 0.18 + 0.1 * math.sin(clock * 0.5))
    Feed(hud.cast, (clock * 0.4) % 1)
    hud.healthOuter:SetStatusBarColor(0.3, 0.95, 0.4)
    hud.power:SetStatusBarColor(0.3, 0.55, 1)
    hud.targetOuter:SetStatusBarColor(1, 0.3, 0.3)
    hud.cast:SetStatusBarColor(1, 0.7, 0.2)
    hud.targetOuter.glow:SetAlpha(p.execute and (0.4 + 0.4 * math.sin(clock * 6)) or 0)
    hud.leftNumber:SetText(math.floor((0.75 + 0.2 * math.sin(clock * 0.7)) * 100) .. "%")
    hud.rightNumber:SetText(math.floor((0.18 + 0.1 * math.sin(clock * 0.5)) * 100) .. "%")
    if p.pips then
      hud:SetOrbs(math.floor(clock * 1.2) % 6, 5, Z.HUD.ORB_COLORS.combo, nil, true)
    else
      hud:SetOrbs(0, 0, {1, 1, 1})
    end
    hud:Tick(e)
  end)
  function box.Refresh()
    local c = Z.P.cross
    cross:SetTexture(Z.Reticle.Texture(c.style))
    cross:SetSize(c.size, c.size)
    local col = c.colorEnemy
    cross:SetVertexColor(col[1], col[2], col[3])
    cross:SetAlpha(c.enabled and c.opacity or 0.15)
    local p = Z.P.hud
    hud:Layout(p, 0)
    hud:SetAlpha(p.opacity)
  end
  return box, h
end
local PREVIEW = {type = "custom", build = Preview}

---------------------------------------------------------------------------
-- Crosshair style browser
---------------------------------------------------------------------------
local function Styles(parent, width)
  local tile, gap = 50, 6
  local per = math.max(1, math.floor((width + gap) / (tile + gap)))
  local rows = math.ceil(#Z.Reticle.STYLES / per)
  local h = rows * (tile + gap)
  local box = CreateFrame("Frame", nil, parent)
  box:SetHeight(h)
  local tiles = {}
  for i, s in ipairs(Z.Reticle.STYLES) do
    local b = CreateFrame("Button", nil, box)
    b:SetSize(tile, tile)
    b:SetPoint("TOPLEFT", ((i - 1) % per) * (tile + gap), -math.floor((i - 1) / per) * (tile + gap))
    W.Fill(b, C.field)
    W.Outline(b, C.line)
    local t = b:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 8, -8)
    t:SetPoint("BOTTOMRIGHT", -8, 8)
    t:SetTexture(Z.Reticle.Texture(s[1]))
    W.Tip(b, s[2], "Click to use this style.")
    b:SetScript("OnClick", function()
      Z.Set("cross.style", s[1])
      Z.Panel.Refresh()
    end)
    b.key = s[1]
    tiles[i] = b
  end
  function box.Refresh()
    local r, g, bl = W.Accent()
    for _, b in ipairs(tiles) do
      if b.key == Z.P.cross.style then
        b:SetOutline(r, g, bl, 1)
      else
        b:SetOutline(C.line[1], C.line[2], C.line[3], 1)
      end
    end
  end
  return box, h
end

---------------------------------------------------------------------------
-- Choice lists
---------------------------------------------------------------------------
local function StyleChoices()
  local out = {}
  for _, s in ipairs(Z.Reticle.STYLES) do
    out[#out + 1] = {s[1], s[2]}
  end
  return out
end

local function SoundChoices()
  local order = {"none", "click", "soft", "page", "chime", "ping", "alert"}
  local out = {}
  for _, k in ipairs(order) do
    out[#out + 1] = {k, Z.SOUND_CHOICES[k]}
  end
  return out
end

local function ActionChoices()
  local out = {}
  for _, a in ipairs(Z.Clicks.ACTIONS) do
    out[#out + 1] = {a[1], a[2]}
  end
  return out
end

local function ProfileChoices()
  local out = {}
  for _, name in ipairs(Z.ProfileList()) do
    out[#out + 1] = {name, name}
  end
  return out
end

local function ThemeChoices()
  local out = {}
  for _, k in ipairs({"green", "ice", "gold", "crimson", "violet"}) do
    out[#out + 1] = {k, W.THEMES[k][1]}
  end
  return out
end

---------------------------------------------------------------------------
-- Mouse Actions rows
---------------------------------------------------------------------------
local function ClickItems()
  local items = {}
  for _, k in ipairs(Z.CLICK_KEYS) do
    local key = k.key
    items[#items + 1] = D(k.name, "clicks.binds." .. key, ActionChoices, "What this click does while Aim Mode is on.",
      {disabled = Off("clicks.enabled")})
    items[#items + 1] = I(k.name .. " - Macro Name", "clicks.macros." .. key,
      "Name of a macro to run (choose Run Macro above).", {
        disabled = function()
          return not Z.P.clicks.enabled or Z.P.clicks.binds[key] ~= "MACRO"
        end
      })
  end
  return items
end

---------------------------------------------------------------------------
-- Situations editor
---------------------------------------------------------------------------
local selected = "combat"
local function Sit(field)
  return {
    get = function()
      return Z.P.camera.situations[selected][field]
    end,
    set = function(v)
      Z.P.camera.situations[selected][field] = v
      Z.Changed("camera.situations")
    end
  }
end
local function SituationChoices()
  local out = {}
  for _, s in ipairs(Z.SITUATIONS) do
    out[#out + 1] = {s.key, s.name}
  end
  return out
end
local function SitOff()
  return not Z.P.camera.situational or Z.Camera.Yield()
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
Z.Pages = {
  {key = "home", title = "Home", subtitle = "Overview and quick actions", section = "Start",
   build = function(...)
     return Z.Home.Build(...)
   end},
  {key = "notes", title = "Patch Notes", subtitle = "What's new in Crosshair Z", section = "Start",
   build = function(...)
     return Z.Home.BuildNotes(...)
   end},

  {key = "look", title = "Aim Mode", subtitle = "Aim Mode keys, cursor unlock, tooltips", section = "Aim",
   cards = {
     {title = "Keys", note = "Aim Mode turns the camera with your mouse without holding a button.", items = {
       Key("Aim Mode - Toggle", "CROSSHAIRZ_LOOK", "Press to turn Aim Mode on or off."),
       Key("Aim Mode - Hold", "CROSSHAIRZ_HOLD", "Hold to free the cursor for a moment (or to look around while Aim Mode is off)."),
       Key("Interact With Target", "INTERACTTARGET", "Talk, loot or use whatever is under the crosshair."),
       Key("Flip Camera Shoulder", "CROSSHAIRZ_FLIP", "Moves the camera to your other shoulder.")
     }},
     {title = "Auto Cursor", items = {
       T("Aim Mode On At Login", "look.startOn", "Aim Mode starts on when you log in, like the default for this kind of addon. Off: press the key to start it."),
       T("Free The Cursor For Game Windows", "look.unlockPanels", "Bags, map, character panel, vendors, dialogs and similar windows free the cursor and Aim Mode comes back when they close."),
       T("Free The Cursor On A Vendor Mount", "look.vendorMount", "Frees the cursor while you sit on a mount with vendors."),
       T("Pulse Cursor When Freed", "look.pulse", "A ring shows where your cursor is when Aim Mode turns off."),
       S("Camera Turn Speed", "look.turnSpeed", 30, 360, 5, "How fast the camera turns with the mouse.", {disabled = function()
         return Z.Camera.Yield()
       end})
     }},
     {title = "Feel", items = {
       T("Weapons Follow Aim Mode", "look.sheathe", "Draws your weapons when Aim Mode turns on and puts them away when it turns off (out of combat)."),
       T("Aim Mode Vignette", "look.vignette", "Darker screen edges while Aim Mode is on."),
       S("Vignette Strength", "look.vignetteStrength", 0.1, 1, 0.05, "How dark the edges get.", {pct = true, disabled = Off("look.vignette")})
     }},
     {title = "Tooltips During Aim Mode", items = {
       D("Tooltips", "look.tooltip", {{"hide", "Hide"}, {"show", "Show"}, {"shift", "Only while holding Shift"},
         {"ctrl", "Only while holding Ctrl"}, {"alt", "Only while holding Alt"}},
         "When shown, you get the tooltip of whatever is under the crosshair."),
       D("Tooltip Position", "look.tooltipAt", {{"crosshair", "Next to the crosshair"}, {"default", "Game default"}},
         "Where the tooltip shows.", {disabled = function()
           return Z.P.look.tooltip == "hide"
         end})
     }}
   }},

  {key = "aim", title = "Crosshair Aim", subtitle = "Target what you aim at", section = "Aim", toggle = "aim.enabled",
   cards = {
     {title = "Crosshair Aim", note = "Aim the crosshair at a unit to make it your target. @mouseover and @cursor macros use the crosshair too.", items = {
       T("Enable Crosshair Aim", "aim.enabled", "Turns aiming to target on or off.", {full = true}),
       T("Target What You Aim At", "aim.prioritize", "The enemy under the crosshair becomes your target. Off: the game only highlights it.", {disabled = Off("aim.enabled")}),
       T("Sticky Crosshair", "aim.sticky", "A slightly wider aim, so the crosshair holds on to moving targets.", {disabled = Off("aim.enabled")}),
       T("Aim At Friendly Units", "aim.friendly", "Friendly players and NPCs can be aimed at too.", {disabled = Off("aim.enabled")}),
       T("No Friendly Aim In Combat", "aim.friendlyCombat", "Stops friendly aiming while you fight.", {disabled = function()
         return not Z.P.aim.enabled or not Z.P.aim.friendly
       end})
     }},
     {title = "World", items = {
       T("Show Target Circle", "aim.circle", "The circle under your target."),
       T("Unit Outlines", "aim.outlines", "The outline around your target, mouseover and group.")
     }}
   }},

  {key = "lock", title = "Target Hold", subtitle = "Keep a target, cycle enemies, sounds", section = "Aim",
   cards = {
     {title = "Keys", items = {
       Key("Target Hold", "CROSSHAIRZ_LOCK", "Locks your current target so aiming elsewhere doesn't change it."),
       D("Target Hold Key Does", "lock.behavior", {{"toggle", "Toggle lock"}, {"switch", "Switch to the enemy I aim at"}},
         "Toggle: press to lock, press again to unlock. Switch: while locked, press to move the lock to the enemy under the crosshair."),
       Key("Hold Cycle - Next Enemy", "CLICK CrosshairZNextEnemy:LeftButton", "Moves to the next nearby enemy, like Tab. Works in combat."),
       Key("Hold Cycle - Previous Enemy", "CLICK CrosshairZPrevEnemy:LeftButton", "Moves to the previous nearby enemy."),
       T("Cycle Keys Lock The New Target", "lock.cycleLocks", "The enemy you cycle to is locked."),
       T("Auto Hold", "lock.auto", "Locks an enemy when you land your first harmful spell on it.")
     }},
     {title = "Hold Marker", items = {
       T("Flash When The Target Casts", "lock.castFlash", "The TARGET HELD tag reads TARGET CASTING and flashes."),
       T("Soft Pulse", "lock.pulse", "The tag pulses every few seconds.")
     }},
     {title = "Sounds", note = "Sounds are off by default.", items = {
       T("Play Hold Sounds", "lock.sounds", "Sounds for lock, cycle, unlock and when your locked target casts.", {full = true}),
       D("Lock", "lock.soundLock", SoundChoices, nil, {disabled = Off("lock.sounds")}),
       D("Cycle", "lock.soundCycle", SoundChoices, nil, {disabled = Off("lock.sounds")}),
       D("Unlock", "lock.soundClear", SoundChoices, nil, {disabled = Off("lock.sounds")}),
       D("Target Casts", "lock.soundCast", SoundChoices, nil, {disabled = Off("lock.sounds")}),
       D("Sound Channel", "lock.channel", {{"SFX", "Effects"}, {"Master", "Master"}, {"Dialog", "Dialog"}, {"Ambience", "Ambience"}}, nil,
         {disabled = Off("lock.sounds")}),
       B("Test Sounds", function()
         Z.Lock.TestSounds()
       end, "Plays all four sounds.", {disabled = Off("lock.sounds")})
     }}
   }},

  {key = "clicks", title = "Mouse Actions", subtitle = "Mouse buttons while Aim Mode is on", section = "Aim", toggle = "clicks.enabled",
   cards = {
     {title = "Mouse Actions", note = "While Aim Mode is on, your clicks run these actions. With Aim Mode off, your mouse works as usual.", items = (function()
       local items = {T("Enable Mouse Actions", "clicks.enabled", nil, {full = true})}
       for _, it in ipairs(ClickItems()) do
         items[#items + 1] = it
       end
       return items
     end)()}
   }},

  {key = "crosshair", title = "Crosshair", subtitle = "Style, size, states and colors", section = "Crosshair", toggle = "cross.enabled",
   cards = {
     {items = {PREVIEW}},
     {title = "Style", items = {{type = "custom", build = Styles}}},
     {title = "Size And Position", items = {
       T("Show Crosshair", "cross.enabled", "Turns the crosshair on or off.", {full = true}),
       S("Size", "cross.size", 12, 96, 1, "Crosshair size."),
       S("Vertical Position", "cross.y", -300, 300, 1, "Moves the crosshair up or down. The hidden cursor follows it."),
       S("Opacity In Combat", "cross.opacity", 0.1, 1, 0.05, nil, {pct = true}),
       S("Opacity Out Of Combat", "cross.opacityOut", 0, 1, 0.05, nil, {pct = true}),
       T("Head Tracking", "cross.head", "The crosshair follows your character's head height as you zoom in and out.")
     }},
     {title = "States", items = {
       D("While Mounted", "cross.mounted", {{"show", "Show"}, {"dim", "Dim"}, {"hide", "Hide"}}),
       D("While Aim Mode Is Off", "cross.offLook", {{"show", "Show"}, {"faint", "Faint"}, {"hide", "Hide"}}),
       T("Grow While Casting", "cross.castGrow", "Grows while you cast or channel."),
       T("Pulse When A Cast Lands", "cross.castPulse"),
       T("Shake When Interrupted", "cross.castShake"),
       B("Test Pulse", function()
         Z.Reticle.Test("pulse")
       end),
       B("Test Shake", function()
         Z.Reticle.Test("shake")
       end)
     }},
     {title = "Colors", items = {
       Col("Enemy", "cross.colorEnemy"),
       Col("Friendly", "cross.colorFriend"),
       Col("Nothing / Object", "cross.colorNeutral")
     }}
   }},

  {key = "smart", title = "Crosshair Rules", subtitle = "Range colors and when to show the crosshair", section = "Crosshair", toggle = "smart.enabled",
   cards = {
     {items = {PREVIEW}},
     {title = "When To Show The Crosshair", items = {
       T("Enable Crosshair Rules", "smart.enabled", nil, {full = true}),
       D("Show Crosshair", "smart.show", {{"always", "Always"}, {"combat", "Only in combat"}, {"enemy", "Only when aiming at an enemy"}},
         nil, {disabled = Off("smart.enabled")}),
       T("Hide In Flight", "smart.hideFlight", "Flight paths and flying.", {disabled = Off("smart.enabled")}),
       T("Hide When Idle", "smart.hideIdle", "After 5 seconds standing still out of combat.", {disabled = Off("smart.enabled")}),
       T("Hide Without A Target", "smart.hideNoTarget", nil, {disabled = Off("smart.enabled")}),
       T("Hide On Friendly Targets", "smart.hideFriendly", nil, {disabled = Off("smart.enabled")}),
       T("Hide On Dead Targets", "smart.hideDead", nil, {disabled = Off("smart.enabled")}),
       T("Hide When Out Of Range", "smart.hideRange", nil, {disabled = Off("smart.enabled")})
     }},
     {title = "Range Colors", note = "Green in melee range, yellow in range of your ranged spells, red when nothing reaches. Spells are picked from your action bars, or set your own.", items = {
       T("Range Colors", "smart.range", nil, {full = true, disabled = Off("smart.enabled")}),
       I("Melee Check Spell", "smart.meleeSpell", "Optional. Spell name or ID. Empty uses auto attack.", {disabled = Off("smart.range")}),
       I("Ranged Check Spell", "smart.rangedSpell", "Optional. Spell name or ID. Empty picks one from your bars.", {disabled = Off("smart.range")}),
       Col("Melee", "smart.colorMelee", nil, {disabled = Off("smart.range")}),
       Col("Ranged", "smart.colorRanged", nil, {disabled = Off("smart.range")}),
       Col("Out Of Range", "smart.colorOut", nil, {disabled = Off("smart.range")})
     }}
   }},

  {key = "hud", title = "Crosshair HUD", subtitle = "Arcs, class resource orbs, hit and kill feedback", section = "HUD", toggle = "hud.enabled",
   cards = {
     {items = {PREVIEW}},
     {title = "Arcs", note = "Your health and power on the left, your target's health and cast on the right.", items = {
       T("Show Crosshair HUD", "hud.enabled", nil, {full = true}),
       D("Show HUD", "hud.show", {{"combat", "Only in combat"}, {"target", "In combat or with a target"}, {"always", "Always"}}, nil, {disabled = Off("hud.enabled")}),
       D("Arc Style", "hud.arcStyle", {{"segments", "Quarter Marks"}, {"smooth", "Smooth"}}, nil, {disabled = Off("hud.enabled")}),
       T("Neon Glow", "hud.neon", "A soft glow around the filled part of each arc.", {disabled = Off("hud.enabled")}),
       T("Show Percent", "hud.numbers", "Your health and your target's health as a number under the arcs.", {disabled = Off("hud.enabled")}),
       S("Arc Thickness", "hud.thick", 1, 6, 1, "How thick the arcs are, from 1 (hairline) to 6 (heavy).", {disabled = Off("hud.enabled")}),
       S("HUD Size", "hud.scale", 0.25, 2, 0.05, nil, {pct = true, disabled = Off("hud.enabled")}),
       S("HUD Opacity", "hud.opacity", 0.1, 1, 0.05, nil, {pct = true, disabled = Off("hud.enabled")}),
       S("Arc Background", "hud.track", 0, 1, 0.05, "How visible the dark rim and the empty part of each arc are.", {pct = true, disabled = Off("hud.enabled")}),
       S("Horizontal Offset", "hud.x", -200, 200, 1, nil, {disabled = Off("hud.enabled")}),
       S("Vertical Offset", "hud.y", -200, 200, 1, nil, {disabled = Off("hud.enabled")}),
       T("Execute Glow", "hud.execute", "The target arc glows when an enemy is low.", {disabled = Off("hud.enabled")}),
       S("Execute Below", "hud.executePct", 5, 50, 1, "Health percent.", {disabled = Off("hud.execute")})
     }},
     {title = "Class Resources", note = "Combo points, holy power, soul shards, chi, arcane charges, essence and runes.", items = {
       T("Show Class Resources", "hud.pips", nil, {disabled = Off("hud.enabled")}),
       T("Orb Style", "hud.orbs", "Gold-ringed animated orbs. Off: small dots.", {disabled = Off("hud.pips")}),
       D("Placement", "hud.pipPlace", {{"below", "Below"}, {"above", "Above"}, {"left", "Left"}, {"right", "Right"}}, nil, {disabled = Off("hud.pips")}),
       S("Distance", "hud.pipDistance", 70, 160, 1, nil, {disabled = Off("hud.pips")}),
       S("Spacing", "hud.pipSpread", 10, 40, 1, nil, {disabled = Off("hud.pips")}),
       S("Size", "hud.pipSize", 8, 32, 1, nil, {disabled = Off("hud.pips")}),
       D("Orb Color", "hud.orbColor", {{"red", "Red"}, {"resource", "Color per resource"}}, nil, {disabled = Off("hud.orbs")}),
       T("Animate Orbs", "hud.orbAnim", "Pop in with a flash, shrink away when spent.", {disabled = Off("hud.orbs")}),
       T("Glow When Full", "hud.orbGlow", nil, {disabled = Off("hud.orbs")})
     }},
     {title = "Hit And Kill Feedback", items = {
       T("Hit Markers", "hud.hits", "A marker on the crosshair when you deal damage, gold on crits."),
       T("Kill Marker", "hud.kills", "A red marker when your enemy dies."),
       B("Test Hit", function()
         Z.Effects.ShowMarker("hit")
       end),
       B("Test Kill", function()
         Z.Effects.ShowMarker("kill")
       end)
     }},
     {title = "Screen Effects", items = {
       T("Stealth Edges", "hud.stealthEdges", "Purple screen edges while stealthed."),
       T("Low Health Pulse", "hud.lowHealth", "Red pulsing screen edges at low health."),
       S("Low Health Below", "hud.lowHealthPct", 10, 60, 1, "Health percent.", {disabled = Off("hud.lowHealth")}),
       B("Test Low Health", function()
         Z.Effects.TestLowHealth()
       end)
     }}
   }},

  {key = "assist", title = "Prompts", subtitle = "Suggested cast and interaction prompt", section = "HUD", toggle = "assist.enabled",
   cards = {
     {title = "General", items = {
       T("Enable Prompts", "assist.enabled", nil, {full = true}),
       T("Show Keybinds", "assist.keybind", "Shows the key (or your mouse click in Aim Mode) next to the suggested spell.", {disabled = Off("assist.enabled")}),
       S("Opacity", "assist.opacity", 0.2, 1, 0.05, nil, {pct = true, disabled = Off("assist.enabled")}),
       B("Move Prompts", function()
         Z.Panel.Hide()
         Z.Assist.SetMoving(true)
       end, "Drag the prompts anywhere, then press Done Moving. Also: /cz move", {disabled = Off("assist.enabled")})
     }},
     {title = "Next Suggested Cast", note = "The spell the game suggests next for your rotation.", visible = function()
       return C_AssistedCombat ~= nil
     end, items = {
       T("Show Suggested Cast", "assist.spell", nil, {disabled = Off("assist.enabled")}),
       T("Only In Combat", "assist.spellCombat", nil, {disabled = Off("assist.spell")}),
       S("Icon Size", "assist.spellSize", 24, 80, 1, nil, {disabled = Off("assist.spell")})
     }},
     {title = "Interaction Prompt", note = "A moving icon and your interact key when the crosshair is on something: a hopping bag for loot, a typing speech bubble for talking, a turning gear for objects.", items = {
       T("Show Interaction Prompt", "assist.prompt", nil, {disabled = Off("assist.enabled")}),
       T("Glow", "assist.promptGlow", nil, {disabled = Off("assist.prompt")}),
       T("Show Name", "assist.promptName", "Shows the name of what you aim at under the key.", {disabled = Off("assist.prompt")}),
       S("Prompt Size", "assist.promptSize", 0.6, 1.6, 0.05, nil, {pct = true, disabled = Off("assist.prompt")})
     }}
   }},

  {key = "camera", title = "Camera", subtitle = "Over the shoulder, field of view, comfort", section = "Camera",
   cards = {
     {title = "Camera", visible = function()
       return Z.Camera.Yield()
     end, items = {Txt("|cffE37527DynamicCam is running. It controls the camera, zoom, shoulder view and turn speed, so the camera settings of Crosshair Z are switched off. Aim Mode, the crosshair and the HUD work on top of it.|r")}},
     {title = "Action Camera", visible = function()
       return not Z.Camera.Yield()
     end, items = {
       T("Over The Shoulder", "camera.actionCam", "Moves the camera beside your character.", {disabled = function()
         return Z.P.camera.safe
       end}),
       S("Shoulder Offset", "camera.shoulder", 0, 3, 0.05, nil, {disabled = function()
         return Z.P.camera.safe or not Z.P.camera.actionCam
       end}),
       T("Dynamic Pitch", "camera.pitch", "Tilts the camera so you see more ahead of you.", {disabled = function()
         return Z.P.camera.safe or not Z.P.camera.actionCam
       end}),
       T("Camera Turns Toward Your Target", "camera.focus", "The camera gently swings toward the enemy you target.", {disabled = function()
         return Z.P.camera.safe or not Z.P.camera.actionCam
       end}),
       S("Turn Strength", "camera.focusStrength", 0.1, 1, 0.05, nil, {pct = true, disabled = function()
         return Z.P.camera.safe or not Z.P.camera.actionCam or not Z.P.camera.focus
       end}),
       T("Flipped To Other Shoulder", "camera.flipped", "Also on the Flip Camera Shoulder key.", {disabled = function()
         return Z.P.camera.safe or not Z.P.camera.actionCam
       end})
     }},
     {title = "Base Camera", visible = function()
       return not Z.Camera.Yield()
     end, items = {
       S("Field Of View", "camera.fov", 50, 90, 1),
       S("Max Zoom Distance", "camera.maxZoom", 1, 2.6, 0.1),
       S("Zoom Scroll Speed", "camera.zoomSpeed", 1, 50, 1),
       S("Head Tracking Strength", "camera.headMove", 0, 2, 0.1, "How much the camera follows your character's head.", {disabled = function()
         return Z.P.camera.safe
       end})
     }},
     {title = "Comfort", visible = function()
       return not Z.Camera.Yield()
     end, items = {
       T("Motion Sickness Protection", "camera.safe", "Crosshair Z never moves the camera off-center or makes it follow head movement.", {full = true})
     }}
   }},

  {key = "situations", title = "Camera Scenes", subtitle = "Zoom and view change by situation", section = "Camera", toggle = "camera.situational",
   cards = {
     {title = "Camera Scenes", note = "The camera changes when your situation changes. The first matching situation in the list wins: dead, flight path, skyriding, dialogue, PvP, boss, combat, dungeon, stealth, swimming, vehicle, mounted, sitting, fishing, indoors, world.", items = {
       T("Use Camera Scenes", "camera.situational", nil, {full = true}),
       T("Skyriding Zoom Follows Speed", "camera.skyZoom", nil, {disabled = SitOff}),
       T("Orbit While Sitting", "camera.sitOrbit", "The camera slowly circles you while you /sit, /kneel or /sleep.", {disabled = SitOff})
     }},
     {title = "Edit A Situation", items = {
       {type = "select", label = "Situation", choices = SituationChoices, full = true, get = function()
         return selected
       end, set = function(v)
         selected = v
       end, disabled = SitOff},
       Merge(T("Use This Situation", nil, nil, {disabled = SitOff}), Sit("on")),
       Merge(S("Zoom", nil, 1, 39, 0.5, nil, {disabled = SitOff}), Sit("zoom")),
       Merge(S("Shoulder Offset", nil, -3, 3, 0.05, "0 keeps your normal shoulder setting.", {disabled = SitOff}), Sit("shoulder")),
       Merge(S("Head Tracking", nil, 0, 2, 0.1, nil, {disabled = SitOff}), Sit("head")),
       Merge(S("Field Of View", nil, 50, 90, 1, nil, {disabled = SitOff}), Sit("fov"))
     }}
   }},

  {key = "composer", title = "Macro Builder", subtitle = "Cast macros aimed at your crosshair, mouseover or cursor", section = "More",
   cards = {
     {title = "Macro Builder", items = {
       I("Spell", "composer.spell", "The spell to cast."),
       D("Cast At", "composer.target", function()
         local out = {}
         for _, k in ipairs({"crosshair", "mouseover", "cursor", "focus", "player"}) do
           out[#out + 1] = {k, Z.Composer.TARGETS[k]}
         end
         return out
       end),
       I("Macro Name", "composer.name", "Up to 16 letters."),
       B("Save Macro", function()
         Z.Composer.Save()
       end, "Saves it to your account macros (Esc > Macros).", {accent = true}),
       Txt(function()
         return "|cffcfcfcf" .. Z.Composer.Text() .. "|r"
       end, {size = 13})
     }}
   }},

  {key = "profiles", title = "Profiles", subtitle = "Per character and per specialization", section = "More",
   cards = {
     {title = "Profiles", note = "Every Crosshair Z setting lives in a profile.", items = {
       {type = "select", label = "Active Profile", choices = ProfileChoices, get = function()
         return Z.profileName
       end, set = function(v)
         Z.UseProfile(v)
       end},
       {type = "input", label = "New Profile (copy of active)", get = function()
         return ""
       end, set = function(v)
         if not Z.NewProfile(v) then
           Z.Print("That name is empty or already used.")
         end
       end},
       {type = "select", label = "Copy Settings From", choices = ProfileChoices, get = function()
         return nil
       end, set = function(v)
         Z.Panel.Confirm("Replace the settings of " .. Z.profileName .. " with " .. v .. "?", function()
           Z.CopyProfile(v)
         end)
       end},
       {type = "toggle", label = "Use A Profile Per Specialization", desc = "Each specialization remembers its own profile.",
        get = function()
          return Z.PerSpec()
        end, set = function(v)
          Z.PerSpec(v)
        end},
       B("Export Profile", function()
         Z.Share.OpenExport()
       end, "Shows this profile as a text string you can copy and share. Also: /cz export"),
       B("Import Profile", function()
         Z.Share.OpenImport()
       end, "Paste a profile string to add it as a new profile. Also: /cz import"),
       B("Reset Profile", function()
         Z.ResetProfile()
       end, "Puts every setting in this profile back to default.", {confirm = "Reset every setting in this profile?"}),
       B("Delete Profile", function()
         Z.DeleteProfile(Z.profileName)
       end, "Deletes this profile. Default can't be deleted.", {
         confirm = function()
           return "Delete the profile " .. Z.profileName .. "?"
         end,
         disabled = function()
           return Z.profileName == "Default"
         end
       })
     }}
   }},

  {key = "advanced", title = "Advanced", subtitle = "Window, custom cursor rule, undo", section = "More",
   cards = {
     {title = "Settings Window", items = {
       D("Theme", "g:theme", ThemeChoices, nil, {after = function()
         Z.Panel.Rebuild()
       end}),
       S("Window Scale", "g:panelScale", 0.7, 1.3, 0.05, nil, {pct = true, after = function()
         Z.Panel.Rescale()
       end})
     }},
     {title = "Auto Cursor Watchlist", note = "Names of other addons' windows that should free the cursor, one per line or separated by spaces.", items = {
       {type = "multiline", label = "Frame Names", path = "look.watchlist", height = 70}
     }},
     {title = "Custom Condition", note = "Lua code that returns true when the cursor should be freed. Example: return IsMounted() and GetUnitSpeed('player') == 0. Your own code runs here, so test it carefully.", items = {
       {type = "multiline", label = "Condition", path = "look.condition", height = 90}
     }},
     {title = "Undo", items = {
       B("Undo All Changes", function()
         Z.Undo()
       end, "Puts back the game settings you had before Crosshair Z, turns the addon off and reloads.", {
         confirm = "Put back your game settings and turn Crosshair Z off? The UI will reload."
       }),
       T("Debug Messages", "g:debug")
     }}
   }}
}
