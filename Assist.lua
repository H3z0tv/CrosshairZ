---------------------------------------------------------------------------------------
--                                    ASSIST HUD                                     --
---------------------------------------------------------------------------------------
-- Next suggested cast (from the game's Assisted Combat) and interaction prompts, shown
-- next to the crosshair. Settings come from the active profile (CZ.P).
local _G = _G
local CZ = _G.LibStub("AceAddon-3.0"):GetAddon("CrosshairZ")

local CreateFrame = _G.CreateFrame
local GetTime = _G.GetTime
local UIParent = _G.UIParent
local pcall = _G.pcall
local type = _G.type
local ipairs = _G.ipairs
local math_min = _G.math.min

local A = {}
CZ.Assist = A

local TEX = "Interface\\AddOns\\CrosshairZ\\assets\\hud\\"
local FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

local issecret = _G.issecretvalue or function()
  return false
end

local function Call(fn, ...)
  if type(fn) ~= "function" then
    return nil
  end
  local ok, a, b = pcall(fn, ...)
  if not ok then
    return nil
  end
  return a, b
end

local function Readable(v)
  return v ~= nil and not issecret(v)
end

local function Bool(fn, ...)
  local v = Call(fn, ...)
  if issecret(v) then
    return nil
  end
  return v and true or false
end

local function InCombat()
  return _G.InCombatLockdown() or Bool(_G.UnitAffectingCombat, "player") == true
end

local function Accent()
  return 0.486, 1, 0.31
end

---------------------------------------------------------------------------------------
--                                     KEYBINDS                                      --
---------------------------------------------------------------------------------------
-- Action slot ranges and the binding that presses them
local SLOT_BINDINGS = {
  {1, 12, "ACTIONBUTTON"},
  {25, 36, "MULTIACTIONBAR3BUTTON"},
  {37, 48, "MULTIACTIONBAR4BUTTON"},
  {49, 60, "MULTIACTIONBAR2BUTTON"},
  {61, 72, "MULTIACTIONBAR1BUTTON"},
  {73, 132, "ACTIONBUTTON"}, -- stance / form / bonus bars replace the main bar
  {145, 156, "MULTIACTIONBAR5BUTTON"},
  {157, 168, "MULTIACTIONBAR6BUTTON"},
  {169, 180, "MULTIACTIONBAR7BUTTON"}
}

local function BindingForSlot(slot)
  for _, range in ipairs(SLOT_BINDINGS) do
    if slot >= range[1] and slot <= range[2] then
      return range[3] .. ((slot - range[1]) % 12 + 1)
    end
  end
  return nil
end

local MOUSE_LABELS = {BUTTON1 = "LMB", BUTTON2 = "RMB", BUTTON3 = "MMB", BUTTON4 = "M4", BUTTON5 = "M5"}

local function ShortKey(key)
  if not key or key == "" then
    return nil
  end
  local mods, base = key:match("^(.-)([^%-]+)$")
  base = MOUSE_LABELS[base] or base
  mods = (mods or ""):gsub("SHIFT%-", "S-"):gsub("CTRL%-", "C-"):gsub("ALT%-", "A-"):gsub("META%-", "M-")
  local text = mods .. base
  if not MOUSE_LABELS[key:match("([^%-]+)$") or ""] and _G.GetBindingText then
    local ok, abbreviated = pcall(_G.GetBindingText, key, true)
    if ok and type(abbreviated) == "string" and abbreviated ~= "" then
      text = abbreviated
    end
  end
  return text
end

-- While Free Look is on, a binding may also be on a mouse click (Click Casting)
local function ClickForBinding(binding)
  if not (CZ.DB and _G.IsMouselooking and _G.IsMouselooking()) then
    return nil
  end
  local location = CZ.GetBindingsLocation and CZ.GetBindingsLocation()
  local bindings = location and CZ.DB[location] and CZ.DB[location].bindings
  if not bindings then
    return nil
  end
  for _, button in ipairs(CZ.Constants.ButtonsToOverride) do
    local b = bindings[button]
    if b and b.enabled and b.value == binding then
      return b.key
    end
  end
  return nil
end

local function KeyForSpell(spellID)
  local C_ActionBar = _G.C_ActionBar
  if not (C_ActionBar and C_ActionBar.FindSpellActionButtons) then
    return nil
  end
  local slots = Call(C_ActionBar.FindSpellActionButtons, spellID)
  if type(slots) ~= "table" then
    return nil
  end
  for _, slot in ipairs(slots) do
    if Readable(slot) then
      local binding = BindingForSlot(slot)
      if binding then
        local click = ClickForBinding(binding)
        if click then
          return ShortKey(click)
        end
        local key = Call(_G.GetBindingKey, binding)
        if Readable(key) and key then
          return ShortKey(key)
        end
      end
    end
  end
  return nil
end

---------------------------------------------------------------------------------------
--                                      FRAMES                                       --
---------------------------------------------------------------------------------------
local root = CreateFrame("Frame", "CrosshairZAssist", UIParent)
root:SetSize(1, 1)
root:SetPoint("CENTER")
root:SetFrameStrata("MEDIUM")

local function KeyCap(parent)
  local cap = CreateFrame("Frame", nil, parent)
  cap:SetSize(18, 18)
  cap.bg = cap:CreateTexture(nil, "ARTWORK")
  cap.bg:SetTexture(TEX .. "keycap")
  cap.bg:SetAllPoints()
  cap.text = cap:CreateFontString(nil, "OVERLAY")
  cap.text:SetFont(FONT, 10, "OUTLINE")
  cap.text:SetPoint("CENTER", 0, 0)
  function cap.SetKey(key)
    if not key then
      cap:Hide()
      return
    end
    cap.text:SetText(key)
    local w = math.max(18, cap.text:GetStringWidth() + 10)
    cap:SetWidth(w)
    cap:Show()
  end
  return cap
end

-- Suggested cast
local spell = CreateFrame("Frame", nil, root)
spell:SetSize(36, 36)
spell.icon = spell:CreateTexture(nil, "ARTWORK")
spell.icon:SetPoint("TOPLEFT", 2, -2)
spell.icon:SetPoint("BOTTOMRIGHT", -2, 2)
spell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
spell.frame = spell:CreateTexture(nil, "OVERLAY")
spell.frame:SetTexture(TEX .. "iconframe")
spell.frame:SetAllPoints()
spell.key = KeyCap(spell)
spell.key:SetPoint("CENTER", spell, "TOPRIGHT", -2, -2)
spell:Hide()
spell.alpha = 0

-- Interaction prompt
local prompt = CreateFrame("Frame", nil, root)
prompt:SetSize(28, 28)
-- the icon alone (no ring, no background)
prompt.icon = prompt:CreateTexture(nil, "ARTWORK")
prompt.icon:SetPoint("CENTER")
prompt.key = KeyCap(prompt)
prompt.key:SetPoint("CENTER", prompt, "TOPRIGHT", -2, -2)
prompt.name = prompt:CreateFontString(nil, "OVERLAY")
prompt.name:SetFont(FONT, 12, "OUTLINE")
prompt.name:SetPoint("LEFT", prompt, "RIGHT", 8, 0)
prompt.name:SetTextColor(1, 0.92, 0.75)
prompt.hint = prompt:CreateFontString(nil, "OVERLAY")
prompt.hint:SetFont(FONT, 10, "OUTLINE")
prompt.hint:SetPoint("TOPLEFT", prompt.name, "BOTTOMLEFT", 0, -3)
prompt.hint:SetTextColor(0.8, 0.82, 0.86)
prompt.glow = prompt:CreateTexture(nil, "BACKGROUND", nil, -1)
prompt.glow:SetTexture(TEX .. "bloom")
prompt.glow:SetBlendMode("ADD")
prompt.glow:SetPoint("CENTER")
prompt:Hide()
prompt.alpha = 0

---------------------------------------------------------------------------------------
--                                   MOVE (UNLOCK)                                   --
---------------------------------------------------------------------------------------
-- Drag the suggested-cast icon and the interaction prompt where you want them.
local unlocked = false
local dragging = nil

local function MoverHighlight(f)
  f.moverBg = f:CreateTexture(nil, "BACKGROUND", nil, -2)
  f.moverBg:SetPoint("TOPLEFT", -6, 6)
  f.moverBg:SetPoint("BOTTOMRIGHT", 6, -6)
  f.moverBg:SetColorTexture(0.486, 1, 0.31, 0.22)
  f.moverBg:Hide()
end
MoverHighlight(spell)
MoverHighlight(prompt)

local function SaveOffset(f, keyX, keyY)
  local fx, fy = f:GetCenter()
  local rx, ry = root:GetCenter()
  if fx and rx and CZ.P then
    CZ.P[keyX] = math.floor(fx - rx + 0.5)
    CZ.P[keyY] = math.floor(fy - ry + 0.5)
    CZ.Profiles.Changed()
  end
end

local function MakeDraggable(f, keyX, keyY)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    dragging = self
    self:StartMoving()
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveOffset(self, keyX, keyY)
    dragging = nil
  end)
