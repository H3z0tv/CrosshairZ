---------------------------------------------------------------------------------------
--                                     CORE LOGIC                                    --
---------------------------------------------------------------------------------------
-- IMPORTS
local _G = _G
local AceAddon = _G.LibStub("AceAddon-3.0")
local AceDB = _G.LibStub("AceDB-3.0")

-- CLIENT FEATURE DETECTION
-- Retail (Midnight) and WoW: Forever share the same UI API, so we detect features
-- instead of checking WOW_PROJECT_ID (Forever reports its own project id).
local HAS_PET_BATTLES = _G.C_PetBattles ~= nil and _G.C_PetBattles.IsInBattle ~= nil
local HAS_MOUSEOVER_CAST = _G.C_CVar.GetCVar("enableMouseoverCast") ~= nil

-- SECRET VALUE SAFETY (Midnight 12.0+ / Forever)
-- Some unit queries return "secret" values in instances and combat. Comparing or
-- doing math on them throws an error, so every read goes through these helpers.
local issecretvalue = _G.issecretvalue or function()
  return false
end

local function SafeCall(fn, ...)
  if not fn then
    return nil
  end
  local ok, result = pcall(fn, ...)
  if not ok or result == nil or issecretvalue(result) then
    return nil
  end
  return result
end

-- KEYBIND LABELS (Bindings.xml)
_G.BINDING_HEADER_CROSSHAIRZ = "Crosshair Z"
_G.BINDING_NAME_CROSSHAIRZ_TOGGLE = "Toggle Free Look"
_G.BINDING_NAME_CROSSHAIRZ_HOLD = "Hold to Switch Free Look"
_G.BINDING_NAME_CROSSHAIRZ_LOCK = "Target Lock"
_G.BINDING_NAME_CROSSHAIRZ_FLIP = "Flip Camera Shoulder"

-- CACHING GLOBAL VARIABLES
-- Slightly better performance than doing a global lookup every time
local CreateFrame = _G.CreateFrame
local CreateMacro = _G.CreateMacro
local DisableAddOn = _G.C_AddOns.DisableAddOn
local GetAddOnMetadata = _G.C_AddOns.GetAddOnMetadata
local GetAuraDataBySpellName = _G.C_UnitAuras.GetAuraDataBySpellName
local GetPlayerAuraBySpellID = _G.C_UnitAuras.GetPlayerAuraBySpellID
local GetBindingKey = _G.GetBindingKey
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local GetCursorPosition = _G.GetCursorPosition
local GetMacroInfo = _G.GetMacroInfo
local GetTime = _G.GetTime
local GetUIPanel = _G.GetUIPanel
local InCinematic = _G.InCinematic
local IsInCinematicScene = _G.IsInCinematicScene
local InCombatLockdown = _G.InCombatLockdown
local IsMounted = _G.IsMounted
local IsMouseButtonDown = _G.IsMouseButtonDown
local IsMouselooking = _G.IsMouselooking
local loadstring = _G.loadstring
local MouselookStart = _G.MouselookStart
local MouselookStop = _G.MouselookStop
local pcall = _G.pcall
local ReloadUI = _G.ReloadUI
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetCVar = _G.C_CVar.SetCVar
local SetModifiedClick = _G.SetModifiedClick
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding
local SpellIsTargeting = _G.SpellIsTargeting
local StaticPopupDialogs = _G.StaticPopupDialogs
local StaticPopup_Show = _G.StaticPopup_Show
local UIParent = _G.UIParent
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitExists = _G.UnitExists
local UnitGUID = _G.UnitGUID
local UnitIsGameObject = _G.UnitIsGameObject
local UnitReaction = _G.UnitReaction
local unpack = _G.unpack

-- INSTANTIATING ADDON & ENCAPSULATING NAMESPACE
local CZ = AceAddon:NewAddon("CrosshairZ", "AceConsole-3.0", "AceEvent-3.0")
_G.CrosshairZ = CZ

-- INITIAL STATE VARIABLES
--[[
Changes when Free Look state is modified through user input
("Toggle" or "Press & Hold" keybinds and "/cz" cmd)
]] --
local FreeLookOverride = false

---------------------------------------------------------------------------------------
--                                 UTILITY FUNCTIONS                                 --
---------------------------------------------------------------------------------------
local function FetchDataFromTOC()
  local dataRetuned = {}
  local keysToFetch = {
    "Version",
    "Title",
    "Notes",
    "Author"
  }

  for _, key in ipairs(keysToFetch) do
    dataRetuned[string.upper(key)] = GetAddOnMetadata("CrosshairZ", key)
  end

  return dataRetuned
end

CZ.METADATA = FetchDataFromTOC()

function CZ.DebugPrint(statement)
  if CZ.DB.global.debugMode then
    print(CZ.Constants.BasePrintMsg .. "|cff909090: " .. tostring(statement) .. "|r")
  end
end

local lastPrintTime = 0
local function PreventDebugSpam(msg)
  local currentTime = GetTime()

  if currentTime - lastPrintTime > 3 then
    CZ.DebugPrint(msg)
    lastPrintTime = currentTime
  end
