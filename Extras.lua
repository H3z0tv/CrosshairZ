---------------------------------------------------------------------------------------
--                                      EXTRAS                                       --
---------------------------------------------------------------------------------------
-- Target Lock, Flip Camera, weapon sheathe with Free Look, crosshair cast feedback and
-- Target Outline.
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UIParent = _G.UIParent
local pcall = _G.pcall
local type = _G.type
local math_min = _G.math.min
local math_max = _G.math.max
local math_sin = _G.math.sin

local X = {}
CZ.Extras = X

local FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local issecret = _G.issecretvalue or function()
  return false
end

local function Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c, d, e
end

local function GetCVarSafe(name)
  local getter = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  return Call(getter, name)
end

local function SetCVarSafe(name, value)
  local setter = _G.C_CVar and _G.C_CVar.SetCVar or _G.SetCVar
  return pcall(setter, name, value)
end

local function Print(msg)
  print(CZ.Constants.BasePrintMsg .. "|cff909090: " .. msg .. "|r")
end

---------------------------------------------------------------------------------------
--                                    TARGET LOCK                                    --
---------------------------------------------------------------------------------------
-- While locked, the reticle stops replacing your target: your current target stays
-- your target until you unlock (or it dies / you clear it).
local LOCK_CVARS = {SoftTargetForce = 0, SoftTargetWithLocked = 0}
local lockSaved = nil
local locked = false

local lockTag = CreateFrame("Frame", "CrosshairZLockTag", UIParent)
lockTag:SetSize(200, 20)
lockTag:SetFrameStrata("HIGH")
local lockText = lockTag:CreateFontString(nil, "OVERLAY")
lockText:SetFont(FONT, 11, "OUTLINE")
lockText:SetPoint("CENTER")
lockText:SetTextColor(1, 0.35, 0.3)
lockText:SetText("TARGET LOCKED")
lockTag:Hide()

local function PlaceLockTag()
  local y = (CZ.GetCrosshairY and CZ.GetCrosshairY() or 0) + 46
  lockTag:ClearAllPoints()
  lockTag:SetPoint("CENTER", UIParent, "CENTER", 0, y)
end

local function HasTarget()
  local exists = Call(_G.UnitExists, "target")
  return not issecret(exists) and exists and true or false
end

function X.IsLocked()
  return locked
end

function X.Lock()
  if locked then
    return
  end
  if not HasTarget() then
    Print("no target to lock.")
    return
  end
  lockSaved = {}
  for name, value in pairs(LOCK_CVARS) do
    lockSaved[name] = GetCVarSafe(name)
    SetCVarSafe(name, value)
  end
  locked = true
  PlaceLockTag()
  lockTag:Show()
end

function X.Unlock()
  if not locked then
    return
  end
  if lockSaved then
    for name, value in pairs(lockSaved) do
      if value ~= nil and not issecret(value) then
        SetCVarSafe(name, value)
      end
    end
  end
  lockSaved = nil
  locked = false
  lockTag:Hide()
end

-- "Switch Target": while locked, pressing the key lets the reticle pick the enemy you're
-- aiming at for a moment, then locks onto it.
local switchFrame = CreateFrame("Frame")
local function SwitchToAim()
  local aim = Call(_G.UnitExists, "softenemy")
  if issecret(aim) or not aim then
    X.Unlock()
    return
  end
  SetCVarSafe("SoftTargetForce", 1)
  SetCVarSafe("SoftTargetWithLocked", 2)
  local waited = 0
  switchFrame:SetScript("OnUpdate", function(self, elapsed)
    waited = waited + elapsed
    if waited >= 0.15 then
      self:SetScript("OnUpdate", nil)
      for name, value in pairs(LOCK_CVARS) do
        SetCVarSafe(name, value)
      end
    end
  end)
end

function X.TargetLockKey()
  local behavior = CZ.DB.global.targetLockBehavior or "toggle"
  if not locked then
    X.Lock()
  elseif behavior == "switch" then
    SwitchToAim()
  else
    X.Unlock()
  end
end

_G.CrosshairZ_TargetLockKey = function()
  X.TargetLockKey()
end

_G.CrosshairZ_FlipKey = function()
  if CZ.MotionSafe() then
    Print("Motion Sickness Protection is on, so the camera stays centered.")
    return
  end
  CZ.FlipShoulder()
end

---------------------------------------------------------------------------------------
--                              SHEATHE WITH FREE LOOK                               --
---------------------------------------------------------------------------------------
local freeLookOn = false

