-- Crosshair Z
-- Camera: over-the-shoulder view, shoulder flip, field of view and zoom, a
-- motion-safe mode, and a camera that changes by situation.

local _, Z = ...
local C = Z.Module("Camera")

-- Another camera addon owns the camera when it's loaded
local OTHER_CAMERA = {"DynamicCam"}
function C.Yield()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or _G.IsAddOnLoaded
  if not loaded then
    return false
  end
  for _, name in ipairs(OTHER_CAMERA) do
    if Z.Call(loaded, name) then
      return true
    end
  end
  return false
end

local current -- active situation key
local sitting = false
local orbiting = false

---------------------------------------------------------------------------
-- Base camera
---------------------------------------------------------------------------
local function Shoulder(p, situation)
  if p.safe then
    return 0
  end
  local s = p.actionCam and p.shoulder or 0
  if situation and p.situational and situation.shoulder ~= 0 then
    s = situation.shoulder
  end
  return p.flipped and -s or s
end

local function ApplyBase()
  local p = Z.P.camera
  local sit = current and p.situational and p.situations[current] or nil
  Z.SetCVar("cameraFov", sit and sit.on and sit.fov or p.fov)
  Z.SetCVar("cameraDistanceMaxZoomFactor", p.maxZoom)
  Z.SetCVar("cameraZoomSpeed", p.zoomSpeed)
  local shoulder = Shoulder(p, sit and sit.on and sit or nil)
  Z.SetCVar("test_cameraOverShoulder", string.format("%.2f", shoulder))
  Z.SetCVar("CameraKeepCharacterCentered", (p.safe or shoulder == 0) and 1 or 0)
  Z.SetCVar("CameraReduceUnexpectedMovement", p.safe and 1 or 0)
  local head = p.safe and 0 or ((sit and sit.on and sit.head) or p.headMove)
  Z.SetCVar("test_cameraHeadMovementStrength", string.format("%.2f", head))
  local pitch = p.actionCam and p.pitch and not p.safe
  Z.SetCVar("test_cameraDynamicPitch", pitch and 1 or 0)
  if pitch then
    -- these make the pitch strong enough to drop your character below the crosshair
    Z.SetCVar("test_cameraDynamicPitchBaseFovPad", 0)
    Z.SetCVar("test_cameraDynamicPitchBaseFovPadFlying", 0.5)
    Z.SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25)
    Z.SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 10)
  end
  local focus = p.actionCam and p.focus and not p.safe
  Z.SetCVar("test_cameraTargetFocusEnemyEnable", focus and 1 or 0)
  if focus then
    Z.SetCVar("test_cameraTargetFocusEnemyStrengthYaw", string.format("%.2f", p.focusStrength))
  end
end

function C.Flip()
  if C.Yield() then
    return
  end
  Z.P.camera.flipped = not Z.P.camera.flipped
  Z.Changed("camera.flipped")
end

---------------------------------------------------------------------------
-- Situations
---------------------------------------------------------------------------
local FISHING = {[7620] = true, [131474] = true, [131476] = true, [131490] = true, [7731] = true, [7732] = true,
                 [18248] = true, [33095] = true, [51294] = true, [88868] = true, [110410] = true}

local function Visible(name)
  local f = _G[name]
  return f and f.IsShown and f:IsShown()
end

local function Gliding()
  if C_PlayerInfo and C_PlayerInfo.GetGlidingInfo then
    local gliding, _, speed = Z.CallAll(C_PlayerInfo.GetGlidingInfo)
    return gliding, speed or 0
  end
  return false, 0
end

local function InstanceType()
  local _, kind = IsInInstance()
  return kind
end

