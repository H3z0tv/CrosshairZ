-- Crosshair Z
-- Core: shared namespace, event and message hub, timers, safe API calls, printing.

local ADDON, Z = ...
_G.CrosshairZ = Z

-- Libraries: AceAddon (start-up), AceEvent (game events and our own messages),
-- AceConsole (slash commands) and AceDB (saved settings and profiles, in Data.lua).
local Ace = LibStub("AceAddon-3.0"):NewAddon("CrosshairZ", "AceEvent-3.0", "AceConsole-3.0")
Z.ace = Ace

Z.name = ADDON
Z.modules = {}
Z.version = "1.0.0"

local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
if GetMeta then
  local ok, v = pcall(GetMeta, ADDON, "Version")
  if ok and type(v) == "string" and v ~= "" then
    Z.version = v
  end
end

Z.isRetail = (_G.WOW_PROJECT_ID == nil) or (_G.WOW_PROJECT_ID == _G.WOW_PROJECT_MAINLINE)
local build = select(4, GetBuildInfo())
Z.build = build or 0

Z.MEDIA = "Interface\\AddOns\\" .. ADDON .. "\\media\\"
Z.GREEN = "|cff7CFF4F"

---------------------------------------------------------------------------
-- Secret values (Midnight): anything we cannot read is treated as unknown
---------------------------------------------------------------------------
local issecretvalue = _G.issecretvalue

function Z.Secret(v)
  return issecretvalue ~= nil and issecretvalue(v) or false
end

-- Calls an API and returns its first values, or nil if it failed or the
-- first value is a secret.
function Z.Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b, c, d, e = pcall(fn, ...)
  if not ok or Z.Secret(a) then
    return nil
  end
  return a, b, c, d, e
end

-- Like Z.Call but each returned value is checked
function Z.CallAll(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local res = {pcall(fn, ...)}
  if not res[1] then
    return nil
  end
  for i = 2, #res do
    if Z.Secret(res[i]) then
      res[i] = nil
    end
  end
  return unpack(res, 2, 6)
end

function Z.Truthy(fn, ...)
  local v = Z.Call(fn, ...)
  return v and true or false
end

-- The settings window or prompt moving is up: show the crosshair and HUD as a preview
function Z.Previewing()
  return (Z.Panel and Z.Panel.IsOpen()) or (Z.Assist and Z.Assist.IsMoving and Z.Assist.IsMoving()) or false
end

function Z.InCombat()
  if InCombatLockdown() then
    return true
  end
  return Z.Truthy(UnitAffectingCombat, "player")
end

---------------------------------------------------------------------------
-- Printing
---------------------------------------------------------------------------
function Z.Print(msg, ...)
  if select("#", ...) > 0 then
    msg = msg:format(...)
  end
  print(Z.GREEN .. "Crosshair Z|r: " .. tostring(msg))
end

function Z.Debug(msg, ...)
  if Z.G and Z.G.debug then
    Z.Print("|cff909090" .. tostring(msg):format(...) .. "|r")
  end
end

---------------------------------------------------------------------------
-- Events: AceEvent delivers them, any number of handlers per event
---------------------------------------------------------------------------
local hub = CreateFrame("Frame", "CrosshairZHub")
Z.hub = hub
local handlers = {}

local function Dispatch(event, ...)
  local list = handlers[event]
  if not list then
    return
  end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then
      Z.Debug("%s: %s", event, tostring(err))
    end
  end
end

function Z.On(event, fn)
  local list = handlers[event]
  if not list then
    list = {}
    handlers[event] = list
    if not pcall(Ace.RegisterEvent, Ace, event, Dispatch) then
      Z.Debug("Event not available: %s", event)
    end
  end
  list[#list + 1] = fn
end

function Z.OnUnit(event, units, fn)
  local set = {}
  for _, u in ipairs(units) do
    set[u] = true
  end
  Z.On(event, function(ev, unit, ...)
    if not Z.Secret(unit) and set[unit] then
      fn(ev, unit, ...)
    end
  end)
end

---------------------------------------------------------------------------
-- Messages between our own modules (AceEvent messages)
---------------------------------------------------------------------------
local listeners = {}
local PREFIX = "CrosshairZ_"

local function Deliver(message, ...)
  local list = listeners[message]
  if not list then
    return
  end
  for i = 1, #list do
    local ok, err = pcall(list[i], ...)
    if not ok then
      Z.Debug("%s: %s", message, tostring(err))
    end
  end
end

function Z.Listen(msg, fn)
  local name = PREFIX .. msg
  if not listeners[name] then
    listeners[name] = {}
    Ace:RegisterMessage(name, Deliver)
  end
  table.insert(listeners[name], fn)
end

function Z.Send(msg, ...)
  Ace:SendMessage(PREFIX .. msg, ...)
end

---------------------------------------------------------------------------
-- Tickers: one OnUpdate drives every repeating job
---------------------------------------------------------------------------
local tickers = {}

function Z.Every(seconds, fn)
  local t = {every = seconds, left = 0, fn = fn}
  tickers[#tickers + 1] = t
  return t
end

hub:SetScript("OnUpdate", function(_, elapsed)
  for i = 1, #tickers do
    local t = tickers[i]
    if not t.paused then
      t.left = t.left - elapsed
      if t.left <= 0 then
        t.left = t.every
        local ok, err = pcall(t.fn, elapsed)
        if not ok then
          Z.Debug("ticker: %s", tostring(err))
        end
      end
    end
  end
end)

function Z.After(seconds, fn)
  if C_Timer and C_Timer.After then
    C_Timer.After(seconds, fn)
  else
    local waited = 0
    local f = CreateFrame("Frame")
    f:SetScript("OnUpdate", function(self, e)
      waited = waited + e
      if waited >= seconds then
        self:SetScript("OnUpdate", nil)
        fn()
      end
    end)
  end
end

-- Runs fn now, or right after combat if we're locked down
local afterCombat = {}
function Z.OutOfCombat(key, fn)
  if InCombatLockdown() then
    afterCombat[key] = fn
    return false
  end
  fn()
  return true
end
Z.On("PLAYER_REGEN_ENABLED", function()
  for key, fn in pairs(afterCombat) do
    afterCombat[key] = nil
    pcall(fn)
  end
end)

---------------------------------------------------------------------------
-- Modules
---------------------------------------------------------------------------
-- A module is a table with optional Setup() (once, after saved data loads),
-- Apply() (every time settings change) and Stop() (on undo).
function Z.Module(name)
  local m = {name = name}
  Z.modules[#Z.modules + 1] = m
  Z[name] = m
  return m
end

function Z.ApplyAll()
  for _, m in ipairs(Z.modules) do
    if m.Apply then
      local ok, err = pcall(m.Apply, m)
      if not ok then
        Z.Debug("%s.Apply: %s", m.name, tostring(err))
      end
    end
  end
  Z.Send("APPLIED")
end

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
function Z.Clamp(v, lo, hi)
  if v < lo then
    return lo
  elseif v > hi then
    return hi
  end
  return v
end

function Z.Lerp(a, b, t)
  return a + (b - a) * t
end

function Z.CharKey()
  local name = UnitName("player") or "Unknown"
  local realm = GetRealmName and GetRealmName() or "Realm"
  return name .. " - " .. realm
end

function Z.ClassColor()
  local _, class = UnitClass("player")
  local c = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
  if c then
    return c.r, c.g, c.b
  end
  return 1, 1, 1
end
