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
_G.BINDING_HEADER_TRUERETICLE = "True Reticle"
_G.BINDING_NAME_TRUERETICLE_TOGGLE = "Toggle Free Look"
_G.BINDING_NAME_TRUERETICLE_HOLD = "Hold to Switch Free Look"

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
local TR = AceAddon:NewAddon("TrueReticle", "AceConsole-3.0", "AceEvent-3.0")
_G.TrueReticle = TR

-- INITIAL STATE VARIABLES
--[[
Changes when Free Look state is modified through user input
("Toggle" or "Press & Hold" keybinds and "/tr" cmd)
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
    dataRetuned[string.upper(key)] = GetAddOnMetadata("TrueReticle", key)
  end

  return dataRetuned
end

TR.METADATA = FetchDataFromTOC()

function TR.DebugPrint(statement)
  if TR.DB.global.debugMode then
    print(TR.Constants.BasePrintMsg .. "|cff909090: " .. tostring(statement) .. "|r")
  end
end

local lastPrintTime = 0
local function PreventDebugSpam(msg)
  local currentTime = GetTime()

  if currentTime - lastPrintTime > 3 then
    TR.DebugPrint(msg)
    lastPrintTime = currentTime
  end
end

local function OpenConfigPanel()
  if InCombatLockdown() then
    print(TR.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end
  TR.UI.Open()
end

local function UndoChanges()
  if InCombatLockdown() then
    print(TR.Constants.BasePrintMsg .. "|cff909090: Cannot run this cmd while in combat.|r")
    return
  end
  TR:ResetCVarsToDefault()
  DisableAddOn("TrueReticle")
  ReloadUI()
end

TR.UndoChanges = function()
  UndoChanges()
end

local function DisplayPopup()
  if TR.DB.char.seenWarning then
    return
  end

  local function OnClosePopup()
    TR.DB.char.seenWarning = true
    OpenConfigPanel()
  end

  StaticPopupDialogs["TrueReticle Warning"] = {
    text = TR.Constants.PopupMsg,
    button1 = "Ok",
    OnButton1 = OnClosePopup,
    OnHide = OnClosePopup,
    timeout = 0,
    whileDead = true
  }

  StaticPopup_Show("TrueReticle Warning")
end

function TR.MacroExists(name)
  return GetMacroInfo(name) ~= nil
end

local function CreateTargetMacros()
  local function createMacroIfNotExists(macroName, icon, macroText)
    if not TR.MacroExists(macroName) then
      CreateMacro(macroName, icon, macroText, false)
    end
  end

  local macroIcon = "ability_hisek_aim"

  -- CreateMacro is blocked in combat and errors when the account macro list is full
  if InCombatLockdown() then
    return
  end

  for macroName, macroText in pairs(TR.Constants.Macros) do
    local ok, err = pcall(createMacroIfNotExists, macroName, macroIcon, macroText)
    if not ok then
      TR.DebugPrint("Could not create macro " .. macroName .. ": " .. tostring(err))
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

local function HideTooltip(shouldHide)
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
  TR.DynamicCam = DC ~= nil and true or false
  if TR.DynamicCam then
    print(TR.Constants.BasePrintMsg ..
            "|cff909090: |cff7CFF4FDynamicCam detected!|r Handing over control of |cffE37527• Camera Features|r.|r")
  end
end

---------------------------------------------------------------------------------------
--                              CVAR HANDLING FUNCTIONS                              --
---------------------------------------------------------------------------------------
local function LoadCVars(info)
  local CVarType, CMValues, BlizzValues, FeatureName = info.CVarType, info.CMValues, info.BlizzValues, info.FeatureName
  local CVarsToLoad

  if CVarType == "truereticle" then
    CVarsToLoad = CMValues
    TR.DebugPrint(FeatureName .. " CVars LOADED")
  elseif CVarType == "blizzard" then
    CVarsToLoad = BlizzValues
    TR.DebugPrint(FeatureName .. " CVars RESET")
  else
    TR.DebugPrint("Invalid CVarType specified in fn TR.ConfigCVars() for " .. FeatureName .. ": " .. tostring(CVarType))
    return
  end

  for name, value in pairs(CVarsToLoad) do
    SetCVar(name, value)
  end
end

function TR.ConfigReticleTargeting(CVarType)
  local info = {
    CVarType = CVarType,
    CMValues = TR.Constants.ReticleTargetingCVarValues,
    BlizzValues = TR.Constants.BlizzardReticleTargetingCVarValues,
    FeatureName = "Reticle Targeting"
  }

  LoadCVars(info)
end

function TR.ConfigActionCamera(CVarType)
  if TR.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = TR.Constants.ActionCameraCVarValues,
    BlizzValues = TR.Constants.BlizzardActionCameraCVarValues,
    FeatureName = "Action Camera"
  }

  LoadCVars(info)
  if CVarType == "truereticle" then
    TR.SetShoulderOffset()
  end
  -- Disable the Action Cam warning message.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

function TR.ConfigStickyCrosshair(CVarType)
  if TR.DynamicCam then
    return
  end

  local info = {
    CVarType = CVarType,
    CMValues = TR.Constants.TagetFocusCVarValues,
    BlizzValues = TR.Constants.BlizzardTagetFocusCVarValues,
    FeatureName = "Sticky Crosshair"
  }

  LoadCVars(info)
end

function TR.SetMouseLookSpeed()
  if TR.DynamicCam then
    return
  end

  local XSpeed = TR.DB.global.mouseLookSpeed
  local YSpeed = TR.DB.global.mouseLookSpeed / 2 -- Blizz wants pitch speed as 1/2 of yaw speed
  SetCVar("cameraYawMoveSpeed", XSpeed)
  SetCVar("cameraPitchMoveSpeed", YSpeed)
  TR.DebugPrint("Setting Camera Turn Speed X to " .. XSpeed .. " and Y to " .. YSpeed)
end

function TR.SetShoulderOffset()
  if TR.DynamicCam then
    return
  end

  local offset = TR.DB.char.shoulderOffset
  SetCVar("test_cameraOverShoulder", offset)
  TR.DebugPrint("Setting Shoulder Offset to " .. offset)
end

function TR.SetCrosshairPriority(enabled)
  if not HAS_MOUSEOVER_CAST then
    return
  end
  if enabled then
    SetCVar("enableMouseoverCast", 1)
    SetModifiedClick("MOUSEOVERCAST", "NONE")
    SaveBindings(GetCurrentBindingSet())
    TR.DebugPrint("Enabling Crosshair Priority")
  else
    SetCVar("enableMouseoverCast", 0)
    TR.DebugPrint("Disabling Crosshair Priority")
  end
end

function TR.SetFriendlyTargeting(enabled)
  if enabled then
    SetCVar("SoftTargetFriend", 3)
    TR.DebugPrint("Enabling Friendly Targeting out of combat")
  else
    SetCVar("SoftTargetFriend", 0)
    TR.DebugPrint("Disabling Friendly Targeting in combat")
  end
end

-- Target circle (the ring on the ground under your target)
function TR.SetTargetCircle(enabled)
  if _G.C_CVar.GetCVar("ObjectSelectionCircle") == nil then
    TR.DebugPrint("ObjectSelectionCircle CVar not found on this client.")
    return
  end
  SetCVar("ObjectSelectionCircle", enabled and 1 or 0)
  TR.DebugPrint((enabled and "Enabling" or "Disabling") .. " Target Circle")
end

-- Temporarily disable friendly targeting during combat
local function HandleFriendlyTargetingInCombat()
  local CharConfig = TR.DB.char or {}
  local isFriendlyTargetingInCombatOn = CharConfig.reticleTargeting and CharConfig.friendlyTargeting and
                                          CharConfig.friendlyTargetingInCombat

  if not isFriendlyTargetingInCombatOn then
    return
  end

  local InCombat = UnitAffectingCombat("player")

  if InCombat then
    TR.SetFriendlyTargeting(false)
  else
    TR.SetFriendlyTargeting(true)
  end
end

local function CenterCursor(shouldCenter)
  if shouldCenter then
    SetCVar("CursorFreelookCentering", 1)
    TR.DebugPrint("Locking cursor to crosshair position.")
  else
    SetCVar("CursorFreelookCentering", 0)
    TR.DebugPrint("Freeing cursor from crosshair position.")
  end
end

function TR:ResetCVarsToDefault()
  if TR.Camera then
    TR.Camera.Deactivate()
  end
  self.ConfigReticleTargeting("blizzard")
  self.ConfigActionCamera("blizzard")
  self.ConfigStickyCrosshair("blizzard")
  self.SetCrosshairPriority(false)
  self.SetFriendlyTargeting(false)

  print(TR.Constants.BasePrintMsg .. "|cff909090: all changes have been reverted.|r")
end
---------------------------------------------------------------------------------------
--                           CROSSHAIR HANDLING FUNCTIONS                            --
---------------------------------------------------------------------------------------
-- SETTING UP CROSSHAIR FRAME & ANIMATION
local CrosshairFrame = CreateFrame("Frame", "TrueReticleCrosshairFrame", UIParent)
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
  return TR.DB.global.crosshairMounted and IsMounted()
end

-- Shared crosshair state used by the HUD / Smart Crosshair modules
TR.CrosshairFrame = CrosshairFrame
TR.CrosshairTexture = CrosshairTexture
TR.crosshairExtraY = 0 -- extra height from head tracking
TR.crosshairAlphaMult = 1 -- visibility multiplier from Smart Crosshair
TR.crosshairTint = nil -- {r, g, b, a} range tint for hostile targets
local lastCrosshairState = "base"

function TR.GetCrosshairY()
  return (TR.DB.global.crosshairY or 0) + (TR.crosshairExtraY or 0)
end

local function SetCrosshairAppearance(state)
  local CrosshairAppearance = TR.DB.global.crosshairAppearance
  local crosshairYPos = TR.GetCrosshairY()
  lastCrosshairState = state
  local r, g, b, a = unpack(TR.Constants.CrosshairReactionColors[state])
  if state == "hostile" and TR.crosshairTint then
    r, g, b, a = TR.crosshairTint[1], TR.crosshairTint[2], TR.crosshairTint[3], TR.crosshairTint[4] or 1
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

function TR.DisplayCrosshair(shouldShow)
  if shouldShow then
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

function TR.CreateCrosshair()
  local DefaultConfig = TR.Constants.DatabaseDefaults.global
  local UserConfig = TR.DB.global or {}
  local crosshairYPos = UserConfig.crosshairY or DefaultConfig.crosshairY

  CrosshairTexture:SetAllPoints(CrosshairFrame)
  CrosshairTexture:SetBlendMode("BLEND")
  CrosshairFrame:SetPoint("CENTER", 0, crosshairYPos)
  CrosshairFrame:SetSize(UserConfig.crosshairSize or DefaultConfig.crosshairSize,
    UserConfig.crosshairSize or DefaultConfig.crosshairSize)
  CrosshairFrame:SetAlpha((UserConfig.crosshairOpacity or DefaultConfig.crosshairOpacity) * (TR.crosshairAlphaMult or 1))

  SetCrosshairAppearance("base")
  AdjustCenteredCursorYPos(TR.GetCrosshairY())
end

-- Range tint for hostile targets (nil clears it)
function TR.SetCrosshairTint(r, g, b, a)
  if r then
    TR.crosshairTint = {r, g, b, a or 1}
  else
    TR.crosshairTint = nil
  end
  if lastCrosshairState == "hostile" then
    local color = TR.crosshairTint or TR.Constants.CrosshairReactionColors.hostile
    CrosshairTexture:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
  end
end

-- Visibility multiplier (0..1) on top of the crosshair opacity setting
function TR.SetCrosshairAlphaMultiplier(mult)
  TR.crosshairAlphaMult = mult
  CrosshairFrame:SetAlpha((TR.DB.global.crosshairOpacity or 1) * mult)
end

-- Extra height (head tracking). Moves the crosshair and the centered cursor with it.
local lastCursorY
function TR.SetCrosshairExtraY(dy)
  dy = dy or 0
  if math.abs(dy - (TR.crosshairExtraY or 0)) < 0.5 then
    return
  end
  TR.crosshairExtraY = dy
  local y = TR.GetCrosshairY()
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
  PulseTexture:SetAtlas(TR.Constants.PulseAtlas, true)
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
  local allowFrameWatching = TR.DB.global.frameWatching
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
        if TR.DB.global.crosshair then
          TR.DisplayCrosshair(false)
        end
        CenterCursor(false)
      end
      return true
    end
  end
end

local function IsCustomConditionTrue()
  if not TR.DB.global.customCondition then
    return false
  end

  local func, err = loadstring(TR.DB.global.customCondition)

  if not func then
    TR.DebugPrint("Invalid custom condition " .. err)
    return false
  else
    -- Calling the fn() protected to check evaluation
    local success, result = pcall(func)

    if not success then
      TR.DebugPrint("Error executing custom condition: " .. result)
      return false
    end

    return result
  end
end

local function IsVendorMountOut()
  if not TR.DB.global.mountCheck then
    return false
  end

  -- Vendor mounts are only used out of combat, and player auras can be secret in combat
  if UnitAffectingCombat("player") then
    return false
  end

  -- Spell IDs first: works on every client language
  if GetPlayerAuraBySpellID then
    for _, spellID in ipairs(TR.Constants.MountSpellIDsToCheck) do
      if SafeCall(GetPlayerAuraBySpellID, spellID) ~= nil then
        return true
      end
    end
  end

  -- English names as a fallback
  for _, mount in ipairs(TR.Constants.MountsToCheck) do
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
  return CursorUnlockFrameVisible(TR.Constants.FramesToCheck) or CursorUnlockFrameVisible(TR.DB.global.watchlist) or
           CursorUnlockFrameGroupVisible(TR.Constants.WildcardFramesToCheck) or isGenericPanelOpen
end

local function ShouldFreeLookBeOff()
  local evaluate = IsCustomConditionTrue() or
                     (FreeLookOverride or SpellIsTargeting() or InCinematic() or IsInCinematicScene() or
                       IsUnlockFrameVisible() or IsVendorMountOut() or IsInPetBattle())
  return evaluate
end

-- FRAME WATCHING FOR SERIALIZED FRAMES (Ex: Opie rings)
local function InitializeWildcardFrameTracking(frameArr)
  TR.DebugPrint("Looking for wildcard frames...")

  -- Initialise the table by going through ALL available globals once and keeping the ones that match
  for _, frameNameToFind in pairs(frameArr) do
    TR.Constants.WildcardFramesToCheck[frameNameToFind] = {}

    for frameName in pairs(_G) do
      if string.match(frameName, frameNameToFind) then
        TR.DebugPrint("Matched " .. frameNameToFind .. " to frame " .. frameName)
        local frameGroup = TR.Constants.WildcardFramesToCheck[frameNameToFind]
        frameGroup[#frameGroup + 1] = frameName
      end
    end
  end

  TR.DebugPrint("Wildcard frames initialized")
end

---------------------------------------------------------------------------------------
--                             BUTTON OVERRIDE FUNCTIONS                             --
---------------------------------------------------------------------------------------
function TR.GetBindingsLocation()
  return TR.DB.char.useGlobalBindings and "global" or "char"
end

function TR.SetNewBinding(buttonSettings)
  if not buttonSettings.enabled then
    return
  end

  local valueToUse
  if buttonSettings.value == "MACRO" then
    valueToUse = "MACRO " .. buttonSettings.macroName
  elseif buttonSettings.value == "CLEARTARGET" then
    valueToUse = "MACRO TR_ClearTarget"
  elseif buttonSettings.value == "CLEARFOCUS" then
    valueToUse = "MACRO TR_ClearFocus"
  else
    valueToUse = buttonSettings.value
  end
  SetMouselookOverrideBinding(buttonSettings.key, valueToUse)
  TR.DebugPrint(buttonSettings.key .. "'s override binding is now " .. valueToUse)
end

function TR.OverrideDefaultButtons()
  for _, button in pairs(TR.Constants.ButtonsToOverride) do
    TR.SetNewBinding(TR.DB[TR.GetBindingsLocation()].bindings[button])
  end
end

function TR.ResetBindingOverride(buttonSettings)
  SetMouselookOverrideBinding(buttonSettings.key, nil)
  TR.DebugPrint(buttonSettings.key .. "'s override binding is now cleared")
end

-- Unbinding MOVEANDSTEER to avoid potential bug when toggling free look with the same key
local function UnbindMoveAndSteer()
  local key = GetBindingKey("MOVEANDSTEER")
  if key then
    SetBinding(key, "TRUERETICLE_TOGGLE")
  end
  SaveBindings(GetCurrentBindingSet())
end

-- Matches the bindable actions values defined in Constants.ActionsToProcess with more readable names for the UI
local function RenameBindableActions()
  for _, bindingAction in pairs(TR.Constants.ActionsToProcess) do
    local bindingUiName = _G["BINDING_NAME_" .. bindingAction]
    TR.Constants.OverrideActions[bindingAction] = bindingUiName or bindingAction
  end
end

---------------------------------------------------------------------------------------
--                             FREE LOOK STATE FUNCTIONS                             --
---------------------------------------------------------------------------------------
local function LockFreeLook()
  if not IsMouselooking() then
    MouselookStart()
    CenterCursor(true)

    if TR.DB.global.crosshair then
      TR.DisplayCrosshair(true)
    end

    if TR.DB.global.hideTooltip then
      HideTooltip(true)
    end

    TR.DebugPrint("Free Look Enabled")
  end
end

local function UnlockFreeLook()
  if IsMouselooking() then
    CenterCursor(false)
    MouselookStop()

    if TR.DB.global.pulseCursor then
      ShowCursorPulse()
    end

    if TR.DB.global.crosshair then
      TR.DisplayCrosshair(false)
    end

    if TR.DB.global.hideTooltip then
      HideTooltip(false)
    end

    TR.DebugPrint("Free Look Disabled")
  end
end

local function ToggleFreeLook(state)
  if IsDefaultMouseActionBeingUsed() then
    TR.DebugPrint("Cannot toggle Free Look while holding down your left or right click.")
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
  TR.SetMouseLookSpeed()

  if TR.DB.global.targetCircle then
    TR.SetTargetCircle(true)
  end

  if TR.DB.global.actionCamera then
    TR.ConfigActionCamera("truereticle")
  end

  if TR.DB.char.reticleTargeting then
    TR.ConfigReticleTargeting("truereticle")

    if TR.DB.char.crosshairPriority then
      TR.SetCrosshairPriority(true)
    end

    if TR.DB.char.friendlyTargeting then
      TR.SetFriendlyTargeting(true)
    end
  end

  if TR.DB.global.crosshair then
    SetCrosshairAppearance(HideCrosshairWhileMounted() and "mounted" or "base")

    if TR.DB.char.stickyCrosshair then
      TR.ConfigStickyCrosshair("truereticle")
    end
  elseif TR.DB.global.crosshair == false then
    TR.DisplayCrosshair(false)
  end

  LockFreeLook()
end

--[[
Handle events based on their category.
You need to first register the event in the TR.Constants.BLIZZARD_EVENTS table before using it here.
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
function _G.TrueReticle_OnEvent(event)
  for category, registered_events in pairs(TR.Constants.BLIZZARD_EVENTS) do
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
function _G.TrueReticle_OnUpdate(_, elapsed)
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
function _G.TrueReticle_ToggleKey()
  local state = IsMouselooking()
  ToggleFreeLook(state)
end

function _G.TrueReticle_HoldKey(keystate)
  local state = keystate == "down"
  ToggleFreeLook(state)
end

-- CREATING /TR CHAT COMMAND
-- /tr toggles the window; "/tr notes", "/tr crosshair", ... open a page directly
function TR:OpenConfigCMD(input)
  input = input and input:trim():lower() or ""
  if InCombatLockdown() then
    print(TR.Constants.BasePrintMsg .. "|cff909090: Cannot open settings while in combat.|r")
    return
  end
  if input == "" then
    TR.UI.Toggle()
  else
    TR.UI.Open(input)
  end
end

-- /CMRESET CHAT COMMAND
function TR:RunUndoCmd()
  UndoChanges()
end

---------------------------------------------------------------------------------------
--                                STANDARD ACE3 METHODS                              --
---------------------------------------------------------------------------------------
--[[
Do init tasks here, like loading the Saved Variables,
or setting up slash commands.
]] --
function TR:OnInitialize()
  self.DB = AceDB:New("TrueReticleDB", TR.Constants.DatabaseDefaults, true)

  -- Profiles for the HUD / Smart Crosshair / Camera settings
  TR.Profiles.Init()

  -- Game Options > AddOns entry that launches the True Reticle window
  TR.UI.RegisterBlizzardPanel()

  self:RegisterChatCommand("tr", "OpenConfigCMD")
  self:RegisterChatCommand("truereticle", "OpenConfigCMD")
  self:RegisterChatCommand("trundo", "RunUndoCmd")
end

function TR:OnResetDB()
  TR.DebugPrint("Reseting True Reticle settings.")
  self.DB:ResetDB("Default")
  ReloadUI();
end

--[[
Do more initialization here, that really enables the use of your addon.
Register Events, Hook functions, Create Frames, Get information from
the game that wasn't available in OnInitialize
]] --
function TR:OnEnable()
  RenameBindableActions()
  TR.OverrideDefaultButtons()
  UnbindMoveAndSteer()
  InitializeWildcardFrameTracking(TR.Constants.WildcardFramesToMatch)
  TR.CreateCrosshair()
  CreatePulse()
  CreateTargetMacros()

  -- Registering Blizzard Events from Constants.lua
  for _, events_to_register in pairs(TR.Constants.BLIZZARD_EVENTS) do
    for _, event in ipairs(events_to_register) do
      self:RegisterEvent(event, _G.TrueReticle_OnEvent)
    end
  end

  -- Greeting message that is printed to chat on initial load
  print(TR.Constants.BasePrintMsg .. "|cff909090: Type |cff69ccf0/tr|r or |cff69ccf0/truereticle|r for settings.|r")

  DisplayPopup()

  -- Reticle HUD, Smart Crosshair and Situational Camera
  TR.Features.Enable()
  TR.Camera.Enable()
end

--[[
Unhook, Unregister Events, Hide frames that you created.
You would probably only use an OnDisable if you want to
build a "standby" mode, or be able to toggle modules on/off.
]] --
function TR:OnDisable()
  CrosshairFrame:Hide()
  TR.Features.Disable()
  TR.Camera.Disable()
  self:ResetCVarsToDefault()
  self:UnregisterAllEvents()
end