local function OnFreeLook(on)
  freeLookOn = on and true or false
  if X.RefreshTooltip then
    X.RefreshTooltip()
  end
  if not CZ.DB.global.sheatheWithFreeLook or _G.InCombatLockdown() then
    return
  end
  local state = Call(_G.GetSheathState)
  if issecret(state) or type(state) ~= "number" then
    return
  end
  -- 1 = sheathed, 2 = melee out, 3 = ranged out
  if (on and state == 1) or (not on and state ~= 1) then
    pcall(_G.ToggleSheath)
  end
end

---------------------------------------------------------------------------------------
--                              CROSSHAIR CAST FEEDBACK                              --
---------------------------------------------------------------------------------------
-- Grows while you cast or channel, pulses when the cast lands, shakes if it's cut short.
local fb = {casting = false, channel = false, pulse = 1, shake = 1, applied = false}

local function CastProgress(now)
  local fn = fb.channel and _G.UnitChannelInfo or _G.UnitCastingInfo
  local ok, name, _, _, startMS, endMS = pcall(fn, "player")
  if not ok or issecret(name) or name == nil or issecret(startMS) or issecret(endMS) then
    return nil
  end
  if type(startMS) ~= "number" or type(endMS) ~= "number" or endMS <= startMS then
    return nil
  end
  local k = (now * 1000 - startMS) / (endMS - startMS)
  return math_max(0, math_min(1, k))
end

local feedbackFrame = CreateFrame("Frame")
local function UpdateFeedback(_, elapsed)
  local P = CZ.P
  local frame = CZ.CrosshairFrame
  if not (P and frame and CZ.DB) then
    return
  end
  local now = GetTime()
  local base = CZ.DB.global.crosshairSize or 64

  if not P.castFeedback then
    if fb.applied then
      fb.applied = false
      frame:SetSize(base, base)
      frame:SetPoint("CENTER", 0, CZ.GetCrosshairY() / (frame:GetScale() or 1))
    end
    return
  end

  local mult = 1
  if P.castGrow and fb.casting then
    local k = CastProgress(now)
    if k then
      mult = mult + 0.25 * (fb.channel and (1 - k) or k)
    end
  end
  if fb.pulse < 1 then
    fb.pulse = math_min(1, fb.pulse + elapsed / 0.22)
    mult = mult + 0.3 * (1 - fb.pulse)
  end
  local x = 0
  if fb.shake < 1 then
    fb.shake = math_min(1, fb.shake + elapsed / 0.3)
    x = math_sin(fb.shake * 40) * 6 * (1 - fb.shake)
  end

  if mult ~= 1 or x ~= 0 or fb.applied then
    local scale = frame:GetScale() or 1
    frame:SetSize(base * mult, base * mult)
    frame:SetPoint("CENTER", x / scale, CZ.GetCrosshairY() / scale)
    fb.applied = mult ~= 1 or x ~= 0
  end
end

local function OnCastEvent(event, unit)
  if unit ~= "player" then
    return
  end
  local P = CZ.P
  if event == "UNIT_SPELLCAST_START" then
    fb.casting, fb.channel = true, false
  elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
    fb.casting, fb.channel = true, true
  elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
    fb.casting = false
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if P and P.castPulse then
      fb.pulse = 0
    end
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    if fb.casting and P and P.castShake then
      fb.shake = 0
    end
    fb.casting = false
  end
end

function X.TestFeedback()
  fb.pulse = 0
  local f = CreateFrame("Frame")
  local t = 0
  f:SetScript("OnUpdate", function(self, elapsed)
    t = t + elapsed
    if t > 0.5 then
      fb.shake = 0
      self:SetScript("OnUpdate", nil)
    end
  end)
end

---------------------------------------------------------------------------------------
--                                  TARGET OUTLINE                                   --
---------------------------------------------------------------------------------------
-- The game's unit outline setting ("Outline"): 0 = off, higher values outline more units.
local OUTLINE_VALUES = {off = 0, hover = 1, target = 2, all = 3}

function X.ApplyTargetOutline()
  local choice = CZ.DB.global.targetOutline or "default"
  local value = OUTLINE_VALUES[choice]
  if value == nil then
    -- "default": put back the value we found before changing it (if we changed it)
    if CZ.DB.global.outlineOriginal ~= nil then
      SetCVarSafe("Outline", CZ.DB.global.outlineOriginal)
      CZ.DB.global.outlineOriginal = nil
    end
    return
  end
  if CZ.DB.global.outlineOriginal == nil then
    local current = GetCVarSafe("Outline")
    if current ~= nil and not issecret(current) then
      CZ.DB.global.outlineOriginal = current
    end
  end
  SetCVarSafe("Outline", value)
