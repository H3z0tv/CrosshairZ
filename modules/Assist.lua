-- Crosshair Z
-- Prompts: the next spell the game suggests (Assisted Combat) beside the
-- crosshair with its key or click, and a prompt when the crosshair is on
-- something you can interact with. Both can be dragged.

local _, Z = ...
local A = Z.Module("Assist")

local TEAL = {0.3, 0.9, 0.85}
local moving = false
local dragging = false

---------------------------------------------------------------------------
-- Key text for a binding, or the mouse click that runs it in Aim Mode
---------------------------------------------------------------------------
local BAR_OFFSETS = {
  {1, "ACTIONBUTTON"}, {61, "MULTIACTIONBAR1BUTTON"}, {49, "MULTIACTIONBAR2BUTTON"},
  {25, "MULTIACTIONBAR3BUTTON"}, {37, "MULTIACTIONBAR4BUTTON"}, {145, "MULTIACTIONBAR5BUTTON"},
  {157, "MULTIACTIONBAR6BUTTON"}, {169, "MULTIACTIONBAR7BUTTON"}
}

local function BindingForSlot(slot)
  for _, b in ipairs(BAR_OFFSETS) do
    if slot >= b[1] and slot < b[1] + 12 then
      return b[2] .. (slot - b[1] + 1)
    end
  end
end

local function ShortKey(key)
  key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
  key = key:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD"):gsub("BUTTON", "M"):gsub("NUMPAD", "N")
  return key
end

-- returns text, mouse side ("l"/"r") or nil
local function KeyFor(spellID)
  if not C_ActionBar or not C_ActionBar.FindSpellActionButtons then
    return nil
  end
  local slots = Z.Call(C_ActionBar.FindSpellActionButtons, spellID)
  if type(slots) ~= "table" then
    return nil
  end
  for _, slot in ipairs(slots) do
    local binding = BindingForSlot(slot)
    if binding then
      if Z.Look.IsOn() and Z.Clicks then
        local click = Z.Clicks.ClickFor(binding)
        if click then
          local mod = click:match("^(%u+)%-") or ""
          local side = click:find("BUTTON1") and "l" or "r"
          return (mod ~= "" and (mod:sub(1, 1) .. mod:sub(2):lower()) or ""), side
        end
      end
      local key = GetBindingKey(binding)
      if key then
        return ShortKey(key)
      end
    end
  end
end

---------------------------------------------------------------------------
-- Frames
---------------------------------------------------------------------------
local function Draggable(f, xKey, yKey)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self)
    if moving then
      dragging = true
      self:StartMoving()
    end
  end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    dragging = false
    -- positions are kept in screen units from the crosshair, whatever the prompt's own size
    local scale = self:GetScale() or 1
    local cx, cy = self:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if cx and ux then
      Z.P.assist[xKey] = math.floor(cx * scale - ux + 0.5)
      Z.P.assist[yKey] = math.floor(cy * scale - uy - Z.CrosshairY() + 0.5)
      Z.Changed("assist." .. xKey)
    end
  end)
  f:SetScript("OnMouseUp", function(self)
    if dragging then
      self:GetScript("OnDragStop")(self)
    end
  end)
  f.box = f:CreateTexture(nil, "BACKGROUND")
  f.box:SetPoint("TOPLEFT", -6, 6)
  f.box:SetPoint("BOTTOMRIGHT", 6, -6)
  f.box:SetColorTexture(0.49, 1, 0.31, 0.25)
  f.box:Hide()
end

local spell = CreateFrame("Frame", "CrosshairZSuggested", UIParent)
spell:SetFrameStrata("HIGH")
spell.icon = spell:CreateTexture(nil, "ARTWORK")
spell.icon:SetAllPoints()
spell.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
spell.border = spell:CreateTexture(nil, "OVERLAY")
spell.border:SetPoint("TOPLEFT", -2, 2)
spell.border:SetPoint("BOTTOMRIGHT", 2, -2)
spell.border:SetColorTexture(0, 0, 0, 0.7)
spell.border:SetDrawLayer("BACKGROUND")
spell.key = spell:CreateFontString(nil, "OVERLAY")
spell.key:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
spell.key:SetPoint("TOPRIGHT", spell, "BOTTOMRIGHT", 0, -3)
spell.mouse = spell:CreateTexture(nil, "OVERLAY")
spell.mouse:SetSize(18, 18)
spell.mouse:SetPoint("LEFT", spell.key, "RIGHT", 0, 0)
spell:Hide()
Draggable(spell, "spellX", "spellY")