end
MakeDraggable(spell, "assistSpellX", "assistSpellY")
MakeDraggable(prompt, "assistInteractX", "assistInteractY")

-- small bar at the top of the screen while moving
local mover = CreateFrame("Frame", "CrosshairZAssistMover", UIParent)
mover:SetSize(360, 64)
mover:SetPoint("TOP", 0, -120)
mover:SetFrameStrata("DIALOG")
mover:EnableMouse(true)
local moverBg = mover:CreateTexture(nil, "BACKGROUND")
moverBg:SetAllPoints()
moverBg:SetColorTexture(0.06, 0.07, 0.09, 0.95)
local moverText = mover:CreateFontString(nil, "OVERLAY")
moverText:SetFont(FONT, 12, "")
moverText:SetPoint("TOP", 0, -10)
moverText:SetText("Drag the Assist HUD prompts. Press Done when finished.")
local done = CreateFrame("Button", nil, mover, "UIPanelButtonTemplate")
done:SetSize(100, 22)
done:SetPoint("BOTTOMRIGHT", -10, 8)
done:SetText("Done")
local reset = CreateFrame("Button", nil, mover, "UIPanelButtonTemplate")
reset:SetSize(130, 22)
reset:SetPoint("BOTTOMLEFT", 10, 8)
reset:SetText("Reset Positions")
mover:Hide()

