-- Crosshair Z
-- Macro Builder: a cast macro aimed where you want, saved in one click.

local _, Z = ...
local M = Z.Module("Composer")

M.TARGETS = {
  crosshair = "Crosshair target",
  mouseover = "Mouseover",
  cursor = "Cursor (ground spells)",
  focus = "Focus",
  player = "Yourself"
}

local CONDITIONS = {
  crosshair = "[@softenemy,exists,nodead][@mouseover,harm,nodead][]",
  mouseover = "[@mouseover,exists,nodead][]",
  cursor = "[@cursor]",
  focus = "[@focus,exists,nodead][]",
  player = "[@player]"
}

function M.Text()
  local p = Z.P.composer
  local spell = (p.spell or ""):match("^%s*(.-)%s*$")
  if spell == "" then
    return "#showtooltip\n/cast " .. CONDITIONS[p.target] .. " <spell name>"
  end
  return "#showtooltip\n/cast " .. (CONDITIONS[p.target] or "") .. " " .. spell
end

function M.Save()
  if InCombatLockdown() then
    Z.Print("Macros can't be saved in combat.")
    return
  end
  local p = Z.P.composer
  if (p.spell or ""):match("^%s*$") then
    Z.Print("Type a spell name first.")
    return
  end
  local name = (p.name or ""):sub(1, 16)
  if name == "" then
    name = "CZ Cast"
  end
  local body = M.Text()
  local index = GetMacroIndexByName(name)
  if index and index > 0 then
    EditMacro(index, name, nil, body)
    Z.Print("Updated macro %s.", name)
  else
    local ok, err = pcall(CreateMacro, name, "INV_MISC_QUESTIONMARK", body, nil)
    if ok then
      Z.Print("Saved macro %s to your account macros.", name)
    else
      Z.Print("Couldn't save the macro (your macro list may be full).")
    end
  end
end
