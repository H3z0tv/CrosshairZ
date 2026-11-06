---------------------------------------------------------------------------------------
--                          RETICLE HUD & SMART CROSSHAIR                            --
---------------------------------------------------------------------------------------
-- Arcs around the crosshair (player health/power, target health/cast), class resource
-- pips, hit and kill feedback, range colors, crosshair hide rules, head tracking and
-- screen vignettes. Settings come from the active profile (TR.P).
--
-- Midnight note: unit health/power and many unit queries can return "secret" values in
-- instances and combat. Secret values are never compared or used in math here; they are
-- only handed to StatusBars, which are allowed to display them.
local _G = _G
local TR = _G.LibStub("AceAddon-3.0"):GetAddon("TrueReticle")

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UIParent = _G.UIParent
local pcall = _G.pcall
local type = _G.type
local ipairs = _G.ipairs
local math_abs = _G.math.abs
local math_cos = _G.math.cos
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local math_rad = _G.math.rad
local math_sin = _G.math.sin

local F = {}
TR.Features = F

local TEX = "Interface\\AddOns\\TrueReticle\\assets\\hud\\"

local issecret = _G.issecretvalue or function()
  return false
end

-- Returns the call's first two results, or nil if it errors
local function Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b
end

-- A value we may compare / do math with
local function Readable(v)
  return v ~= nil and not issecret(v)
end

local function Bool(fn, ...)
  local v = Call(fn, ...)
  if issecret(v) then
    return nil
  end
  return v and true or false
end

local function UnitOK(unit)
  return Bool(_G.UnitExists, unit) == true
end

local function InCombat()
  return _G.InCombatLockdown() or Bool(_G.UnitAffectingCombat, "player") == true
end

-- Readable health fraction (0..1) or nil when the game keeps it secret
local function HealthPct(unit)
  local cur = Call(_G.UnitHealth, unit)
  local max = Call(_G.UnitHealthMax, unit)
  if Readable(cur) and Readable(max) and type(cur) == "number" and type(max) == "number" and max > 0 then
    return math_max(0, math_min(1, cur / max))
  end
  return nil
end

local function PowerPct(unit, powerType)
  local cur = Call(_G.UnitPower, unit, powerType)
  local max = Call(_G.UnitPowerMax, unit, powerType)
  if Readable(cur) and Readable(max) and type(cur) == "number" and type(max) == "number" and max > 0 then
    return math_max(0, math_min(1, cur / max))
  end
  return nil
end

-- Unit the HUD shows on the right side: hard target first, then the soft (reticle) target
local function HudTargetUnit()
  if UnitOK("target") then
    return "target"
  elseif UnitOK("softenemy") then
    return "softenemy"
  end
  return nil
end

local function IsHostile(unit)
  local attack = Bool(_G.UnitCanAttack, "player", unit)
  if attack == nil then
    return true
  end
  return attack
end

local function IsDead(unit)
  return Bool(_G.UnitIsDeadOrGhost, unit)
end

---------------------------------------------------------------------------------------
--                                    HUD FRAMES                                     --
---------------------------------------------------------------------------------------
local hud = CreateFrame("Frame", "TrueReticleHUD", UIParent)
hud:SetSize(128, 128)
hud:SetPoint("CENTER")
hud:Hide()
hud.alpha = 0

local function MakeArc(texture, side, level, owner)
  owner = owner or hud
  local arc = {base = texture}
  arc.bg = owner:CreateTexture(nil, "BACKGROUND")
  arc.bg:SetTexture(TEX .. texture)
  arc.bg:SetVertexColor(0, 0, 0, 0.45)

  arc.bar = CreateFrame("StatusBar", nil, owner)
  arc.bar:SetOrientation("VERTICAL")
  arc.bar:SetStatusBarTexture(TEX .. texture)
  arc.bar:SetMinMaxValues(0, 1)
  arc.bar:SetValue(1)
  arc.bar:SetFrameLevel(owner:GetFrameLevel() + (level or 1))
  arc.side = side

  function arc.Layout(size)
    local w, h = size / 2, size
    for _, region in ipairs({arc.bg, arc.bar}) do
      region:ClearAllPoints()
      region:SetSize(w, h)
      if side == "left" then
        region:SetPoint("RIGHT", owner, "CENTER", 0, 0)
      else
        region:SetPoint("LEFT", owner, "CENTER", 0, 0)
      end
    end
  end

  -- "thin", "normal" or "thick"
  function arc.SetThickness(variant)
    local file = TEX .. arc.base .. ((variant == "thin" or variant == "thick") and ("_" .. variant) or "")
    arc.bg:SetTexture(file)
    arc.bar:SetStatusBarTexture(file)
  end

  function arc.SetShown(shown)
    arc.bg:SetShown(shown)
    arc.bar:SetShown(shown)
  end

  function arc.SetColor(r, g, b, a)
    arc.bar:SetStatusBarColor(r, g, b, a or 1)
  end

  -- Accepts plain numbers or secret values (StatusBars can display secrets)
  function arc.SetValues(cur, max)
    if cur == nil or max == nil then
      return false
    end
    local ok = pcall(arc.bar.SetMinMaxValues, arc.bar, 0, max)
    if ok then
      ok = pcall(arc.bar.SetValue, arc.bar, cur)
    end
    return ok
  end

  return arc