function A.SetUnlocked(on)
  if on and _G.InCombatLockdown() then
    print(CZ.Constants.BasePrintMsg .. "|cff909090: can't move the prompts in combat.|r")
    return
  end
  unlocked = on and true or false
  for _, f in ipairs({spell, prompt}) do
    f:EnableMouse(unlocked)
    f.moverBg:SetShown(unlocked)
  end
  mover:SetShown(unlocked)
  if unlocked and CZ.UI and CZ.UI.Hide then
    CZ.UI.Hide()
  end
end

function A.IsUnlocked()
  return unlocked
end

done:SetScript("OnClick", function()
  A.SetUnlocked(false)
end)
reset:SetScript("OnClick", function()
  local d = CZ.FeatureDefaults
  for _, key in ipairs({"assistSpellX", "assistSpellY", "assistInteractX", "assistInteractY"}) do
    CZ.P[key] = d[key]
  end
  CZ.Profiles.Changed()
end)
mover:RegisterEvent("PLAYER_REGEN_DISABLED")
mover:SetScript("OnEvent", function()
  if unlocked then
    A.SetUnlocked(false)
  end
end)

-- Shows the interact target's name above it (game setting), restored when turned off
local nameplateSaved
local function ApplyInteractNameplate(want)
  local getter = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  local setter = _G.C_CVar and _G.C_CVar.SetCVar or _G.SetCVar
  if want then
    if nameplateSaved == nil then
      nameplateSaved = Call(getter, "SoftTargetNameplateInteract") or "0"
    end
    if Call(getter, "SoftTargetNameplateInteract") ~= "1" then
      pcall(setter, "SoftTargetNameplateInteract", 1)
    end
  elseif nameplateSaved ~= nil then
    pcall(setter, "SoftTargetNameplateInteract", nameplateSaved)
    nameplateSaved = nil
  end
