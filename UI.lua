---------------------------------------------------------------------------------------
--                                  SETTINGS WINDOW                                  --
---------------------------------------------------------------------------------------
-- Standalone True Reticle settings window: sidebar navigation, Home page, Patch Notes
-- and option pages rendered from the option tables defined in Config.lua.
local _G = _G
local TR = _G.LibStub("AceAddon-3.0"):GetAddon("TrueReticle")

local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local tostring = _G.tostring
local type = _G.type
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local table_sort = _G.table.sort
local table_insert = _G.table.insert
local table_remove = _G.table.remove

local UI = {}
TR.UI = UI

---------------------------------------------------------------------------------------
--                                    LOOK & FEEL                                    --
---------------------------------------------------------------------------------------
local FONT = _G.STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
local FRAME_NAME = "TrueReticleOptionsFrame"

local WIN_W, WIN_H = 920, 690
local SIDEBAR_W = 210
local TOPBAR_H = 34
local FOOTER_H = 40
local MARGIN = 12
local GAP = 8
local ROW_CAPACITY = 3.8 -- option "width" units that fit on one row

local C = {
  window = {0.06, 0.07, 0.09, 0.97},
  sidebar = {0.09, 0.10, 0.12, 1},
  panel = {0.10, 0.11, 0.13, 1},
  header = {0.08, 0.09, 0.11, 1},
  card = {0.13, 0.14, 0.17, 1},
  row = {0.16, 0.17, 0.20, 1},
  input = {0.07, 0.08, 0.10, 1},
  border = {0.24, 0.26, 0.30, 1},
  text = {0.92, 0.92, 0.92},
  muted = {0.60, 0.62, 0.66},
  off = {0.30, 0.32, 0.36, 1}
}

local THEMES = {
  {key = "Green", r = 0.486, g = 1.0, b = 0.310},
  {key = "Satin Gold", r = 0.851, g = 0.722, b = 0.451},
  {key = "Ice Blue", r = 0.384, g = 0.761, b = 1.0},
  {key = "Crimson", r = 0.898, g = 0.169, b = 0.314}
}
local THEME_BY_KEY = {}
for _, theme in ipairs(THEMES) do
  THEME_BY_KEY[theme.key] = theme
end

local function Accent()
  local key = TR.DB and TR.DB.global.uiTheme
  local theme = THEME_BY_KEY[key] or THEMES[1]
  return theme.r, theme.g, theme.b
end

local function AccentHex()
  local r, g, b = Accent()
  return string.format("|cff%02x%02x%02x", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5),
    math.floor(b * 255 + 0.5))
end

-- Everything painted in the accent color is registered here so a theme change can repaint it
local accentTextures, accentTexts = {}, {}

