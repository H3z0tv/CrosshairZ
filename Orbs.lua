---------------------------------------------------------------------------------------
--                                  RESOURCE ORBS                                    --
---------------------------------------------------------------------------------------
-- Class points (combo points, holy power, soul shards, chi, arcane charges, essence,
-- runes) drawn as a row of gold-ringed orbs. Points pop in with a flash, spent points
-- shrink away, and a full row glows softly. Settings come from the active profile (CZ.P).
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UIParent = _G.UIParent
local pcall = _G.pcall
local select = _G.select
local math_floor = _G.math.floor
local math_min = _G.math.min
local math_max = _G.math.max
local math_sin = _G.math.sin
local math_cos = _G.math.cos
local math_rad = _G.math.rad

local O = {}
CZ.Orbs = O

local TEX = "Interface\\AddOns\\CrosshairZ\\assets\\hud\\"
local MAX_ORBS = 10
local GAIN_TIME = 0.5
local SPEND_TIME = 0.35
local DEMO_COLOR = {1, 0.85, 0.2}

local playerClass = select(2, _G.UnitClass("player"))

local function InCombat()
  if _G.InCombatLockdown() then
    return true
  end
  local ok, v = pcall(_G.UnitAffectingCombat, "player")
  if not ok or (_G.issecretvalue and _G.issecretvalue(v)) then
    return false
  end
  return v and true or false
end

