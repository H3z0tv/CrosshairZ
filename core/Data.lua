-- Crosshair Z
-- Saved data: defaults, profiles (per character or per specialization),
-- reading and writing settings by path ("hud.scale"), and game setting
-- (CVar) changes that can be undone.

local _, Z = ...

local SAVED = "CrosshairZData"

---------------------------------------------------------------------------
-- Defaults
---------------------------------------------------------------------------
local function Situation(on, zoom, shoulder, head, fov)
  return {on = on, zoom = zoom, shoulder = shoulder, head = head, fov = fov}
end

Z.SITUATIONS = {
  {key = "dead", name = "Dead"},
  {key = "taxi", name = "Flight Path"},
  {key = "skyriding", name = "Skyriding"},
  {key = "dialog", name = "NPC Dialogue"},
  {key = "pvp", name = "PvP"},
  {key = "boss", name = "Boss Fight"},
  {key = "combat", name = "Combat"},
  {key = "dungeon", name = "Dungeon or Raid"},
  {key = "stealth", name = "Stealth"},
  {key = "swimming", name = "Swimming"},
  {key = "vehicle", name = "Vehicle"},
  {key = "mounted", name = "Mounted"},
  {key = "sitting", name = "Sitting"},
  {key = "fishing", name = "Fishing"},
  {key = "indoors", name = "Indoors"},
  {key = "world", name = "World"}
}

Z.CLICK_KEYS = {
  {key = "BUTTON1", name = "Left Click"},
  {key = "BUTTON2", name = "Right Click"},
  {key = "SHIFT-BUTTON1", name = "Shift + Left Click"},
  {key = "SHIFT-BUTTON2", name = "Shift + Right Click"},
  {key = "CTRL-BUTTON1", name = "Ctrl + Left Click"},
  {key = "CTRL-BUTTON2", name = "Ctrl + Right Click"},
  {key = "ALT-BUTTON1", name = "Alt + Left Click"},
  {key = "ALT-BUTTON2", name = "Alt + Right Click"}
}

Z.PROFILE_DEFAULTS = {
  look = {
    startOn = true,
    pulse = true,
    unlockPanels = true,
    watchlist = "",
    vendorMount = true,
    condition = "",
    sheathe = false,
    vignette = false,
    vignetteStrength = 0.45,
    tooltip = "hide",
    tooltipAt = "crosshair",
    turnSpeed = 120
  },
  aim = {
    enabled = true,
    prioritize = true,
    friendly = false,
    friendlyCombat = false,
    sticky = false,
    circle = true,
    outlines = true
  },
  clicks = {
    enabled = true,
    binds = {
      ["BUTTON1"] = "ACTIONBUTTON1",
      ["BUTTON2"] = "ACTIONBUTTON2",
      ["SHIFT-BUTTON1"] = "ACTIONBUTTON3",
      ["SHIFT-BUTTON2"] = "ACTIONBUTTON4",
      ["CTRL-BUTTON1"] = "ACTIONBUTTON5",
      ["CTRL-BUTTON2"] = "ACTIONBUTTON6",
      ["ALT-BUTTON1"] = "ACTIONBUTTON7",
      ["ALT-BUTTON2"] = "ACTIONBUTTON8"
    },
    macros = {}
  },
  lock = {
    behavior = "toggle",
    cycleLocks = true,
    auto = false,
    castFlash = true,
    pulse = true,
    sounds = false,
    soundLock = "click",
    soundCycle = "ping",
    soundClear = "soft",
    soundCast = "alert",
    channel = "SFX"
  },
  cross = {
    enabled = true,
    style = "iris",
    size = 44,
    opacity = 1,
    opacityOut = 0.8,
    y = 50,
    mounted = "dim",
    offLook = "hide",
    castGrow = true,
    castPulse = true,
    castShake = true,
    head = false,
    colorEnemy = {1, 0.25, 0.25},
    colorFriend = {0.35, 1, 0.4},
    colorNeutral = {1, 1, 1}
  },
  smart = {
    enabled = true,
    show = "always",
    hideFlight = true,
    hideIdle = false,
    hideNoTarget = false,
    hideFriendly = false,
    hideDead = true,
    hideRange = false,
    range = true,
    meleeSpell = "",
    rangedSpell = "",
    colorMelee = {0.35, 1, 0.4},
    colorRanged = {1, 0.85, 0.2},
    colorOut = {1, 0.25, 0.25}
  },
  hud = {
    enabled = true,
    show = "combat",
    scale = 1,
    thick = 3,
    arcStyle = "segments",
    neon = true,
    numbers = true,
    opacity = 0.9,
    track = 0.8,
    x = 0,
    y = 0,
    execute = true,
    executePct = 20,
    pips = true,
    orbs = true,
    pipPlace = "below",
    pipDistance = 76,
    pipSpread = 20,
    pipSize = 14,
    orbColor = "red",
    orbAnim = true,
    orbGlow = true,
    hits = true,
    kills = true,
    stealthEdges = true,
    lowHealth = true,
    lowHealthPct = 35
  },
  assist = {
    enabled = true,
    keybind = true,
    opacity = 1,
    spell = true,
    spellCombat = true,
    spellSize = 40,
    spellX = 70,
    spellY = -10,
    prompt = true,
    promptGlow = false,
    promptName = false,
    promptSize = 1,
    promptX = 0,
    promptY = -90
  },
  camera = {
    actionCam = true,
    shoulder = 1.2,
    flipped = false,
    pitch = true,
    focus = true,
    focusStrength = 0.7,
    fov = 90,
    maxZoom = 2.6,
    zoomSpeed = 20,
    headMove = 0,
    safe = false,
    situational = false,
    skyZoom = true,
    sitOrbit = true,
    situations = {
      dead = Situation(true, 8, 0, 0, 90),
      taxi = Situation(true, 18, 0, 0, 90),
      skyriding = Situation(true, 18, 0, 0, 90),
      dialog = Situation(true, 4, 0, 0, 80),
      pvp = Situation(false, 14, 0, 0, 90),
      boss = Situation(true, 20, 0, 0, 90),
      combat = Situation(true, 14, 0, 0, 90),
      dungeon = Situation(false, 16, 0, 0, 90),
      stealth = Situation(false, 8, 0, 0, 90),
      swimming = Situation(false, 10, 0, 0, 90),
      vehicle = Situation(true, 18, 0, 0, 90),
      mounted = Situation(true, 14, 0, 0, 90),
      sitting = Situation(true, 6, 0, 0, 80),
      fishing = Situation(true, 6, 0, 0, 90),
      indoors = Situation(false, 8, 0, 0, 90),
      world = Situation(true, 12, 0, 0, 90)
    }
  },
  composer = {spell = "", target = "crosshair", name = "CZ Cast"}
}

