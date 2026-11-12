---------------------------------------------------------------------------------------
--                                     PROFILES                                      --
---------------------------------------------------------------------------------------
-- Profiles hold the settings of the Reticle HUD, Smart Crosshair and Situational Camera.
-- Each character picks a profile, optionally one per specialization.
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local pairs = _G.pairs
local ipairs = _G.ipairs
local type = _G.type

local Profiles = {}
CZ.Profiles = Profiles

local DEFAULT_NAME = "Default"

---------------------------------------------------------------------------------------
--                                 FEATURE DEFAULTS                                  --
---------------------------------------------------------------------------------------
-- Camera situations, highest priority first. Only the first matching one applies.
CZ.CameraSituations = {
  {key = "dead", name = "Dead / Ghost", desc = "While dead or running back as a ghost."},
  {key = "taxi", name = "Flight Path", desc = "While on a flight master taxi."},
  {key = "skyriding", name = "Skyriding", desc = "While gliding or skyriding. Zoom grows with your speed when Dynamic Skyriding Zoom is on."},
  {key = "dialogue", name = "NPC Dialogue", desc = "While talking to quest givers and gossip NPCs."},
  {key = "pvp", name = "PvP", desc = "Inside battlegrounds and arenas."},
  {key = "boss", name = "Boss Fight", desc = "In combat during a dungeon or raid boss encounter."},
  {key = "combat", name = "Combat", desc = "In combat (trash, open world)."},
  {key = "instance", name = "Dungeon / Raid", desc = "Inside dungeons, raids, delves and scenarios, out of combat."},
  {key = "stealth", name = "Stealth", desc = "While stealthed, prowling or invisible."},
  {key = "swimming", name = "Swimming", desc = "While swimming or underwater."},
  {key = "vehicle", name = "Vehicle", desc = "While in a vehicle or on a turret."},
  {key = "mounted", name = "Mounted", desc = "While mounted (ground or steady flight)."},
  {key = "resting", name = "Sitting", desc = "While sitting, kneeling or sleeping with an emote. The camera can slowly orbit around you."},
  {key = "fishing", name = "Fishing", desc = "While fishing."},
  {key = "indoors", name = "Indoors", desc = "Inside buildings and caves."},
  {key = "world", name = "World", desc = "Everything else: exploring out of combat."}
}

local function Situation(enabled, zoom, shoulder, fov, head)
  return {enabled = enabled, zoom = zoom, shoulder = shoulder, fov = fov, head = head}
end