end

local arcs = {
  health = MakeArc("arc_outer_left", "left", 2),
  power = MakeArc("arc_inner_left", "left", 2),
  target = MakeArc("arc_outer_right", "right", 2),
  cast = MakeArc("arc_inner_right", "right", 3)
}

local executeGlow = hud:CreateTexture(nil, "OVERLAY")
executeGlow:SetTexture(TEX .. "arc_glow_right")
executeGlow:SetBlendMode("ADD")
executeGlow:SetVertexColor(1, 0.25, 0.15, 1)
executeGlow:Hide()

-- Resource pips
local MAX_PIPS = 10
local pips = {}
for i = 1, MAX_PIPS do
  local pip = hud:CreateTexture(nil, "ARTWORK")
  pip:SetTexture(TEX .. "pip")
  pip:Hide()
  pips[i] = pip
end

-- Hit / kill effects live on their own frame so they still show when arcs are hidden
local fx = CreateFrame("Frame", "TrueReticleFX", UIParent)
fx:SetSize(64, 64)
fx:SetPoint("CENTER")
fx:SetFrameStrata("HIGH")
local hitTex = fx:CreateTexture(nil, "OVERLAY")
hitTex:SetTexture(TEX .. "hitmarker")
hitTex:SetPoint("CENTER")
hitTex:SetAlpha(0)
local bloomTex = fx:CreateTexture(nil, "ARTWORK")
bloomTex:SetTexture(TEX .. "bloom")
bloomTex:SetBlendMode("ADD")
bloomTex:SetPoint("CENTER")
bloomTex:SetAlpha(0)

-- Full-screen vignette (below the interface, above the world)
local vignette = CreateFrame("Frame", "TrueReticleVignette", UIParent)
vignette:SetAllPoints(UIParent)
vignette:SetFrameStrata("BACKGROUND")
vignette:SetFrameLevel(0)
local vignetteTex = vignette:CreateTexture(nil, "BACKGROUND")
vignetteTex:SetTexture(TEX .. "vignette")
vignetteTex:SetAllPoints()
vignetteTex:SetAlpha(0)
vignette.alpha = 0

---------------------------------------------------------------------------------------
--                                   TEST MODE                                       --
---------------------------------------------------------------------------------------
local testUntil = 0
local vignetteTestUntil = 0

local function Testing()
  return GetTime() < testUntil
end

function F.TestHUD()
  testUntil = GetTime() + 5
  hud:Show()
end

function F.TestVignette()
  vignetteTestUntil = GetTime() + 4
end

---------------------------------------------------------------------------------------
--                                  CLASS RESOURCES                                  --
---------------------------------------------------------------------------------------
local PT = _G.Enum and _G.Enum.PowerType or {}
local POWER = {
  combo = PT.ComboPoints or 4,
  holy = PT.HolyPower or 9,
  shards = PT.SoulShards or 7,
  chi = PT.Chi or 12,
  arcane = PT.ArcaneCharges or 16,
  essence = PT.Essence or 19
}

local playerClass = select(2, _G.UnitClass("player"))

local function SpecIndex()
  local index = Call(_G.GetSpecialization)
  return Readable(index) and index or nil
end

-- Returns current, max, r, g, b for the player's class resource, or nil
local function ClassResource()
  local cls = playerClass
  local powerType
  local r, g, b = 1, 0.82, 0.25

  if cls == "ROGUE" then
    powerType = POWER.combo
    r, g, b = 1, 0.85, 0.2
  elseif cls == "DRUID" then
    local form = Call(_G.GetShapeshiftFormID)
    local combo = Call(_G.UnitPower, "player", POWER.combo)
    if form == 1 or (Readable(combo) and type(combo) == "number" and combo > 0) then
      powerType = POWER.combo
      r, g, b = 1, 0.6, 0.15
    end
  elseif cls == "PALADIN" then
    powerType = POWER.holy
    r, g, b = 0.95, 0.9, 0.45
  elseif cls == "WARLOCK" then
    powerType = POWER.shards
    r, g, b = 0.65, 0.35, 0.95
  elseif cls == "MONK" then
    if SpecIndex() == 3 then
      powerType = POWER.chi
      r, g, b = 0.45, 1, 0.75
    end
  elseif cls == "MAGE" then
    if SpecIndex() == 1 then
      powerType = POWER.arcane
      r, g, b = 0.45, 0.6, 1
    end
  elseif cls == "EVOKER" then
    powerType = POWER.essence
    r, g, b = 0.3, 0.85, 0.85
  elseif cls == "DEATHKNIGHT" and _G.GetRuneCooldown then
    local ready = 0
    for i = 1, 6 do
      local okRune, _, _, isReady = pcall(_G.GetRuneCooldown, i)
      if okRune and Readable(isReady) and isReady then
        ready = ready + 1
      end
    end
    return ready, 6, 0.8, 0.2, 0.25
  end

  if not powerType then
    return nil
  end
  local cur = Call(_G.UnitPower, "player", powerType)
  local max = Call(_G.UnitPowerMax, "player", powerType)
  if not (Readable(cur) and Readable(max)) or type(max) ~= "number" or max <= 0 then
    return nil
  end
  return math_min(cur, MAX_PIPS), math_min(max, MAX_PIPS), r, g, b
