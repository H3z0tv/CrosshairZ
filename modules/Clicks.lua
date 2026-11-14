-- Crosshair Z
-- Mouse Actions: while Aim Mode is on, mouse clicks (with Shift, Ctrl or
-- Alt) run your chosen actions instead of turning the camera.

local _, Z = ...
local C = Z.Module("Clicks")

-- Choices offered for each click
C.ACTIONS = {
  {"ACTIONBUTTON1", "Action Button 1"}, {"ACTIONBUTTON2", "Action Button 2"},
  {"ACTIONBUTTON3", "Action Button 3"}, {"ACTIONBUTTON4", "Action Button 4"},
  {"ACTIONBUTTON5", "Action Button 5"}, {"ACTIONBUTTON6", "Action Button 6"},
  {"ACTIONBUTTON7", "Action Button 7"}, {"ACTIONBUTTON8", "Action Button 8"},
  {"ACTIONBUTTON9", "Action Button 9"}, {"ACTIONBUTTON10", "Action Button 10"},
  {"ACTIONBUTTON11", "Action Button 11"}, {"ACTIONBUTTON12", "Action Button 12"},
  {"MULTIACTIONBAR1BUTTON1", "Bar 2 Button 1"}, {"MULTIACTIONBAR1BUTTON2", "Bar 2 Button 2"},
  {"MULTIACTIONBAR1BUTTON3", "Bar 2 Button 3"}, {"MULTIACTIONBAR1BUTTON4", "Bar 2 Button 4"},
  {"INTERACTTARGET", "Interact"}, {"TARGETNEARESTENEMY", "Target Nearest Enemy"},
  {"FOCUSTARGET", "Focus Target"}, {"CLEARTARGET", "Clear Target"}, {"JUMP", "Jump"},
  {"CAMERA", "Turn Camera (game default)"}, {"MACRO", "Run Macro (name below)"}
}

local applied = {}

local function Clear()
  for key in pairs(applied) do
    pcall(SetMouselookOverrideBinding, key, nil)
    applied[key] = nil
  end
end

function C.Update()
  if InCombatLockdown() then
    Z.OutOfCombat("clicks", C.Update)
    return
  end
  Clear()
  local p = Z.P.clicks
  if not p.enabled or not SetMouselookOverrideBinding then
    return
  end
  for _, k in ipairs(Z.CLICK_KEYS) do
    local action = p.binds[k.key]
    local command
    if action == "MACRO" then
      local name = p.macros[k.key]
      local exists = name and name ~= "" and GetMacroIndexByName and (GetMacroIndexByName(name) or 0) > 0
      if exists then
        command = "MACRO " .. name
      else
        -- no such macro here: use the plain action instead of a dead click
        command = Z.CLICK_FALLBACK[k.key]
      end
    elseif action and action ~= "CAMERA" then
      command = action
    end
    if command then
      if pcall(SetMouselookOverrideBinding, k.key, command) then
        applied[k.key] = true
      end
    end
  end
end

-- Which click runs a binding (for keybind labels on the Prompts)
function C.ClickFor(binding)
  local p = Z.P.clicks
  if not p.enabled then
    return nil
  end
  for _, k in ipairs(Z.CLICK_KEYS) do
    if p.binds[k.key] == binding then
      return k.key
    end
  end
end

Z.On("UPDATE_MACROS", function()
  if Z.P then
    C.Update()
  end
end)

function C:Apply()
  C.Update()
end

function C:Stop()
  if not InCombatLockdown() then
    Clear()
  end
end