CZ.FeatureDefaults = {
  -- Reticle HUD
  hudEnabled = true,
  hudScale = 0.5,
  hudOpacity = 1.0,
  hudOffsetX = 0,
  hudOffsetY = 0,
  hudTrackOpacity = 0.75,
  arcThickness = "normal",
  hudShow = "combat", -- always | active (combat, target or hurt) | combat
  arcPlayerHealth = true,
  arcPlayerPower = true,
  arcTargetHealth = true,
  arcTargetCast = true,
  arcExecuteGlow = true,
  executeThreshold = 0.20,
  arcHealthColor = {0.30, 0.86, 0.35},
  pipsEnabled = true,
  pipPlacement = "below",
  pipDistance = 82,
  pipSpread = 25,
  pipSize = 12,
  hitConfirm = false,
  hitAllSources = false,
  killConfirm = true,
  killBloom = true,
  killBloomSize = 1.0,

  -- Assist HUD
  assistEnabled = true,
  assistOpacity = 1.0,
  assistKeybind = true,
  assistSpell = true,
  assistSpellOnlyCombat = true,
  assistSpellSize = 34,
  assistSpellX = -72,
  assistSpellY = 0,
  assistInteract = true,
  assistInteractName = true,
  assistInteractHint = true,
  assistInteractGlow = false,
  assistInteractNameplate = true,
  assistInteractHideCombat = true,
  assistInteractSize = 28,
  assistInteractX = 72,
  assistInteractY = 0,

  -- Resource Orbs (class points)
  orbsEnabled = true,
  orbsColor = "red",
  orbsAnimate = true,
  orbsGlow = true,

  -- Crosshair cast feedback
  castFeedback = true,
  castGrow = true,
  castPulse = true,
  castShake = true,

  -- Base camera (applies when the Situational Camera is off, or for what it doesn't control)
  baseCamEnabled = false,
  baseFov = 90,
  baseMaxZoom = 28.5,
  baseZoomSpeed = 20,
  baseHead = 0.5,

  -- Smart Crosshair
  smartEnabled = true,
  visibility = "always", -- always | combat | target
  hideFlightForm = true,
  hideIdle = false,
  idleSeconds = 4,
  hideNoTarget = false,
  hideFriendly = false,
  hideDead = false,
  hideOutOfRange = false,
  combatOpacity = false,
  opacityInCombat = 1.0,
  opacityOutCombat = 0.6,
  rangeColors = true,
  colorMelee = {0.25, 0.95, 0.35},
  colorRanged = {0.95, 0.75, 0.12},
  colorOutOfRange = {0.95, 0.18, 0.12},
  rangeSpellMelee = "",
  rangeSpellRanged = "",
  headTracking = false,
  headFactor = 1500,
  stealthVignette = true,
  stealthOpacity = 0.6,
  lowHealthVignette = false,
  lowHealthThreshold = 0.30,
  lowHealthOpacity = 0.5,
  freelookVignette = false,
  freelookVignetteOpacity = 0.35,

  -- Situational Camera
  camEnabled = false,
  camTransition = 1.5,
  camFov = false,
  camShoulder = true,
  camHead = true,
  camShoulderMountedZero = true,
  camSkyridingDynamic = true,
  camRestingOrbit = true,
  camOrbitSpeed = 1.0,
  situations = {
    dead = Situation(true, 30, 0, 75, 0),
    taxi = Situation(true, 22, 1.0, 80, 0.5),
    skyriding = Situation(true, 20, 1.0, 85, 0.5),
    dialogue = Situation(false, 6, 1.0, 70, 1),
    pvp = Situation(true, 28, 0, 90, 0),
    boss = Situation(true, 26, 1.0, 90, 0.5),
    combat = Situation(true, 16, 1.0, 90, 0.5),
    instance = Situation(true, 18, 1.0, 85, 1),
    stealth = Situation(true, 9, 1.0, 80, 1),
    swimming = Situation(true, 10, 1.0, 80, 1),
    vehicle = Situation(true, 25, 0, 90, 0),
    mounted = Situation(true, 18, 1.0, 85, 0.5),
    resting = Situation(true, 8, 0.8, 70, 1),
    fishing = Situation(true, 7, 0.8, 70, 1),
    indoors = Situation(false, 12, 1.0, 80, 1),
    world = Situation(true, 12, 1.0, 85, 1)
  }
}

---------------------------------------------------------------------------------------
--                                     HELPERS                                       --
---------------------------------------------------------------------------------------
local function DeepCopy(value)
  if type(value) ~= "table" then
    return value
  end
  local copy = {}
  for k, v in pairs(value) do
    copy[k] = DeepCopy(v)
  end
  return copy
end
Profiles.DeepCopy = DeepCopy

-- Adds any missing keys from defaults (new settings in later versions)
local function FillMissing(target, defaults)
  for k, v in pairs(defaults) do
    if target[k] == nil then
      target[k] = DeepCopy(v)
    elseif type(v) == "table" and type(target[k]) == "table" and v[1] == nil then
      FillMissing(target[k], v)
    end
  end
end

local function Store()
  local global = CZ.DB.global
  global.czProfiles = global.czProfiles or {}
  if not global.czProfiles[DEFAULT_NAME] then
    global.czProfiles[DEFAULT_NAME] = DeepCopy(CZ.FeatureDefaults)
  end
  return global.czProfiles
end

local function CharData()
  local char = CZ.DB.char
  char.czProfile = char.czProfile or DEFAULT_NAME
  char.czSpecProfiles = char.czSpecProfiles or {}
  return char
end

---------------------------------------------------------------------------------------
--                                 SPECIALIZATIONS                                   --
---------------------------------------------------------------------------------------
function Profiles.GetSpecs()
  local list = {}
  local GetNumSpecializations = _G.GetNumSpecializations
  local GetSpecializationInfo = _G.GetSpecializationInfo
  if not (GetNumSpecializations and GetSpecializationInfo) then
    return list
  end
  local ok, count = pcall(GetNumSpecializations)
  if not ok or type(count) ~= "number" then
    return list
  end
  for i = 1, count do
    local okInfo, id, name = pcall(GetSpecializationInfo, i)
    if okInfo and id and name then
      list[#list + 1] = {id = id, name = name}
    end
  end
  return list
end

function Profiles.CurrentSpecID()
  local GetSpecialization = _G.GetSpecialization
  local GetSpecializationInfo = _G.GetSpecializationInfo
  if not (GetSpecialization and GetSpecializationInfo) then
    return nil
  end
  local ok, index = pcall(GetSpecialization)
  if not ok or not index then
    return nil
  end
  local okInfo, id = pcall(GetSpecializationInfo, index)
  return okInfo and id or nil
end

---------------------------------------------------------------------------------------
--                                  ACTIVE PROFILE                                   --
---------------------------------------------------------------------------------------
local listeners = {}

function Profiles.OnChange(fn)
  listeners[#listeners + 1] = fn
end

function Profiles.Notify()
  for _, fn in ipairs(listeners) do
    local ok, err = pcall(fn)
    if not ok then
      CZ.DebugPrint("Profile listener error: " .. tostring(err))
    end
  end
end

function Profiles.ActiveName()
  local store = Store()
  local char = CharData()
  local name
  if char.czUseSpecProfiles then
    local spec = Profiles.CurrentSpecID()
    name = spec and char.czSpecProfiles[spec]
  end
  name = name or char.czProfile
  if not store[name] then
    name = DEFAULT_NAME
  end
  return name
end

function Profiles.Resolve()
  local store = Store()
  local name = Profiles.ActiveName()
  local profile = store[name]
  -- 0.1.2 update: pips used to sit on top of the arcs
  if (profile.schema or 0) < 2 then
    if profile.pipDistance == 50 then
      profile.pipDistance = 72
    end
    profile.schema = 2
  end
  -- 0.1.2 update: "Only When Needed" switch became the "Show HUD" choice
  if (profile.schema or 0) < 3 then
    if profile.hudOnlyActive ~= nil and profile.hudShow == nil then
      profile.hudShow = profile.hudOnlyActive and "combat" or "always"
    end
    profile.hudOnlyActive = nil
    profile.schema = 3
  end
  -- 0.1.5: the prompt is now a plain icon; its green glow is off unless turned back on
  if (profile.schema or 0) < 4 then
    profile.assistInteractGlow = false
    profile.schema = 4
  end
  -- 0.1.7: Resource Orbs replace the resource pips; they stay off if the pips were off
  if (profile.schema or 0) < 5 then
    profile.orbsEnabled = profile.pipsEnabled ~= false
    profile.schema = 5
  end
  if (profile.schema or 0) < 6 then
    -- early 0.1.7 builds had separate orb position and size settings
    profile.orbsX, profile.orbsY, profile.orbsSize, profile.orbsSpacing = nil, nil, nil, nil
    profile.schema = 6
  end
  FillMissing(profile, CZ.FeatureDefaults)
  CZ.P = profile
  CZ.ActiveProfileName = name
  Profiles.Notify()
end

function Profiles.Init()
  Store()
  CharData()
  CZ.P = nil
  Profiles.Resolve()

  local f = _G.CreateFrame("Frame")
  f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
  f:RegisterEvent("PLAYER_ENTERING_WORLD")
  f:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
      return
    end
    local before = CZ.ActiveProfileName
    Profiles.Resolve()
    if event == "PLAYER_SPECIALIZATION_CHANGED" and before ~= CZ.ActiveProfileName then
      print(CZ.Constants.BasePrintMsg .. "|cff909090: profile |r" .. CZ.ActiveProfileName .. "|cff909090 loaded.|r")
    end
    if CZ.UI and CZ.UI.Refresh then
      CZ.UI.Refresh()
    end
  end)
end

-- Called by settings after a value changed
function Profiles.Changed()
  Profiles.Notify()
end

function Profiles.List()
  local names = {}
  for name in pairs(Store()) do
    names[#names + 1] = name
  end
  table.sort(names, function(a, b)
    if a == DEFAULT_NAME then
      return true
    elseif b == DEFAULT_NAME then
      return false
    end
    return a:lower() < b:lower()
  end)
  return names
end

-- Makes `name` this character's profile (or this spec's, when per-spec profiles are on)
function Profiles.SetActive(name)
  if not Store()[name] then
    return
  end
  local char = CharData()
  if char.czUseSpecProfiles then
    local spec = Profiles.CurrentSpecID()
    if spec then
      char.czSpecProfiles[spec] = name
    else
      char.czProfile = name
    end
  else
    char.czProfile = name
  end
  Profiles.Resolve()
end

function Profiles.SetSpecProfile(specID, name)
  local char = CharData()
  char.czSpecProfiles[specID] = (name ~= "" and name) or nil
  Profiles.Resolve()
end

function Profiles.Create(name, copyFrom)
  name = (name or ""):gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    return false, "Enter a profile name."
  end
  local store = Store()
  if store[name] then
    return false, "A profile with that name already exists."
  end
  local source = copyFrom and store[copyFrom]
  store[name] = source and DeepCopy(source) or DeepCopy(CZ.FeatureDefaults)
  Profiles.SetActive(name)
  return true
end

function Profiles.CopyInto(sourceName)
  local store = Store()
  local source = store[sourceName]
  local active = Profiles.ActiveName()
  if not source or sourceName == active then
    return
  end
  store[active] = DeepCopy(source)
  Profiles.Resolve()
end

function Profiles.Delete(name)
  local store = Store()
  if name == DEFAULT_NAME or not store[name] then
    return false
  end
  store[name] = nil
  local char = CharData()
  if char.czProfile == name then
    char.czProfile = DEFAULT_NAME
  end
  for spec, profileName in pairs(char.czSpecProfiles) do
    if profileName == name then
      char.czSpecProfiles[spec] = nil
    end
  end
  Profiles.Resolve()
  return true
end

function Profiles.ResetActive()
  local store = Store()
  store[Profiles.ActiveName()] = DeepCopy(CZ.FeatureDefaults)
  Profiles.Resolve()
end

function Profiles.SetUseSpecProfiles(enabled)
  local char = CharData()
  char.czUseSpecProfiles = enabled and true or false
  if enabled then
    -- start every spec on the profile the character uses now
    local current = char.czProfile
    for _, spec in ipairs(Profiles.GetSpecs()) do
      if not char.czSpecProfiles[spec.id] then
        char.czSpecProfiles[spec.id] = current
      end
    end
  end
  Profiles.Resolve()
end

function Profiles.UsesSpecProfiles()
  return CharData().czUseSpecProfiles and true or false
end