end

---------------------------------------------------------------------------------------
--                                    HUD UPDATE                                     --
---------------------------------------------------------------------------------------
local lastLayoutSize, lastAnchorY, lastAnchorX, lastThickness, lastTrack

local function LayoutHUD(P)
  local size = math_floor(128 * (P.hudScale or 1) + 0.5)
  local y = (TR.GetCrosshairY and TR.GetCrosshairY() or 0) + (P.hudOffsetY or 0)
  local x = P.hudOffsetX or 0
  local thickness = P.arcThickness or "normal"
  if thickness ~= lastThickness then
    lastThickness = thickness
    for _, arc in pairs(arcs) do
      arc.SetThickness(thickness)
    end
  end
  local track = P.hudTrackOpacity or 0.75
  if track ~= lastTrack then
    lastTrack = track
    for _, arc in pairs(arcs) do
      arc.bg:SetVertexColor(0, 0, 0, track)
    end
  end
  if size ~= lastLayoutSize then
    lastLayoutSize = size
    hud:SetSize(size, size)
    for _, arc in pairs(arcs) do
      arc.Layout(size)
    end
    executeGlow:ClearAllPoints()
    executeGlow:SetSize(size / 2, size)
    executeGlow:SetPoint("LEFT", hud, "CENTER", 0, 0)
  end
  if y ~= lastAnchorY or x ~= lastAnchorX then
    lastAnchorY, lastAnchorX = y, x
    hud:ClearAllPoints()
    hud:SetPoint("CENTER", UIParent, "CENTER", x, y)
    -- hit / kill markers stay on the crosshair itself
    fx:ClearAllPoints()
    fx:SetPoint("CENTER", UIParent, "CENTER", 0, y - (P.hudOffsetY or 0))
  end
end

local function PowerColor()
  local _, token = Call(_G.UnitPowerType, "player")
  local colors = _G.PowerBarColor
  local c = colors and token and colors[token]
  if c and c.r then
    return c.r, c.g, c.b
  end
  return 0.25, 0.55, 1
end

local function UpdateCast(unit, P, now)
  local arc = arcs.cast
  if not (P.arcTargetCast and unit) then
    arc.SetShown(false)
    return
  end

  -- the cast name may be secret: check that before comparing it with nil
  local ok, cName, _, _, cStart, cEnd, _, _, cNoInt = pcall(_G.UnitCastingInfo, unit)
  local casting = ok and (issecret(cName) or cName ~= nil)
  local channel = false
  if not casting then
    ok, cName, _, _, cStart, cEnd, _, cNoInt = pcall(_G.UnitChannelInfo, unit)
    casting = ok and (issecret(cName) or cName ~= nil)
    channel = true
  end
  if not casting then
    arc.SetShown(false)
    return
  end

  local r, g, b = 1, 0.8, 0.2
  if Readable(cNoInt) and cNoInt then
    r, g, b = 0.6, 0.6, 0.65
  end
  arc.SetColor(r, g, b, 1)
  arc.SetShown(true)

  if Readable(cStart) and Readable(cEnd) and type(cStart) == "number" and type(cEnd) == "number" and cEnd > cStart then
    local progress = (now * 1000 - cStart) / (cEnd - cStart)
    if channel then
      progress = 1 - progress
    end
    arc.SetValues(math_max(0, math_min(1, progress)), 1)
  else
    -- timing is secret: show a pulsing full arc so the cast is still visible
    arc.SetValues(1, 1)
    arc.bar:SetAlpha(0.55 + 0.45 * math_sin(now * 8))
    return
  end
  arc.bar:SetAlpha(1)
end

local function UpdatePips(P, active)
  if not P.pipsEnabled then
    for _, pip in ipairs(pips) do
      pip:Hide()
    end
    return
  end

  local cur, max, r, g, b = ClassResource()
  if Testing() then
    cur, max, r, g, b = 3, 5, 1, 0.85, 0.2
  end
  if not cur or (cur == 0 and not active) then
    for _, pip in ipairs(pips) do
      pip:Hide()
    end
    return
  end

  local dist = (P.pipDistance or 82) * (P.hudScale or 1)
  local size = P.pipSize or 12
  local step = P.pipSpread or 25 -- degrees between pips
  local center = 270 -- below
  if P.pipPlacement == "above" then
    center = 90
  elseif P.pipPlacement == "left" then
    center = 180
  elseif P.pipPlacement == "right" then
    center = 0
  end
  local start = center - step * (max - 1) / 2
  for i = 1, MAX_PIPS do
    local pip = pips[i]
    if i <= max then
      local angle = math_rad(start + (i - 1) * step)
      pip:ClearAllPoints()
      pip:SetSize(size, size)
      pip:SetPoint("CENTER", hud, "CENTER", math_cos(angle) * dist, math_sin(angle) * dist)
      if i <= cur then
        pip:SetVertexColor(r, g, b, 1)
      else
        pip:SetVertexColor(0.15, 0.15, 0.18, 0.7)
      end
      pip:Show()
    else
      pip:Hide()
    end
  end
end