end

local function OpenConfigPanel()
  if InCombatLockdown() then
    print(CZ.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end
  CZ.UI.Open()
end

local function UndoChanges()
  if InCombatLockdown() then
    print(CZ.Constants.BasePrintMsg .. "|cff909090: Cannot run this cmd while in combat.|r")
    return
  end
  CZ:ResetCVarsToDefault()
  DisableAddOn("CrosshairZ")
  ReloadUI()
end

CZ.UndoChanges = function()
  UndoChanges()
end

local function DisplayPopup()
  -- fresh installs get the setup wizard instead (see UI.CheckFirstRun)
  if CZ.DB.char.seenWarning or CZ.DB.global.lastSeenVersion == nil then
    return
  end

  local function OnClosePopup()
    CZ.DB.char.seenWarning = true
    OpenConfigPanel()
  end

  StaticPopupDialogs["CrosshairZ Warning"] = {
    text = CZ.Constants.PopupMsg,
    button1 = "Ok",
    OnButton1 = OnClosePopup,
    OnHide = OnClosePopup,
    timeout = 0,
    whileDead = true
  }

  StaticPopup_Show("CrosshairZ Warning")
end

function CZ.MacroExists(name)
  return GetMacroInfo(name) ~= nil
end

local function CreateTargetMacros()
  local function createMacroIfNotExists(macroName, icon, macroText)
    if not CZ.MacroExists(macroName) then
      CreateMacro(macroName, icon, macroText, false)
    end
  end

  local macroIcon = "ability_hisek_aim"

  -- CreateMacro is blocked in combat and errors when the account macro list is full
  if InCombatLockdown() then
    return
  end

  for macroName, macroText in pairs(CZ.Constants.Macros) do
    local ok, err = pcall(createMacroIfNotExists, macroName, macroIcon, macroText)
    if not ok then
      CZ.DebugPrint("Could not create macro " .. macroName .. ": " .. tostring(err))
    end
  end
end

-- This prevents the auto running bug.
local function IsDefaultMouseActionBeingUsed()
  return IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
end

--[[
  Tooltip hiding while Free Look is active.
  We hook GameTooltip's OnShow ONCE and check a flag, instead of replacing its script.
  Replacing (SetScript) GameTooltip handlers wipes Blizzard's own handler and spreads
  taint, which on Midnight breaks tooltips that carry secret values.
]] --
local tooltipSuppressed = false
local tooltipHooked = false

-- "hide", "show", "shift", "ctrl" or "alt" (older versions only had the hide switch)
function CZ.TooltipMode()
  local mode = CZ.DB.global.tooltipMode
  if mode then
    return mode
  end
  return CZ.DB.global.hideTooltip and "hide" or "show"
end

local HideTooltip
function CZ.SetTooltipHidden(hidden)
  HideTooltip(hidden)
end

HideTooltip = function(shouldHide)
  tooltipSuppressed = shouldHide and true or false

  if not tooltipHooked then
    _G.GameTooltip:HookScript("OnShow", function(tooltip)
      if tooltipSuppressed then
        tooltip:Hide()
      end
    end)
    tooltipHooked = true
  end

  -- Hide immediately in case a tooltip is still fading
  if tooltipSuppressed then
    _G.GameTooltip:Hide()
  end
end

--[[
  Checking if DynamicCam is loaded so we can relinquish control of a few camera features
  as DynamicCam allows fine-grained control of Mouselook Speed & Target Focus
]] --
local function IsDCLoaded()
  local DC = AceAddon:GetAddon("DynamicCam", true)
  CZ.DynamicCam = DC ~= nil and true or false
  if CZ.DynamicCam then
    print(CZ.Constants.BasePrintMsg ..
            "|cff909090: |cff7CFF4FDynamicCam detected!|r Handing over control of |cffE37527• Camera Features|r.|r")
  end
end

---------------------------------------------------------------------------------------
--                              CVAR HANDLING FUNCTIONS                              --
---------------------------------------------------------------------------------------
local function LoadCVars(info)
  local CVarType, CMValues, BlizzValues, FeatureName = info.CVarType, info.CMValues, info.BlizzValues, info.FeatureName
  local CVarsToLoad

  if CVarType == "crosshairz" then
    CVarsToLoad = CMValues
    CZ.DebugPrint(FeatureName .. " CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = BlizzValues
    CZ.DebugPrint(FeatureName .. " CVars RESET")
  else
    CZ.DebugPrint("Invalid CVarType specified in fn CZ.ConfigCVars() for " .. FeatureName .. ": " .. tostring(CVarType))
    return
  end

  for name, value in pairs(CVarsToLoad) do
    SetCVar(name, value)
  end
end

function CZ.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = CZ.Constants.ReticleTargetingCVarValues,
    BlizzValues = CZ.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting"
  }

  LoadCVars(info)
end

-- Motion Sickness Protection: Crosshair Z never moves the camera off-center or makes it bob
function CZ.MotionSafe()
  return CZ.DB and CZ.DB.global.motionSickness and true or false
end

-- Flip Camera keybind: mirrors the shoulder offset to the other side
CZ.shoulderSign = 1
function CZ.FlipShoulder()
  CZ.shoulderSign = -(CZ.shoulderSign or 1)
  if not CZ.MotionSafe() and CZ.DB.global.actionCamera then
    CZ.SetShoulderOffset()
  end
  if CZ.Camera and CZ.Camera.Reapply then
    CZ.Camera.Reapply()
  end
end

function CZ.ConfigActionCamera(CVarType)
  if CZ.DynamicCam then
    return
  end
  if CVarType == "crosshairz" and CZ.MotionSafe() then
    CZ.DebugPrint("Motion Sickness Protection is on: Action Camera preset skipped.")
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CZ.Constants.ActionCameraCVarValues,
    BlizzValues = CZ.Constants.BlizzardActionCameraCVarValues,
    FeatureName = "Action Camera"
  }

  LoadCVars(info)
  if CVarType == "crosshairz" then
    CZ.SetShoulderOffset()
  end
  -- Disable the Action Cam warning message.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