-- The interaction prompt: a moving icon for what you'll do, and the key to press
local prompt = CreateFrame("Frame", "CrosshairZPrompt", UIParent)
prompt:SetFrameStrata("HIGH")
prompt:SetSize(80, 108)
prompt.glow = prompt:CreateTexture(nil, "BACKGROUND")
prompt.glow:SetSize(90, 90)
prompt.glow:SetPoint("CENTER", prompt, "TOP", 0, -19)
prompt.glow:SetTexture(Z.MEDIA .. "glow")
prompt.glow:SetBlendMode("ADD")
prompt.glow:SetVertexColor(TEAL[1], TEAL[2], TEAL[3])
prompt.icon = prompt:CreateTexture(nil, "ARTWORK")
prompt.icon:SetSize(34, 34)
prompt.icon:SetPoint("TOP", 0, -2)
prompt.icon:SetVertexColor(TEAL[1], TEAL[2], TEAL[3])
-- a brush-stroke circle around the icon: sweeps in when the prompt appears,
-- then turns slowly and breathes
prompt.enso = prompt:CreateTexture(nil, "ARTWORK", nil, -1)
prompt.enso:SetTexture(Z.MEDIA .. "enso")
prompt.enso:SetVertexColor(TEAL[1], TEAL[2], TEAL[3])
prompt.enso:SetPoint("CENTER", prompt, "TOP", 0, -19)
prompt.appear = 0
prompt.dots = {}
for i = 1, 3 do
  local dot = prompt:CreateTexture(nil, "OVERLAY")
  dot:SetSize(9, 9)
  dot:SetTexture(Z.MEDIA .. "pip")
  dot:SetVertexColor(0.03, 0.05, 0.06)
  prompt.dots[i] = dot
end
prompt.cap = prompt:CreateTexture(nil, "ARTWORK")
prompt.cap:SetTexture(Z.MEDIA .. "keycap")
prompt.cap:SetSize(30, 30)
prompt.cap:SetPoint("TOP", prompt.icon, "BOTTOM", 0, -24)
prompt.hint = prompt:CreateFontString(nil, "OVERLAY")
prompt.hint:SetFont(STANDARD_TEXT_FONT, 13, "OUTLINE")
prompt.hint:SetPoint("CENTER", prompt.cap, "CENTER", 0, 1)
prompt.hint:SetTextColor(1, 1, 1)
prompt.name = prompt:CreateFontString(nil, "OVERLAY")
prompt.name:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
prompt.name:SetPoint("TOP", prompt.cap, "BOTTOM", 0, -3)
prompt.kind, prompt.clock = "use", 0
prompt:Hide()
Draggable(prompt, "promptX", "promptY")

-- bag hops, speech bubble types, gear turns
prompt:HookScript("OnShow", function(self)
  self.appear = 0
end)

local function Smooth(k)
  return k * k * (3 - 2 * k)
end

prompt:SetScript("OnUpdate", function(self, e)
  self.clock = self.clock + e
  local t = self.clock
  -- brush circle
  self.appear = math.min(1, (self.appear or 1) + e / 0.45)
  local k = Smooth(self.appear)
  local ring = 72 * (1.3 - 0.3 * k) * (1 + 0.025 * math.sin(GetTime() * 2.4))
  self.enso:SetSize(ring, ring)
  self.enso:SetRotation(-(1 - k) * 2.2 - GetTime() * 0.35)
  self.enso:SetAlpha(k * (0.82 + 0.12 * math.sin(GetTime() * 2.4)))
  local lift, size = 0, 34
  if self.kind == "loot" then
    local hop = (t * 1.6) % 1
    lift = hop < 0.5 and math.sin(hop * 2 * math.pi) * 5 or 0
    size = 34 + (hop < 0.5 and math.sin(hop * 2 * math.pi) * 3 or 0)
    self.icon:SetRotation(hop < 0.5 and math.sin(hop * 4 * math.pi) * 0.12 or 0)
  elseif self.kind == "talk" then
    lift = math.sin(t * 2.2) * 1.5
    self.icon:SetRotation(0)
  else
    self.icon:SetRotation(-t * 0.9)
  end
  self.icon:SetSize(size, size)
  self.icon:ClearAllPoints()
  self.icon:SetPoint("TOP", self, "TOP", 0, -2 + lift)
  for i, dot in ipairs(self.dots) do
    if self.kind == "talk" then
      local k = ((t * 1.4) - i * 0.22) % 1
      local up = k < 0.35 and math.sin(k / 0.35 * math.pi) or 0
      dot:ClearAllPoints()
      dot:SetPoint("CENTER", self.icon, "CENTER", (i - 2) * 7.5, 4 + up * 3.5)
      dot:SetAlpha(0.45 + 0.55 * up)
      dot:Show()
    else
      dot:Hide()
    end
  end
  if self.glow:IsShown() then
    self.glow:SetAlpha(0.5 + 0.3 * math.sin(t * 3))
  end
end)

local done = CreateFrame("Button", "CrosshairZMoveDone", UIParent, "UIPanelButtonTemplate")
done:SetSize(120, 26)
done:SetPoint("TOP", UIParent, "TOP", 0, -120)
done:SetText("Done Moving")
done:SetScript("OnClick", function()
  A.SetMoving(false)
end)
done:Hide()

