-- Crosshair Z
-- Hit and kill markers on the crosshair, purple screen edges in stealth and a
-- red pulse at low health.

local _, Z = ...
local E = Z.Module("Effects")

---------------------------------------------------------------------------
-- Markers
---------------------------------------------------------------------------
local marker = CreateFrame("Frame", "CrosshairZMarker", UIParent)
marker:SetFrameStrata("HIGH")
marker:SetSize(48, 48)
marker.t = marker:CreateTexture(nil, "OVERLAY")
marker.t:SetAllPoints()
marker.glow = marker:CreateTexture(nil, "ARTWORK")
marker.glow:SetPoint("CENTER")
marker.glow:SetTexture(Z.MEDIA .. "glow")
marker.glow:SetBlendMode("ADD")
marker:Hide()
marker:SetScript("OnUpdate", function(self, e)
  self.age = self.age + e
  local k = self.age / self.life
  if k >= 1 then
    self:Hide()
    return
  end
  local size = self.size * (1 + 0.25 * k)
  self:SetSize(size, size)
  self:SetAlpha(1 - k * k)
  self.glow:SetSize(size * 2.2, size * 2.2)
end)

local function Show(kind)
  local p = Z.P.hud
  if kind == "kill" and not p.kills then
    return
  end
  if kind ~= "kill" and not p.hits then
    return
  end
  if marker:IsShown() and marker.kind == "kill" and kind ~= "kill" then
    return
  end
  marker.kind = kind
  marker.age = 0
  if kind == "kill" then
    marker.t:SetTexture(Z.MEDIA .. "kill")
    marker.t:SetVertexColor(1, 0.2, 0.2)
    marker.glow:SetVertexColor(1, 0.15, 0.1)
    marker.glow:Show()
    marker.size, marker.life = 56, 0.7
  elseif kind == "crit" then
    marker.t:SetTexture(Z.MEDIA .. "hit")
    marker.t:SetVertexColor(1, 0.82, 0.25)
    marker.glow:Hide()
    marker.size, marker.life = 46, 0.35
  else
    marker.t:SetTexture(Z.MEDIA .. "hit")
    marker.t:SetVertexColor(1, 1, 1)
    marker.glow:Hide()
    marker.size, marker.life = 34, 0.25
  end
  marker:ClearAllPoints()
  marker:SetPoint("CENTER", UIParent, "CENTER", 0, Z.CrosshairY())
  marker:Show()
end
E.ShowMarker = Show

local lastHit = 0

-- Newer clients: damage to the current target
local function UnitCombat(_, unit, action, indicator)
  if Z.Secret(unit) or Z.Secret(action) or unit ~= "target" then
    return
  end
  if action ~= "WOUND" then
    return
  end
  if not Z.InCombat() then
    return
  end
  lastHit = GetTime()
  Show((not Z.Secret(indicator) and indicator == "CRITICAL") and "crit" or "hit")
end

local function TargetHealth()
  if GetTime() - lastHit < 3 and Z.Call(UnitIsDead, "target") then
    lastHit = 0
    Show("kill")
  end
end

-- Older clients: the combat log tells us exactly what we hit
local playerGUID
local hitGUIDs = {}
local function CombatLog()
  local _, sub, _, src, _, _, _, dest = CombatLogGetCurrentEventInfo()
  if sub == "UNIT_DIED" or sub == "PARTY_KILL" then
    if hitGUIDs[dest] and GetTime() - hitGUIDs[dest] < 5 then
      hitGUIDs[dest] = nil
      Show("kill")
    end
    return
  end
  if src ~= playerGUID then
    return
  end
  if sub == "SWING_DAMAGE" or sub == "SPELL_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" then
    local crit
    if sub == "SWING_DAMAGE" then
      crit = select(18, CombatLogGetCurrentEventInfo())
    else
      crit = select(21, CombatLogGetCurrentEventInfo())
    end
    hitGUIDs[dest] = GetTime()
    if sub ~= "SPELL_PERIODIC_DAMAGE" then
      Show(crit and "crit" or "hit")
    end
  end
end

---------------------------------------------------------------------------
-- Screen edges
---------------------------------------------------------------------------
local edges = CreateFrame("Frame", "CrosshairZEdges", UIParent)
edges:SetAllPoints(UIParent)
edges:SetFrameStrata("BACKGROUND")
edges.t = edges:CreateTexture(nil, "BACKGROUND", nil, 1)
edges.t:SetAllPoints()
edges.t:SetTexture(Z.MEDIA .. "edges")
edges:SetAlpha(0)
edges.cur, edges.clock, edges.test = 0, 0, 0
edges:SetScript("OnUpdate", function(self, e)
  if not Z.P then
    return
  end
  local p = Z.P.hud
  self.clock = self.clock + e
  local want, r, g, b = 0, 1, 0.1, 0.1
  local low = false
  if self.test > 0 then
    self.test = self.test - e
    low = true
  elseif p.lowHealth then
    local cur = Z.Call(UnitHealth, "player")
    local max = Z.Call(UnitHealthMax, "player")
    low = cur and max and max > 0 and cur > 0 and (cur / max * 100) <= p.lowHealthPct
  end
  if low then
    want = 0.35 + 0.35 * math.abs(math.sin(self.clock * 3))
  elseif p.stealthEdges and IsStealthed and IsStealthed() then
    want, r, g, b = 0.45, 0.55, 0.2, 0.9
  end
  self.t:SetVertexColor(r, g, b)
  self.cur = self.cur + (want - self.cur) * math.min(1, e * 8)
  self:SetAlpha(self.cur)
end)

function E.TestLowHealth()
  edges.test = 3
end

function E:Setup()
  playerGUID = UnitGUID("player")
  local useLog = Z.build < 120000 and CombatLogGetCurrentEventInfo ~= nil
  if useLog then
    Z.On("COMBAT_LOG_EVENT_UNFILTERED", CombatLog)
  else
    Z.On("UNIT_COMBAT", UnitCombat)
    Z.OnUnit("UNIT_HEALTH", {"target"}, TargetHealth)
  end
  Z.On("PLAYER_TARGET_CHANGED", function()
    lastHit = 0
  end)
end

function E:Stop()
  edges:Hide()
  marker:Hide()
end