-- what each click falls back to when its macro doesn't exist on this character
Z.CLICK_FALLBACK = {}
for key, action in pairs(Z.PROFILE_DEFAULTS.clicks.binds) do
  Z.CLICK_FALLBACK[key] = action
end

Z.GLOBAL_DEFAULTS = {
  theme = "green",
  panelScale = 1,
  recent = {},
  cvars = {},
  debug = false
}

---------------------------------------------------------------------------
-- Table helpers
---------------------------------------------------------------------------
local function Copy(src)
  if type(src) ~= "table" then
    return src
  end
  local out = {}
  for k, v in pairs(src) do
    out[k] = Copy(v)
  end
  return out
end
Z.Copy = Copy

---------------------------------------------------------------------------
-- Load (AceDB keeps the profiles and fills in defaults)
---------------------------------------------------------------------------
local db

local function SpecIndex()
  if GetSpecialization then
    return Z.Call(GetSpecialization) or 0
  end
  return 0
end

local function Point()
  Z.P = db.profile
  Z.G = db.global
  Z.profileName = db:GetCurrentProfile()
end

local function ProfileSwapped()
  Point()
  Z.Send("PROFILE")
  Z.ApplyAll()
end

function Z.LoadData()
  db = LibStub("AceDB-3.0"):New(SAVED, {
    profile = Z.PROFILE_DEFAULTS,
    global = Z.GLOBAL_DEFAULTS,
    char = {perSpec = false, spec = {}}
  }, "Default")
  Z.db = db
  Z.firstRun = not db.global.seen
  db.global.seen = true
  if db.char.perSpec then
    local name = db.char.spec[SpecIndex()]
    if name and name ~= db:GetCurrentProfile() then
      db:SetProfile(name)
    end
  end
  Point()
  db.RegisterCallback(Z, "OnProfileChanged", ProfileSwapped)
  db.RegisterCallback(Z, "OnProfileCopied", ProfileSwapped)
  db.RegisterCallback(Z, "OnProfileReset", ProfileSwapped)
  Z.SV = db
end

---------------------------------------------------------------------------
-- Reading and writing settings
---------------------------------------------------------------------------
local function Walk(root, path)
  local t = root
  local last
  for part in path:gmatch("[^%.]+") do
    if last then
      if type(t[last]) ~= "table" then
        t[last] = {}
      end
      t = t[last]
    end
    last = part
  end
  return t, last
end

-- "g:theme" reads the account-wide table, anything else the profile
function Z.Get(path)
  local root = Z.P
  if path:sub(1, 2) == "g:" then
    root, path = Z.G, path:sub(3)
  end
  local t, k = Walk(root, path)
  return t[k]
end