function A.IsMoving()
  return moving
end

function A.SetMoving(on)
  moving = on
  dragging = false
  for _, f in ipairs({spell, prompt}) do
    f:StopMovingOrSizing()
    f:SetFrameStrata(on and "DIALOG" or "HIGH")
    f:EnableMouse(on)
    f.box:SetShown(on)
  end
  done:SetShown(on)
  if on then
    Z.Print("Drag the prompts, then press Done Moving.")
  end
  if Z.P then
    Z.After(0, function()
      Z.ApplyAll()
    end)
  end
end

---------------------------------------------------------------------------
-- Updating
---------------------------------------------------------------------------
local function Place()
  local p = Z.P.assist
  local y = Z.CrosshairY()
  spell:SetSize(p.spellSize, p.spellSize)
  spell:ClearAllPoints()
  spell:SetPoint("CENTER", UIParent, "CENTER", p.spellX, y + p.spellY)
  prompt:SetScale(p.promptSize)
  prompt:ClearAllPoints()
  prompt:SetPoint("CENTER", UIParent, "CENTER", p.promptX / p.promptSize, (y + p.promptY) / p.promptSize)
end

local function NextSpell()
  local ac = C_AssistedCombat
  if not ac or not ac.GetNextCastSpell then
    return nil
  end
  return Z.Call(ac.GetNextCastSpell, false)
end

local function UpdateSpell(preview)
  local p = Z.P.assist
  local id = preview and 133 or NextSpell()
  local show = moving or (p.enabled and p.spell and id and (preview or not p.spellCombat or Z.InCombat()))
  if not show then
    spell:Hide()
    return
  end
  local tex = C_Spell and C_Spell.GetSpellTexture and Z.Call(C_Spell.GetSpellTexture, id)
  spell.icon:SetTexture(tex or 134400)
  local text, side
  if p.keybind then
    if preview then
      text, side = "", "l"
    else
      text, side = KeyFor(id)
    end
  end
  spell.key:SetText(text or "")
  if side then
    spell.mouse:SetTexture(Z.MEDIA .. "mouse_" .. side)
    spell.mouse:Show()
  else
    spell.mouse:Hide()
  end
  spell:SetAlpha(p.opacity)
  spell:Show()
end

local function InteractKey()
  local key = GetBindingKey("INTERACTTARGET") or GetBindingKey("INTERACTMOUSEOVER")
  return key and ShortKey(key) or nil
end

local ICONS = {loot = "icon_bag", talk = "icon_bubble", use = "icon_use"}

local function UpdatePrompt(preview)
  local p = Z.P.assist
  if not moving and (not p.enabled or not p.prompt) then
    prompt:Hide()
    return
  end
  local unit = "softinteract"
  if not (preview or Z.Truthy(UnitExists, unit)) then
    prompt:Hide()
    return
  end
  local kind = "talk"
  local name = "Sample NPC"
  if not preview then
    kind = "use"
    if Z.Call(UnitIsDead, unit) then
      kind = "loot"
    elseif not (UnitIsGameObject and Z.Call(UnitIsGameObject, unit)) and not Z.Call(UnitIsPlayer, unit) then
      kind = "talk"
    end
    name = nil
  elseif not moving then
    -- the settings preview walks through all three
    kind = ({"talk", "loot", "use"})[math.floor(GetTime() / 2.5) % 3 + 1]
  end
  if kind ~= prompt.kind then
    prompt.kind = kind
    prompt.clock = 0
    prompt.appear = 0
  end
  prompt.icon:SetTexture(Z.MEDIA .. ICONS[kind])
  -- just the key, on a key cap
  local key = InteractKey() or "?"
  prompt.hint:SetText(key)
  prompt.cap:SetWidth(math.max(30, 16 + #key * 9))
  if p.promptName then
    if name then
      prompt.name:SetText(name)
    elseif not pcall(prompt.name.SetText, prompt.name, UnitName(unit)) then
      prompt.name:SetText("")
    end
    prompt.name:Show()
  else
    prompt.name:Hide()
  end
  prompt.glow:SetShown(p.promptGlow)
  prompt:SetAlpha(p.opacity)
  prompt:Show()
end

local function Update()
  if not Z.P then
    return
  end
  local preview = (Z.Panel and Z.Panel.IsOpen()) or moving
  if dragging then
    return -- never pull a prompt out of the player's hand
  end
  Place()
  UpdateSpell(preview)
  UpdatePrompt(preview)
end

function A.Test()
  Z.Panel.Hide()
  A.SetMoving(true)
  Z.After(5, function()
    if moving then
      A.SetMoving(false)
    end
  end)
end

function A:Setup()
  Z.Every(0.12, Update)
end

function A:Apply()
  Update()
end

function A:Stop()
  spell:Hide()
  prompt:Hide()
end