local CHECKS = {
  dead = function()
    return Z.Truthy(UnitIsDeadOrGhost, "player")
  end,
  taxi = function()
    return UnitOnTaxi("player")
  end,
  skyriding = function()
    return (Gliding())
  end,
  dialog = function()
    return Visible("GossipFrame") or Visible("QuestFrame")
  end,
  pvp = function()
    local k = InstanceType()
    return k == "pvp" or k == "arena"
  end,
  boss = function()
    return IsEncounterInProgress and IsEncounterInProgress()
  end,
  combat = function()
    return Z.InCombat()
  end,
  dungeon = function()
    local k = InstanceType()
    return k == "party" or k == "raid" or k == "scenario"
  end,
  stealth = function()
    return IsStealthed and IsStealthed()
  end,
  swimming = function()
    return IsSwimming and IsSwimming()
  end,
  vehicle = function()
    return UnitInVehicle and UnitInVehicle("player")
  end,
  mounted = function()
    return IsMounted()
  end,
  sitting = function()
    return sitting
  end,
  fishing = function()
    local ok, _, _, _, _, _, _, _, id = pcall(UnitChannelInfo, "player")
    if not ok or Z.Secret(id) or not id then
      return false
    end
    return FISHING[id] or false
  end,
  indoors = function()
    return IsIndoors and IsIndoors()
  end,
  world = function()
    return true
  end
}

local function Pick()
  local p = Z.P.camera
  for _, s in ipairs(Z.SITUATIONS) do
    local data = p.situations[s.key]
    if data and data.on and CHECKS[s.key] and CHECKS[s.key]() then
      return s.key
    end
  end
end

local function ZoomTo(target)
  local now = GetCameraZoom and Z.Call(GetCameraZoom)
  if not now then
    return
  end
  local delta = target - now
  if delta > 0.3 then
    CameraZoomOut(delta)
  elseif delta < -0.3 then
    CameraZoomIn(-delta)
  end
end

local function Orbit(on)
  if on == orbiting then
    return
  end
  orbiting = on
  if on then
    pcall(MoveViewLeftStart, 0.04)
  else
    pcall(MoveViewLeftStop)
  end
end

local skyTimer = 0
local function Situational(elapsed)
  local p = Z.P.camera
  if not p.situational or C.Yield() then
    if current then
      current = nil
      Orbit(false)
    end
    return
  end
  if sitting and (Z.Call(GetUnitSpeed, "player") or 0) > 0 then
    sitting = false
  end
  local key = Pick()
  if key ~= current then
    current = key
    if key then
      ZoomTo(p.situations[key].zoom)
    end
    ApplyBase()
  elseif key == "skyriding" and p.skyZoom then
    skyTimer = skyTimer + (elapsed or 0)
    if skyTimer > 0.5 then
      skyTimer = 0
      local _, speed = Gliding()
      ZoomTo(Z.Clamp(p.situations.skyriding.zoom + speed * 0.35, 4, 39))
    end
  end
  Orbit(key == "sitting" and p.sitOrbit and not p.safe)
end

function C.Situation()
  return current
end

---------------------------------------------------------------------------
-- Module
---------------------------------------------------------------------------
function C:Setup()
  -- don't let the game warn about the shoulder setting every login
  if UIParent and UIParent.UnregisterEvent then
    pcall(UIParent.UnregisterEvent, UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
  end
  if DoEmote then
    hooksecurefunc("DoEmote", function(emote)
      emote = type(emote) == "string" and emote:upper() or ""
      if emote == "SIT" or emote == "KNEEL" or emote == "SLEEP" then
        sitting = true
      elseif emote == "STAND" then
        sitting = false
      end
    end)
  end
  Z.On("PLAYER_STARTED_MOVING", function()
    sitting = false
  end)
  local ticker = 0
  Z.Every(0.25, function()
    Situational(0.25)
  end)
end

function C:Apply()
  if C.Yield() then
    -- the camera addon is in charge: stop anything of ours that moves the camera
    Orbit(false)
    current = nil
    if not C.toldYield then
      C.toldYield = true
      Z.Print("DynamicCam found. It runs the camera; Crosshair Z leaves every camera setting to it.")
    end
    return
  end
  ApplyBase()
end

function C:Stop()
  Orbit(false)
end