end

---------------------------------------------------------------------------------------
--                                      UPDATE                                       --
---------------------------------------------------------------------------------------
local testUntil = 0
local TEST_ICON = 136243 -- generic spell icon

function A.Test()
  testUntil = GetTime() + 5
end

local function NextSuggestedSpell()
  local AC = _G.C_AssistedCombat
  if not (AC and AC.GetNextCastSpell) then
    return nil
  end
  local id = Call(AC.GetNextCastSpell, false)
  if Readable(id) and type(id) == "number" and id > 0 then
    return id
  end
  return nil
end

local function SpellIcon(id)
  local C_Spell = _G.C_Spell
  local tex = C_Spell and C_Spell.GetSpellTexture and Call(C_Spell.GetSpellTexture, id)
  if Readable(tex) then
    return tex
  end
  return nil
end

local function Fade(f, want, elapsed, maxAlpha)
  local target = want and maxAlpha or 0
  f.alpha = f.alpha + (target - f.alpha) * math_min(1, elapsed * 10)
  if f.alpha < 0.02 and target == 0 then
    f.alpha = 0
    f:Hide()
    return
  end
  f:SetAlpha(f.alpha)
  f:Show()
end

-- Crosshair Z's own prompt icons (game cursor files differ between clients)
local INTERACT_ICON_NPC = TEX .. "icon_talk"
local INTERACT_ICON_OBJECT = TEX .. "icon_use"
local INTERACT_ICON_LOOT = TEX .. "icon_loot"

-- What kind of interaction the soft-interact target offers: "loot", "talk" or "use"
local function InteractKind(unit, exists)
  if not exists then
    return "talk"
  end
  if Bool(_G.UnitIsGameObject, unit) then
    return "use"
  end
  if Bool(_G.UnitIsDead, unit) then
    -- a dead creature you can interact with is a corpse to loot (or skin)
    local guid = Call(_G.UnitGUID, unit)
    if Readable(guid) and _G.CanLootUnit then
      local hasLoot = Call(_G.CanLootUnit, guid)
      if Readable(hasLoot) and hasLoot == false then
        return "use"
      end
    end
    return "loot"
  end
  return "talk"
end

local KIND_ICON = {loot = INTERACT_ICON_LOOT, talk = INTERACT_ICON_NPC, use = INTERACT_ICON_OBJECT}
local KIND_VERB = {loot = "to loot", talk = "to talk", use = "to interact"}

local lastSpell, lastSpellKeyCheck = nil, 0