local function UpdateHUD(elapsed, now)
  local P = TR.P
  if not P then
    return
  end
  local testing = Testing()

  if not P.hudEnabled and not testing then
    hud:Hide()
    return
  end

  LayoutHUD(P)

  local crosshairShown = TR.CrosshairTexture and TR.CrosshairTexture:IsShown() and TR.DB.global.crosshair
  local unit = HudTargetUnit()
  local inCombat = InCombat()
  local healthPct = HealthPct("player")
  local hurt = healthPct ~= nil and healthPct < 0.999

  -- hudShow: "always", "active" (combat, target or hurt) or "combat"
  local mode = P.hudShow or "active"
  local active
  if mode == "combat" then
    active = inCombat
  elseif mode == "always" then
    active = true
  else
    active = inCombat or unit ~= nil or hurt
  end
  active = active or testing
  local want = (crosshairShown or testing) and active

  -- fade in / out
  local target = want and ((P.hudOpacity or 0.9) * (TR.crosshairAlphaMult or 1)) or 0
  if testing then
    target = P.hudOpacity or 0.9
  end
  local speed = elapsed * 6
  hud.alpha = hud.alpha + (target - hud.alpha) * math_min(1, speed)
  if hud.alpha < 0.01 and target == 0 then
    hud.alpha = 0
    hud:Hide()
    return
  end
  hud:Show()
  hud:SetAlpha(hud.alpha)

  if testing then
    arcs.health.SetShown(P.arcPlayerHealth)
    arcs.health.SetColor(P.arcHealthColor[1], P.arcHealthColor[2], P.arcHealthColor[3])
    arcs.health.SetValues(0.62, 1)
    arcs.power.SetShown(P.arcPlayerPower)
    arcs.power.SetColor(PowerColor())
    arcs.power.SetValues(0.45, 1)
    arcs.target.SetShown(P.arcTargetHealth)
    arcs.target.SetColor(0.9, 0.2, 0.2)
    arcs.target.SetValues(0.18, 1)
    arcs.cast.SetShown(P.arcTargetCast)
    arcs.cast.SetColor(1, 0.8, 0.2)
    arcs.cast.SetValues((now % 2) / 2, 1)
    arcs.cast.bar:SetAlpha(1)
    executeGlow:SetShown(P.arcExecuteGlow and P.arcTargetHealth)
    executeGlow:SetAlpha(0.45 + 0.35 * math_sin(now * 6))
    UpdatePips(P, true)
    return
  end

  -- Player health (left, outer)
  if P.arcPlayerHealth then
    arcs.health.SetColor(P.arcHealthColor[1], P.arcHealthColor[2], P.arcHealthColor[3])
    local shown = arcs.health.SetValues(Call(_G.UnitHealth, "player"), Call(_G.UnitHealthMax, "player"))
    arcs.health.SetShown(shown)
  else
    arcs.health.SetShown(false)
  end

  -- Player power (left, inner)
  if P.arcPlayerPower then
    arcs.power.SetColor(PowerColor())
    local shown = arcs.power.SetValues(Call(_G.UnitPower, "player"), Call(_G.UnitPowerMax, "player"))
    arcs.power.SetShown(shown)
  else
    arcs.power.SetShown(false)
  end

  -- Target health (right, outer) + execute glow
  local glow = false
  if P.arcTargetHealth and unit then
    if IsHostile(unit) then
      arcs.target.SetColor(0.92, 0.22, 0.2)
    else
      arcs.target.SetColor(0.3, 0.85, 0.35)
    end
    local shown = arcs.target.SetValues(Call(_G.UnitHealth, unit), Call(_G.UnitHealthMax, unit))
    arcs.target.SetShown(shown)
    if shown and P.arcExecuteGlow and IsHostile(unit) then
      local pct = HealthPct(unit)
      glow = pct ~= nil and pct > 0 and pct <= (P.executeThreshold or 0.2)
    end
  else
    arcs.target.SetShown(false)
  end
  executeGlow:SetShown(glow)
  if glow then
    executeGlow:SetAlpha(0.45 + 0.35 * math_sin(now * 6))
  end

  UpdateCast(unit, P, now)
  UpdatePips(P, active)
end