function CZ.ConfigStickyCrosshair(CVarType)
  if CZ.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = CZ.Constants.TagetFocusCVarValues,
    BlizzValues = CZ.Constants.BlizzardTagetFocusCVarValues,
    FeatureName = "Sticky Crosshair"
  }

  LoadCVars(info)
end

function CZ.SetMouseLookSpeed()
  if CZ.DynamicCam then
    return
  end

  local XSpeed = CZ.DB.global.mouseLookSpeed
  local YSpeed = CZ.DB.global.mouseLookSpeed / 2 -- Blizz wants pitch speed as 1/2 of yaw speed
  SetCVar("cameraYawMoveSpeed", XSpeed)
  SetCVar("cameraPitchMoveSpeed", YSpeed)
  CZ.DebugPrint("Setting Camera Turn Speed X to " .. XSpeed .. " and Y to " .. YSpeed)
end

function CZ.SetShoulderOffset()
  if CZ.DynamicCam then
    return
  end

  if CZ.MotionSafe() then
    return
  end
  local offset = (CZ.DB.char.shoulderOffset or 0) * (CZ.shoulderSign or 1)
  SetCVar("test_cameraOverShoulder", offset)
  CZ.DebugPrint("Setting Shoulder Offset to " .. offset)
end

function CZ.SetCrosshairPriority(enabled)
  if not HAS_MOUSEOVER_CAST then
    return
  end
  if enabled then
    SetCVar("enableMouseoverCast", 1)
    SetModifiedClick("MOUSEOVERCAST", "NONE")
    SaveBindings(GetCurrentBindingSet())
    CZ.DebugPrint("Enabling Crosshair Priority")
  else
    SetCVar("enableMouseoverCast", 0)
    CZ.DebugPrint("Disabling Crosshair Priority")
  end
end