local function Update(elapsed)
  local P = CZ.P
  if not P then
    return
  end
  ApplyInteractNameplate(P.assistEnabled and P.assistInteract and P.assistInteractNameplate)
  local testing = GetTime() < testUntil or unlocked or (CZ.IsLiveEditing and CZ.IsLiveEditing())
  local inCombat = InCombat()
  local crosshairShown = CZ.CrosshairTexture and CZ.CrosshairTexture:IsShown() and CZ.DB.global.crosshair
  local enabled = (P.assistEnabled and crosshairShown) or testing
  local opacity = (P.assistOpacity or 1) * (testing and 1 or (CZ.crosshairAlphaMult or 1))

  -- position next to the crosshair
  local y = CZ.GetCrosshairY and CZ.GetCrosshairY() or 0
  root:ClearAllPoints()
  root:SetPoint("CENTER", UIParent, "CENTER", 0, y)

  -- Suggested cast
  local spellID = enabled and P.assistSpell and (not P.assistSpellOnlyCombat or inCombat or testing) and
                    NextSuggestedSpell()
  if testing and not spellID then
    spellID = -1
  end
  if spellID then
    local size = P.assistSpellSize or 36
    spell:SetSize(size, size)
    if dragging ~= spell then
      spell:ClearAllPoints()
      spell:SetPoint("CENTER", root, "CENTER", P.assistSpellX or 0, P.assistSpellY or -60)
    end
    if spellID ~= lastSpell then
      lastSpell = spellID
      spell.icon:SetTexture(spellID == -1 and TEST_ICON or SpellIcon(spellID) or TEST_ICON)
      lastSpellKeyCheck = 0
    end
    lastSpellKeyCheck = lastSpellKeyCheck - elapsed
    if lastSpellKeyCheck <= 0 then
      lastSpellKeyCheck = 0.5
      spell.key.SetKey(P.assistKeybind and (spellID == -1 and "1" or KeyForSpell(spellID)) or nil)
    end
    spell.frame:SetVertexColor(Accent())
    -- grey out when the spell can't be cast right now (if the game tells us)
    local usable
    if spellID ~= -1 and _G.C_Spell then
      usable = Call(_G.C_Spell.IsSpellUsable, spellID)
    end
    spell.icon:SetDesaturated(Readable(usable) and usable == false)
  end
  Fade(spell, spellID and true or false, elapsed, opacity)

  -- Interaction prompt
  local showPrompt = false
  if enabled and P.assistInteract and (not P.assistInteractHideCombat or not inCombat or testing) then
    local unit = "softinteract"
    local exists = Bool(_G.UnitExists, unit)
    if exists or testing then
      showPrompt = true
      local size = P.assistInteractSize or 28
      prompt:SetSize(size, size)
      prompt.icon:SetSize(size, size)
      if dragging ~= prompt then
        prompt:ClearAllPoints()
        prompt:SetPoint("CENTER", root, "CENTER", P.assistInteractX or 70, P.assistInteractY or 0)
      end

      local kind = InteractKind(unit, exists)
      prompt.icon:SetTexture(KIND_ICON[kind])

      local key = Call(_G.GetBindingKey, "INTERACTTARGET")
      local keyText = (Readable(key) and key and ShortKey(key)) or (testing and "F") or nil
      prompt.key.SetKey(P.assistKeybind and keyText or nil)

      -- "Press F to interact" under the name
      if P.assistInteractHint and keyText then
        prompt.hint:SetText("Press |cff7CFF4F" .. keyText .. "|r " .. KIND_VERB[kind])
        prompt.hint:Show()
      else
        prompt.hint:Hide()
      end

      -- pulsing glow around the badge
      if P.assistInteractGlow then
        local pulse = 0.55 + 0.35 * math.sin(GetTime() * 4)
        prompt.glow:SetSize(size * 2.6, size * 2.6)
        prompt.glow:SetVertexColor(0.486, 1, 0.31, 1)
        prompt.glow:SetAlpha(pulse)
        prompt.glow:Show()
      else
        prompt.glow:Hide()
      end

      if P.assistInteractName then
        local name = exists and Call(_G.UnitName, unit) or (testing and "Silvermoon Guard") or ""
        -- names can be secret in some places; FontStrings can still display them
        pcall(prompt.name.SetText, prompt.name, name)
        prompt.name:Show()
      else
        prompt.name:Hide()
      end
    end
  end
  Fade(prompt, showPrompt, elapsed, opacity)
end

local driver = CreateFrame("Frame")
local since = 0

function A.Enable()
  driver:SetScript("OnUpdate", function(_, elapsed)
    since = since + elapsed
    if since < 0.05 then
      return
    end
    local step = since
    since = 0
    local ok, err = pcall(Update, step)
    if not ok then
      CZ.DebugPrint("Assist HUD error: " .. tostring(err))
    end
  end)
end

function A.Disable()
  driver:SetScript("OnUpdate", nil)
  spell:Hide()
  prompt:Hide()
end

-- True when this client offers the next-cast suggestion
function A.HasSuggestions()
  local AC = _G.C_AssistedCombat
  return AC ~= nil and AC.GetNextCastSpell ~= nil
end