---------------------------------------------------------------------------------------
--                              SETTINGS WINDOW PREVIEW                              --
---------------------------------------------------------------------------------------
-- A small live copy of the crosshair + HUD for the settings window. It uses the active
-- profile's settings and sample values, so changes show immediately.
function F.CreatePreview(parent, width)
  local height = 190
  local box = CreateFrame("Frame", nil, parent)
  box:SetHeight(height)

  local bg = box:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.05, 0.06, 0.08, 1)

  local label = box:CreateFontString(nil, "OVERLAY")
  label:SetFont(_G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 11, "")
  label:SetTextColor(0.6, 0.62, 0.66)
  label:SetPoint("TOPLEFT", 8, -6)
  label:SetText("Preview")

  -- clip children so large sizes / offsets stay inside the box
  if box.SetClipsChildren then
    pcall(box.SetClipsChildren, box, true)
  end

  local stage = CreateFrame("Frame", nil, box)
  stage:SetSize(128, 128)
  stage:SetPoint("CENTER")

  local crosshair = box:CreateTexture(nil, "ARTWORK")
  crosshair:SetPoint("CENTER")

  local p = {
    health = MakeArc("arc_outer_left", "left", 2, stage),
    power = MakeArc("arc_inner_left", "left", 2, stage),
    target = MakeArc("arc_outer_right", "right", 2, stage),
    cast = MakeArc("arc_inner_right", "right", 3, stage)
  }
  local glow = stage:CreateTexture(nil, "OVERLAY")
  glow:SetTexture(TEX .. "arc_glow_right")
  glow:SetBlendMode("ADD")
  glow:SetVertexColor(1, 0.25, 0.15, 1)

  local dots = {}
  for i = 1, 5 do
    local dot = stage:CreateTexture(nil, "ARTWORK")
    dot:SetTexture(TEX .. "pip")
    dots[i] = dot
  end

  local elapsedTotal = 0

  function box.Refresh()
    local P = TR.P
    if not P then
      return
    end
    local scale = P.hudScale or 1
    local size = math_floor(128 * scale + 0.5)
    stage:SetSize(size, size)
    stage:ClearAllPoints()
    stage:SetPoint("CENTER", box, "CENTER", P.hudOffsetX or 0, P.hudOffsetY or 0)
    stage:SetAlpha(P.hudEnabled and (P.hudOpacity or 0.9) or 0.25)

    -- crosshair as configured in the Crosshair page
    local appearance = TR.DB.global.crosshairAppearance
    local cSize = TR.DB.global.crosshairSize or 64
    crosshair:SetSize(cSize, cSize)
    crosshair:SetTexture(appearance and appearance.Active or nil)
    local tint = P.smartEnabled and P.rangeColors and P.colorMelee
    if tint then
      crosshair:SetVertexColor(tint[1], tint[2], tint[3], 1)
    else
      crosshair:SetVertexColor(1, 0.2, 0.3, 1)
    end
    crosshair:SetAlpha(TR.DB.global.crosshair and (TR.DB.global.crosshairOpacity or 1) or 0.2)

    local track = P.hudTrackOpacity or 0.75
    for _, arc in pairs(p) do
      arc.SetThickness(P.arcThickness or "normal")
      arc.Layout(size)
      arc.bg:SetVertexColor(0, 0, 0, track)
    end
    local hc = P.arcHealthColor or {0.3, 0.86, 0.35}
    p.health.SetColor(hc[1], hc[2], hc[3])
    p.health.SetValues(0.7, 1)
    p.health.SetShown(P.arcPlayerHealth)
    p.power.SetColor(PowerColor())
    p.power.SetValues(0.5, 1)
    p.power.SetShown(P.arcPlayerPower)
    p.target.SetColor(0.92, 0.22, 0.2)
    p.target.SetValues(0.18, 1)
    p.target.SetShown(P.arcTargetHealth)
    p.cast.SetColor(1, 0.8, 0.2)
    p.cast.SetShown(P.arcTargetCast)

    glow:ClearAllPoints()
    glow:SetSize(size / 2, size)
    glow:SetPoint("LEFT", stage, "CENTER", 0, 0)
    glow:SetShown(P.arcTargetHealth and P.arcExecuteGlow)

    -- 3 of 5 pips
    local dist = (P.pipDistance or 82) * scale
    local pipSize = P.pipSize or 12
    local step = P.pipSpread or 25
    local center = 270
    if P.pipPlacement == "above" then
      center = 90
    elseif P.pipPlacement == "left" then
      center = 180
    elseif P.pipPlacement == "right" then
      center = 0
    end
    local start = center - step * 2
    for i, dot in ipairs(dots) do
      local angle = math_rad(start + (i - 1) * step)
      dot:ClearAllPoints()
      dot:SetSize(pipSize, pipSize)
      dot:SetPoint("CENTER", stage, "CENTER", math_cos(angle) * dist, math_sin(angle) * dist)
      if i <= 3 then
        dot:SetVertexColor(1, 0.85, 0.2, 1)
      else
        dot:SetVertexColor(0.15, 0.15, 0.18, 0.7)
      end
      dot:SetShown(P.pipsEnabled)
    end
  end

  -- the cast arc and execute glow animate while the preview is visible
  box:SetScript("OnUpdate", function(_, elapsed)
    elapsedTotal = elapsedTotal + elapsed
    p.cast.SetValues((elapsedTotal % 2) / 2, 1)
    glow:SetAlpha(0.45 + 0.35 * math_sin(elapsedTotal * 6))
  end)

  return box, height
end

---------------------------------------------------------------------------------------
--                                HIT & KILL FEEDBACK                                --
---------------------------------------------------------------------------------------
local hitAnim = {t = 1, duration = 0.18, scale = 1, r = 1, g = 1, b = 1}
local bloomAnim = {t = 1, duration = 0.35, scale = 1, r = 1, g = 0.7, b = 0.2}
local lastPlayerAction = 0
local lastKill = 0

local function PlayHit(crit)
  local P = TR.P
  hitAnim.t = 0
  if crit then
    hitAnim.duration, hitAnim.scale = 0.26, 1.35
    hitAnim.r, hitAnim.g, hitAnim.b = 1, 0.85, 0.2
  else
    hitAnim.duration, hitAnim.scale = 0.18, 1
    hitAnim.r, hitAnim.g, hitAnim.b = 1, 1, 1
  end
end

local function PlayKill()
  local P = TR.P
  hitAnim.t = 0
  hitAnim.duration, hitAnim.scale = 0.4, 1.7
  hitAnim.r, hitAnim.g, hitAnim.b = 1, 0.3, 0.2
  if P and P.killBloom then
    bloomAnim.t = 0
    bloomAnim.scale = P.killBloomSize or 1
  end