function CZ.SetFriendlyTargeting(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    CZ.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    CZ.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

-- Target circle (the ring on the ground under your target)
function CZ.SetTargetCircle(enabled)
  if _G.C_CVar.GetCVar("ObjectSelectionCircle") == nil then
    CZ.DebugPrint("ObjectSelectionCircle CVar not found on this client.")
    return
  end
  SetCVar("ObjectSelectionCircle", enabled and 1 or 0)
  CZ.DebugPrint((enabled and "Enabling" or "Disabling") .. " Target Circle")
end

-- Temporarily disable friendly targeting during combat
local function HandleFriendlyTargetingInCombat()
  local CharConfig = CZ.DB.char or {}
  local isFriendlyTargetingInCombatOn = CharConfig.reticleTargeting and CharConfig.friendlyTargeting and
                                          CharConfig.friendlyTargetingInCombat

  if not isFriendlyTargetingInCombatOn then
    return
  end

  local InCombat = UnitAffectingCombat("player")

  if InCombat then
    CZ.SetFriendlyTargeting(false)
  else
    CZ.SetFriendlyTargeting(true)
  end
end

local function CenterCursor(shouldCenter)
  if shouldCenter then
    SetCVar("CursorFreelookCentering", 1)
    CZ.DebugPrint("Locking cursor to crosshair position.")
  else
    SetCVar("CursorFreelookCentering", 0)
    CZ.DebugPrint("Freeing cursor from crosshair position.")
  end
end

function CZ:ResetCVarsToDefault()
  if CZ.Camera then
    CZ.Camera.Deactivate()
  end
  self.ConfigReticleTargeting("blizzard")
  self.ConfigActionCamera("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.SetCrosshairPriority(false)
  self.SetFriendlyTargeting(false)

  print(CZ.Constants.BasePrintMsg .. "|cff909090: all changes have been reverted.|r")
end
---------------------------------------------------------------------------------------
--                           CROSSHAIR HANDLING FUNCTIONS                            --
---------------------------------------------------------------------------------------
-- SETTING UP CROSSHAIR FRAME & ANIMATION
local CrosshairFrame = CreateFrame("Frame", "CrosshairZCrosshairFrame", UIParent)
local CrosshairTexture = CrosshairFrame:CreateTexture(nil, "OVERLAY")
local CrosshairAnimation = CrosshairFrame:CreateAnimationGroup()
local ScaleAnimation = CrosshairAnimation:CreateAnimation("Scale")
local startingScale = 1
local endingScale = 0.8
local scaleDuration = 0.15
ScaleAnimation:SetDuration(scaleDuration)
ScaleAnimation:SetScaleFrom(startingScale, startingScale)
ScaleAnimation:SetScaleTo(endingScale, endingScale)
ScaleAnimation:SetSmoothProgress(scaleDuration)
ScaleAnimation:SetSmoothing("IN_OUT")

local function HideCrosshairWhileMounted()
  return CZ.DB.global.crosshairMounted and IsMounted()
end

-- Shared crosshair state used by the HUD / Smart Crosshair modules
CZ.CrosshairFrame = CrosshairFrame
CZ.CrosshairTexture = CrosshairTexture
CZ.crosshairExtraY = 0 -- extra height from head tracking
CZ.crosshairAlphaMult = 1 -- visibility multiplier from Smart Crosshair
CZ.crosshairTint = nil -- {r, g, b, a} range tint for hostile targets
local lastCrosshairState = "base"

function CZ.GetCrosshairY()
  return (CZ.DB.global.crosshairY or 0) + (CZ.crosshairExtraY or 0)
end

local function SetCrosshairAppearance(state)
  local CrosshairAppearance = CZ.DB.global.crosshairAppearance
  local crosshairYPos = CZ.GetCrosshairY()
  lastCrosshairState = state
  local r, g, b, a = unpack(CZ.Constants.CrosshairReactionColors[state])
  if state == "mounted" and CZ.DB.global.crosshairMountedStyle == "dim" then
    r, g, b, a = 1, 1, 1, 0.35
  end
  if state == "hostile" and CZ.crosshairTint then
    r, g, b, a = CZ.crosshairTint[1], CZ.crosshairTint[2], CZ.crosshairTint[3], CZ.crosshairTint[4] or 1
  end
  local textureToUse = state == "base" and CrosshairAppearance.Base or CrosshairAppearance.Active
  local reverseAnimation = state == "base" and true or false

  -- Sets new scale at the end of animation
  CrosshairAnimation:SetScript("OnFinished", function()
    if state ~= "base" then
      CrosshairFrame:SetScale(endingScale)
      CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos / endingScale)
    end
  end)

  CrosshairTexture:SetTexture(textureToUse)
  CrosshairTexture:SetVertexColor(r, g, b, a)
  CrosshairAnimation:Play(reverseAnimation)
  if state == "base" then
    CrosshairFrame:SetScale(startingScale)
    CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  end
end

function CZ.IsLiveEditing()
  return CZ.UI and CZ.UI.IsOpen and CZ.UI.IsOpen() or false
end

function CZ.DisplayCrosshair(shouldShow)
  CZ.crosshairWanted = shouldShow and true or false
  if CZ.IsLiveEditing() and CZ.DB.global.crosshair then
    shouldShow = true -- live preview while the settings window is open
  end
  if shouldShow then
    CrosshairTexture:SetAlpha(1)
    CrosshairTexture:Show()
  elseif CZ.DB.global.crosshair and CZ.DB.global.crosshairDisabledStyle == "dim" then
    -- Free Look off: keep a faint crosshair on screen
    CrosshairTexture:SetAlpha(0.3)
    CrosshairTexture:Show()
  else
    CrosshairTexture:Hide()
  end
end

-- Adjusts centered cursor vertical positioning to match crosshair's
local function AdjustCenteredCursorYPos(crosshairYPos)
  local cursorCenteredYpos = (crosshairYPos / 1000) + 0.5 -- adding 0.5 to prevent going below screen center
  local adjustment = (crosshairYPos * 0.15) / 1000 -- lowering the cursor by 15% of YPos to keep it within xhair
  cursorCenteredYpos = cursorCenteredYpos - adjustment
  SetCVar("CursorCenteredYPos", cursorCenteredYpos)
end

function CZ.CreateCrosshair()
  local DefaultConfig = CZ.Constants.DatabaseDefaults.global
  local UserConfig = CZ.DB.global or {}
  local crosshairYPos = UserConfig.crosshairY or DefaultConfig.crosshairY

  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  CrosshairFrame:SetSize(UserConfig.crosshairSize or DefaultConfig.crosshairSize,
    UserConfig.crosshairSize or DefaultConfig.crosshairSize)
  CrosshairFrame:SetAlpha((UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity) * (CZ.crosshairAlphaMult or 1))

  SetCrosshairAppearance("base")
  AdjustCenteredCursorYPos(CZ.GetCrosshairY())
end

-- Range tint for hostile targets (nil clears it)
function CZ.SetCrosshairTint(r, g, b, a)
  if r then
    CZ.crosshairTint = {r, g, b, a or 1}
  else
    CZ.crosshairTint = nil
  end
  if lastCrosshairState == "hostile" then
    local color = CZ.crosshairTint or CZ.Constants.CrosshairReactionColors.hostile
    CrosshairTexture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
end

-- Visibility multiplier (0..1) on top of the crosshair opacity setting
function CZ.SetCrosshairAlphaMultiplier(mult)
  CZ.crosshairAlphaMult = mult
  CrosshairFrame:SetAlpha((CZ.DB.global.crosshairOpacity or 1) * mult)
end

-- Extra height (head tracking). Moves the crosshair and the centered cursor with it.
local lastCursorY
function CZ.SetCrosshairExtraY(dy)
  dy = dy or 0
  if math.abs(dy - (CZ.crosshairExtraY or 0)) < 0.5 then
    return
  end
  CZ.crosshairExtraY = dy
  local y = CZ.GetCrosshairY()
  local scale = CrosshairFrame:GetScale() or 1
  CrosshairFrame:SetPoint("CENTER", 0, y / (scale > 0 and scale or 1))
  if not lastCursorY or math.abs(y - lastCursorY) >= 2 then
    lastCursorY = y
    AdjustCenteredCursorYPos(y)
  end
end

--[[
  Midnight: UnitGUID / UnitReaction can return secret values inside instances and in
  combat. A soft ENEMY target is attackable by definition, so it is always "hostile".
  For soft INTERACT targets we read the reaction safely and fall back to "object".
]] --
local function HandleCrosshairReactionToTarget(target)
  local exists = SafeCall(UnitExists, target) == true

  if target == "softenemy" then
    SetCrosshairAppearance(exists and "hostile" or "base")
    return
  end

  if SafeCall(UnitIsGameObject, target) == true then
    SetCrosshairAppearance("object")
    return
  end

  if not exists then
    SetCrosshairAppearance("base")
    return
  end

  local reaction = SafeCall(UnitReaction, "player", target)
  if type(reaction) ~= "number" then
    SetCrosshairAppearance("object")
  elseif reaction <= 4 then
    SetCrosshairAppearance("hostile")
  else
    SetCrosshairAppearance("friendly")
  end
end

---------------------------------------------------------------------------------------
--                                CURSOR PULSE EFFECT                                --
---------------------------------------------------------------------------------------
local PULSE_DURATION = 0.4; -- total duration of the effect
local PULSE_STARTING_ALPHA = 0.5; -- initial transparency
local PULSE_STARTING_SIZE = 256 -- initial size of texture
local PULSE_TOTAL_ELAPSED = -1;

local PulseFrame = CreateFrame("Frame", nil, UIParent)
local PulseTexture = PulseFrame:CreateTexture(nil, "BACKGROUND")

local function CreatePulse()
  PulseFrame:SetSize(0, 0)
  PulseFrame:Hide()
  PulseTexture:SetAtlas(CZ.Constants.PulseAtlas, true)
  PulseTexture:SetVertexColor(1, 1, 1, 1)
  PulseTexture:SetAllPoints()
end

local function UpdatePulse(_, elapsed)
  if PULSE_TOTAL_ELAPSED == -1 then
    return
  end

  PULSE_TOTAL_ELAPSED = PULSE_TOTAL_ELAPSED + elapsed
  if PULSE_TOTAL_ELAPSED > PULSE_DURATION then
    PULSE_TOTAL_ELAPSED = -1
    PulseFrame:Hide()
    return
  end

  local progress = PULSE_TOTAL_ELAPSED / PULSE_DURATION
  local invertedProgress = 1 - progress * progress

  local alpha = invertedProgress * PULSE_STARTING_ALPHA
  PulseTexture:SetAlpha(alpha)

  local size = invertedProgress * PULSE_STARTING_SIZE
  PulseFrame:SetSize(size, size)

  local cursorX, cursorY = GetCursorPosition()
  local scale = UIParent:GetEffectiveScale()
  PulseFrame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (cursorX / scale) - size / 2, (cursorY / scale) - size / 2)