---------------------------------------------------------------------------------------
--                                     ORB ROW                                       --
---------------------------------------------------------------------------------------
-- A row of orbs with its own animation state. Used in the world and in the settings preview.
local function NewRow(parent, name)
  local row = CreateFrame("Frame", name, parent)
  row.orbs = {}
  row:SetSize(1, 1)
  row.count, row.size = 0, 0
  row.r, row.g, row.b = 1, 0.25, 0.25
  row.primed = false

  for i = 1, MAX_ORBS do
    local o = CreateFrame("Frame", nil, row)
    o.empty = o:CreateTexture(nil, "BACKGROUND")
    o.empty:SetTexture(TEX .. "pt_empty")
    o.empty:SetAllPoints()
    o.fill = o:CreateTexture(nil, "ARTWORK")
    o.fill:SetTexture(TEX .. "pt_orb")
    o.fill:SetPoint("CENTER")
    o.stripes = o:CreateTexture(nil, "ARTWORK", nil, 1)
    o.stripes:SetTexture(TEX .. "pt_stripes")
    o.stripes:SetPoint("CENTER")
    o.ring = o:CreateTexture(nil, "OVERLAY")
    o.ring:SetTexture(TEX .. "pt_ring")
    o.ring:SetAllPoints()
    o.burst = o:CreateTexture(nil, "OVERLAY", nil, 2)
    o.burst:SetTexture(TEX .. "pt_burst")
    o.burst:SetBlendMode("ADD")
    o.burst:SetPoint("CENTER")
    o.lit, o.anim, o.t = false, nil, 0
    o:Hide()
    row.orbs[i] = o
  end

  -- Places the orbs on an arc around the row's center, the way the old pips were:
  -- "center" is the angle of the middle orb, "step" the degrees between orbs
  function row:Layout(max, size, dist, step, center)
    if max == self.count and size == self.size and dist == self.dist and step == self.step and center == self.center then
      return
    end
    self.count, self.size, self.dist, self.step, self.center = max, size, dist, step, center
    local first = center - step * (max - 1) / 2
    for i = 1, MAX_ORBS do
      local o = self.orbs[i]
      o:SetSize(size, size)
      o:ClearAllPoints()
      local angle = math_rad(first + (i - 1) * step)
      o:SetPoint("CENTER", self, "CENTER", math_cos(angle) * dist, math_sin(angle) * dist)
      o.burst:SetSize(size * 2.4, size * 2.4)
      o:SetShown(i <= max)
    end
  end

  -- Tells the row what to show. Orbs that change play their animation unless animate is false.
  function row:SetState(cur, max, r, g, b, charging, animate)
    if max ~= self.shownMax then
      self.shownMax = max
      self.primed = false -- talent or spec change: snap instead of animating
    end
    self.r, self.g, self.b = r, g, b
    self.charging = (charging and cur < max) and (cur + 1) or nil

    local snap = not self.primed or not animate
    local spendTotal, gainRank, spendRank = 0, 0, 0
    for i = 1, max do
      if self.orbs[i].lit and i > cur then
        spendTotal = spendTotal + 1
      end
    end
    for i = 1, max do
      local o = self.orbs[i]
      local want = i <= cur
      if want ~= o.lit then
        o.lit = want
        if snap then
          o.anim, o.t = nil, 0
        elseif want then
          o.anim, o.t = "gain", -0.05 * gainRank
          gainRank = gainRank + 1
        else
          spendRank = spendRank + 1
          -- the highest orb goes first
          o.anim, o.t = "spend", -0.04 * (spendTotal - spendRank)
        end
      end
    end
    self.primed = true
  end

  -- Advances the animations and updates every orb's look
  function row:Tick(dt, now, glowFull)
    local r, g, b = self.r, self.g, self.b
    local size = self.size
    local full = self.count > 0
    for i = 1, self.count do
      if not self.orbs[i].lit then
        full = false
        break
      end
    end
    local br, bg, bb = r + (1 - r) * 0.45, g + (1 - g) * 0.45, b + (1 - b) * 0.45

    for i = 1, self.count do
      local o = self.orbs[i]
      local fillA, scale, stripeA, burstA, burstS = 0, 1, 0, 0, 1
      local anim = o.anim
      if anim then
        o.t = o.t + dt
        local t = o.t
        if t < 0 then
          fillA = anim == "gain" and 0 or 1 -- waiting its turn
        else
          local k = t / (anim == "gain" and GAIN_TIME or SPEND_TIME)
          if k >= 1 then
            o.anim = nil
            anim = nil
          elseif anim == "gain" then
            local inv = 1 - k
            fillA = math_min(1, k * 4)
            scale = 1 + 0.7 * inv * inv
            stripeA = 0.8 * inv
            burstA = 0.85 * inv
            burstS = 0.7 + 0.9 * k
          else
            local inv = 1 - k
            fillA = inv
            scale = 1 - 0.45 * k
            burstA = 0.45 * inv
            burstS = 0.9 + 0.5 * k
          end
        end
      end
      if not anim then
        if o.lit then
          fillA = 1
          if glowFull and full then
            -- a soft wave runs across a full row
            local s = 0.5 + 0.5 * math_sin(now * 3 - i * 0.55)
            burstA = 0.08 + 0.16 * s
            burstS = 0.95
            scale = 1 + 0.03 * s
          end
        elseif self.charging == i then
          -- the next point is on its way (essence)
          local s = 0.5 + 0.5 * math_sin(now * 5)
          fillA = 0.3 + 0.2 * s
          stripeA = 0.25 + 0.35 * s
        end
      end

      o.fill:SetVertexColor(r, g, b, 1)
      o.fill:SetAlpha(fillA)
      o.fill:SetSize(size * scale, size * scale)
      o.stripes:SetAlpha(stripeA)
      o.stripes:SetSize(size * scale, size * scale)
      o.burst:SetVertexColor(br, bg, bb, 1)
      o.burst:SetAlpha(burstA)
      o.burst:SetSize(size * 2.4 * burstS, size * 2.4 * burstS)
    end
  end

  return row
end

---------------------------------------------------------------------------------------
--                                    SAMPLE DATA                                    --
---------------------------------------------------------------------------------------
-- 0 to 5 points, one more each second, then all spent: shows gain, full glow and spend
local function DemoCount(now)
  local t = now % 7
  if t >= 6 then
    return 0
  end
  return math_min(5, math_floor(t))
end