end

---------------------------------------------------------------------------------------
--                            TOOLTIPS DURING FREE LOOK                              --
---------------------------------------------------------------------------------------
-- There's no mouse cursor during Free Look, so the game shows no tooltip for what you
-- aim at. When allowed, Crosshair Z shows the tooltip of the unit under the crosshair.
local AIM_UNITS = {"softenemy", "softinteract", "softfriend", "mouseover"}
local MODIFIERS = {shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown", alt = "IsAltKeyDown"}
local tip = {ours = false, unit = nil, dirty = true, allowed = nil}

local function AimUnit()
  for _, unit in ipairs(AIM_UNITS) do
    local exists = Call(_G.UnitExists, unit)
    if exists and not issecret(exists) then
      return unit
    end
  end
  return nil
end

local function TooltipAllowed()
  local mode = CZ.TooltipMode()
  if mode == "show" then
    return true
  end
  local fn = MODIFIERS[mode] and _G[MODIFIERS[mode]]
  return fn ~= nil and fn() and true or false
end

local function HideOurTooltip()
  if tip.ours then
    tip.ours = false
    _G.GameTooltip:Hide()
  end
  tip.unit = nil
end

local function PlaceTooltip()
  local GameTooltip = _G.GameTooltip
  if (CZ.DB.global.tooltipAnchor or "crosshair") == "default" and _G.GameTooltip_SetDefaultAnchor then
    _G.GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
  else
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local y = CZ.GetCrosshairY and CZ.GetCrosshairY() or 0
    GameTooltip:SetPoint("TOPLEFT", UIParent, "CENTER", 48, y - 40)
  end
end

local function UpdateTooltip()
  if not freeLookOn then
    -- Free Look is off: the game handles tooltips normally
    if tip.allowed ~= nil then
      tip.allowed = nil
      HideOurTooltip()
    end
    return
  end

  local allowed = TooltipAllowed()
  if allowed ~= tip.allowed then
    tip.allowed = allowed
    tip.dirty = true
    CZ.SetTooltipHidden(not allowed)
  end
  if not allowed then
    HideOurTooltip()
    return
  end

  local unit = AimUnit()
  if not unit then
    HideOurTooltip()
    return
  end
  if tip.dirty or unit ~= tip.unit or not _G.GameTooltip:IsShown() then
    tip.dirty = false
    tip.unit = unit
    PlaceTooltip()
    local ok = pcall(_G.GameTooltip.SetUnit, _G.GameTooltip, unit)
    tip.ours = ok
    if ok then
      _G.GameTooltip:Show()
    end
  end
end

function X.RefreshTooltip()
  tip.dirty = true
  tip.allowed = nil
end

local tooltipFrame = CreateFrame("Frame")
local tooltipSince = 0

---------------------------------------------------------------------------------------
--                                      ENABLE                                       --
---------------------------------------------------------------------------------------
local events = CreateFrame("Frame")

function X.Enable()
  CZ.OnFreeLook(OnFreeLook)
  for _, event in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED",
    "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED",
    "PLAYER_SOFT_FRIEND_CHANGED", "MODIFIER_STATE_CHANGED"}) do
    pcall(events.RegisterEvent, events, event)
  end
  events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_TARGET_CHANGED" then
      if locked and not HasTarget() then
        X.Unlock()
      end
    elseif event == "PLAYER_ENTERING_WORLD" then
      X.ApplyTargetOutline()
    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" or event == "PLAYER_SOFT_INTERACT_CHANGED" or
      event == "PLAYER_SOFT_FRIEND_CHANGED" or event == "MODIFIER_STATE_CHANGED" then
      tip.dirty = true
    else
      OnCastEvent(event, unit)
    end
  end)
  feedbackFrame:SetScript("OnUpdate", UpdateFeedback)
  tooltipFrame:SetScript("OnUpdate", function(_, elapsed)
    tooltipSince = tooltipSince + elapsed
    if tooltipSince >= 0.1 or tip.dirty then
      tooltipSince = 0
      local ok, err = pcall(UpdateTooltip)
      if not ok then
        CZ.DebugPrint("Tooltip error: " .. tostring(err))
      end
    end
  end)
end

function X.Disable()
  X.Unlock()
  tooltipFrame:SetScript("OnUpdate", nil)
  feedbackFrame:SetScript("OnUpdate", nil)
end