end

local function ShowCursorPulse()
  PULSE_TOTAL_ELAPSED = 0
  PulseFrame:Show()
end

PulseFrame:SetScript("OnUpdate", UpdatePulse)

---------------------------------------------------------------------------------------
--                      FRAME WATCHING / CURSOR UNLOCK FUNCTIONS                     --
---------------------------------------------------------------------------------------
local function CursorUnlockFrameVisible(frameArr)
  local allowFrameWatching = CZ.DB.global.frameWatching
  if not allowFrameWatching then
    return false
  end

  for _, frameName in pairs(frameArr) do
    local curFrame = _G[frameName]
    if curFrame and curFrame.IsVisible and curFrame:IsVisible() then
      PreventDebugSpam(frameName .. " is visible, preventing re-locking.")
      return true
    end
  end
end

local function CursorUnlockFrameGroupVisible(frameNameGroups)
  for wildcardFrameName, frameNames in pairs(frameNameGroups) do
    if CursorUnlockFrameVisible(frameNames) then
      if wildcardFrameName == "OPieRT" then
        -- Hiding crosshair because OPie runs MouselookStop() itself,
        -- which skips UnlockCursor()'s checks to hide crosshair
        if CZ.DB.global.crosshair then
          CZ.DisplayCrosshair(false)
        end
        CenterCursor(false)
      end
      return true
    end
  end