function Z.Set(path, value)
  local root = Z.P
  local p = path
  if p:sub(1, 2) == "g:" then
    root, p = Z.G, p:sub(3)
  end
  local t, k = Walk(root, p)
  t[k] = value
  Z.Changed(path)
end

local pending = false
function Z.Changed(path)
  Z.Send("SETTING", path)
  if not pending then
    pending = true
    Z.After(0, function()
      pending = false
      Z.ApplyAll()
    end)
  end
end

---------------------------------------------------------------------------
-- Profiles
---------------------------------------------------------------------------
function Z.ActiveProfileName()
  return db:GetCurrentProfile()
end

function Z.ProfileList()
  local list = db:GetProfiles({})
  table.sort(list)
  return list
end

local function Exists(name)
  for _, n in ipairs(db:GetProfiles({})) do
    if n == name then
      return true
    end
  end
  return false
end

function Z.UseProfile(name)
  if not Exists(name) then
    return
  end
  if db.char.perSpec then
    db.char.spec[SpecIndex()] = name
  end
  if name ~= db:GetCurrentProfile() then
    db:SetProfile(name)
  end
end

function Z.NewProfile(name)
  name = (name or ""):match("^%s*(.-)%s*$")
  if name == "" or Exists(name) then
    return false
  end
  local from = db:GetCurrentProfile()
  if db.char.perSpec then
    db.char.spec[SpecIndex()] = name
  end
  db:SetProfile(name)
  db:CopyProfile(from, true)
  return true
end

function Z.CopyProfile(from)
  if Exists(from) and from ~= db:GetCurrentProfile() then
    db:CopyProfile(from, true)
  end
end

function Z.ResetProfile()
  db:ResetProfile()
end

function Z.DeleteProfile(name)
  if name == "Default" or not Exists(name) then
    return
  end
  for spec, n in pairs(db.char.spec) do
    if n == name then
      db.char.spec[spec] = nil
    end
  end
  if name == db:GetCurrentProfile() then
    db:SetProfile("Default")
  end
  db:DeleteProfile(name, true)
  Z.Send("PROFILE")
end

function Z.PerSpec(on)
  if on == nil then
    return db.char.perSpec
  end
  db.char.perSpec = on and true or false
  if on then
    db.char.spec[SpecIndex()] = db:GetCurrentProfile()
  end
end

Z.On("PLAYER_SPECIALIZATION_CHANGED", function(_, unit)
  if db and unit == "player" and db.char.perSpec then
    local name = db.char.spec[SpecIndex()]
    if name and Exists(name) and name ~= db:GetCurrentProfile() then
      db:SetProfile(name)
      Z.Print("Profile %s for this specialization.", name)
    end
  end
end)

---------------------------------------------------------------------------
-- Game settings (CVars). The value a player had before Crosshair Z first
-- touched a setting is kept, so Undo can put it back.
---------------------------------------------------------------------------
local GetCVarRaw = (C_CVar and C_CVar.GetCVar) or _G.GetCVar
local SetCVarRaw = (C_CVar and C_CVar.SetCVar) or _G.SetCVar

function Z.GetCVar(name)
  return Z.Call(GetCVarRaw, name)
end

-- Aiming set-up values are never touched in combat. Only the two switches the
-- addon needs mid-fight (follow the aim, friendly aim) are tried there.
local MID_FIGHT = {SoftTargetForce = true, SoftTargetFriend = true}
function Z.CombatLocked(name)
  if name:find("^SoftTarget") and not MID_FIGHT[name] then
    return true
  end
  local info = C_CVar and C_CVar.GetCVarInfo
  if info then
    local ok, _, _, _, _, _, secure = pcall(info, name)
    if ok and not Z.Secret(secure) and secure then
      return true
    end
  end
  return false
end

function Z.SetCVar(name, value)
  if value == nil then
    return
  end
  if type(value) == "boolean" then
    value = value and "1" or "0"
  end
  value = tostring(value)
  local current = Z.GetCVar(name)
  if current == nil then
    return -- not on this client
  end
  if current == value then
    return
  end
  if Z.G and Z.G.cvars[name] == nil then
    Z.G.cvars[name] = current
  end
  -- the game refuses some settings during combat; those wait until it ends
  if InCombatLockdown() and Z.CombatLocked(name) then
    Z.OutOfCombat("cvar:" .. name, function()
      pcall(SetCVarRaw, name, value)
    end)
    return
  end
  pcall(SetCVarRaw, name, value)
end

-- Puts every touched setting back. Returns how many were restored.
function Z.RestoreCVars()
  local n = 0
  for name, value in pairs(Z.G.cvars) do
    if pcall(SetCVarRaw, name, value) then
      n = n + 1
    end
  end
  wipe(Z.G.cvars)
  return n
end