local function AccentTex(tex, alpha)
  accentTextures[#accentTextures + 1] = {tex, alpha or 1}
  local r, g, b = Accent()
  tex:SetColorTexture(r, g, b, alpha or 1)
end

local function AccentText(fs)
  accentTexts[#accentTexts + 1] = fs
  fs:SetTextColor(Accent())
end

---------------------------------------------------------------------------------------
--                                   BASIC BUILDERS                                  --
---------------------------------------------------------------------------------------
-- Calls a widget method only if this client has it (keeps the window working if an
-- optional method is missing or changed on Retail / Forever).
local function Try(obj, method, ...)
  local fn = obj and obj[method]
  if type(fn) == "function" then
    pcall(fn, obj, ...)
  end
end

local function Fill(frame, layer, color)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  return t
end

local function Border(frame, color)
  local edges = {}
  local top = frame:CreateTexture(nil, "BORDER")
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(1)
  local bottom = frame:CreateTexture(nil, "BORDER")
  bottom:SetPoint("BOTTOMLEFT")
  bottom:SetPoint("BOTTOMRIGHT")
  bottom:SetHeight(1)
  local left = frame:CreateTexture(nil, "BORDER")
  left:SetPoint("TOPLEFT")
  left:SetPoint("BOTTOMLEFT")
  left:SetWidth(1)
  local right = frame:CreateTexture(nil, "BORDER")
  right:SetPoint("TOPRIGHT")
  right:SetPoint("BOTTOMRIGHT")
  right:SetWidth(1)
  edges[1], edges[2], edges[3], edges[4] = top, bottom, left, right

  function frame.SetBorderColor(_, r, g, b, a)
    for _, edge in ipairs(edges) do
      edge:SetColorTexture(r, g, b, a or 1)
    end
  end
  frame:SetBorderColor(color[1], color[2], color[3], color[4])
end

local function Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  color = color or C.text
  fs:SetTextColor(color[1], color[2], color[3])
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

local function StripColors(s)
  s = tostring(s or "")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|r", "")
  return s
end

local function TitleCase(s)
  if s ~= s:upper() then
    return s
  end
  return (s:lower():gsub("(%a)([%w']*)", function(first, rest)
    return first:upper() .. rest
  end))
end

local function ShowTip(owner)
  if not owner.tipTitle or owner.tipTitle == "" then
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(owner.tipTitle, 1, 1, 1, 1, true)
  if owner.tipText and owner.tipText ~= "" then
    GameTooltip:AddLine(owner.tipText, 0.82, 0.82, 0.82, true)
  end
  GameTooltip:Show()
end

local function HideTip()
  GameTooltip:Hide()
end

local function HoverBorder(frame)
  frame:HookScript("OnEnter", function(self)
    self:SetBorderColor(Accent())
    ShowTip(self)
  end)
  frame:HookScript("OnLeave", function(self)
    self:SetBorderColor(C.border[1], C.border[2], C.border[3], C.border[4])
    HideTip()
  end)
end

local function Button(parent, label, width, height, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, height or 26)
  b.bg = Fill(b, "BACKGROUND", C.row)
  Border(b, C.border)
  b.text = Text(b, 12, C.text, "CENTER")
  b.text:SetPoint("LEFT", 6, 0)
  b.text:SetPoint("RIGHT", -6, 0)
  b.text:SetText(label or "")
  Try(b, "SetMotionScriptsWhileDisabled", true)
  HoverBorder(b)
  if onClick then
    b:SetScript("OnClick", onClick)
  end
  return b
end

-- Pill switch used by toggle rows and nav items
local function Switch(parent)
  local s = CreateFrame("Frame", nil, parent)
  s:SetSize(30, 16)
  s.track = s:CreateTexture(nil, "ARTWORK")
  s.track:SetAllPoints()
  s.knob = s:CreateTexture(nil, "OVERLAY")
  s.knob:SetSize(12, 12)

  function s.SetState(self, on)
    self.knob:ClearAllPoints()
    if on then
      local r, g, b = Accent()
      self.track:SetColorTexture(r, g, b, 0.85)
      self.knob:SetColorTexture(1, 1, 1, 1)
      self.knob:SetPoint("RIGHT", self, "RIGHT", -2, 0)
    else
      self.track:SetColorTexture(C.off[1], C.off[2], C.off[3], 1)
      self.knob:SetColorTexture(0.75, 0.76, 0.78, 1)
      self.knob:SetPoint("LEFT", self, "LEFT", 2, 0)
    end
  end

  s:SetState(false)
  return s
end

-- Confirmation dialog (used by options marked "confirm")
_G.StaticPopupDialogs["TRUERETICLE_CONFIRM"] = {
  text = "%s",
  button1 = _G.YES or "Yes",
  button2 = _G.NO or "No",
  OnAccept = function(_, data)
    if type(data) == "function" then
      data()
    end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3
}

local function Confirm(text, onAccept)
  _G.StaticPopup_Show("TRUERETICLE_CONFIRM", text or "Are you sure?", nil, onAccept)
end

-- Dropdown menu (modern Menu API; falls back to cycling through values)
local function OpenMenu(owner, items, isSelected, onSelect)
  if #items == 0 then
    print(TR.Constants.BasePrintMsg .. "|cff909090: nothing to choose here yet.|r")
    return
  end
  local MenuUtil = _G.MenuUtil
  if MenuUtil and MenuUtil.CreateContextMenu then
    MenuUtil.CreateContextMenu(owner, function(_, root)
      if root.SetScrollMode and #items > 14 then
        root:SetScrollMode(360)
      end
      for _, item in ipairs(items) do
        root:CreateRadio(item.text, function()
          return isSelected(item.key)
        end, function()
          onSelect(item.key)
        end, item.key)
      end
    end)
    return
  end

  -- Fallback: pick the next value
  local nextIndex = 1
  for i, item in ipairs(items) do
    if isSelected(item.key) then
      nextIndex = (i % #items) + 1
    end
  end
  if items[nextIndex] then
    onSelect(items[nextIndex].key)
  end
end

---------------------------------------------------------------------------------------
--                                OPTION TABLE HELPERS                               --
---------------------------------------------------------------------------------------
local INFO = {}

local function Resolve(value)
  if type(value) == "function" then
    local ok, result = pcall(value, INFO)
    if ok then
      return result
    end
    return nil
  end
  return value
end

local function Str(value)
  value = Resolve(value)
  if value == nil then
    return ""
  end
  value = tostring(value)
  -- shrink oversized inline atlases (e.g. mouse button icons)
  value = value:gsub("|A:([^:|]+):%d+:%d+|a", "|A:%1:18:18|a")
  return value
end

local function TrimNewlines(s)
  s = s:gsub("^%s*\n+", "")
  s = s:gsub("\n+%s*$", "")
  return s
end

local function Get(opt)
  if opt.get then
    local ok, value = pcall(opt.get, INFO)
    if ok then
      return value
    end
  end
  return nil
end

local function PrintMsg(msg)
  print(TR.Constants.BasePrintMsg .. "|cff909090: " .. tostring(msg) .. "|r")
end

local function DoSet(opt, value)
  if opt.set then
    local ok, err = pcall(opt.set, INFO, value)
    if not ok then
      PrintMsg("|cffFF5050" .. tostring(err) .. "|r")
    end
  end
  UI.Refresh()
end

local function Set(opt, value)
  if InCombatLockdown() then
    PrintMsg("Settings can't be changed in combat.")
    UI.Refresh()
    return
  end
  if Resolve(opt.confirm) then
    local text = Resolve(opt.confirmText) or "Are you sure?"
    Confirm(text, function()
      DoSet(opt, value)
    end)
    UI.Refresh() -- show the old value until the dialog is accepted
    return
  end
  DoSet(opt, value)
end

local function IsDisabled(opt)
  local d = opt.disabled
  if type(d) == "function" then
    local ok, result = pcall(d, INFO)
    return ok and result and true or false
  end
  return d and true or false
end

local function SortedArgs(args)
  local list = {}
  for key, opt in pairs(args or {}) do
    if type(opt) == "table" and not Resolve(opt.hidden) then
      list[#list + 1] = {key = key, opt = opt}
    end
  end
  table_sort(list, function(a, b)
    local oa, ob = a.opt.order or 100, b.opt.order or 100
    if oa == ob then
      return a.key < b.key
    end
    return oa < ob
  end)
  return list
end

local function IsSpacer(opt)
  if opt.type ~= "description" or opt.image then
    return false
  end
  local name = opt.name
  return name == nil or (type(name) == "string" and name:match("^%s*$") ~= nil)
end

local function WeightOf(opt)
  local w = opt.width
  if w == "full" then
    return "full"
  elseif w == "double" then
    return 2
  elseif w == "half" then
    return 0.6
  elseif type(w) == "number" then
    return math_max(0.6, w)
  end
  if opt.type == "toggle" then
    return 1.8
  end
  return 1.5
end

---------------------------------------------------------------------------------------
--                                   FLOW LAYOUT                                     --
---------------------------------------------------------------------------------------
-- Controls are queued into a row until the row's width units are used up, then the row
-- is stretched to the full width. "full" items always get a row of their own.
local Layout = {}
Layout.__index = Layout

local function NewLayout(parent, width, x0, y0)
  return setmetatable({
    parent = parent,
    width = width,
    x0 = x0 or 0,
    y = y0 or 0,
    pending = {},
    pendingWeight = 0
  }, Layout)
end

function Layout:Flush()
  local n = #self.pending
  if n == 0 then
    return
  end
  local total = self.pendingWeight
  local usable = self.width - GAP * (n - 1)
  local x = self.x0
  local rowH = 0
  for _, item in ipairs(self.pending) do
    local w = math_floor(usable * item.weight / total)
    item.frame:ClearAllPoints()
    item.frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", x, -self.y)
    item.frame:SetWidth(w)
    x = x + w + GAP
    rowH = math_max(rowH, item.height)
  end
  self.y = self.y + rowH + GAP
  self.pending = {}
  self.pendingWeight = 0
end

function Layout:Add(frame, height, weight)
  if weight == "full" then
    self:Flush()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", self.parent, "TOPLEFT", self.x0, -self.y)
    frame:SetWidth(self.width)
    self.y = self.y + height + GAP
    return
  end
  if self.pendingWeight + weight > ROW_CAPACITY then
    self:Flush()
  end
  table_insert(self.pending, {frame = frame, height = height, weight = weight})
  self.pendingWeight = self.pendingWeight + weight
end

function Layout:Space(h)
  self:Flush()
  self.y = self.y + (h or GAP)
end

---------------------------------------------------------------------------------------
--                                     CONTROLS                                      --
---------------------------------------------------------------------------------------
-- Each control returns frame, height and registers a refresh function.
local function ControlBox(parent, opt, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(height)
  Fill(f, "BACKGROUND", C.row)
  Border(f, C.border)
  f:EnableMouse(true)
  f.tipTitle = StripColors(Str(opt.name))
  f.tipText = Str(opt.desc)
  HoverBorder(f)
  return f
end

local function LabelOn(f, opt)
  local label = Text(f, 12, C.text)
  label:SetPoint("TOPLEFT", 10, -8)
  label:SetPoint("TOPRIGHT", -10, -8)
  label:SetText(Str(opt.name))
  return label
end

local function ToggleControl(parent, opt, disabledFn, refreshers)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(40)
  Fill(row, "BACKGROUND", C.row)
  Border(row, C.border)
  Try(row, "SetMotionScriptsWhileDisabled", true)
  row.tipTitle = StripColors(Str(opt.name))
  row.tipText = Str(opt.desc)
  HoverBorder(row)

  local label = Text(row, 12, C.text)
  label:SetPoint("LEFT", 10, 0)
  label:SetPoint("RIGHT", -48, 0)
  label:SetWordWrap(true)
  Try(label, "SetMaxLines", 2)
  label:SetText(Str(opt.name))

  local sw = Switch(row)
  sw:SetPoint("RIGHT", -10, 0)

  row:SetScript("OnClick", function()
    if disabledFn() then
      return
    end
    Set(opt, not Get(opt))
  end)

  refreshers[#refreshers + 1] = function()
    sw:SetState(Get(opt) and true or false)
    row:SetAlpha(disabledFn() and 0.4 or 1)
  end
  return row, 40
end

local function RoundToStep(v, minV, step)
  if not step or step <= 0 then
    return v
  end
  local n = math_floor((v - minV) / step + 0.5)
  return tonumber(string.format("%.4f", minV + n * step))
end

local function RangeControl(parent, opt, disabledFn, refreshers)
  local f = ControlBox(parent, opt, 56)
  LabelOn(f, opt)
  local valueText = Text(f, 12, C.muted, "RIGHT")
  valueText:SetPoint("TOPRIGHT", -10, -8)

  local minV = opt.min or 0
  local maxV = opt.max or 100
  local step = opt.step or 1

  local s = CreateFrame("Slider", nil, f)
  s:SetOrientation("HORIZONTAL")
  s:SetHeight(16)
  s:SetPoint("BOTTOMLEFT", 10, 9)
  s:SetPoint("BOTTOMRIGHT", -10, 9)
  s:SetMinMaxValues(minV, maxV)
  s:SetValueStep(step)
  Try(s, "SetObeyStepsOnDrag", true)

  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  track:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)

  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(8, 16)
  AccentTex(thumb)
  s:SetThumbTexture(thumb)

  local function Format(v)
    if opt.isPercent then
      return string.format("%d%%", math_floor(v * 100 + 0.5))
    elseif step < 1 then
      return string.format("%.1f", v)
    end
    return tostring(math_floor(v + 0.5))
  end

  local updating = false
  s:SetScript("OnValueChanged", function(_, value, userInput)
    if updating then
      return
    end
    value = RoundToStep(value, minV, step)
    valueText:SetText(Format(value))
    if userInput == false then
      return
    end
    if value ~= Get(opt) then
      Set(opt, value)
    end
  end)

  refreshers[#refreshers + 1] = function()
    local value = tonumber(Get(opt)) or minV
    updating = true
    s:SetValue(value)
    updating = false
    valueText:SetText(Format(value))
    local dis = disabledFn()
    if dis then
      s:Disable()
    else
      s:Enable()
    end
    f:SetAlpha(dis and 0.4 or 1)
  end
  return f, 56
end

local function SortedValues(opt)
  local values = Resolve(opt.values) or {}
  local items = {}
  for key, text in pairs(values) do
    items[#items + 1] = {key = key, text = tostring(text)}
  end
  table_sort(items, function(a, b)
    return StripColors(a.text):lower() < StripColors(b.text):lower()
  end)
  return items
end

local function SelectControl(parent, opt, disabledFn, refreshers)
  local f = ControlBox(parent, opt, 56)
  LabelOn(f, opt)

  local btn = Button(f, "", 100, 22)
  btn:SetPoint("BOTTOMLEFT", 10, 8)
  btn:SetPoint("BOTTOMRIGHT", -10, 8)
  btn.bg:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)
  btn.text:SetJustifyH("LEFT")
  btn.text:SetPoint("RIGHT", -20, 0)
  local arrow = Text(btn, 11, C.muted, "RIGHT")
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("v")
  btn.tipTitle = f.tipTitle
  btn.tipText = f.tipText

  btn:SetScript("OnClick", function(self)
    if disabledFn() then
      return
    end
    OpenMenu(self, SortedValues(opt), function(key)
      return Get(opt) == key
    end, function(key)
      Set(opt, key)
    end)
  end)

  refreshers[#refreshers + 1] = function()
    local values = Resolve(opt.values) or {}
    local current = Get(opt)
    btn.text:SetText(values[current] and tostring(values[current]) or tostring(current or ""))
    f:SetAlpha(disabledFn() and 0.4 or 1)
  end
  return f, 56
end

local function StyledEditBox(parent)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:SetAutoFocus(false)
  eb:SetFont(FONT, 12, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  Try(eb, "SetTextInsets", 6, 6, 0, 0)
  Fill(eb, "BACKGROUND", C.input)
  Border(eb, C.border)
  return eb
end

local function InputControl(parent, opt, disabledFn, refreshers)
  local f = ControlBox(parent, opt, 56)
  LabelOn(f, opt)
  local readOnly = opt.set == nil

  local eb = StyledEditBox(f)
  eb:SetHeight(22)
  eb:SetPoint("BOTTOMLEFT", 10, 8)
  eb:SetPoint("BOTTOMRIGHT", -10, 8)

  local function Revert()
    eb:SetText(tostring(Get(opt) or ""))
  end

  eb:SetScript("OnEnterPressed", function(self)
    if readOnly then
      self:ClearFocus()
      return
    end
    local value = self:GetText()
    if opt.validate then
      local ok, result = pcall(opt.validate, INFO, value)
      if ok and result ~= true and result ~= nil then
        PrintMsg(StripColors(tostring(result)):gsub("\n+", " "))
        self:ClearFocus()
        Revert()
        return
      end
    end
    self:ClearFocus()
    Set(opt, value)
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    Revert()
  end)
  eb:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)
  eb:SetScript("OnTextChanged", function(self, userInput)
    if readOnly and userInput then
      Revert()
      self:HighlightText()
    end
  end)

  refreshers[#refreshers + 1] = function()
    if not eb:HasFocus() then
      Revert()
    end
    local dis = disabledFn()
    if dis then
      eb:ClearFocus()
      eb:Disable()
    else
      eb:Enable()
    end
    f:SetAlpha(dis and 0.4 or 1)
  end
  return f, 56
end

local function MultilineControl(parent, opt, disabledFn, refreshers)
  local lines = type(opt.multiline) == "number" and opt.multiline or 4
  local boxH = lines * 14 + 10
  local height = 30 + boxH + 38
  local f = ControlBox(parent, opt, height)
  LabelOn(f, opt)

  local holder = CreateFrame("Frame", nil, f)
  holder:SetPoint("TOPLEFT", 10, -28)
  holder:SetPoint("TOPRIGHT", -10, -28)
  holder:SetHeight(boxH)
  Fill(holder, "BACKGROUND", C.input)
  Border(holder, C.border)

  local sf = CreateFrame("ScrollFrame", nil, holder)
  sf:SetPoint("TOPLEFT", 6, -5)
  sf:SetPoint("BOTTOMRIGHT", -6, 5)

  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFont(FONT, 12, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  eb:SetWidth(400)
  sf:SetScrollChild(eb)
  sf:SetScript("OnSizeChanged", function(_, w)
    eb:SetWidth(w)
  end)
  sf:EnableMouse(true)
  sf:SetScript("OnMouseDown", function()
    eb:SetFocus()
  end)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(self, delta)
    local value = self:GetVerticalScroll() - delta * 28
    self:SetVerticalScroll(math_max(0, math_min(self:GetVerticalScrollRange(), value)))
  end)
  eb:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
  end)
  eb:SetScript("OnCursorChanged", function(_, _, y, _, cursorH)
    local top = sf:GetVerticalScroll()
    local bottom = top + sf:GetHeight()
    y = -y
    if y < top then
      sf:SetVerticalScroll(y)
    elseif y + cursorH > bottom then
      sf:SetVerticalScroll(math_max(0, y + cursorH - sf:GetHeight()))
    end
  end)

  local save = Button(f, "Save", 90, 22, function()
    eb:ClearFocus()
    Set(opt, eb:GetText())
  end)
  save:SetPoint("BOTTOMRIGHT", -10, 8)
  local revert = Button(f, "Revert", 90, 22, function()
    eb:ClearFocus()
    eb:SetText(tostring(Get(opt) or ""))
  end)
  revert:SetPoint("RIGHT", save, "LEFT", -GAP, 0)

  refreshers[#refreshers + 1] = function()
    if not eb:HasFocus() then
      eb:SetText(tostring(Get(opt) or ""))
    end
    local dis = disabledFn()
    if dis then
      eb:ClearFocus()
      eb:Disable()
      save:Disable()
    else
      eb:Enable()
      save:Enable()
    end
    f:SetAlpha(dis and 0.4 or 1)
  end
  return f, height
end

local IGNORED_KEYS = {
  LSHIFT = true,
  RSHIFT = true,
  LCTRL = true,
  RCTRL = true,
  LALT = true,
  RALT = true,
  LMETA = true,
  RMETA = true,
  UNKNOWN = true
}
local MOUSE_KEYS = {MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5"}

local function Modifiers()
  return (_G.IsAltKeyDown() and "ALT-" or "") .. (_G.IsControlKeyDown() and "CTRL-" or "") ..
           (_G.IsShiftKeyDown() and "SHIFT-" or "")
end

local function KeybindingControl(parent, opt, disabledFn, refreshers)
  local f = ControlBox(parent, opt, 56)
  LabelOn(f, opt)

  local btn = Button(f, "", 100, 22)
  btn:SetPoint("BOTTOMLEFT", 10, 8)
  btn:SetPoint("BOTTOMRIGHT", -10, 8)
  btn.bg:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)
  btn.tipTitle = f.tipTitle
  btn.tipText = (f.tipText ~= "" and (f.tipText .. "\n\n") or "") .. "|cff909090Click, then press a key. Esc cancels.|r"

  local capturing = false
  local refresh

  local function Stop()
    capturing = false
    btn:EnableKeyboard(false)
    btn:SetScript("OnKeyDown", nil)
    refresh()
  end

  local function Bind(key)
    Stop()
    Set(opt, key)
  end

  btn:SetScript("OnClick", function(self)
    if disabledFn() then
      return
    end
    if InCombatLockdown() then
      PrintMsg("Keybinds can't be changed in combat.")
      return
    end
    if capturing then
      Stop()
      return
    end
    capturing = true
    self.text:SetText(AccentHex() .. "Press a key...|r")
    self:EnableKeyboard(true)
    self:SetScript("OnKeyDown", function(_, key)
      if key == "ESCAPE" then
        Stop()
        return
      end
      if IGNORED_KEYS[key] then
        return
      end
      Bind(Modifiers() .. key)
    end)
  end)
  btn:SetScript("OnMouseDown", function(_, mouseButton)
    if capturing and MOUSE_KEYS[mouseButton] then
      Bind(Modifiers() .. MOUSE_KEYS[mouseButton])
    end
  end)
  btn:SetScript("OnHide", function()
    if capturing then
      Stop()
    end
  end)

  refresh = function()
    if capturing then
      return
    end
    local key = Get(opt)
    if key and key ~= "" then
      local display = _G.GetBindingText and _G.GetBindingText(key) or key
      btn.text:SetText(display)
    else
      btn.text:SetText("|cff909090Not bound|r")
    end
    f:SetAlpha(disabledFn() and 0.4 or 1)
  end
  refreshers[#refreshers + 1] = refresh
  return f, 56
end

local function ColorControl(parent, opt, disabledFn, refreshers)
  local row = CreateFrame("Button", nil, parent)
  row:SetHeight(40)
  Fill(row, "BACKGROUND", C.row)
  Border(row, C.border)
  Try(row, "SetMotionScriptsWhileDisabled", true)
  row.tipTitle = StripColors(Str(opt.name))
  row.tipText = Str(opt.desc)
  HoverBorder(row)

  local label = Text(row, 12, C.text)
  label:SetPoint("LEFT", 10, 0)
  label:SetPoint("RIGHT", -48, 0)
  label:SetText(Str(opt.name))

  local swatch = CreateFrame("Frame", nil, row)
  swatch:SetSize(26, 16)
  swatch:SetPoint("RIGHT", -10, 0)
  Border(swatch, C.border)
  local fill = swatch:CreateTexture(nil, "ARTWORK")
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)

  local function Current()
    if not opt.get then
      return 1, 1, 1
    end
    local ok, r, g, b = pcall(opt.get, INFO)
    if ok and type(r) == "number" then
      return r, g, b
    end
    return 1, 1, 1
  end

  local function Apply(r, g, b)
    if opt.set then
      local ok, err = pcall(opt.set, INFO, r, g, b, 1)
      if not ok then
        PrintMsg("|cffFF5050" .. tostring(err) .. "|r")
      end
    end
    UI.Refresh()
  end

  row:SetScript("OnClick", function()
    if disabledFn() then
      return
    end
    local picker = _G.ColorPickerFrame
    if not picker then
      return
    end
    local r, g, b = Current()
    if picker.SetupColorPickerAndShow then
      picker:SetupColorPickerAndShow({
        r = r,
        g = g,
        b = b,
        hasOpacity = false,
        swatchFunc = function()
          Apply(picker:GetColorRGB())
        end,
        cancelFunc = function(previous)
          if type(previous) == "table" and previous.r then
            Apply(previous.r, previous.g, previous.b)
          else
            Apply(r, g, b)
          end
        end
      })
    end
  end)

  refreshers[#refreshers + 1] = function()
    fill:SetColorTexture(Current())
    row:SetAlpha(disabledFn() and 0.4 or 1)
  end
  return row, 40
end

local function ExecuteControl(parent, opt, disabledFn, refreshers)
  local b = Button(parent, StripColors(Str(opt.name)), 120, 30)
  b.tipTitle = StripColors(Str(opt.name))
  b.tipText = Str(opt.desc)
  b:SetScript("OnClick", function()
    if disabledFn() or not opt.func then
      return
    end
    local run = function()
      opt.func(INFO)
      UI.Refresh()
    end
    if Resolve(opt.confirm) then
      Confirm(Resolve(opt.confirmText), run)
    else
      run()
    end
  end)
  refreshers[#refreshers + 1] = function()
    b:SetAlpha(disabledFn() and 0.4 or 1)
  end
  return b, 30
end

local function ImageControl(parent, opt, disabledFn, refreshers)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(56)
  Fill(f, "BACKGROUND", C.row)
  Border(f, C.border)
  local tex = f:CreateTexture(nil, "ARTWORK")
  tex:SetSize(40, 40)
  tex:SetPoint("CENTER")
  refreshers[#refreshers + 1] = function()
    local image = Resolve(opt.image)
    if image then
      tex:SetTexture(image)
    end
    f:SetAlpha(disabledFn() and 0.4 or 1)
  end
  return f, 56
end

local function DescriptionText(parent, opt, width)
  local holder = CreateFrame("Frame", nil, parent)
  local fs = Text(holder, opt.fontSize == "medium" and 13 or 12, C.muted)
  fs:SetWordWrap(true)
  fs:SetJustifyV("TOP")
  fs:SetPoint("TOPLEFT")
  fs:SetWidth(width)
  fs:SetText(TrimNewlines(Str(opt.name)))
  local h = math_floor(fs:GetStringHeight() + 4)
  holder:SetHeight(h)
  return holder, h
end

local function SectionTitle(parent, text, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(26)
  local bar = f:CreateTexture(nil, "ARTWORK")
  bar:SetSize(3, 16)
  bar:SetPoint("LEFT", 0, 0)
  AccentTex(bar)
  local fs = Text(f, 15, C.text)
  fs:SetPoint("LEFT", bar, "RIGHT", 8, 0)
  fs:SetText(text)
  local line = f:CreateTexture(nil, "ARTWORK")
  line:SetHeight(1)
  line:SetPoint("LEFT", fs, "RIGHT", 12, 0)
  line:SetPoint("RIGHT", f, "RIGHT", 0, 0)
  AccentTex(line, 0.35)
  return f, 26
end

---------------------------------------------------------------------------------------
--                                 OPTION RENDERER                                   --
---------------------------------------------------------------------------------------
local RenderArgs -- forward declaration

local function BuildCard(parent, width, groupOpt, disabledFn, refreshers, showTitle, stateKey)
  local card = CreateFrame("Frame", nil, parent)
  card:SetWidth(width)
  Fill(card, "BACKGROUND", C.card)
  Border(card, C.border)

  local y = 12
  if showTitle then
    local title = Text(card, 13, C.text)
    title:SetWordWrap(true)
    title:SetJustifyV("TOP")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetWidth(width - 24)
    title:SetText(Str(groupOpt.name))
    y = y + math_floor(title:GetStringHeight()) + 10
  end

  local inner = NewLayout(card, width - 24, 12, y)
  RenderArgs(inner, groupOpt.args, disabledFn, refreshers, stateKey)
  inner:Flush()
  local h = inner.y - GAP + 12
  card:SetHeight(h)
  return card, h
end

local function RenderTabs(layout, tabs, disabledFn, refreshers, stateKey)
  layout:Flush()
  local bar = CreateFrame("Frame", nil, layout.parent)
  local cards, buttons = {}, {}
  local Select -- defined below, used by the tab buttons

  -- tab buttons wrap onto extra rows when they don't fit
  local x, row = 0, 0
  for i, tab in ipairs(tabs) do
    local b = CreateFrame("Button", nil, bar)
    b.text = Text(b, 12, C.muted, "CENTER")
    b.text:SetPoint("CENTER", 0, 2)
    b.text:SetText(StripColors(Str(tab.opt.name)))
    local w = math_floor(b.text:GetStringWidth()) + 24
    if x > 0 and x + w > layout.width then
      x = 0
      row = row + 1
    end
    b:SetSize(w, 26)
    b:SetPoint("TOPLEFT", bar, "TOPLEFT", x, -row * 28)
    x = x + w + 4
    b.underline = b:CreateTexture(nil, "ARTWORK")
    b.underline:SetHeight(2)
    b.underline:SetPoint("BOTTOMLEFT", 4, 0)
    b.underline:SetPoint("BOTTOMRIGHT", -4, 0)
    AccentTex(b.underline)
    b:SetScript("OnClick", function()
      Select(i)
    end)
    buttons[i] = b
  end
  local barH = (row + 1) * 28
  bar:SetHeight(barH)
  layout:Add(bar, barH, "full")

  local startY = layout.y
  local maxH = 0
  for i, tab in ipairs(tabs) do
    local groupDisabled = function()
      return disabledFn() or IsDisabled(tab.opt)
    end
    local card, h = BuildCard(layout.parent, layout.width, tab.opt, groupDisabled, refreshers, false,
      stateKey .. "." .. tab.key)
    card:SetPoint("TOPLEFT", layout.parent, "TOPLEFT", layout.x0, -startY)
    cards[i] = card
    maxH = math_max(maxH, h)
  end

  UI.tabState = UI.tabState or {}
  Select = function(index)
    UI.tabState[stateKey] = index
    for i, card in ipairs(cards) do
      card:SetShown(i == index)
      local b = buttons[i]
      b.underline:SetShown(i == index)
      local color = (i == index) and C.text or C.muted
      b.text:SetTextColor(color[1], color[2], color[3])
    end
  end

  Select(UI.tabState[stateKey] or 1)
  layout.y = startY + maxH + GAP
end

RenderArgs = function(layout, args, disabledFn, refreshers, stateKey)
  local tabs = {}
  stateKey = stateKey or "root"

  for _, entry in ipairs(SortedArgs(args)) do
    local opt = entry.opt
    local optDisabled = function()
      return disabledFn() or IsDisabled(opt)
    end
    local t = opt.type

    if IsSpacer(opt) then
      if opt.width == "full" then
        layout:Flush()
      end
    elseif t == "header" then
      local f, h = SectionTitle(layout.parent, TitleCase(StripColors(Str(opt.name))), layout.width)
      layout:Space(4)
      layout:Add(f, h, "full")
    elseif t == "description" then
      if opt.image then
        local f, h = ImageControl(layout.parent, opt, optDisabled, refreshers)
        layout:Add(f, h, 0.6)
      else
        local f, h = DescriptionText(layout.parent, opt, layout.width)
        layout:Add(f, h, "full")
      end
    elseif t == "group" then
      if opt.inline then
        local card, h = BuildCard(layout.parent, layout.width, opt, optDisabled, refreshers, true,
          stateKey .. "." .. entry.key)
        layout:Add(card, h, "full")
      else
        tabs[#tabs + 1] = entry
      end
    elseif t == "toggle" then
      local f, h = ToggleControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    elseif t == "range" then
      local f, h = RangeControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    elseif t == "select" then
      local f, h = SelectControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    elseif t == "input" then
      if opt.multiline then
        local f, h = MultilineControl(layout.parent, opt, optDisabled, refreshers)
        layout:Add(f, h, "full")
      else
        local f, h = InputControl(layout.parent, opt, optDisabled, refreshers)
        layout:Add(f, h, WeightOf(opt))
      end
    elseif t == "keybinding" then
      local f, h = KeybindingControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    elseif t == "custom" and type(opt.create) == "function" then
      local ok, f, h = pcall(opt.create, layout.parent, layout.width)
      if ok and f then
        if f.Refresh then
          refreshers[#refreshers + 1] = f.Refresh
        end
        layout:Add(f, h or f:GetHeight(), "full")
      end
    elseif t == "color" then
      local f, h = ColorControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    elseif t == "execute" then
      local f, h = ExecuteControl(layout.parent, opt, optDisabled, refreshers)
      layout:Add(f, h, WeightOf(opt))
    end
  end

  if #tabs > 0 then
    RenderTabs(layout, tabs, disabledFn, refreshers, stateKey .. ".tabs")
  end
end

---------------------------------------------------------------------------------------
--                                       PAGES                                       --
---------------------------------------------------------------------------------------
local function OptionsPage(argsProvider)
  return function(child, width, refreshers)
    local layout = NewLayout(child, width, 0, 4)
    RenderArgs(layout, argsProvider(), function()
      return false
    end, refreshers)
    layout:Flush()
    return layout.y + 12
  end
end

local function ConfigArgs(index, exclude, extra)
  return function()
    local source = TR.Config.OptionCategories[index].table.args
    local args = {}
    for key, opt in pairs(source) do
      if not (exclude and exclude[key]) then
        args[key] = opt
      end
    end
    if extra then
      for key, opt in pairs(extra()) do
        args[key] = opt
      end
    end
    return args
  end
end

local function CrosshairArgs()
  local group = TR.Config.OptionCategories[2].table.args.CrosshairGroup
  local args = {
    header = {type = "header", name = "Crosshair", order = 0}
  }
  for key, opt in pairs(group.args) do
    args[key] = opt
  end
  return args
end

local function AdvancedExtra()
  return {
    debugModeToggle = TR.Config.AboutOptions.args.debugModeToggle
  }
end

-- Forward declarations for page builders defined below
local BuildHome, BuildPatchNotes

UI.Pages = {
  {
    key = "home",
    title = "Home",
    subtitle = "Overview · Quick actions · Recent pages",
    section = "Setup"
  },
  {
    key = "notes",
    title = "Patch Notes",
    subtitle = "What's new in True Reticle",
    section = "Setup"
  },
  {
    key = "freelook",
    title = "Mouse Look",
    subtitle = "Keybinds · Camera · Auto cursor unlock",
    section = "Combat",
    build = OptionsPage(ConfigArgs(1))
  },
  {
    key = "reticle",
    title = "Reticle Targeting",
    subtitle = "Target what you aim at · Target circle",
    section = "Combat",
    build = OptionsPage(ConfigArgs(2, {CrosshairGroup = true, spacing3 = true})),
    navToggle = function()
      return TR.Config.OptionCategories[2].table.args.reticleTargeting
    end
  },
  {
    key = "crosshair",
    title = "Crosshair",
    subtitle = "Style · Size · Opacity · Position",
    section = "Combat",
    build = OptionsPage(CrosshairArgs),
    navToggle = function()
      return TR.Config.OptionCategories[2].table.args.CrosshairGroup.args.crosshair
    end
  },
  {
    key = "clicks",
    title = "Click Casting",
    subtitle = "Mouse button actions while in Mouse Look",
    section = "Combat",
    build = OptionsPage(ConfigArgs(3))
  },
  {
    key = "hud",
    title = "Reticle HUD",
    subtitle = "Health, power, target and cast arcs · Resource pips · Hit & kill feedback",
    section = "HUD & Camera",
    build = OptionsPage(function()
      return TR.Config.Features.hud.args
    end),
    navToggle = function()
      return TR.Config.Features.hud.args.hudEnabled
    end
  },
  {
    key = "smart",
    title = "Smart Crosshair",
    subtitle = "Range colors · Hide rules · Head tracking · Screen effects",
    section = "HUD & Camera",
    build = OptionsPage(function()
      return TR.Config.Features.smart.args
    end),
    navToggle = function()
      return TR.Config.Features.smart.args.smartEnabled
    end
  },
  {
    key = "camera",
    title = "Situational Camera",
    subtitle = "Zoom, shoulder, head movement and field of view per situation",
    section = "HUD & Camera",
    build = OptionsPage(function()
      return TR.Config.Features.camera.args
    end),
    navToggle = function()
      return TR.Config.Features.camera.args.camEnabled
    end
  },
  {
    key = "profiles",
    title = "Profiles",
    subtitle = "Per-character and per-specialization settings",
    section = "Other",
    build = OptionsPage(function()
      return TR.Config.Features.BuildProfiles()
    end)
  },
  {
    key = "advanced",
    title = "Advanced",
    subtitle = "Custom cursor-unlock condition · Debug",
    section = "Other",
    build = OptionsPage(ConfigArgs(4, nil, AdvancedExtra))
  }
}

local PAGE_BY_KEY = {}
for _, page in ipairs(UI.Pages) do
  PAGE_BY_KEY[page.key] = page
end

---------------------------------------------------------------------------------------
--                                   SMALL HELPERS                                   --
---------------------------------------------------------------------------------------
local function ClientName()
  local toc = select(4, _G.GetBuildInfo()) or 0
  if toc >= 100000 then
    return "RETAIL"
  end
  return "FOREVER"
end

local function OpenKeybindings()
  if InCombatLockdown() then
    return
  end
  local Settings = _G.Settings
  if Settings and Settings.OpenToCategory and Settings.KEYBINDINGS_CATEGORY_ID then
    UI.Hide()
    pcall(Settings.OpenToCategory, Settings.KEYBINDINGS_CATEGORY_ID)
  end
end

local function OpenMacros()
  if InCombatLockdown() then
    return
  end
  UI.Hide()
  if _G.ShowMacroFrame then
    pcall(_G.ShowMacroFrame)
  end
end

local function CountActiveClicks()
  local count = 0
  local location = TR.GetBindingsLocation()
  for _, button in pairs(TR.Constants.ButtonsToOverride) do
    local settings = TR.DB[location].bindings[button]
    if settings and settings.enabled then
      count = count + 1
    end
  end
  return count
end

local function ClassColoredPlayer()
  local name = _G.UnitName("player") or "?"
  local level = _G.UnitLevel("player") or 0
  local className, classFile = _G.UnitClass("player")
  local color = classFile and _G.C_ClassColor and _G.C_ClassColor.GetClassColor(classFile)
  local hex = color and color:GenerateHexColor() or "ffffffff"
  return string.format("|c%s%s|r  -  Level %d %s", hex, name, level, className or "")
end

---------------------------------------------------------------------------------------
--                                     HOME PAGE                                     --
---------------------------------------------------------------------------------------
local function StatCard(parent, label, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 52)
  Fill(f, "BACKGROUND", C.card)
  Border(f, C.border)
  local l = Text(f, 11, C.muted)
  l:SetPoint("TOPLEFT", 12, -10)
  l:SetText(label)
  local v = Text(f, 14, C.text)
  v:SetPoint("TOPLEFT", 12, -27)
  v:SetPoint("RIGHT", -10, 0)
  f.value = v
  return f
end

BuildHome = function(child, width, refreshers)
  local y = 4

  -- Profile card
  local hero = CreateFrame("Frame", nil, child)
  hero:SetPoint("TOPLEFT", 0, -y)
  hero:SetSize(width, 64)
  Fill(hero, "BACKGROUND", C.card)
  Border(hero, C.border)
  local heroGlow = hero:CreateTexture(nil, "ARTWORK")
  heroGlow:SetPoint("TOPLEFT", 1, -1)
  heroGlow:SetPoint("BOTTOMLEFT", 1, 1)
  heroGlow:SetWidth(3)
  AccentTex(heroGlow)
  local heroTitle = Text(hero, 18, C.text)
  heroTitle:SetPoint("TOPLEFT", 16, -12)
  heroTitle:SetText("True Reticle")
  local heroSub = Text(hero, 12, C.muted)
  heroSub:SetPoint("TOPLEFT", 16, -38)
  local heroLogo = hero:CreateTexture(nil, "ARTWORK")
  heroLogo:SetSize(48, 48)
  heroLogo:SetPoint("RIGHT", -12, 0)
  heroLogo:SetTexture(TR.Constants.Logo)
  y = y + 64 + 14

  -- Stat cards (3 per row)
  local cardW = math_floor((width - GAP * 2) / 3)
  local stats = {
    {"Toggle Key", function()
      local key = _G.GetBindingKey("TRUERETICLE_TOGGLE")
      return key and (_G.GetBindingText and _G.GetBindingText(key) or key) or "|cff909090Not bound|r"
    end},
    {"Reticle Targeting", function()
      return TR.DB.char.reticleTargeting and (AccentHex() .. "On|r") or "|cff909090Off|r"
    end},
    {"Crosshair", function()
      if not TR.DB.global.crosshair then
        return "|cff909090Hidden|r"
      end
      return TR.DB.global.crosshairAppearance and TR.DB.global.crosshairAppearance.Name or "Default"
    end},
    {"Click Casting", function()
      return CountActiveClicks() .. " / " .. #TR.Constants.ButtonsToOverride .. " active"
    end},
    {"Client", function()
      return ClientName() == "RETAIL" and "Retail" or "Forever"
    end},
    {"Profile", function()
      return TR.ActiveProfileName or "Default"
    end}
  }
  local statCards = {}
  for i, stat in ipairs(stats) do
    local col = (i - 1) % 3
    local rowIndex = math_floor((i - 1) / 3)
    local card = StatCard(child, stat[1], cardW)
    card:SetPoint("TOPLEFT", col * (cardW + GAP), -(y + rowIndex * (52 + GAP)))
    statCards[i] = card
  end
  y = y + 2 * (52 + GAP) + 10

  -- Quick actions
  local qa = SectionTitle(child, "Quick Actions", width)
  qa:SetPoint("TOPLEFT", 0, -y)
  qa:SetWidth(width)
  y = y + 26 + GAP

  local actions = {
    {"Keybindings", OpenKeybindings, "Open the game's keybinding settings."},
    {"Macros", OpenMacros, "Open the macro window. True Reticle adds example TR_ macros there."},
    {"Patch Notes", function()
      UI.ShowPage("notes")
    end, "See what's new in True Reticle."},
    {"Reload UI", function()
      _G.ReloadUI()
    end, "Reload the interface."},
    {"Reset Settings", function()
      Confirm(TR.METADATA["TITLE"] .. "\n\nReset all True Reticle settings to default?\nThis reloads your UI.", function()
        TR:OnResetDB()
      end)
    end, "Restore every True Reticle setting to its default (reloads the UI)."},
    {"Undo All Changes", function()
      Confirm(TR.METADATA["TITLE"] ..
                "\n\nRevert every game setting True Reticle changed and disable the addon?\nThis reloads your UI.",
        function()
          TR.UndoChanges()
        end)
    end, "Same as /trundo: restores game settings and disables True Reticle."}
  }
  for i, action in ipairs(actions) do
    local col = (i - 1) % 3
    local rowIndex = math_floor((i - 1) / 3)
    local b = Button(child, action[1], cardW, 28, action[2])
    b.tipTitle = action[1]
    b.tipText = action[3]
    b:SetPoint("TOPLEFT", col * (cardW + GAP), -(y + rowIndex * (28 + GAP)))
  end
  y = y + 2 * (28 + GAP) + 10

  -- Recent pages
  local recentTitle = Text(child, 13, C.text)
  recentTitle:SetPoint("TOPLEFT", 0, -y)
  recentTitle:SetText("Recent Pages")
  y = y + 22
  local recentButtons = {}
  for i = 1, 4 do
    local b = Button(child, "", width, 26)
    b.text:SetJustifyH("LEFT")
    b:SetPoint("TOPLEFT", 0, -(y + (i - 1) * (26 + 6)))
    b:Hide()
    recentButtons[i] = b
  end
  local recentEmpty = Text(child, 12, C.muted)
  recentEmpty:SetPoint("TOPLEFT", 0, -y)
  recentEmpty:SetText("Pages you open will show up here.")
  y = y + 4 * (26 + 6) + 6

  -- Tip
  local tip = Text(child, 12, C.muted)
  tip:SetWordWrap(true)
  tip:SetJustifyV("TOP")
  tip:SetWidth(width)
  tip:SetPoint("TOPLEFT", 0, -y)
  tip:SetText("Tip: type /tr to open this window, /trundo to revert every game setting True Reticle changed.")
  y = y + math_floor(tip:GetStringHeight()) + 12

  refreshers[#refreshers + 1] = function()
    heroSub:SetText(ClassColoredPlayer())
    for i, stat in ipairs(stats) do
      local ok, value = pcall(stat[2])
      statCards[i].value:SetText(ok and tostring(value) or "?")
    end
    local recent = UI.recent or {}
    for i, b in ipairs(recentButtons) do
      local key = recent[i]
      local page = key and PAGE_BY_KEY[key]
      if page then
        b.text:SetText("Home  /  " .. page.title)
        b:SetScript("OnClick", function()
          UI.ShowPage(key)
        end)
        b:Show()
      else
        b:Hide()
      end
    end
    recentEmpty:SetShown(#recent == 0)
  end

  return y
end

---------------------------------------------------------------------------------------
--                                 PATCH NOTES PAGE                                  --
---------------------------------------------------------------------------------------
BuildPatchNotes = function(child, width)
  local y = 4
  for _, entry in ipairs(TR.Changelog or {}) do
    local title = SectionTitle(child, "Version " .. entry.version, width)
    title:SetPoint("TOPLEFT", 0, -y)
    title:SetWidth(width)
    y = y + 26
    local date = Text(child, 11, C.muted)
    date:SetPoint("TOPLEFT", 11, -y)
    date:SetText(entry.date or "")
    y = y + 20
    for _, line in ipairs(entry.notes or {}) do
      local dot = child:CreateTexture(nil, "ARTWORK")
      dot:SetSize(4, 4)
      dot:SetPoint("TOPLEFT", 12, -(y + 6))
      AccentTex(dot)
      local fs = Text(child, 12, C.text)
      fs:SetWordWrap(true)
      fs:SetJustifyV("TOP")
      fs:SetWidth(width - 28)
      fs:SetPoint("TOPLEFT", 24, -y)
      fs:SetText(line)
      y = y + math_floor(fs:GetStringHeight()) + 8
    end
    y = y + 14
  end
  return y
end

PAGE_BY_KEY.home.build = BuildHome
PAGE_BY_KEY.notes.build = BuildPatchNotes

---------------------------------------------------------------------------------------
--                                   MAIN WINDOW                                     --
---------------------------------------------------------------------------------------
local frame -- the window, created on first open
local currentPage
local navItems = {}

function UI.Refresh()
  if not frame or not frame:IsShown() then
    return
  end
  if currentPage and currentPage.refreshers then
    for _, refresh in ipairs(currentPage.refreshers) do
      pcall(refresh)
    end
  end
  for _, item in ipairs(navItems) do
    item.Refresh()
  end
end

function UI.ApplyTheme()
  local r, g, b = Accent()
  for _, entry in ipairs(accentTextures) do
    entry[1]:SetColorTexture(r, g, b, entry[2])
  end
  for _, fs in ipairs(accentTexts) do
    fs:SetTextColor(r, g, b)
  end
  if frame and frame.themeButton then
    frame.themeButton.text:SetText(TR.DB.global.uiTheme or "Green")
  end
  UI.Refresh()
end

local function UpdateScrollThumb()
  local sf, track, thumb = frame.scroll, frame.track, frame.thumb
  local range = sf:GetVerticalScrollRange()
  if range <= 0 then
    thumb:Hide()
    return
  end
  thumb:Show()
  local trackH = track:GetHeight()
  local visible = sf:GetHeight()
  local thumbH = math_max(28, trackH * visible / (visible + range))
  thumb:SetHeight(thumbH)
  thumb:ClearAllPoints()
  thumb:SetPoint("TOP", track, "TOP", 0, -(trackH - thumbH) * (sf:GetVerticalScroll() / range))
end

local function RememberPage(key)
  if key == "home" then
    return
  end
  UI.recent = UI.recent or {}
  for i = #UI.recent, 1, -1 do
    if UI.recent[i] == key then
      table_remove(UI.recent, i)
    end
  end
  table_insert(UI.recent, 1, key)
  while #UI.recent > 4 do
    table_remove(UI.recent)
  end
end

function UI.ShowPage(key)
  if not frame or not frame.scroll then
    return
  end
  local page = PAGE_BY_KEY[key] or PAGE_BY_KEY.home

  if currentPage and currentPage.child then
    currentPage.child:Hide()
  end

  if not page.child then
    -- content width: window - sidebar column - right margin - scroll insets (16 + 26)
    local width = WIN_W - (MARGIN * 2 + SIDEBAR_W) - MARGIN - 42
    local child = CreateFrame("Frame", nil, frame.scroll)
    child:SetWidth(width)
    page.refreshers = {}
    local ok, height = pcall(page.build, child, width, page.refreshers)
    if not ok then
      PrintMsg("|cffFF5050Page error: " .. tostring(height) .. "|r")
      height = 100
    end
    child:SetHeight(math_max(1, height or 1))
    page.child = child
  end

  currentPage = page
  RememberPage(page.key)
  TR.DB.global.lastPage = page.key

  frame.scroll:SetScrollChild(page.child)
  page.child:Show()
  frame.scroll:SetVerticalScroll(0)
  frame.pageTitle:SetText(page.title)
  frame.pageSubtitle:SetText(page.subtitle or "")

  for _, item in ipairs(navItems) do
    item.SetSelected(item.key == page.key)
  end

  UI.Refresh()
  UpdateScrollThumb()
end

local function CreateNavItem(parent, page, y)
  local b = CreateFrame("Button", nil, parent)
  b:SetPoint("TOPLEFT", 0, -y)
  b:SetPoint("TOPRIGHT", 0, -y)
  b:SetHeight(26)

  local hl = Fill(b, "BACKGROUND", {1, 1, 1, 0.06})
  hl:Hide()
  local bar = b:CreateTexture(nil, "ARTWORK")
  bar:SetPoint("TOPLEFT")
  bar:SetPoint("BOTTOMLEFT")
  bar:SetWidth(3)
  AccentTex(bar)
  bar:Hide()

  local dot = b:CreateTexture(nil, "ARTWORK")
  dot:SetSize(5, 5)
  dot:SetPoint("LEFT", 14, 0)
  dot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)

  local label = Text(b, 12, C.text)
  label:SetPoint("LEFT", 28, 0)
  label:SetText(page.title)

  local item = {key = page.key}
  local selected = false

  local toggleOpt = page.navToggle and page.navToggle()
  local sw
  if toggleOpt then
    local swButton = CreateFrame("Button", nil, b)
    swButton:SetSize(30, 16)
    swButton:SetPoint("RIGHT", -10, 0)
    sw = Switch(swButton)
    sw:SetAllPoints()
    swButton.tipTitle = StripColors(Str(toggleOpt.name))
    swButton.tipText = Str(toggleOpt.desc)
    swButton:SetScript("OnEnter", ShowTip)
    swButton:SetScript("OnLeave", HideTip)
    swButton:SetScript("OnClick", function()
      if not IsDisabled(toggleOpt) then
        Set(toggleOpt, not Get(toggleOpt))
      end
    end)
  else
    local arrow = Text(b, 12, C.muted, "RIGHT")
    arrow:SetPoint("RIGHT", -12, 0)
    arrow:SetText(">")
  end

  b:SetScript("OnEnter", function()
    if not selected then
      hl:Show()
    end
  end)
  b:SetScript("OnLeave", function()
    if not selected then
      hl:Hide()
    end
  end)
  b:SetScript("OnClick", function()
    UI.ShowPage(page.key)
  end)

  function item.SetSelected(isSelected)
    selected = isSelected
    bar:SetShown(isSelected)
    hl:SetShown(isSelected)
    if isSelected then
      dot:SetColorTexture(Accent())
    else
      dot:SetColorTexture(C.muted[1], C.muted[2], C.muted[3], 1)
    end
  end

  function item.Refresh()
    if sw then
      sw:SetState(Get(toggleOpt) and true or false)
    end
    if selected then
      dot:SetColorTexture(Accent())
    end
  end

  navItems[#navItems + 1] = item
  return b
end

local function BuildSidebar(parent)
  local side = CreateFrame("Frame", nil, parent)
  side:SetPoint("TOPLEFT", MARGIN, -MARGIN)
  side:SetPoint("BOTTOMLEFT", MARGIN, MARGIN)
  side:SetWidth(SIDEBAR_W)
  Fill(side, "BACKGROUND", C.sidebar)
  Border(side, C.border)

  -- Brand header
  local logo = side:CreateTexture(nil, "ARTWORK")
  logo:SetSize(44, 44)
  logo:SetPoint("TOPLEFT", 10, -10)
  logo:SetTexture(TR.Constants.Logo)
  local title = Text(side, 17, C.text)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 8, -6)
  title:SetText("True Reticle")
  local client = Text(side, 10, C.text)
  client:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
  client:SetText(ClientName())
  AccentText(client)

  local divider = side:CreateTexture(nil, "ARTWORK")
  divider:SetHeight(1)
  divider:SetPoint("TOPLEFT", 8, -64)
  divider:SetPoint("TOPRIGHT", -8, -64)
  divider:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

  -- Navigation
  local nav = CreateFrame("Frame", nil, side)
  nav:SetPoint("TOPLEFT", 1, -72)
  nav:SetPoint("TOPRIGHT", -1, -72)
  nav:SetHeight(420)

  local y = 0
  local lastSection
  for _, page in ipairs(UI.Pages) do
    if page.section ~= lastSection then
      if lastSection then
        y = y + 6
      end
      local s = Text(nav, 11, C.text)
      s:SetPoint("TOPLEFT", 12, -y - 4)
      s:SetText(page.section)
      AccentText(s)
      y = y + 22
      lastSection = page.section
    end
    CreateNavItem(nav, page, y)
    y = y + 26
  end

  -- Tools
  local version = Text(side, 10, C.muted)
  version:SetPoint("BOTTOMLEFT", 12, 10)
  version:SetText("v" .. (TR.METADATA["VERSION"] or "?"))

  local tools = {
    {"Keybindings", OpenKeybindings},
    {"Macros", OpenMacros},
    {"Undo Changes", function()
      Confirm(TR.METADATA["TITLE"] ..
                "\n\nRevert every game setting True Reticle changed and disable the addon?\nThis reloads your UI.",
        function()
          TR.UndoChanges()
        end)
    end}
  }
  local by = 30
  for i = #tools, 1, -1 do
    local b = Button(side, tools[i][1], SIDEBAR_W - 20, 24, tools[i][2])
    b:SetPoint("BOTTOMLEFT", 10, by)
    by = by + 24 + 4
  end
  local toolsLabel = Text(side, 10, C.muted)
  toolsLabel:SetPoint("BOTTOMLEFT", 12, by + 2)
  toolsLabel:SetText("TOOLS")

  return side
end

-- Builds one part of the window; a failure is reported in chat (and to the error
-- handler) but no longer stops the rest of the window from being created.
local function SafeBuild(label, fn, ...)
  local ok, err = xpcall(fn, function(e)
    return tostring(e) .. "\n" .. (_G.debugstack and _G.debugstack(2, 6, 0) or "")
  end, ...)
  if not ok then
    PrintMsg("|cffFF5050Window part '" .. label .. "' failed:|r " .. tostring(err):match("^[^\n]*"))
    local handler = _G.geterrorhandler and _G.geterrorhandler()
    if handler then
      handler(err)
    end
  end
  return ok
end

local function BuildTopBar(parent, contentLeft)
  local close = Button(parent, "X", 24, 22, function()
    UI.Hide()
  end)
  close:SetPoint("TOPRIGHT", -MARGIN, -MARGIN - 1)

  local version = Text(parent, 12, C.text)
  version:SetPoint("RIGHT", close, "LEFT", -12, 0)
  version:SetText("v" .. (TR.METADATA["VERSION"] or "?"))

  local themeLabel = Text(parent, 12, C.muted)
  themeLabel:SetPoint("TOPLEFT", contentLeft, -MARGIN - 6)
  themeLabel:SetText("Theme")

  local themeButton = Button(parent, TR.DB.global.uiTheme or "Green", 110, 22)
  themeButton:SetPoint("LEFT", themeLabel, "RIGHT", 8, 0)
  themeButton.bg:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)
  themeButton.tipTitle = "Theme"
  themeButton.tipText = "Accent color of the True Reticle window."
  themeButton:SetScript("OnClick", function(self)
    local items = {}
    for _, theme in ipairs(THEMES) do
      items[#items + 1] = {key = theme.key, text = theme.key}
    end
    OpenMenu(self, items, function(key)
      return (TR.DB.global.uiTheme or "Green") == key
    end, function(key)
      TR.DB.global.uiTheme = key
      UI.ApplyTheme()
    end)
  end)
  parent.themeButton = themeButton

  SafeBuild("panel scale", function()
  local scaleLabel = Text(parent, 12, C.muted)
  scaleLabel:SetPoint("LEFT", themeButton, "RIGHT", 22, 0)
  scaleLabel:SetText("Panel Scale")

  local scaleValue = Text(parent, 12, C.text)
  local slider = CreateFrame("Slider", nil, parent)
  slider:SetOrientation("HORIZONTAL")
  slider:SetSize(110, 16)
  slider:SetPoint("LEFT", scaleLabel, "RIGHT", 10, 0)
  slider:SetMinMaxValues(0.7, 1.3)
  slider:SetValueStep(0.05)
  Try(slider, "SetObeyStepsOnDrag", true)
  local track = slider:CreateTexture(nil, "BACKGROUND")
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  track:SetHeight(4)
  track:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)
  local thumb = slider:CreateTexture(nil, "OVERLAY")
  thumb:SetSize(8, 16)
  AccentTex(thumb)
  slider:SetThumbTexture(thumb)
  scaleValue:SetPoint("LEFT", slider, "RIGHT", 8, 0)

  slider:SetValue(TR.DB.global.panelScale or 1)
  scaleValue:SetText(string.format("%.2f", TR.DB.global.panelScale or 1))
  -- apply the new scale when the mouse is released so the window doesn't jump while dragging
  slider:SetScript("OnValueChanged", function(_, value)
    value = RoundToStep(value, 0.7, 0.05)
    scaleValue:SetText(string.format("%.2f", value))
  end)
  slider:SetScript("OnMouseUp", function(self)
    local value = RoundToStep(self:GetValue(), 0.7, 0.05)
    TR.DB.global.panelScale = value
    parent:SetScale(value)
  end)
  end)

end

local function BuildWindow()
  frame = CreateFrame("Frame", FRAME_NAME, _G.UIParent)
  frame:SetSize(WIN_W, WIN_H)
  frame:SetFrameStrata("HIGH")
  Try(frame, "SetToplevel", true)
  Try(frame, "SetClampedToScreen", true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    TR.DB.global.panelPoint = {point, relPoint, x, y}
  end)
  frame:Hide()

  Fill(frame, "BACKGROUND", C.window)
  Border(frame, C.border)

  local saved = TR.DB.global.panelPoint
  if saved then
    frame:SetPoint(saved[1], _G.UIParent, saved[2], saved[3], saved[4])
  else
    frame:SetPoint("CENTER")
  end
  frame:SetScale(TR.DB.global.panelScale or 1)

  -- Esc closes the window
  table_insert(_G.UISpecialFrames, FRAME_NAME)

  local contentLeft = MARGIN * 2 + SIDEBAR_W
  SafeBuild("sidebar", BuildSidebar, frame)
  SafeBuild("top bar", BuildTopBar, frame, contentLeft)

  -- Content panel
  local content = CreateFrame("Frame", nil, frame)
  content:SetPoint("TOPLEFT", contentLeft, -(MARGIN + TOPBAR_H))
  content:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + FOOTER_H)
  Fill(content, "BACKGROUND", C.panel)
  Border(content, C.border)

  local header = CreateFrame("Frame", nil, content)
  header:SetPoint("TOPLEFT", 1, -1)
  header:SetPoint("TOPRIGHT", -1, -1)
  header:SetHeight(66)
  Fill(header, "BACKGROUND", C.header)
  frame.pageTitle = Text(header, 22, C.text)
  frame.pageTitle:SetPoint("TOPLEFT", 16, -12)
  frame.pageSubtitle = Text(header, 12, C.muted)
  frame.pageSubtitle:SetPoint("TOPLEFT", 17, -44)

  local scroll = CreateFrame("ScrollFrame", nil, content)
  scroll:SetPoint("TOPLEFT", 16, -82)
  scroll:SetPoint("BOTTOMRIGHT", -26, 12)
  scroll:EnableMouseWheel(true)
  scroll:SetScript("OnMouseWheel", function(self, delta)
    local value = self:GetVerticalScroll() - delta * 48
    self:SetVerticalScroll(math_max(0, math_min(self:GetVerticalScrollRange(), value)))
    UpdateScrollThumb()
  end)
  scroll:SetScript("OnScrollRangeChanged", function()
    UpdateScrollThumb()
  end)
  frame.scroll = scroll

  local track = CreateFrame("Frame", nil, content)
  track:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
  track:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
  track:SetWidth(5)
  Fill(track, "BACKGROUND", C.input)
  frame.track = track

  local thumb = CreateFrame("Frame", nil, track)
  thumb:SetWidth(5)
  thumb:EnableMouse(true)
  local thumbTex = thumb:CreateTexture(nil, "ARTWORK")
  thumbTex:SetAllPoints()
  AccentTex(thumbTex, 0.8)
  thumb:SetScript("OnMouseDown", function(self)
    local _, cursorY = _G.GetCursorPosition()
    self.startY = cursorY / self:GetEffectiveScale()
    self.startScroll = scroll:GetVerticalScroll()
    self:SetScript("OnUpdate", function(s)
      local _, y = _G.GetCursorPosition()
      y = y / s:GetEffectiveScale()
      local range = scroll:GetVerticalScrollRange()
      local free = track:GetHeight() - s:GetHeight()
      if free <= 0 then
        return
      end
      local value = s.startScroll + (s.startY - y) * range / free
      scroll:SetVerticalScroll(math_max(0, math_min(range, value)))
      UpdateScrollThumb()
    end)
  end)
  thumb:SetScript("OnMouseUp", function(self)
    self:SetScript("OnUpdate", nil)
  end)
  frame.thumb = thumb

  -- Footer
  local reload = Button(frame, "Reload UI", 110, 26, function()
    _G.ReloadUI()
  end)
  reload:SetPoint("BOTTOMLEFT", contentLeft, MARGIN + 6)

  local notes = Button(frame, "Patch Notes", 110, 26, function()
    UI.ShowPage("notes")
  end)
  notes:SetPoint("BOTTOM", content, "BOTTOM", 0, -(FOOTER_H - 6))

  local closeBtn = Button(frame, "Close", 110, 26, function()
    UI.Hide()
  end)
  closeBtn:SetPoint("BOTTOMRIGHT", -MARGIN, MARGIN + 6)

  -- Close the window when combat starts (settings can't be changed in combat)
  frame:RegisterEvent("PLAYER_REGEN_DISABLED")
  frame:SetScript("OnEvent", function(self)
    if self:IsShown() then
      self:Hide()
      PrintMsg("Settings closed for combat.")
    end
  end)

  frame:SetScript("OnShow", function()
    UI.Refresh()
  end)
end

function UI.Open(pageKey)
  if InCombatLockdown() then
    PrintMsg("Cannot open settings while in combat.")
    return
  end
  -- a window whose core parts failed to build is thrown away and rebuilt
  if frame and not frame.scroll then
    frame:Hide()
    frame = nil
    navItems = {}
  end
  if not frame then
    if not SafeBuild("window", BuildWindow) or not frame or not frame.scroll then
      return
    end
  end
  frame:Show()
  UI.ShowPage(pageKey or (currentPage and currentPage.key) or "home")
end

function UI.Hide()
  if frame then
    frame:Hide()
  end
end

function UI.Toggle(pageKey)
  if frame and frame:IsShown() then
    UI.Hide()
  else
    UI.Open(pageKey)
  end
end

---------------------------------------------------------------------------------------
--                       GAME OPTIONS > ADDONS ENTRY (LAUNCHER)                      --
---------------------------------------------------------------------------------------
function UI.RegisterBlizzardPanel()
  local Settings = _G.Settings
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
    return
  end

  local panel = CreateFrame("Frame")
  panel:Hide()

  local logo = panel:CreateTexture(nil, "ARTWORK")
  logo:SetSize(72, 72)
  logo:SetPoint("TOPLEFT", 20, -20)
  logo:SetTexture(TR.Constants.Logo)

  local title = Text(panel, 22, C.text)
  title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -10)
  title:SetText("True Reticle")

  local sub = Text(panel, 12, C.muted)
  sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  sub:SetText("v" .. (TR.METADATA["VERSION"] or "?") .. "  -  settings live in their own window.")

  local open = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
  open:SetSize(200, 28)
  open:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -18)
  open:SetText("Open True Reticle")
  open:SetScript("OnClick", function()
    if _G.SettingsPanel then
      pcall(_G.HideUIPanel, _G.SettingsPanel)
    end
    UI.Open()
  end)

  local hint = Text(panel, 12, C.muted)
  hint:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -10)
  hint:SetText("Or type /tr in chat.")

  local category = Settings.RegisterCanvasLayoutCategory(panel, "True Reticle")
  Settings.RegisterAddOnCategory(category)
  TR.SettingsCategoryID = category.GetID and category:GetID() or category.ID
end