end

local function IsCustomConditionTrue()
  if not CZ.DB.global.customCondition then
    return false
  end

  local func, err = loadstring(CZ.DB.global.customCondition)

  if not func then
    CZ.DebugPrint("Invalid custom condition " .. err)
    return false
  else
    -- Calling the fn() protected to check evaluation
    local success, result = pcall(func)

    if not success then
      CZ.DebugPrint("Error executing custom condition: " .. result)
      return false
    end

    return result
  end
end

local function IsVendorMountOut()
  if not CZ.DB.global.mountCheck then
    return false
  end

  -- Vendor mounts are only used out of combat, and player auras can be secret in combat
  if UnitAffectingCombat("player") then
    return false
  end

  -- Spell IDs first: works on every client language
  if GetPlayerAuraBySpellID then
    for _, spellID in ipairs(CZ.Constants.MountSpellIDsToCheck) do
      if SafeCall(GetPlayerAuraBySpellID, spellID) ~= nil then
        return true
      end
    end
  end

  -- English names as a fallback
  for _, mount in ipairs(CZ.Constants.MountsToCheck) do
    if SafeCall(GetAuraDataBySpellName, "player", mount, "HELPFUL") ~= nil then
      return true
    end
  end

  return false
end

local function IsInPetBattle()
  if HAS_PET_BATTLES then
    return SafeCall(_G.C_PetBattles.IsInBattle) == true
  end
  return false
end

