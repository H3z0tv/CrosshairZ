---------------------------------------------------------------------------------------
--                               SITUATIONAL CAMERA                                  --
---------------------------------------------------------------------------------------
-- Picks the current situation (combat, mounted, indoors, ...) and moves the camera to
-- that situation's zoom, shoulder offset, head tracking and field of view. Your own
-- mouse-wheel zoom is kept until the situation changes again.
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local pcall = _G.pcall
local type = _G.type
local ipairs = _G.ipairs
local tonumber = _G.tonumber
local math_abs = _G.math.abs
local math_max = _G.math.max
local math_min = _G.math.min

local Cam = {}
CZ.Camera = Cam

local issecret = _G.issecretvalue or function()
  return false
end

local function Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b, c
end

local function Bool(fn, ...)
  local v = Call(fn, ...)
  if issecret(v) then
    return nil
  end
  return v and true or false
end

local function Num(v)
  if v == nil or issecret(v) then
    return nil
  end
  return tonumber(v)
end

local function GetCVarNum(name)
  local getter = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  return Num(Call(getter, name))
end

local function SetCVarSafe(name, value)
  local setter = _G.C_CVar and _G.C_CVar.SetCVar or _G.SetCVar
  pcall(setter, name, value)
end

-- CVars this module changes; their original values are restored when it is turned off
local MANAGED = {"test_cameraOverShoulder", "test_cameraHeadMovementStrength", "cameraFov", "cameraZoomSpeed",
                 "cameraDistanceMaxZoomFactor"}

local state = {
  active = false,
  situation = nil,
  original = nil,
  sitting = false,
  orbiting = false,
  dialogue = false,
  lastSkyZoom = nil,
  shoulder = nil,
  fov = nil
}

---------------------------------------------------------------------------------------
--                                SITUATION DETECTION                                --
---------------------------------------------------------------------------------------
local FISHING_SPELLS = {[131474] = true, [131476] = true, [131490] = true, [7620] = true, [110410] = true,
                        [158743] = true, [377895] = true}

local function InCombat()
  return _G.InCombatLockdown() or Bool(_G.UnitAffectingCombat, "player") == true
end

local function Moving()
  local speed = Num(Call(_G.GetUnitSpeed, "player"))
  return speed ~= nil and speed > 0
end

local function Fishing()
  local ok, name, _, _, _, _, _, _, spellID = pcall(_G.UnitChannelInfo, "player")
  if not ok or issecret(name) or issecret(spellID) then
    return false
  end
  return spellID ~= nil and FISHING_SPELLS[spellID] == true
end

local function Gliding()
  local info = _G.C_PlayerInfo
  if not (info and info.GetGlidingInfo) then
    return false, nil
  end
  local ok, isGliding, _, forwardSpeed = pcall(info.GetGlidingInfo)
  if not ok or issecret(isGliding) then
    return false, nil
  end
  return isGliding == true, Num(forwardSpeed)
end

local DETECT = {
  dead = function()
    return Bool(_G.UnitIsDeadOrGhost, "player")
  end,
  taxi = function()
    return Bool(_G.UnitOnTaxi, "player")
  end,
  skyriding = function()
    return (Gliding())
  end,
  dialogue = function()
    return state.dialogue
  end,
  pvp = function()
    local _, kind = Call(_G.IsInInstance)
    return kind == "pvp" or kind == "arena"
  end,
  boss = function()
    return InCombat() and Bool(_G.IsEncounterInProgress) == true
  end,
  combat = function()
    return InCombat()
  end,
  instance = function()
    local _, kind = Call(_G.IsInInstance)
    return kind == "party" or kind == "raid" or kind == "scenario"
  end,
  stealth = function()
    return Bool(_G.IsStealthed)
  end,
  swimming = function()
    return Bool(_G.IsSwimming) or Bool(_G.IsSubmerged)
  end,
  vehicle = function()
    return Bool(_G.UnitInVehicle, "player") or Bool(_G.UnitUsingVehicle, "player")
  end,
  mounted = function()
    return Bool(_G.IsMounted)
  end,
  resting = function()
    return state.sitting
  end,
  fishing = Fishing,
  indoors = function()
    return Bool(_G.IsIndoors)
  end,
  world = function()
    return true
  end
}

function Cam.CurrentSituation()
  local P = CZ.P
  if not P then
    return nil
  end
  for _, sit in ipairs(CZ.CameraSituations) do
    local settings = P.situations[sit.key]
    if settings and settings.enabled and DETECT[sit.key] and DETECT[sit.key]() then
      return sit.key
    end
  end
  return nil
end

