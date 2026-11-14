-- Crosshair Z
-- Start-up, key binding names, slash commands and Undo.

local ADDON, Z = ...

_G.BINDING_HEADER_CROSSHAIRZ = "Crosshair Z"
_G.BINDING_NAME_CROSSHAIRZ_LOOK = "Aim Mode - Toggle"
_G.BINDING_NAME_CROSSHAIRZ_HOLD = "Aim Mode - Hold To Free Cursor"
_G.BINDING_NAME_CROSSHAIRZ_LOCK = "Target Hold"
_G.BINDING_NAME_CROSSHAIRZ_FLIP = "Flip Camera Shoulder"
_G["BINDING_NAME_CLICK CrosshairZNextEnemy:LeftButton"] = "Hold Cycle - Next Enemy"
_G["BINDING_NAME_CLICK CrosshairZPrevEnemy:LeftButton"] = "Hold Cycle - Previous Enemy"

local started = false

local function Start()
  if started then
    return
  end
  started = true
  for _, m in ipairs(Z.modules) do
    if m.Setup then
      local ok, err = pcall(m.Setup, m)
      if not ok then
        Z.Print("|cffff5050%s failed to start: %s|r", m.name, tostring(err))
      end
    end
  end
  Z.ApplyAll()
  Z.Send("READY")
end

function Z.ace:OnInitialize()
  Z.LoadData()
end

function Z.ace:OnEnable()
  Start()
end

Z.On("PLAYER_ENTERING_WORLD", function()
  Z.After(1, Z.ApplyAll)
end)

---------------------------------------------------------------------------
-- Undo: put back the player's game settings and turn the addon off
---------------------------------------------------------------------------
function Z.Undo()
  if InCombatLockdown() then
    Z.Print("Can't undo in combat.")
    return
  end
  for _, m in ipairs(Z.modules) do
    if m.Stop then
      pcall(m.Stop, m)
    end
  end
  local n = Z.RestoreCVars()
  Z.Print("Put back %d game settings to what you had before Crosshair Z.", n)
  local disable = (C_AddOns and C_AddOns.DisableAddOn) or _G.DisableAddOn
  if disable then
    pcall(disable, ADDON)
  end
  _G.ReloadUI()
end

---------------------------------------------------------------------------
-- Slash commands
---------------------------------------------------------------------------
local function Command(input)
  input = (input or ""):lower():match("^%s*(.-)%s*$")
  if input == "wizard" then
    if Z.Wizard then
      Z.Wizard.Open()
    end
  elseif input == "move" then
    if Z.Assist then
      Z.Assist.SetMoving(true)
    end
  elseif input == "undo" then
    Z.Panel.Confirm("Put back your game settings and turn Crosshair Z off? The UI will reload.", Z.Undo)
  elseif Z.slashExtra and Z.slashExtra[input] then
    Z.slashExtra[input]()
  elseif input == "status" then
    Z.Look.Status()
  elseif input == "debug" then
    Z.G.debug = not Z.G.debug
    Z.Print("Debug %s.", Z.G.debug and "on" or "off")
  else
    if InCombatLockdown() then
      Z.Print("Settings can't open in combat.")
      return
    end
    Z.Panel.Toggle(input ~= "" and input or nil)
  end
end

Z.ace:RegisterChatCommand("cz", Command)
Z.ace:RegisterChatCommand("crosshairz", Command)
Z.ace:RegisterChatCommand("czundo", function()
  Z.Undo()
end)