local function IsUnlockFrameVisible()
  local isGenericPanelOpen = (GetUIPanel("left") or GetUIPanel("right") or GetUIPanel("center")) and true or false
  return CursorUnlockFrameVisible(CZ.Constants.FramesToCheck) or CursorUnlockFrameVisible(CZ.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(CZ.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function ShouldFreeLookBeOff()
  local evaluate = IsCustomConditionTrue() or
                     (FreeLookOverride or SpellIsTargeting() or InCinematic() or IsInCinematicScene() or
                       IsUnlockFrameVisible() or IsVendorMountOut() or IsInPetBattle())
  return evaluate
end

-- FRAME WATCHING FOR SERIALIZED FRAMES (Ex: Opie rings)
local function InitializeWildcardFrameTracking(frameArr)
  CZ.DebugPrint("Looking for wildcard frames...")

  -- Initialise the table by going through ALL available globals once and keeping the ones that match
  for _, frameNameToFind in pairs(frameArr) do
    CZ.Constants.WildcardFramesToCheck[frameNameToFind] = {}

    for frameName in pairs(_G) do
      if string.match(frameName, frameNameToFind) then
        CZ.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
        local frameGroup = CZ.Constants.WildcardFramesToCheck[frameNameToFind]
        frameGroup[#frameGroup + 1] = frameName
      end
    end
  end

  CZ.DebugPrint("Wildcard frames initialized")
end

---------------------------------------------------------------------------------------
--                             BUTTON OVERRIDE FUNCTIONS                             --
---------------------------------------------------------------------------------------
function CZ.GetBindingsLocation()
  return CZ.DB.char.useGlobalBindings and "global" or "char"
end

function CZ.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then
    return
  end

  local valueToUse
  if buttonSettings.value == "MACRO" then
    valueToUse = "MACRO " .. buttonSettings.macroName
  elseif buttonSettings.value == "CLEARTARGET" then
    valueToUse = "MACRO CZ_ClearTarget"
  elseif buttonSettings.value == "CLEARFOCUS" then
    valueToUse = "MACRO CZ_ClearFocus"
  else
    valueToUse = buttonSettings.value
  end
  SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  CZ.DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

function CZ.OverrideDefaultButtons()
  for _, button in pairs(CZ.Constants.ButtonsToOverride) do
    CZ.SetNewBinding(CZ.DB[CZ.GetBindingsLocation()].bindings[button])
  end
end

function CZ.ResetBindingOverride(buttonSettings)
  SetMouselookOverrideBinding(buttonSettings.key, nil)
  CZ.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- Unbinding MOVEANDSTEER to avoid potential bug when toggling free look with the same key
-- Fresh install: middle mouse toggles Free Look, unless the player already bound a key
local function ApplyDefaultToggleKey()
  if CZ.DB.char.defaultToggleApplied or InCombatLockdown() then
    return
  end
  CZ.DB.char.defaultToggleApplied = true
  if GetBindingKey("CROSSHAIRZ_TOGGLE") then
    return
  end
  SetBinding("BUTTON3", "CROSSHAIRZ_TOGGLE")
  SaveBindings(GetCurrentBindingSet())
  print(CZ.Constants.BasePrintMsg .. "|cff909090: middle mouse button now toggles Free Look. Change it with /cz.|r")
end

local function UnbindMoveAndSteer()
  local key = GetBindingKey("MOVEANDSTEER")
  if key then
    SetBinding(key, "CROSSHAIRZ_TOGGLE")
  end
  SaveBindings(GetCurrentBindingSet())
end

-- Matches the bindable actions values defined in Constants.ActionsToProcess with more readable names for the UI
local function RenameBindableActions()
  for _, bindingAction in pairs(CZ.Constants.ActionsToProcess) do
    local bindingUiName = _G["BINDING_NAME_" .. bindingAction]
    CZ.Constants.OverrideActions[bindingAction] = bindingUiName or bindingAction
  end
end

---------------------------------------------------------------------------------------
--                             FREE LOOK STATE FUNCTIONS                             --
---------------------------------------------------------------------------------------
-- Other modules can react to Free Look turning on / off
CZ.freeLookListeners = {}
function CZ.OnFreeLook(fn)
  CZ.freeLookListeners[#CZ.freeLookListeners + 1] = fn
end
local function FireFreeLook(on)
  for _, fn in ipairs(CZ.freeLookListeners) do
    local ok, err = pcall(fn, on)
    if not ok then
      CZ.DebugPrint("Free Look listener error: " .. tostring(err))
    end
  end
end

local function LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    CenterCursor(true)

    if CZ.DB.global.crosshair then
      CZ.DisplayCrosshair(true)
    end

    -- tooltips are managed per mode while Free Look is on (see Extras.lua)
    HideTooltip(CZ.TooltipMode() ~= "show")

    CZ.DebugPrint("Free Look Enabled")
    FireFreeLook(true)
  end
end

local function UnlockFreeLook()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

    if CZ.DB.global.pulseCursor then
      ShowCursorPulse()
    end

    if CZ.DB.global.crosshair then
      CZ.DisplayCrosshair(false)
    end

    HideTooltip(false)

    CZ.DebugPrint("Free Look Disabled")
    FireFreeLook(false)
  end
end

local function ToggleFreeLook(state)
  if IsDefaultMouseActionBeingUsed() then
    CZ.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
    return
  end

  -- the Override state change is enough to trigger a Free Look update, but we call the fns directly to bypass the OnUpdate throttle
  if not state then
    LockFreeLook()
    FreeLookOverride = false
  elseif state then
    UnlockFreeLook()
    FreeLookOverride = true
  end
end

---------------------------------------------------------------------------------------
--                                   EVENT HANDLING                                  --
---------------------------------------------------------------------------------------
-- Rematch is called after every reload and this is where we make sure our config persists
local function Rematch()
  IsDCLoaded()
  CZ.SetMouseLookSpeed()

  if CZ.DB.global.targetCircle then
    CZ.SetTargetCircle(true)
  end

  if CZ.DB.global.actionCamera then
    CZ.ConfigActionCamera("crosshairz")
  end

  if CZ.DB.char.reticleTargeting then
    CZ.ConfigReticleTargeting("crosshairz")

    if CZ.DB.char.crosshairPriority then
      CZ.SetCrosshairPriority(true)
    end

    if CZ.DB.char.friendlyTargeting then
      CZ.SetFriendlyTargeting(true)
    end
  end

  if CZ.DB.global.crosshair then
    SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")

    if CZ.DB.char.stickyCrosshair then
      CZ.ConfigStickyCrosshair("crosshairz")
    end
  elseif CZ.DB.global.crosshair == false then
    CZ.DisplayCrosshair(false)
  end

  LockFreeLook()
end

--[[
Handle events based on their category.
You need to first register the event in the CZ.Constants.BLIZZARD_EVENTS table before using it here.
Checks which category in the table the event that's been fired belongs to, and then calls the appropriate function.
]] --
local function HandleEventByCategory(category, event)
  local eventHandlers = {
    UNLOCK_EVENTS = function()
      UnlockFreeLook()
    end,
    LOCK_EVENTS = function()
      LockFreeLook()
    end,
    REMATCH_EVENTS = function()
      Rematch()
    end,
    TARGETING_EVENTS = function()
      if not HideCrosshairWhileMounted() then
        HandleCrosshairReactionToTarget(event == "PLAYER_SOFT_ENEMY_CHANGED" and "softenemy" or "softinteract")
      end
    end,
    FRIENDLY_TARGETING_EVENTS = function()
      HandleFriendlyTargetingInCombat()
    end,
    UNCATEGORIZED_EVENTS = function()
      SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")
    end
  }

  if eventHandlers[category] then
    eventHandlers[category]()
  end
end

-- FIRES WHEN ONE OF OUR REGISTERED EVENTS HAPPEN IN GAME
function _G.CrosshairZ_OnEvent(event)
  for category, registered_events in pairs(CZ.Constants.BLIZZARD_EVENTS) do
    for _, registered_event in ipairs(registered_events) do
      if event == registered_event then
        HandleEventByCategory(category, event)
      end
    end
  end
end

---------------------------------------------------------------------------------------
--                                   GAME STATE LOOP                                 --
---------------------------------------------------------------------------------------
--[[
The game engine will call the OnUpdate function once each frame.
This is (in most cases) extremely excessive, hence why we're adding a throttle.
]] --
local ONUPDATE_INTERVAL = 0.15
local TimeSinceLastUpdate = 0
function _G.CrosshairZ_OnUpdate(_, elapsed)
  -- Making this thread-safe by keeping track of the last update cycle
  TimeSinceLastUpdate = TimeSinceLastUpdate + elapsed

  -- As the frame watching doesn't need to perform a visibility check every frame, we're adding a stagger
  if (TimeSinceLastUpdate >= ONUPDATE_INTERVAL) then
    TimeSinceLastUpdate = 0

    if IsDefaultMouseActionBeingUsed() then
      return
    end

    if ShouldFreeLookBeOff() then
      UnlockFreeLook()
      return
    end

    if not IsMouselooking() then
      LockFreeLook()
    end
  end
end

---------------------------------------------------------------------------------------
--                            KEYBIND FUNCTIONS & COMMANDS                           --
---------------------------------------------------------------------------------------
-- FUNCTIONS CALLED FROM BINDINGS.XML
function _G.CrosshairZ_ToggleKey()
  local state = IsMouselooking()
  ToggleFreeLook(state)
end

function _G.CrosshairZ_HoldKey(keystate)
  local state = keystate == "down"
  ToggleFreeLook(state)
end

-- CREATING /CZ CHAT COMMAND
-- /cz toggles the window; "/cz notes", "/cz crosshair", ... open a page directly
function CZ:OpenConfigCMD(input)
  input = input and input:trim():lower() or ""
  if InCombatLockdown() then
    print(CZ.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end
  if input == "" then
    CZ.UI.Toggle()
  elseif input == "wizard" or input == "setup" then
    CZ.UI.OpenWizard()
  elseif input == "move" then
    CZ.Assist.SetUnlocked(true)
  else
    CZ.UI.Open(input)
  end
end

-- /CMRESET CHAT COMMAND
function CZ:RunUndoCmd()
  UndoChanges()
end

---------------------------------------------------------------------------------------
--                                STANDARD ACE3 METHODS                              --
---------------------------------------------------------------------------------------
--[[
Do init tasks here, like loading the Saved Variables,
or setting up slash commands.
]] --
function CZ:OnInitialize()
  self.DB = AceDB:New("CrosshairZDB", CZ.Constants.DatabaseDefaults, true)

  -- Profiles for the HUD / Smart Crosshair / Camera settings
  CZ.Profiles.Init()

  -- Game Options > AddOns entry that launches the Crosshair Z window
  CZ.UI.RegisterBlizzardPanel()

  self:RegisterChatCommand("cz", "OpenConfigCMD")
  self:RegisterChatCommand("crosshairz", "OpenConfigCMD")
  self:RegisterChatCommand("czundo", "RunUndoCmd")
end

function CZ:OnResetDB()
  CZ.DebugPrint("Reseting Crosshair Z settings.")
  self.DB:ResetDB("Default")
  ReloadUI();
end

--[[
Do more initialization here, that really enables the use of your addon.
Register Events, Hook functions, Create Frames, Get information from
the game that wasn't available in OnInitialize
]] --
function CZ:OnEnable()
  RenameBindableActions()
  CZ.OverrideDefaultButtons()
  UnbindMoveAndSteer()
  ApplyDefaultToggleKey()
  InitializeWildcardFrameTracking(CZ.Constants.WildcardFramesToMatch)
  CZ.CreateCrosshair()
  CreatePulse()
  CreateTargetMacros()

  -- Registering Blizzard Events from Constants.lua
  for _, events_to_register in pairs(CZ.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(events_to_register) do
      self:RegisterEvent(event, _G.CrosshairZ_OnEvent)
    end
  end

  -- Greeting message that is printed to chat on initial load
  print(CZ.Constants.BasePrintMsg .. "|cff909090: Type |cff69ccf0/cz|r or |cff69ccf0/crosshairz|r for settings.|r")

  DisplayPopup()

  -- Reticle HUD, Smart Crosshair and Situational Camera
  CZ.Features.Enable()
  CZ.Camera.Enable()
  CZ.Assist.Enable()
  CZ.Orbs.Enable()
  CZ.Extras.Enable()
  CZ.UI.CheckFirstRun()
end

--[[
Unhook, Unregister Events, Hide frames that you created.
You would probably only use an OnDisable if you want to
build a "standby" mode, or be able to toggle modules on/off.
]] --
function CZ:OnDisable()
  CrosshairFrame:Hide()
  CZ.Features.Disable()
  CZ.Camera.Disable()
  CZ.Assist.Disable()
  CZ.Orbs.Disable()
  CZ.Extras.Disable()
  self:ResetCVarsToDefault()
  self:UnregisterAllEvents()
end
