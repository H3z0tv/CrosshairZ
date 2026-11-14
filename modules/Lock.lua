-- Crosshair Z
-- Target Hold: keep your target while you aim elsewhere. Cycle keys move the
-- lock to the next enemy, a tag under the crosshair shows the lock, and
-- optional sounds play for each step.

local _, Z = ...
local K = Z.Module("Lock")

local locked = false
local cyclingAt = 0
local targetCasting = false

Z.SOUND_CHOICES = {
  none = "None", click = "Click", soft = "Soft", page = "Page", chime = "Chime", ping = "Ping", alert = "Alert"
}
local SOUND_IDS = {click = 856, soft = 857, page = 836, chime = 3081, ping = 3175, alert = 8959}

function K.PlayChoice(choice)
  local id = SOUND_IDS[choice]
  if id then
    pcall(PlaySound, id, Z.P.lock.channel or "SFX")
  end
end

local function Sound(kind)
  local p = Z.P.lock
  if not p.sounds then
    return
  end
  local key = ({lock = "soundLock", cycle = "soundCycle", clear = "soundClear", cast = "soundCast"})[kind]
  K.PlayChoice(p[key])
end

function K.TestSounds()
  local p = Z.P.lock
  local order = {p.soundLock, p.soundCycle, p.soundCast, p.soundClear}
  for i, choice in ipairs(order) do
    Z.After((i - 1) * 0.6, function()
      K.PlayChoice(choice)
    end)
  end
end

local function HasEnemyTarget()
  if not Z.Truthy(UnitExists, "target") then
    return false
  end
  local dead = Z.Call(UnitIsDead, "target")
  if dead then
    return false
  end
  local hostile = Z.Call(UnitCanAttack, "player", "target")
  return hostile ~= false
end

---------------------------------------------------------------------------
-- The tag under the crosshair
---------------------------------------------------------------------------
local tag = CreateFrame("Frame", "CrosshairZLockTag", UIParent)
tag:SetSize(160, 20)
tag:SetFrameStrata("HIGH")
tag.text = tag:CreateFontString(nil, "OVERLAY")
tag.text:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
tag.text:SetPoint("CENTER")
tag:Hide()
tag.clock = 0
tag:SetScript("OnUpdate", function(self, e)
  self.clock = self.clock + e
  local p = Z.P.lock
  local a = 0.9
  if targetCasting and p.castFlash then
    self.text:SetText("TARGET CASTING")
    self.text:SetTextColor(1, 0.55, 0.15)
    a = 0.55 + 0.45 * math.abs(math.sin(self.clock * 9))
  else
    self.text:SetText("TARGET HELD")
    self.text:SetTextColor(1, 0.3, 0.3)
    if p.pulse then
      local k = (self.clock % 3) / 3
      if k < 0.25 then
        a = 0.9 - 0.5 * math.sin(k / 0.25 * math.pi)
      end
    end
  end
  self:SetAlpha(a)
end)

local function PlaceTag()
  tag:ClearAllPoints()
  local y = (Z.CrosshairY and Z.CrosshairY() or 0) - (Z.P.cross.size * 0.5 + 16)
  tag:SetPoint("CENTER", UIParent, "CENTER", 0, y)
end

---------------------------------------------------------------------------
-- Locking
---------------------------------------------------------------------------
function K.IsLocked()
  return locked
end

function K.Lock(silent)
  if not HasEnemyTarget() then
    return false
  end
  locked = true
  targetCasting = false
  PlaceTag()
  tag.clock = 0
  tag:Show()
  if not silent then
    Sound("lock")
  end
  Z.Send("LOCK", true)
  return true
end

function K.Unlock(silent)
  if not locked then
    return
  end
  locked = false
  targetCasting = false
  tag:Hide()
  if not silent then
    Sound("clear")
  end
  Z.Send("LOCK", false)
end

-- Switch target: let the aim pick for a moment, then lock the new target
local function SwitchToAim()
  if not Z.Truthy(UnitExists, "softenemy") then
    K.Unlock()
    return
  end
  if Z.Truthy(UnitIsUnit, "softenemy", "target") then
    return
  end
  locked = false
  Z.Send("LOCK", false)
  Z.After(0.35, function()
    if K.Lock(true) then
      Sound("cycle")
    end
  end)
end

function K.Key()
  if locked then
    if Z.P.lock.behavior == "switch" then
      SwitchToAim()
    else
      K.Unlock()
    end
  elseif not K.Lock() then
    Z.Print("Aim at an enemy first.")
  end
end

---------------------------------------------------------------------------
-- Cycle keys (secure, so they work in combat)
---------------------------------------------------------------------------
local function CycleButton(name, macro)
  local ok, b = pcall(CreateFrame, "Button", name, UIParent, "SecureActionButtonTemplate")
  if not ok or not b then
    return
  end
  b:SetSize(1, 1)
  b:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", -20, -20)
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("type", "macro")
  b:SetAttribute("macrotext", macro)
  b:HookScript("PostClick", function()
    cyclingAt = GetTime()
  end)
end
CycleButton("CrosshairZNextEnemy", "/targetenemy")
CycleButton("CrosshairZPrevEnemy", "/targetenemy 1")

local function TargetChanged()
  local fromCycle = GetTime() - cyclingAt < 0.6
  if fromCycle then
    cyclingAt = 0
    if HasEnemyTarget() then
      if Z.P.lock.cycleLocks then
        if locked then
          targetCasting = false
          Z.Send("LOCK", true)
        else
          K.Lock(true)
        end
      end
      Sound("cycle")
    end
    return
  end
  if locked and not HasEnemyTarget() then
    K.Unlock()
  end
end

---------------------------------------------------------------------------
-- The locked target's casts and Auto Hold
---------------------------------------------------------------------------
local lastCastSound = 0
local CAST_START = {UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true}

local function TargetCast(event)
  if not locked then
    return
  end
  if CAST_START[event] then
    targetCasting = true
    if GetTime() - lastCastSound > 1.5 then
      lastCastSound = GetTime()
      Sound("cast")
    end
  else
    targetCasting = false
  end
end

local function PlayerCast(_, _, _, spellID)
  if locked or not Z.P.lock.auto or Z.Secret(spellID) or not spellID then
    return
  end
  local harmful = C_Spell and C_Spell.IsSpellHarmful and Z.Call(C_Spell.IsSpellHarmful, spellID)
  if harmful and HasEnemyTarget() then
    K.Lock()
  end
end

function K:Setup()
  Z.On("PLAYER_TARGET_CHANGED", TargetChanged)
  Z.On("PLAYER_DEAD", function()
    K.Unlock(true)
  end)
  for _, ev in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
                       "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_SUCCEEDED"}) do
    Z.OnUnit(ev, {"target"}, TargetCast)
  end
  Z.OnUnit("UNIT_SPELLCAST_SUCCEEDED", {"player"}, PlayerCast)
end

function K:Apply()
  if locked then
    PlaceTag()
  end
end

function K:Stop()
  K.Unlock(true)
end