end

function F.TestHit(crit)
  PlayHit(crit)
end

function F.TestKill()
  PlayKill()
end

local function UpdateEffects(elapsed)
  local base = (TR.DB and TR.DB.global.crosshairSize or 64)

  if hitAnim.t < 1 then
    hitAnim.t = math_min(1, hitAnim.t + elapsed / hitAnim.duration)
    local k = hitAnim.t
    local size = base * 0.75 * hitAnim.scale * (1.15 - 0.15 * k)
    hitTex:SetSize(size, size)
    hitTex:SetVertexColor(hitAnim.r, hitAnim.g, hitAnim.b, 1)
    hitTex:SetAlpha(1 - k * k)
  else
    hitTex:SetAlpha(0)
  end

  if bloomAnim.t < 1 then
    bloomAnim.t = math_min(1, bloomAnim.t + elapsed / bloomAnim.duration)
    local k = bloomAnim.t
    local size = base * 2.4 * bloomAnim.scale * (0.6 + 0.8 * k)
    bloomTex:SetSize(size, size)
    bloomTex:SetVertexColor(bloomAnim.r, bloomAnim.g, bloomAnim.b, 1)
    bloomTex:SetAlpha(0.9 * (1 - k))
  else
    bloomTex:SetAlpha(0)
  end
end

-- Kill detection: a tracked hostile unit goes from alive to dead while you're in combat
local tracked = {}

local function TrackUnit(unit)
  if not UnitOK(unit) then
    tracked[unit] = nil
    return
  end
  local dead = IsDead(unit)
  if dead == nil then
    return
  end
  local guid = Call(_G.UnitGUID, unit)
  local id = Readable(guid) and guid or "?"
  local prev = tracked[unit]
  if prev and prev.id == id and prev.alive and dead and prev.hostile then
    local now = GetTime()
    if now - lastKill > 0.4 and InCombat() then
      lastKill = now
      if TR.P and TR.P.killConfirm then
        PlayKill()
      end
    end
  end
  tracked[unit] = {id = id, alive = not dead, hostile = IsHostile(unit)}
end

local AUTO_ATTACK = 6603
local function AutoAttacking()
  local fn = (_G.C_Spell and _G.C_Spell.IsCurrentSpell) or _G.IsCurrentSpell
  return Bool(fn, AUTO_ATTACK) == true
end

local function OnUnitCombat(unit, action, descriptor)
  local P = TR.P
  if not (P and P.hitConfirm) then
    return
  end
  if unit ~= "target" and unit ~= "softenemy" then
    return
  end
  if not P.hitAllSources then
    local recent = (GetTime() - lastPlayerAction) < 1.5
    if not recent and not AutoAttacking() then
      return
    end
  end
  if issecret(action) then
    PlayHit(false)
    return
  end
  if action ~= "WOUND" then
    return
  end
  local crit = not issecret(descriptor) and descriptor == "CRITICAL"
  PlayHit(crit)
end

---------------------------------------------------------------------------------------
--                                  RANGE FEEDBACK                                   --
---------------------------------------------------------------------------------------
local meleeProbes, rangedProbes = {}, {}
local probesDirty = true

local function SpellIDFromInput(input)
  if not input or input == "" then
    return nil
  end
  local asNumber = tonumber(input)
  local C_Spell = _G.C_Spell
  if C_Spell and C_Spell.GetSpellInfo then
    local info = Call(C_Spell.GetSpellInfo, asNumber or input)
    if type(info) == "table" and Readable(info.spellID) then
      return info.spellID
    end
  end
  return asNumber
end