---------------------------------------------------------------------------------------
--                                   CAMERA CONTROL                                  --
---------------------------------------------------------------------------------------
local function SaveOriginals()
  if state.original then
    return
  end
  state.original = {}
  local getter = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  for _, name in ipairs(MANAGED) do
    state.original[name] = Call(getter, name)
  end
end

local function RestoreOriginals()
  if not state.original then
    return
  end
  for name, value in pairs(state.original) do
    if value ~= nil and not issecret(value) then
      SetCVarSafe(name, value)
    end
  end
  state.original = nil
end

local function StopOrbit()
  if state.orbiting then
    state.orbiting = false
    pcall(_G.MoveViewRightStop)
  end
end

-- Asks the game to move the camera to `distance` yards; the game animates it at cameraZoomSpeed
local function ZoomTo(distance)
  local current = Num(Call(_G.GetCameraZoom))
  if not current or not distance then
    return
  end
  distance = math_max(1, math_min(39, distance))
  local needFactor = distance / 15
  local factor = GetCVarNum("cameraDistanceMaxZoomFactor") or 1.9
  if factor < needFactor then
    SetCVarSafe("cameraDistanceMaxZoomFactor", math_min(2.6, needFactor + 0.05))
  end
  local diff = distance - current
  if diff > 0.3 then
    pcall(_G.CameraZoomOut, diff)
  elseif diff < -0.3 then
    pcall(_G.CameraZoomIn, -diff)
  end
end

local function Approach(current, target, rate, elapsed)
  if not current then
    return target
  end
  local nextValue = current + (target - current) * math_min(1, elapsed * rate)
  if math_abs(target - nextValue) < 0.01 then
    nextValue = target
  end
  return nextValue
end

local function ApplySituation(key)
  local P = CZ.P
  local sit = P.situations[key]
  if not sit then
    return
  end
  SetCVarSafe("cameraZoomSpeed", math_max(4, math_min(50, 10 * (P.camTransition or 1.5))))
  if P.camHead and not CZ.MotionSafe() then
    SetCVarSafe("test_cameraHeadMovementStrength", sit.head or 0)
  end
  if key == "skyriding" and P.camSkyridingDynamic then
    state.lastSkyZoom = nil -- handled continuously in Update
  else
    ZoomTo(sit.zoom)
  end
  CZ.DebugPrint("Camera situation: " .. key)
end

local sinceCheck, sinceSky = 1, 0

---------------------------------------------------------------------------------------
--                                   BASE CAMERA                                     --
---------------------------------------------------------------------------------------
-- Field of view, max zoom distance, zoom scroll speed and head tracking for everyday play.
-- The Situational Camera overrides the parts it controls while it's on.
local baseSaved = nil
local BASE_CVARS = {"cameraFov", "cameraDistanceMaxZoomFactor", "cameraZoomSpeed", "test_cameraHeadMovementStrength"}