O.NewRow = NewRow
O.DemoCount = DemoCount
O.DEMO_COLOR = DEMO_COLOR

local function OrbColor(P, r, g, b)
  if P.orbsColor == "resource" and r then
    return r, g, b
  end
  return 1, 0.25, 0.25
end

---------------------------------------------------------------------------------------
--                                     WORLD ROW                                     --
---------------------------------------------------------------------------------------
-- The orbs are the old resource pips with a new skin: same arc around the reticle, same
-- Placement, Distance, Spacing and Size settings.
local CENTER_ANGLE = {below = 270, above = 90, left = 180, right = 0}

O.OrbColor = OrbColor
O.CENTER_ANGLE = CENTER_ANGLE

local row = NewRow(UIParent, "CrosshairZOrbs")
row:SetFrameStrata("MEDIUM")
row:Hide()
row.alpha = 0

local testUntil = 0
local lastX, lastY
local poll = 0
local cur, max, rr, rg, rb, charging = 0, 0, 1, 1, 1, false

function O.Test()
  testUntil = GetTime() + 8
end

local function Update(dt)
  local P = CZ.P
  if not P then
    return
  end
  local now = GetTime()
  local testing = (now < testUntil or (CZ.IsLiveEditing and CZ.IsLiveEditing())) and P.pipsEnabled and P.orbsEnabled
  local enabled = P.pipsEnabled and P.orbsEnabled and (P.hudEnabled or testing)

  -- what to show (checked 20 times a second; animation runs every frame)
  poll = poll - dt
  if poll <= 0 then
    poll = 0.05
    local c, m, r, g, b
    if testing then
      c, m, r, g, b = DemoCount(now), 5, DEMO_COLOR[1], DEMO_COLOR[2], DEMO_COLOR[3]
      charging = false
    else
      c, m, r, g, b = CZ.Features.ClassResource()
      charging = playerClass == "EVOKER"
    end
    cur, max = c or 0, m or 0
    rr, rg, rb = OrbColor(P, r, g, b)
  end

  -- The orbs belong to the Reticle HUD: they show, fade and dim with it (Show HUD, HUD Opacity,
  -- crosshair visibility), exactly like the old dots did.
  local hud = CZ.Features.hud
  local hudAlpha = (hud and hud:IsShown()) and hud.alpha or 0
  if not (enabled and max > 0 and hudAlpha > 0.01) then
    row.alpha = 0
    row:Hide()
    if max > 0 then
      row:SetState(cur, max, rr, rg, rb, charging, false) -- stay in sync while hidden
    end
    return
  end
  row.alpha = hudAlpha

  -- same spot as the HUD arcs
  row:Layout(math_max(max, 1), P.pipSize or 12, (P.pipDistance or 82) * (P.hudScale or 1), P.pipSpread or 25,
    CENTER_ANGLE[P.pipPlacement] or 270)
  local x = P.hudOffsetX or 0
  local y = (CZ.GetCrosshairY and CZ.GetCrosshairY() or 0) + (P.hudOffsetY or 0)
  if x ~= lastX or y ~= lastY then
    lastX, lastY = x, y
    row:ClearAllPoints()
    row:SetPoint("CENTER", UIParent, "CENTER", x, y)
  end
  row:SetAlpha(row.alpha)
  row:Show()
  local animate = P.orbsAnimate ~= false
  row:SetState(cur, max, rr, rg, rb, charging, animate)
  row:Tick(animate and dt or 1, now, animate and P.orbsGlow)
end

local driver = CreateFrame("Frame")

function O.Enable()
  driver:SetScript("OnUpdate", function(_, dt)
    local ok, err = pcall(Update, dt)
    if not ok then
      CZ.DebugPrint("Resource Orbs error: " .. tostring(err))
    end
  end)
  CZ.Profiles.OnChange(function()
    lastX, lastY = nil, nil
  end)
end

function O.Disable()
  driver:SetScript("OnUpdate", nil)
  row:Hide()
end