-- Picks a few of the player's own harmful spells as melee / ranged range probes
function F.RebuildRangeProbes()
  meleeProbes, rangedProbes = {}, {}
  local P = TR.P
  local C_Spell, C_SpellBook = _G.C_Spell, _G.C_SpellBook
  if P then
    local melee = SpellIDFromInput(P.rangeSpellMelee)
    local ranged = SpellIDFromInput(P.rangeSpellRanged)
    if melee then
      meleeProbes[1] = melee
    end
    if ranged then
      rangedProbes[1] = ranged
    end
  end
  if not (C_Spell and C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines) then
    return
  end
  local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player or 0
  local spellType = _G.Enum and _G.Enum.SpellBookItemType and _G.Enum.SpellBookItemType.Spell or 1
  local lines = Call(C_SpellBook.GetNumSpellBookSkillLines) or 0
  for line = 1, lines do
    local lineInfo = Call(C_SpellBook.GetSpellBookSkillLineInfo, line)
    if type(lineInfo) == "table" and not lineInfo.shouldHide and not lineInfo.offSpecID then
      local first = (lineInfo.itemIndexOffset or 0) + 1
      local last = (lineInfo.itemIndexOffset or 0) + (lineInfo.numSpellBookItems or 0)
      for slot = first, last do
        local item = Call(C_SpellBook.GetSpellBookItemInfo, slot, bank)
        if type(item) == "table" and item.itemType == spellType and not item.isPassive and not item.isOffSpec and
          item.spellID then
          local id = item.spellID
          if Bool(C_Spell.IsSpellHarmful, id) then
            local info = Call(C_Spell.GetSpellInfo, id)
            local maxRange = type(info) == "table" and info.maxRange
            if Readable(maxRange) and type(maxRange) == "number" then
              if maxRange <= 6 and #meleeProbes < 4 then
                meleeProbes[#meleeProbes + 1] = id
              elseif maxRange >= 25 and maxRange <= 46 and #rangedProbes < 4 then
                rangedProbes[#rangedProbes + 1] = id
              end
            end
          end
        end
      end
    end
  end
  TR.DebugPrint("Range probes: " .. #meleeProbes .. " melee, " .. #rangedProbes .. " ranged")
end

local function ProbeRange(list, unit)
  local fn = _G.C_Spell and _G.C_Spell.IsSpellInRange
  local sawFalse = false
  for _, id in ipairs(list) do
    local result = Call(fn, id, unit)
    if Readable(result) then
      if result == true or result == 1 then
        return true
      elseif result == false or result == 0 then
        sawFalse = true
      end
    end
  end
  if sawFalse then
    return false
  end
  return nil
end

-- "melee", "ranged", "out" or nil (unknown / no hostile aim)
local rangeState
local function EvaluateRange()
  local unit = UnitOK("softenemy") and "softenemy" or (UnitOK("target") and "target" or nil)
  if not unit or not IsHostile(unit) or IsDead(unit) then
    return nil
  end
  local melee = ProbeRange(meleeProbes, unit)
  if melee then
    return "melee"
  end
  local ranged = ProbeRange(rangedProbes, unit)
  if ranged then
    return "ranged"
  end
  if melee == false or ranged == false then
    return "out"
  end
  return nil
end

---------------------------------------------------------------------------------------
--                                  SMART CROSSHAIR                                  --
---------------------------------------------------------------------------------------
local smartMult = 1
local idle = {time = 0}
local headZoom
local smartWasOn = false

local function DruidFlying()
  if playerClass ~= "DRUID" then
    return false
  end
  return Bool(_G.IsFlying) == true
end

local function UpdateIdle(elapsed)
  local facing = Call(_G.GetPlayerFacing)
  local zoom = Call(_G.GetCameraZoom)
  local speed = Call(_G.GetUnitSpeed, "player")
  local moved = false
  if Readable(speed) and type(speed) == "number" and speed > 0 then
    moved = true
  end
  if Readable(facing) and idle.facing and math_abs(facing - idle.facing) > 0.001 then
    moved = true
  end
  if Readable(zoom) and idle.zoom and math_abs(zoom - idle.zoom) > 0.01 then
    moved = true
  end
  idle.facing = Readable(facing) and facing or idle.facing
  idle.zoom = Readable(zoom) and zoom or idle.zoom
  if moved or InCombat() then
    idle.time = 0
  else
    idle.time = idle.time + elapsed
  end
end

local function DesiredCrosshairMult(P, elapsed)
  local inCombat = InCombat()
  local unit = HudTargetUnit()

  if P.visibility == "combat" and not inCombat then
    return 0
  end
  if P.visibility == "target" and not (unit and IsHostile(unit)) then
    return 0
  end
  if P.hideFlightForm and DruidFlying() then
    return 0
  end
  if P.hideIdle then
    UpdateIdle(elapsed)
    if idle.time >= (P.idleSeconds or 4) then
      return 0
    end
  end
  if P.hideNoTarget and not unit then
    return 0
  end
  if unit then
    if P.hideFriendly and not IsHostile(unit) then
      return 0
    end
    if P.hideDead and IsDead(unit) then
      return 0
    end
  end
  if P.hideOutOfRange and rangeState == "out" then
    return 0
  end

  local mult = 1
  if P.combatOpacity then
    mult = inCombat and (P.opacityInCombat or 1) or (P.opacityOutCombat or 0.6)
  end
  return mult
end

local function UpdateHeadTracking(P, elapsed)
  if not P.headTracking then
    if (TR.crosshairExtraY or 0) ~= 0 then
      TR.SetCrosshairExtraY(0)
    end
    headZoom = nil
    return
  end
  local zoom = Call(_G.GetCameraZoom)
  if not (Readable(zoom) and type(zoom) == "number") then
    return
  end
  headZoom = headZoom and (headZoom + (zoom - headZoom) * math_min(1, elapsed * 4)) or zoom
  local factor = P.headFactor or 1500
  if _G.IsMounted() then
    factor = factor * 1.8
  end
  -- zero at 15 yards, higher when the camera is close, a little lower when far
  local dy = factor / math_max(3, headZoom) - factor / 15
  TR.SetCrosshairExtraY(math_floor(dy + 0.5))
end

local function UpdateSmart(elapsed, rangeTick)
  local P = TR.P
  if not P or not TR.SetCrosshairAlphaMultiplier then
    return
  end

  if not P.smartEnabled then
    if smartWasOn then
      smartWasOn = false
      smartMult = 1
      TR.SetCrosshairAlphaMultiplier(1)
      TR.SetCrosshairTint(nil)
      TR.SetCrosshairExtraY(0)
    end
    return
  end
  smartWasOn = true

  if rangeTick then
    local newState = (P.rangeColors or P.hideOutOfRange) and EvaluateRange() or nil
    if newState ~= rangeState then
      rangeState = newState
      local color = P.rangeColors and
                      ((rangeState == "melee" and P.colorMelee) or (rangeState == "ranged" and P.colorRanged) or
                        (rangeState == "out" and P.colorOutOfRange))
      if color then
        TR.SetCrosshairTint(color[1], color[2], color[3], 1)
      else
        TR.SetCrosshairTint(nil)
      end
    end
  end

  local want = DesiredCrosshairMult(P, elapsed)
  local nextMult = smartMult + (want - smartMult) * math_min(1, elapsed * 6)
  if math_abs(want - nextMult) < 0.01 then
    nextMult = want
  end
  if math_abs(nextMult - smartMult) > 0.001 or nextMult ~= TR.crosshairAlphaMult then
    smartMult = nextMult
    TR.SetCrosshairAlphaMultiplier(smartMult)
  end

  UpdateHeadTracking(P, elapsed)
end

---------------------------------------------------------------------------------------
--                                    VIGNETTES                                      --
---------------------------------------------------------------------------------------
local function UpdateVignette(elapsed, now)
  local P = TR.P
  if not P then
    return
  end
  local r, g, b, target = 0, 0, 0, 0

  if now < vignetteTestUntil then
    r, g, b = 0.85, 0.1, 0.1
    target = 0.6 + 0.25 * math_sin(now * 5)
  else
    local pct = P.lowHealthVignette and HealthPct("player")
    local dead = Bool(_G.UnitIsDeadOrGhost, "player")
    if pct and not dead and pct > 0 and pct < (P.lowHealthThreshold or 0.3) then
      r, g, b = 0.85, 0.08, 0.08
      local strength = 1 - pct / (P.lowHealthThreshold or 0.3)
      target = (P.lowHealthOpacity or 0.5) * (0.55 + 0.45 * strength) * (0.75 + 0.25 * math_sin(now * 4))
    elseif P.stealthVignette and Bool(_G.IsStealthed) then
      r, g, b = 0.32, 0.12, 0.5
      target = P.stealthOpacity or 0.6
    end
  end

  vignette.alpha = vignette.alpha + (target - vignette.alpha) * math_min(1, elapsed * 5)
  if target > 0 then
    vignetteTex:SetVertexColor(r, g, b, 1)
  end
  if vignette.alpha < 0.005 and target == 0 then
    vignette.alpha = 0
  end
  vignetteTex:SetAlpha(vignette.alpha)
end

---------------------------------------------------------------------------------------
--                                      DRIVER                                       --
---------------------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local sinceHUD, sinceRange, sinceKill = 0, 0, 0

local function OnUpdate(_, elapsed)
  if not TR.P or not TR.DB then
    return
  end
  local now = GetTime()
  UpdateEffects(elapsed)
  UpdateVignette(elapsed, now)

  sinceHUD = sinceHUD + elapsed
  sinceRange = sinceRange + elapsed
  sinceKill = sinceKill + elapsed

  if sinceHUD >= 0.033 then
    local step = sinceHUD
    sinceHUD = 0
    local rangeTick = sinceRange >= 0.2
    if rangeTick then
      sinceRange = 0
      if probesDirty then
        probesDirty = false
        pcall(F.RebuildRangeProbes)
      end
    end
    local ok, err = pcall(UpdateSmart, step, rangeTick)
    if not ok then
      TR.DebugPrint("Smart crosshair error: " .. tostring(err))
    end
    ok, err = pcall(UpdateHUD, step, now)
    if not ok then
      TR.DebugPrint("HUD error: " .. tostring(err))
    end
  end

  if sinceKill >= 0.1 then
    sinceKill = 0
    if TR.P.killConfirm then
      TrackUnit("target")
      TrackUnit("softenemy")
    end
  end
end

local function OnEvent(_, event, unit, ...)
  if event == "UNIT_COMBAT" then
    OnUnitCombat(unit, ...)
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if unit == "player" then
      lastPlayerAction = GetTime()
    end
  elseif event == "PLAYER_TARGET_CHANGED" then
    tracked.target = nil
  elseif event == "PLAYER_SOFT_ENEMY_CHANGED" then
    tracked.softenemy = nil
  elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    probesDirty = true
  end
end

function F.Enable()
  for _, event in ipairs({"UNIT_COMBAT", "UNIT_SPELLCAST_SUCCEEDED", "PLAYER_TARGET_CHANGED",
    "PLAYER_SOFT_ENEMY_CHANGED", "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_SPECIALIZATION_CHANGED"}) do
    pcall(driver.RegisterEvent, driver, event)
  end
  driver:SetScript("OnEvent", OnEvent)
  driver:SetScript("OnUpdate", OnUpdate)
  probesDirty = true

  TR.Profiles.OnChange(function()
    lastLayoutSize, lastAnchorY, lastAnchorX, lastThickness, lastTrack = nil, nil, nil, nil, nil
    rangeState = "refresh"
    probesDirty = true
  end)
end

function F.Disable()
  driver:SetScript("OnUpdate", nil)
  driver:UnregisterAllEvents()
  hud:Hide()
  vignetteTex:SetAlpha(0)
  if TR.SetCrosshairAlphaMultiplier then
    TR.SetCrosshairAlphaMultiplier(1)
    TR.SetCrosshairTint(nil)
    TR.SetCrosshairExtraY(0)
  end
end