function Cam.ApplyBase()
  local P = CZ.P
  if not P then
    return
  end
  if P.baseCamEnabled and not CZ.DynamicCam then
    if not baseSaved then
      baseSaved = {}
      local getter = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
      for _, name in ipairs(BASE_CVARS) do
        baseSaved[name] = Call(getter, name)
      end
    end
    SetCVarSafe("cameraFov", math_max(50, math_min(90, P.baseFov or 90)))
    SetCVarSafe("cameraDistanceMaxZoomFactor", math_max(1, math_min(2.6, (P.baseMaxZoom or 28.5) / 15)))
    SetCVarSafe("cameraZoomSpeed", math_max(1, math_min(50, P.baseZoomSpeed or 20)))
    if not CZ.MotionSafe() then
      if _G.UIParent and _G.UIParent.UnregisterEvent then
        pcall(_G.UIParent.UnregisterEvent, _G.UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
      end
      SetCVarSafe("test_cameraHeadMovementStrength", P.baseHead or 0)
    end
  elseif baseSaved then
    for name, value in pairs(baseSaved) do
      if value ~= nil and not issecret(value) then
        SetCVarSafe(name, value)
      end
    end
    baseSaved = nil
  end
end

local function Update(_, elapsed)
  local P = CZ.P
  if not P then
    return
  end

  local enabled = P.camEnabled and not CZ.DynamicCam
  if not enabled then
    if state.active then
      Cam.Deactivate()
    end
    return
  end
  if not state.active then
    state.active = true
    SaveOriginals()
    if _G.UIParent and _G.UIParent.UnregisterEvent then
      pcall(_G.UIParent.UnregisterEvent, _G.UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end
    state.situation = nil
  end

  -- standing up / moving ends a sitting emote
  if state.sitting and (Moving() or InCombat()) then
    state.sitting = false
  end

  sinceCheck = sinceCheck + elapsed
  if sinceCheck >= 0.25 then
    sinceCheck = 0
    local key = Cam.CurrentSituation()
    if key ~= state.situation then
      state.situation = key
      if key then
        ApplySituation(key)
      end
    end
  end

  local key = state.situation
  local sit = key and P.situations[key]
  if not sit then
    StopOrbit()
    return
  end

  -- Shoulder offset and field of view glide to their targets
  if P.camShoulder and not CZ.MotionSafe() then
    local target = (sit.shoulder or 0) * (CZ.shoulderSign or 1)
    if P.camShoulderMountedZero and Bool(_G.IsMounted) then
      target = 0
    end
    local actual = GetCVarNum("test_cameraOverShoulder")
    local nextValue = Approach(actual, target, 4, elapsed)
    if not actual or math_abs(nextValue - actual) > 0.005 then
      SetCVarSafe("test_cameraOverShoulder", nextValue)
    end
  end
  if P.camFov then
    local target = math_max(50, math_min(90, sit.fov or 90))
    local actual = GetCVarNum("cameraFov")
    local nextValue = Approach(actual, target, 4, elapsed)
    if not actual or math_abs(nextValue - actual) > 0.05 then
      SetCVarSafe("cameraFov", nextValue)
    end
  end

  -- Skyriding: zoom out the faster you fly
  if key == "skyriding" and P.camSkyridingDynamic then
    sinceSky = sinceSky + elapsed
    if sinceSky >= 0.3 then
      sinceSky = 0
      local _, speed = Gliding()
      if speed then
        local base = sit.zoom or 20
        local k = math_max(0, math_min(1, (speed - 20) / 50))
        local target = base + k * (39 - base)
        if not state.lastSkyZoom or math_abs(target - state.lastSkyZoom) > 2 then
          state.lastSkyZoom = target
          ZoomTo(target)
        end
      end
    end
  end

  -- Sitting: slow orbit around the character
  if key == "resting" and P.camRestingOrbit then
    if not state.orbiting then
      state.orbiting = pcall(_G.MoveViewRightStart, 0.05 * (P.camOrbitSpeed or 1))
    end
  else
    StopOrbit()
  end
end

function Cam.Deactivate()
  StopOrbit()
  RestoreOriginals()
  state.active = false
  state.situation = nil
  -- the base camera settings take over again
  Cam.ApplyBase()
end

-- Re-applies the current situation (after a setting changed)
function Cam.Reapply()
  state.situation = nil
  sinceCheck = 1
end

function Cam.ActiveSituationName()
  if not state.active or not state.situation then
    return nil
  end
  for _, sit in ipairs(CZ.CameraSituations) do
    if sit.key == state.situation then
      return sit.name
    end
  end
  return state.situation
end

-- Zooms to a situation's distance for a moment so the setting can be previewed
function Cam.Preview(key)
  local sit = CZ.P and CZ.P.situations[key]
  if sit then
    ZoomTo(sit.zoom)
  end
end

---------------------------------------------------------------------------------------
--                                      EVENTS                                       --
---------------------------------------------------------------------------------------
local SIT_EMOTES = {SIT = true, SLEEP = true, KNEEL = true, LAY = true, LAYDOWN = true}

local driver = CreateFrame("Frame")

function Cam.Enable()
  if _G.hooksecurefunc and _G.DoEmote then
    _G.hooksecurefunc("DoEmote", function(emote)
      if type(emote) ~= "string" then
        return
      end
      emote = emote:upper()
      if SIT_EMOTES[emote] then
        state.sitting = true
      elseif emote == "STAND" then
        state.sitting = false
      end
    end)
  end

  for _, event in ipairs({"GOSSIP_SHOW", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_GREETING",
    "GOSSIP_CLOSED", "QUEST_FINISHED", "PLAYER_REGEN_DISABLED"}) do
    pcall(driver.RegisterEvent, driver, event)
  end
  driver:SetScript("OnEvent", function(_, event)
    if event == "GOSSIP_CLOSED" or event == "QUEST_FINISHED" then
      state.dialogue = false
    elseif event == "PLAYER_REGEN_DISABLED" then
      state.sitting = false
      sinceCheck = 1
    else
      state.dialogue = true
    end
  end)
  driver:SetScript("OnUpdate", Update)

  CZ.Profiles.OnChange(function()
    Cam.ApplyBase()
    Cam.Reapply()
  end)
  Cam.ApplyBase()
end

function Cam.Disable()
  driver:SetScript("OnUpdate", nil)
  Cam.Deactivate()
end
