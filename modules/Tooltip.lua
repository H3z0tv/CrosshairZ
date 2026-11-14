-- Crosshair Z
-- Tooltips during Aim Mode. The hidden cursor sits on the crosshair, so the
-- game already makes a tooltip for whatever you aim at. This module only
-- decides whether that tooltip may show, and where.

local _, Z = ...
local T = Z.Module("Tooltip")

local MODIFIERS = {shift = "IsShiftKeyDown", ctrl = "IsControlKeyDown", alt = "IsAltKeyDown"}

local function Active()
  return Z.P and Z.Look and Z.Look.IsOn()
end

local function Allowed()
  local mode = Z.P.look.tooltip
  if mode == "show" then
    return true
  end
  local fn = MODIFIERS[mode] and _G[MODIFIERS[mode]]
  return fn and fn() and true or false
end

local function BesideCrosshair(tip)
  tip:ClearAllPoints()
  tip:SetPoint("BOTTOMLEFT", UIParent, "CENTER", 40, Z.CrosshairY() + 20)
end

local function ShowAimed()
  if not Z.Truthy(UnitExists, "mouseover") then
    return
  end
  if GameTooltip_SetDefaultAnchor then
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
  else
    GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    BesideCrosshair(GameTooltip)
  end
  if pcall(GameTooltip.SetUnit, GameTooltip, "mouseover") then
    GameTooltip:Show()
  end
end

function T:Setup()
  -- where the tooltip goes
  if GameTooltip_SetDefaultAnchor then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tip)
      if tip == GameTooltip and Active() and Allowed() and Z.P.look.tooltipAt == "crosshair" then
        BesideCrosshair(tip)
      end
    end)
  end
  -- whether it may show
  GameTooltip:HookScript("OnShow", function(self)
    if Active() and not Allowed() then
      self:Hide()
    end
  end)
  -- holding or letting go of the chosen key shows or hides it right away
  Z.On("MODIFIER_STATE_CHANGED", function()
    if not Active() or not MODIFIERS[Z.P.look.tooltip] then
      return
    end
    if Allowed() then
      ShowAimed()
    else
      GameTooltip:Hide()
    end
  end)
  Z.Listen("LOOK", function(on)
    if on and not Allowed() then
      GameTooltip:Hide()
    end
  end)
end
