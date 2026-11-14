-- Crosshair Z
-- Crosshair HUD: arcs around the crosshair (your health and power on the left,
-- your target's health and cast on the right) and class resources as orbs.
-- The same builder draws the HUD in the world and in the settings preview.

local _, Z = ...
local H = Z.Module("HUD")


local function SafeBar(bar, method, ...)
  pcall(bar[method], bar, ...)
end

---------------------------------------------------------------------------
-- Arcs
---------------------------------------------------------------------------
-- Each arc has three layers: a dark rim behind it (always visible, so the
-- arc reads on any ground), a soft neon glow, and the fill itself. The glow
-- follows the fill's value and color on its own.
local function NewArc(parent, side)
  local a = CreateFrame("StatusBar", nil, parent)
  a:SetOrientation("VERTICAL")
  a.track = a:CreateTexture(nil, "BACKGROUND")
  a.track:SetAllPoints()
  local neon = CreateFrame("StatusBar", nil, a)
  neon:SetAllPoints()
  neon:SetOrientation("VERTICAL")
  neon:SetFrameLevel(math.max(0, a:GetFrameLevel() - 1))
  a.neon = neon
  local setValue, setRange, setColor = a.SetValue, a.SetMinMaxValues, a.SetStatusBarColor
  local nValue, nRange, nColor = neon.SetValue, neon.SetMinMaxValues, neon.SetStatusBarColor
  a.SetValue = function(self, v)
    setValue(self, v)
    pcall(nValue, neon, v)
  end
  a.SetMinMaxValues = function(self, lo, hi)
    setRange(self, lo, hi)
    pcall(nRange, neon, lo, hi)
  end
  a.SetStatusBarColor = function(self, r, g, b)
    setColor(self, r, g, b)
    pcall(nColor, neon, r, g, b)
  end
  a:SetMinMaxValues(0, 1)
  a:SetValue(1)
  a.glow = a:CreateTexture(nil, "OVERLAY")
  a.glow:SetAllPoints()
  a.glow:SetTexture(Z.MEDIA .. "arc_" .. side .. "_glow")
  a.glow:SetBlendMode("ADD")
  a.glow:SetAlpha(0)
  a.side = side
  return a
end

local function StyleArc(a, p)
  local level = Z.Clamp(math.floor((tonumber(p.thick) or 3) + 0.5), 1, 6)
  local base = Z.MEDIA .. "arc_" .. a.side .. "_" .. level
  local style = p.arcStyle == "smooth" and "s" or "g"
  a:SetStatusBarTexture(base .. style)
  a.track:SetTexture(base .. style .. "_bg")
  a.track:SetAlpha(p.track)
  a.neon:SetStatusBarTexture(base .. "_neon")
  local tex = a.neon:GetStatusBarTexture()
  if tex then
    tex:SetBlendMode("ADD")
  end
  a.neon:SetAlpha(p.neon and 0.55 or 0)
end

---------------------------------------------------------------------------
-- Orbs
---------------------------------------------------------------------------
local MAX_ORBS = 10
local ORB_COLORS = {
  combo = {1, 0.78, 0.2}, holy = {1, 0.9, 0.45}, shards = {0.68, 0.38, 1}, chi = {0.4, 1, 0.75},
  arcane = {0.45, 0.65, 1}, essence = {0.35, 0.9, 0.85}, runes = {0.85, 0.2, 0.25}
}
local RED = {0.95, 0.18, 0.18}

local function NewOrb(parent)
  local o = CreateFrame("Frame", nil, parent)
  o.empty = o:CreateTexture(nil, "BACKGROUND")
  o.empty:SetAllPoints()
  o.empty:SetTexture(Z.MEDIA .. "orb_empty")
  o.fill = o:CreateTexture(nil, "ARTWORK")
  o.fill:SetPoint("CENTER")
  o.fill:SetTexture(Z.MEDIA .. "orb_fill")
  o.shine = o:CreateTexture(nil, "ARTWORK", nil, 2)
  o.shine:SetAllPoints()
  o.shine:SetTexture(Z.MEDIA .. "orb_shine")
  o.shine:SetBlendMode("ADD")
  o.ring = o:CreateTexture(nil, "OVERLAY")
  o.ring:SetAllPoints()
  o.ring:SetTexture(Z.MEDIA .. "orb_ring")
  o.burst = o:CreateTexture(nil, "OVERLAY", nil, 2)
  o.burst:SetPoint("CENTER")
  o.burst:SetTexture(Z.MEDIA .. "orb_burst")
  o.burst:SetBlendMode("ADD")
  o.burst:SetAlpha(0)
  o.dot = o:CreateTexture(nil, "ARTWORK")
  o.dot:SetAllPoints()
  o.dot:SetTexture(Z.MEDIA .. "pip")
  o.lit, o.k, o.gain, o.spend = false, 0, 0, 0
  return o
end

---------------------------------------------------------------------------
-- One HUD (world or preview)
---------------------------------------------------------------------------
function H.New(parent)
  local hud = CreateFrame("Frame", nil, parent)
  hud:SetSize(1, 1)
  hud.healthOuter = NewArc(hud, "l")
  hud.power = NewArc(hud, "l")
  hud.targetOuter = NewArc(hud, "r")
  hud.cast = NewArc(hud, "r")
  hud.orbs = {}
  for i = 1, MAX_ORBS do
    hud.orbs[i] = NewOrb(hud)
  end
  hud.count, hud.clock = 0, 0
  local function Label()
    local fs = hud:CreateFontString(nil, "OVERLAY")
    fs:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    return fs
  end
  hud.leftNumber = Label()
  hud.rightNumber = Label()

  -- Arcs are two crescents per side that close almost into a circle around the
  -- crosshair. The images are half rings (128 x 256) whose ring centre sits on
  -- their inner edge, with the outer edge 118 pixels from it.
  local R_OUTER = 58
  local TEX_W, TEX_H, TEX_R = 128, 256, 118
  local WEIGHTS = {7, 10, 13, 17, 21, 26}
  local R_INNER = 46

  function hud:Layout(p, centerY)
    local s = p.scale
    local level = Z.Clamp(math.floor((tonumber(p.thick) or 3) + 0.5), 1, 6)
    -- the inner arc sits just inside the outer one, however thick it is
    R_INNER = R_OUTER - WEIGHTS[level] * R_OUTER / TEX_R - 4
    self.rOuter = R_OUTER
    local function Put(arc, radius, side)
      local k = radius * s / TEX_R
      arc:SetSize(TEX_W * k, TEX_H * k)
      arc:ClearAllPoints()
      arc:SetPoint(side < 0 and "RIGHT" or "LEFT", self, "CENTER", p.x, centerY + p.y)
      StyleArc(arc, p)
    end
    -- percent labels just outside the middle of each side
    for side, fs in pairs({[-1] = self.leftNumber, [1] = self.rightNumber}) do
      fs:SetFont(STANDARD_TEXT_FONT, math.max(8, math.floor(12 * s + 0.5)), "OUTLINE")
      fs:ClearAllPoints()
      fs:SetPoint(side < 0 and "RIGHT" or "LEFT", self, "CENTER", side * (R_OUTER * s + 6) + p.x, centerY + p.y)
      fs:SetShown(p.numbers and true or false)
    end
    Put(self.healthOuter, R_OUTER, -1)
    Put(self.power, R_INNER, -1)
    Put(self.targetOuter, R_OUTER, 1)
    Put(self.cast, R_INNER, 1)
    self.centerY = centerY
    self.p = p
    self:LayoutOrbs()
  end

  function hud:LayoutOrbs()
    local p = self.p
    local n = self.count
    local s = p.scale
    -- everything scales together, so a small HUD keeps its proportions
    local size = math.max(5, p.pipSize * s * (p.orbs and 1.25 or 0.8))
    local dist = math.max(p.pipDistance, (self.rOuter or 58) + 12) * s
    local step = p.pipSpread
    local mid = (n + 1) / 2
    for i = 1, MAX_ORBS do
      local o = self.orbs[i]
      if i <= n then
        -- orb 1 is always the left one (or the top one on the sides)
        local d = (i - mid) * step
        local deg
        if p.pipPlace == "above" then
          deg = 90 - d
        elseif p.pipPlace == "left" then
          deg = 180 + d
        elseif p.pipPlace == "right" then
          deg = -d
        else
          deg = 270 + d
        end
        local ang = math.rad(deg)
        o:SetSize(size, size)
        o.size = size
        o:ClearAllPoints()
        o:SetPoint("CENTER", self, "CENTER", math.cos(ang) * dist + p.x, math.sin(ang) * dist + self.centerY + p.y)
        local orb = p.orbs
        o.empty:SetShown(orb)
        o.fill:SetShown(orb)
        o.ring:SetShown(orb)
        o.shine:SetShown(orb)
        o.burst:SetShown(orb)
        o.dot:SetShown(not orb)
        o:Show()
      else
        o:Hide()
      end
    end
  end

  -- cur/max orbs, color, which ones are charging (table or nil)
  function hud:SetOrbs(cur, max, color, charging, animate)
    if max ~= self.count then
      self.count = max
      for i = 1, MAX_ORBS do
        self.orbs[i].lit = i <= cur
        self.orbs[i].k = i <= cur and 1 or 0
      end
      if self.p then
        self:LayoutOrbs()
      end
    end
    local p = self.p
    local col = (p and p.orbColor == "red") and RED or color
    local stagger = 0
    for i = 1, max do
      local o = self.orbs[i]
      local lit = i <= cur
      if lit ~= o.lit then
        if animate and p.orbAnim then
          if lit then
            o.gain = 1 + stagger
          else
            o.spend = 1 + stagger
          end
          stagger = stagger + 0.12
        else
          o.k = lit and 1 or 0
        end
        o.lit = lit
      end
      o.charging = charging and charging[i]
      o.fill:SetVertexColor(col[1], col[2], col[3])
      o.burst:SetVertexColor(col[1], col[2], col[3])
      o.dot:SetVertexColor(col[1], col[2], col[3])
      o.dot:SetAlpha(lit and 1 or 0.25)
    end
    self.full = cur >= max and max > 0
  end

  function hud:Tick(e)
    self.clock = self.clock + e
    local p = self.p
    if not p then
      return
    end
    for i = 1, self.count do
      local o = self.orbs[i]
      local size = o.size or 16
      if o.gain > 0 then
        o.gain = o.gain - e / 0.45
        local t = 1 - Z.Clamp(o.gain, 0, 1)
        if o.gain <= 1 then
          o.k = t
          o.burst:SetAlpha(1 - t)
          o.burst:SetSize(size * (1 + 1.6 * t), size * (1 + 1.6 * t))
        end
        if o.gain <= 0 then
          o.gain, o.k = 0, 1
          o.burst:SetAlpha(0)
        end
      elseif o.spend > 0 then
        o.spend = o.spend - e / 0.3
        if o.spend <= 1 then
          o.k = Z.Clamp(o.spend, 0, 1)
        end
        if o.spend <= 0 then
          o.spend, o.k = 0, 0
        end
      end
      if o.gain <= 0 and o.spend <= 0 then
        o.k = o.lit and 1 or 0
      end
      local k = o.k
      local pop = (o.gain > 0 and o.gain <= 1) and (1 + 0.3 * math.sin((1 - o.gain) * math.pi)) or 1
      o.fill:SetSize(size * 0.86 * math.max(k, 0.01) * pop, size * 0.86 * math.max(k, 0.01) * pop)
      o.fill:SetAlpha(k)
      local shine = 0
      if o.charging then
        shine = 0.35 + 0.3 * math.sin(self.clock * 5)
        o.fill:SetSize(size * 0.86, size * 0.86)
        o.fill:SetAlpha(0.3)
      elseif self.full and p.orbGlow then
        shine = 0.25 + 0.35 * math.max(0, math.sin(self.clock * 2.5 - i * 0.6))
      elseif o.gain > 0 then
        shine = 0.8
      end
      o.shine:SetAlpha(shine * k + (o.charging and shine or 0))
    end
  end

  return hud
end

---------------------------------------------------------------------------
-- Class resources
---------------------------------------------------------------------------
local P = Enum and Enum.PowerType or {}
local _, class = UnitClass("player")

local function Resource()
  local spec = GetSpecialization and Z.Call(GetSpecialization) or 0
  if class == "ROGUE" or (class == "DRUID" and GetShapeshiftFormID and GetShapeshiftFormID() == 1) then
    return "combo", P.ComboPoints or 4
  elseif class == "PALADIN" then
    return "holy", P.HolyPower or 9
  elseif class == "WARLOCK" then
    return "shards", P.SoulShards or 7
  elseif class == "MONK" and spec == 3 then
    return "chi", P.Chi or 12
  elseif class == "MAGE" and spec == 1 then
    return "arcane", P.ArcaneCharges or 16
  elseif class == "EVOKER" then
    return "essence", P.Essence or 19
  elseif class == "DEATHKNIGHT" then
    return "runes"
  end
end

local function ReadResource()
  local kind, ptype = Resource()
  if not kind then
    return nil
  end
  if kind == "runes" then
    if not GetRuneCooldown then
      return nil
    end
    local ready, charging = 0, {}
    local states = {}
    for i = 1, 6 do
      local start, duration, isReady = Z.CallAll(GetRuneCooldown, i)
      states[i] = isReady and true or false
      if isReady then
        ready = ready + 1
      end
    end
    for i = ready + 1, 6 do
      charging[i] = true
    end
    return ready, 6, ORB_COLORS.runes, charging
  end
  local cur = Z.Call(UnitPower, "player", ptype) or 0
  local max = Z.Call(UnitPowerMax, "player", ptype) or 0
  if max <= 0 then
    return nil
  end
  max = math.min(max, MAX_ORBS)
  local charging
  if kind == "essence" and cur < max then
    charging = {[cur + 1] = true}
  end
  return cur, max, ORB_COLORS[kind], charging
end

---------------------------------------------------------------------------
-- The HUD in the world
---------------------------------------------------------------------------
local world = H.New(UIParent)
world:SetPoint("CENTER")
world:SetFrameStrata("MEDIUM")
world:SetAlpha(0)
H.world = world

local function PowerColor()
  local _, token = UnitPowerType("player")
  local c = token and PowerBarColor and PowerBarColor[token]
  if c then
    return c.r, c.g, c.b
  end
  return 0.3, 0.55, 1
end

-- Writes a unit's health percent, also when the game hides the real numbers
local function Percent(fs, unit)
  if UnitHealthPercent then
    local curve = CurveConstants and CurveConstants.ScaleTo100
    local ok, v = pcall(UnitHealthPercent, unit, true, curve)
    if ok and v ~= nil and pcall(fs.SetFormattedText, fs, "%d%%", v) then
      return
    end
  end
  local cur, max = Z.Call(UnitHealth, unit), Z.Call(UnitHealthMax, unit)
  if cur and max and max > 0 then
    fs:SetFormattedText("%d%%", math.floor(cur / max * 100 + 0.5))
  else
    fs:SetText("")
  end
end

local function Feed(bar, cur, max)
  SafeBar(bar, "SetMinMaxValues", 0, max or 1)
  SafeBar(bar, "SetValue", cur or 0)
end

local castInfo
local function UpdateCast(bar)
  local name, _, _, startMS, endMS = Z.CallAll(UnitCastingInfo, "target")
  local channel = false
  if not name then
    name, _, _, startMS, endMS = Z.CallAll(UnitChannelInfo, "target")
    channel = name ~= nil
  end
  if name and startMS and endMS and endMS > startMS then
    local now = GetTime() * 1000
    local k = Z.Clamp((now - startMS) / (endMS - startMS), 0, 1)
    if channel then
      k = 1 - k
    end
    Feed(bar, k, 1)
    bar:SetStatusBarColor(1, 0.7, 0.2)
    bar:SetAlpha(1)
    return true
  end
  -- the game hides cast times from us here; show a full bar while a cast runs
  local ok, secretName = pcall(UnitCastingInfo, "target")
  if not ok or (not Z.Secret(secretName) and secretName == nil) then
    ok, secretName = pcall(UnitChannelInfo, "target")
  end
  if ok and (Z.Secret(secretName) or secretName ~= nil) then
    Feed(bar, 1, 1)
    bar:SetStatusBarColor(1, 0.7, 0.2)
    bar:SetAlpha(0.8)
    return true
  end
  Feed(bar, 0, 1)
  return false
end

local function Execute(p)
  if not p.execute then
    return false
  end
  local cur = Z.Call(UnitHealth, "target")
  local max = Z.Call(UnitHealthMax, "target")
  if not cur or not max or max <= 0 or cur <= 0 then
    return false
  end
  if not Z.Call(UnitCanAttack, "player", "target") then
    return false
  end
  return cur / max * 100 <= p.executePct
end

local function Visible(p)
  if not p.enabled then
    return false
  end
  if Z.Previewing() then
    return true
  end
  if p.show == "always" then
    return true
  end
  local combat = Z.InCombat()
  if p.show == "target" then
    return combat or Z.Truthy(UnitExists, "target")
  end
  return combat
end
H.Visible = function()
  return Z.P and Visible(Z.P.hud)
end

local sampleClock = 0
local function UpdateWorld(e)
  local p = Z.P.hud
  local y = Z.CrosshairY()
  if not world.centerY or math.abs(world.centerY - y) > 0.5 then
    world:Layout(p, y)
  end
  local want = Visible(p) and p.opacity or 0
  world.alpha = (world.alpha or 0) + (want - (world.alpha or 0)) * math.min(1, e * 8)
  world:SetAlpha(world.alpha)
  if world.alpha < 0.01 and want == 0 then
    return
  end
  local preview = Z.Previewing()
  if preview then
    sampleClock = sampleClock + e
    local t = sampleClock
    Feed(world.healthOuter, 0.75 + 0.2 * math.sin(t * 0.7), 1)
    Feed(world.power, 0.55 + 0.3 * math.sin(t * 0.9), 1)
    Feed(world.targetOuter, 0.15 + 0.1 * math.sin(t * 0.5), 1)
    Feed(world.cast, (t * 0.4) % 1, 1)
    world.healthOuter:SetStatusBarColor(0.3, 0.95, 0.4)
    world.power:SetStatusBarColor(PowerColor())
    world.targetOuter:SetStatusBarColor(1, 0.3, 0.3)
    world.cast:SetStatusBarColor(1, 0.7, 0.2)
    world.targetOuter.glow:SetAlpha(p.execute and 0.4 + 0.4 * math.sin(t * 6) or 0)
    world.leftNumber:SetText(math.floor((0.75 + 0.2 * math.sin(t * 0.7)) * 100) .. "%")
    world.rightNumber:SetText(math.floor((0.15 + 0.1 * math.sin(t * 0.5)) * 100) .. "%")
    if p.pips then
      local n = math.floor(t * 1.2) % 6
      world:SetOrbs(n, 5, ORB_COLORS.combo, nil, true)
    else
      world:SetOrbs(0, 0, RED)
    end
  else
    Feed(world.healthOuter, UnitHealth("player"), UnitHealthMax("player"))
    world.healthOuter:SetStatusBarColor(0.3, 0.95, 0.4)
    Feed(world.power, UnitPower("player"), UnitPowerMax("player"))
    world.power:SetStatusBarColor(PowerColor())
    Percent(world.leftNumber, "player")
    if UnitExists("target") then
      Percent(world.rightNumber, "target")
      Feed(world.targetOuter, UnitHealth("target"), UnitHealthMax("target"))
      if Z.Call(UnitCanAttack, "player", "target") then
        world.targetOuter:SetStatusBarColor(1, 0.3, 0.3)
      else
        world.targetOuter:SetStatusBarColor(0.3, 0.95, 0.4)
      end
      world.targetOuter:SetAlpha(1)
      UpdateCast(world.cast)
      world.targetOuter.glow:SetAlpha(Execute(p) and (0.45 + 0.4 * math.sin(GetTime() * 6)) or 0)
    else
      Feed(world.targetOuter, 0, 1)
      Feed(world.cast, 0, 1)
      world.rightNumber:SetText("")
      world.targetOuter.glow:SetAlpha(0)
    end
    local cur, max, color, charging
    if p.pips then
      cur, max, color, charging = ReadResource()
    end
    if cur then
      world:SetOrbs(cur, max, color, charging, true)
    else
      world:SetOrbs(0, 0, RED)
    end
  end
  world:Tick(e)
end

function H:Setup()
  world:SetScript("OnUpdate", function(_, e)
    if Z.P then
      UpdateWorld(e)
    end
  end)
end

function H:Apply()
  world:Layout(Z.P.hud, Z.CrosshairY())
end

Z.Listen("SETTING", function(path)
  if path and path:find("^cross%.") then
    world:Layout(Z.P.hud, Z.CrosshairY())
  end
end)

function H:Stop()
  world:Hide()
end

H.ORB_COLORS = ORB_COLORS
