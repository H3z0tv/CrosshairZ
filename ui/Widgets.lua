-- Crosshair Z
-- Settings window controls. Flat rows: name on the left, control on the right.
-- Everything that moves (switches, sliders, hover, lists) glides instead of jumping.

local _, Z = ...
local W = {}
Z.W = W

local FONT = STANDARD_TEXT_FONT

W.C = {
  bg = {0.03, 0.034, 0.044, 0.97},
  bar = {0.015, 0.018, 0.024, 1},
  card = {1, 1, 1, 0.04},
  line = {1, 1, 1, 0.1},
  field = {0, 0, 0, 0.5},
  text = {0.94, 0.95, 0.97},
  muted = {0.56, 0.6, 0.66},
  off = {0.27, 0.29, 0.33}
}
local C = W.C

W.THEMES = {
  green = {"Crosshair Green", 0.49, 1, 0.31},
  ice = {"Ice Blue", 0.38, 0.76, 1},
  gold = {"Satin Gold", 0.85, 0.72, 0.45},
  crimson = {"Crimson", 0.92, 0.22, 0.34},
  violet = {"Violet", 0.66, 0.5, 1}
}

function W.Accent()
  local t = W.THEMES[Z.G and Z.G.theme or "green"] or W.THEMES.green
  return t[2], t[3], t[4]
end

function W.AccentHex()
  local r, g, b = W.Accent()
  local function B(v)
    return math.floor(v * 255 + 0.5)
  end
  return string.format("|cff%02x%02x%02x", B(r), B(g), B(b))
end

---------------------------------------------------------------------------
-- Glide: moves a value toward its goal a little every frame
---------------------------------------------------------------------------
local driver = CreateFrame("Frame")
local gliding = {}
driver:SetScript("OnUpdate", function(_, e)
  for key, t in pairs(gliding) do
    local d = t.to - t.v
    if math.abs(d) < 0.002 then
      t.v = t.to
      gliding[key] = nil
    else
      t.v = t.v + d * math.min(1, e * t.speed)
    end
    if not pcall(t.fn, t.v) then
      gliding[key] = nil
    end
  end
end)

-- key: any table that stands for this animation. The first call jumps straight
-- to the goal; later calls glide. snap = true forces a jump.
function W.Glide(key, to, fn, speed, snap)
  local t = key.__glide
  if not t then
    t = {v = to}
    key.__glide = t
    snap = true
  end
  t.to, t.fn, t.speed = to, fn, speed or 14
  if snap then
    t.v = to
    gliding[key] = nil
    fn(to)
  else
    gliding[key] = t
  end
end

---------------------------------------------------------------------------
-- Primitives
---------------------------------------------------------------------------
function W.Fill(frame, color, layer)
  local t = frame:CreateTexture(nil, layer or "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(color[1], color[2], color[3], color[4] or 1)
  return t
end

function W.Outline(frame, color)
  local parts = {}
  local function Edge(p1, p2, horizontal)
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetPoint(p1)
    t:SetPoint(p2)
    if horizontal then
      t:SetHeight(1)
    else
      t:SetWidth(1)
    end
    parts[#parts + 1] = t
  end
  Edge("TOPLEFT", "TOPRIGHT", true)
  Edge("BOTTOMLEFT", "BOTTOMRIGHT", true)
  Edge("TOPLEFT", "BOTTOMLEFT", false)
  Edge("TOPRIGHT", "BOTTOMRIGHT", false)
  function frame:SetOutline(r, g, b, a)
    for _, t in ipairs(parts) do
      t:SetColorTexture(r, g, b, a or 1)
    end
  end
  frame:SetOutline(color[1], color[2], color[3], color[4])
end

function W.Text(parent, size, color, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY")
  fs:SetFont(FONT, size or 12, "")
  local c = color or C.text
  fs:SetTextColor(c[1], c[2], c[3])
  fs:SetJustifyH(justify or "LEFT")
  fs:SetWordWrap(false)
  return fs
end

function W.TextWidth(fs, text)
  local w = fs:GetStringWidth() or 0
  if w < 4 then
    w = #(text or "") * 7
  end
  return w
end

-- A white wash that fades in under the mouse
local function Wash(frame, rest, over)
  local t = frame:CreateTexture(nil, "BACKGROUND")
  t:SetAllPoints()
  t:SetColorTexture(1, 1, 1, 1)
  local key = {}
  local function Paint(v)
    t:SetAlpha(v)
  end
  W.Glide(key, rest, Paint, 18, true)
  frame:HookScript("OnEnter", function()
    W.Glide(key, over, Paint, 18)
  end)
  frame:HookScript("OnLeave", function()
    W.Glide(key, rest, Paint, 12)
  end)
  return t
end
W.Wash = Wash

function W.Tip(frame, title, body)
  frame:HookScript("OnEnter", function(self)
    local t = type(title) == "function" and title() or title
    local b = type(body) == "function" and body() or body
    if not b then
      return
    end
    GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
    if t then
      GameTooltip:AddLine(t, 1, 1, 1)
    end
    GameTooltip:AddLine(b, C.muted[1], C.muted[2], C.muted[3], true)
    GameTooltip:Show()
  end)
  frame:HookScript("OnLeave", function()
    GameTooltip:Hide()
  end)
end

function W.Button(parent, label, width, height, onClick)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 120, height or 28)
  b.bg = Wash(b, 0.07, 0.16)
  W.Outline(b, C.line)
  b.label = W.Text(b, 12, C.text, "CENTER")
  b.label:SetPoint("CENTER")
  b.label:SetText(label or "")
  if onClick then
    b:SetScript("OnClick", onClick)
  end
  function b:SetLabel(text)
    self.label:SetText(text)
  end
  return b
end

function W.AccentButton(parent, label, width, height, onClick)
  local b = W.Button(parent, label, width, height, onClick)
  local r, g, bl = W.Accent()
  local tint = b:CreateTexture(nil, "BACKGROUND", nil, 1)
  tint:SetAllPoints()
  tint:SetColorTexture(r, g, bl, 0.22)
  b:SetOutline(r, g, bl, 0.7)
  b.label:SetTextColor(1, 1, 1)
  return b
end

function W.EditBox(parent)
  local eb = CreateFrame("EditBox", nil, parent)
  eb:SetAutoFocus(false)
  eb:SetFont(FONT, 12, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  eb:SetTextInsets(8, 8, 0, 0)
  W.Fill(eb, C.field)
  W.Outline(eb, C.line)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  return eb
end

---------------------------------------------------------------------------
-- Value access
---------------------------------------------------------------------------
local function Resolve(v)
  if type(v) == "function" then
    return v()
  end
  return v
end
W.Resolve = Resolve

local function Get(item)
  if item.get then
    return item.get()
  end
  return item.path and Z.Get(item.path)
end

local function Set(item, value)
  if item.set then
    item.set(value)
  elseif item.path then
    Z.Set(item.path, value)
  end
  if item.after then
    item.after(value)
  end
  if Z.Panel then
    Z.Panel.Refresh()
  end
end

local function Off(item)
  return item.disabled and item.disabled() or false
end

local function Dim(f, item)
  f:SetAlpha(Off(item) and 0.35 or 1)
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------
local ROW, SIDE, INSET = 34, 220, 12

local function Row(parent, item, kind)
  local f = CreateFrame(kind or "Frame", nil, parent)
  f:SetHeight(ROW)
  f:EnableMouse(true)
  Wash(f, 0.035, 0.085)
  f.label = W.Text(f, 12)
  f.label:SetPoint("LEFT", INSET, 0)
  f.label:SetPoint("RIGHT", -(SIDE + INSET * 2), 0)
  f.label:SetText(Resolve(item.label) or "")
  W.Tip(f, function()
    return Resolve(item.label)
  end, function()
    return Resolve(item.desc)
  end)
  return f
end

local function SideButton(row)
  local b = CreateFrame("Button", nil, row)
  b:SetSize(SIDE, 22)
  b:SetPoint("RIGHT", -INSET, 0)
  W.Fill(b, C.field)
  W.Outline(b, C.line)
  Wash(b, 0, 0.08)
  b.text = W.Text(b, 12, C.text, "CENTER")
  b.text:SetPoint("LEFT", 8, 0)
  b.text:SetPoint("RIGHT", -8, 0)
  return b
end

local Make = {}
W.Make = Make

function Make.toggle(parent, item)
  local f = Row(parent, item, "Button")
  local sw = CreateFrame("Frame", nil, f)
  sw:SetSize(36, 18)
  sw:SetPoint("RIGHT", -INSET, 0)
  local track = sw:CreateTexture(nil, "ARTWORK")
  track:SetAllPoints()
  local knob = sw:CreateTexture(nil, "OVERLAY")
  knob:SetSize(14, 14)
  knob:SetColorTexture(1, 1, 1, 1)
  local key = {}
  local function Paint(v)
    local r, g, b = W.Accent()
    local o = C.off
    track:SetColorTexture(o[1] + (r * 0.85 - o[1]) * v, o[2] + (g * 0.85 - o[2]) * v, o[3] + (b * 0.85 - o[3]) * v, 1)
    knob:ClearAllPoints()
    knob:SetPoint("LEFT", sw, "LEFT", 2 + 18 * v, 0)
  end
  f:SetScript("OnClick", function()
    if not Off(item) then
      Set(item, not Get(item))
    end
  end)
  function f.Refresh()
    W.Glide(key, Get(item) and 1 or 0, Paint, 16)
    Dim(f, item)
  end
  return f, ROW
end

local TRACK = 150
function Make.slider(parent, item)
  local f = Row(parent, item)
  local min, max, step = item.min or 0, item.max or 1, item.step or 0.01
  local value = W.Text(f, 12, C.muted, "RIGHT")
  value:SetPoint("RIGHT", -INSET, 0)
  value:SetWidth(50)
  local track = CreateFrame("Frame", nil, f)
  track:SetSize(TRACK, 18)
  track:SetPoint("RIGHT", -(INSET + 62), 0)
  track:EnableMouse(true)
  local line = track:CreateTexture(nil, "ARTWORK")
  line:SetHeight(3)
  line:SetPoint("LEFT")
  line:SetPoint("RIGHT")
  line:SetColorTexture(1, 1, 1, 0.13)
  local fill = track:CreateTexture(nil, "ARTWORK", nil, 1)
  fill:SetHeight(3)
  fill:SetPoint("LEFT")
  local knob = track:CreateTexture(nil, "OVERLAY")
  knob:SetSize(22, 22)
  knob:SetTexture(Z.MEDIA .. "pip")

  local function Format(v)
    if item.pct then
      return string.format("%d%%", math.floor(v * 100 + 0.5))
    elseif step >= 1 then
      return tostring(math.floor(v + 0.5))
    end
    return string.format("%.2f", v)
  end

  local key = {}
  local function Paint(k)
    local r, g, b = W.Accent()
    fill:SetColorTexture(r, g, b, 1)
    fill:SetWidth(math.max(1, TRACK * k))
    knob:ClearAllPoints()
    knob:SetPoint("CENTER", track, "LEFT", TRACK * k, 0)
  end

  local dragging = false
  local function FromCursor()
    local scale = track:GetEffectiveScale() or 1
    local x = GetCursorPosition() / scale
    local left = track:GetLeft() or 0
    local k = Z.Clamp((x - left) / TRACK, 0, 1)
    local v = min + (max - min) * k
    v = Z.Clamp(math.floor(v / step + 0.5) * step, min, max)
    if v ~= Get(item) then
      Set(item, v)
    end
  end
  track:SetScript("OnMouseDown", function()
    if not Off(item) then
      dragging = true
      FromCursor()
    end
  end)
  track:SetScript("OnMouseUp", function()
    dragging = false
  end)
  track:SetScript("OnUpdate", function()
    if dragging then
      if IsMouseButtonDown("LeftButton") then
        FromCursor()
      else
        dragging = false
      end
    end
  end)

  function f.Refresh()
    local v = Get(item) or min
    W.Glide(key, Z.Clamp((v - min) / (max - min), 0, 1), Paint, dragging and 40 or 14)
    value:SetText(Format(v))
    Dim(f, item)
  end
  return f, ROW
end

-- One shared list for every dropdown
local list
local function ListFrame()
  if list then
    return list
  end
  list = CreateFrame("Frame", "CrosshairZDropdown", UIParent)
  list:SetFrameStrata("FULLSCREEN_DIALOG")
  list:SetClampedToScreen(true)
  list:EnableMouse(true)
  W.Fill(list, {0.04, 0.045, 0.058, 0.98})
  W.Outline(list, C.line)
  list.rows = {}
  list.key = {}
  list:Hide()
  list:SetScript("OnUpdate", function(self)
    if IsMouseButtonDown("LeftButton") and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
      self:Hide()
    end
  end)
  return list
end

local function OpenList(owner, choices, current, onPick)
  local l = ListFrame()
  if l:IsShown() and l.owner == owner then
    l:Hide()
    return
  end
  l.owner = owner
  l:SetScale((owner:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1))
  local rowH, maxRows = 22, 14
  local n = #choices
  local cols = math.max(1, math.ceil(n / maxRows))
  local colW = math.max(owner:GetWidth() or 0, 170)
  for i, choice in ipairs(choices) do
    local row = l.rows[i]
    if not row then
      row = CreateFrame("Button", nil, l)
      row:SetHeight(rowH)
      Wash(row, 0, 0.1)
      row.text = W.Text(row, 12)
      row.text:SetPoint("LEFT", 10, 0)
      row.text:SetPoint("RIGHT", -8, 0)
      l.rows[i] = row
    end
    row:SetWidth(colW - 4)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 2 + math.floor((i - 1) / maxRows) * colW, -2 - ((i - 1) % maxRows) * rowH)
    if choice[1] == current then
      row.text:SetTextColor(W.Accent())
    else
      row.text:SetTextColor(C.text[1], C.text[2], C.text[3])
    end
    row.text:SetText(choice[2])
    row:SetScript("OnClick", function()
      l:Hide()
      onPick(choice[1])
    end)
    row:Show()
  end
  for i = n + 1, #l.rows do
    l.rows[i]:Hide()
  end
  l:SetSize(cols * colW + 4, math.min(n, maxRows) * rowH + 4)
  l:ClearAllPoints()
  l:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -3)
  l:Show()
  W.Glide(l.key, 0, function(v)
    l:SetAlpha(v)
  end, 16, true)
  W.Glide(l.key, 1, function(v)
    l:SetAlpha(v)
  end, 16)
end
W.OpenList = OpenList

local function Choices(item)
  local raw = Resolve(item.choices) or {}
  if raw[1] then
    return raw
  end
  local out = {}
  for k, v in pairs(raw) do
    out[#out + 1] = {k, v}
  end
  table.sort(out, function(a, b)
    return tostring(a[2]) < tostring(b[2])
  end)
  return out
end

function Make.select(parent, item)
  local f = Row(parent, item)
  local btn = SideButton(f)
  btn.text:SetJustifyH("LEFT")
  local arrow = W.Text(btn, 9, C.muted, "RIGHT")
  arrow:SetPoint("RIGHT", -8, 0)
  arrow:SetText("v")
  btn:SetScript("OnClick", function()
    if not Off(item) then
      OpenList(btn, Choices(item), Get(item), function(v)
        Set(item, v)
      end)
    end
  end)
  function f.Refresh()
    local v = Get(item)
    local label = v ~= nil and tostring(v) or "Choose..."
    for _, c in ipairs(Choices(item)) do
      if c[1] == v then
        label = c[2]
      end
    end
    btn.text:SetText(label)
    Dim(f, item)
  end
  return f, ROW
end

function Make.color(parent, item)
  local f = Row(parent, item, "Button")
  local swatch = CreateFrame("Frame", nil, f)
  swatch:SetSize(44, 16)
  swatch:SetPoint("RIGHT", -INSET, 0)
  local paint = W.Fill(swatch, {1, 1, 1, 1}, "ARTWORK")
  W.Outline(swatch, C.line)
  f:SetScript("OnClick", function()
    if Off(item) then
      return
    end
    local c = Get(item) or {1, 1, 1}
    local before = {c[1], c[2], c[3]}
    local function Use(r, g, b)
      Set(item, {r, g, b})
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({
        r = c[1], g = c[2], b = c[3], hasOpacity = false,
        swatchFunc = function()
          Use(ColorPickerFrame:GetColorRGB())
        end,
        cancelFunc = function()
          Use(before[1], before[2], before[3])
        end
      })
    else
      ColorPickerFrame.func = function()
        Use(ColorPickerFrame:GetColorRGB())
      end
      ColorPickerFrame.cancelFunc = function()
        Use(before[1], before[2], before[3])
      end
      ColorPickerFrame.hasOpacity = false
      ColorPickerFrame:SetColorRGB(c[1], c[2], c[3])
      ColorPickerFrame:Show()
    end
  end)
  function f.Refresh()
    local c = Get(item) or {1, 1, 1}
    paint:SetColorTexture(c[1], c[2], c[3], 1)
    Dim(f, item)
  end
  return f, ROW
end

-- Key capture for a game binding (item.binding)
function Make.key(parent, item)
  local f = Row(parent, item)
  local btn = SideButton(f)
  btn:RegisterForClicks("AnyUp")
  local waiting = false

  local function Stop()
    waiting = false
    btn:EnableKeyboard(false)
    btn:SetScript("OnKeyDown", nil)
    f.Refresh()
  end

  local function Bind(key)
    Stop()
    if InCombatLockdown() then
      Z.Print("Keys can't be changed in combat.")
      return
    end
    local old1, old2 = GetBindingKey(item.binding)
    if old1 then
      SetBinding(old1)
    end
    if old2 then
      SetBinding(old2)
    end
    if key then
      SetBinding(key, item.binding)
    end
    SaveBindings(GetCurrentBindingSet())
    if Z.Panel then
      Z.Panel.Refresh()
    end
  end

  local IGNORE = {LSHIFT = 1, RSHIFT = 1, LCTRL = 1, RCTRL = 1, LALT = 1, RALT = 1, UNKNOWN = 1}
  local function WithMods(key)
    if IGNORE[key] then
      return nil
    end
    return (IsAltKeyDown() and "ALT-" or "") .. (IsControlKeyDown() and "CTRL-" or "") ..
             (IsShiftKeyDown() and "SHIFT-" or "") .. key
  end

  local MOUSE = {MiddleButton = "BUTTON3", Button4 = "BUTTON4", Button5 = "BUTTON5"}
  btn:SetScript("OnClick", function(_, mouse)
    if Off(item) then
      return
    end
    if waiting then
      if MOUSE[mouse] then
        Bind(WithMods(MOUSE[mouse]))
      elseif mouse == "RightButton" then
        Stop()
      end
      return
    end
    if mouse == "RightButton" then
      Bind(nil)
      return
    end
    waiting = true
    btn.text:SetText("Press a key...")
    btn.text:SetTextColor(W.Accent())
    btn:EnableKeyboard(true)
    btn:SetScript("OnKeyDown", function(_, key)
      if key == "ESCAPE" then
        Stop()
      else
        local full = WithMods(key)
        if full then
          Bind(full)
        end
      end
    end)
  end)
  W.Tip(btn, function()
    return Resolve(item.label)
  end, "Click, then press a key or a mouse button. Right-click clears it. Esc cancels.")

  function f.Refresh()
    if not waiting then
      local key = GetBindingKey(item.binding)
      btn.text:SetText(key and ((GetBindingText and GetBindingText(key)) or key) or "Not set")
      if key then
        btn.text:SetTextColor(C.text[1], C.text[2], C.text[3])
      else
        btn.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
      end
    end
    Dim(f, item)
  end
  return f, ROW
end

function Make.input(parent, item)
  local f = Row(parent, item)
  local eb = W.EditBox(f)
  eb:SetSize(SIDE, 22)
  eb:SetPoint("RIGHT", -INSET, 0)
  local cancelled = false
  local function Revert()
    eb:SetText(tostring(Get(item) or ""))
  end
  eb:SetScript("OnEnterPressed", eb.ClearFocus)
  eb:SetScript("OnEscapePressed", function(self)
    cancelled = true
    self:ClearFocus()
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    if cancelled then
      cancelled = false
      Revert()
      return
    end
    local v = self:GetText()
    if v ~= tostring(Get(item) or "") then
      Set(item, v)
    end
  end)
  function f.Refresh()
    if not eb:HasFocus() then
      Revert()
    end
    eb:SetEnabled(not Off(item))
    Dim(f, item)
  end
  return f, ROW
end

function Make.multiline(parent, item)
  local h = item.height or 90
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(h + 26)
  local label = W.Text(f, 12)
  label:SetPoint("TOPLEFT", INSET, -4)
  label:SetText(Resolve(item.label) or "")
  local field = CreateFrame("Frame", nil, f)
  field:SetPoint("TOPLEFT", 0, -22)
  field:SetPoint("BOTTOMRIGHT", 0, 0)
  W.Fill(field, C.field)
  W.Outline(field, C.line)
  field:EnableMouse(true)
  local eb = CreateFrame("EditBox", nil, field)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFont("Fonts\\ARIALN.TTF", 13, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  eb:SetPoint("TOPLEFT", 8, -6)
  eb:SetPoint("BOTTOMRIGHT", -8, 6)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  eb:SetScript("OnEditFocusLost", function(self)
    local v = self:GetText()
    if v ~= (Get(item) or "") then
      Set(item, v)
    end
  end)
  field:SetScript("OnMouseDown", function()
    eb:SetFocus()
  end)
  function f.Refresh()
    if not eb:HasFocus() then
      eb:SetText(Get(item) or "")
    end
    Dim(f, item)
  end
  return f, h + 26
end

function Make.text(parent, item, width)
  local f = CreateFrame("Frame", nil, parent)
  local fs = W.Text(f, item.size or 12, item.color or C.muted)
  fs:SetWordWrap(true)
  fs:SetPoint("TOPLEFT", INSET, -2)
  fs:SetWidth(width - INSET * 2)
  fs:SetText(Resolve(item.label) or "")
  local lines = select(2, (Resolve(item.label) or ""):gsub("\n", "\n")) + 1
  local h = math.max(lines * 15, fs:GetStringHeight() or 0) + 8
  f:SetHeight(h)
  function f.Refresh()
    fs:SetText(Resolve(item.label) or "")
  end
  return f, h
end

function Make.custom(parent, item, width)
  return item.build(parent, width)
end

-- A run of buttons shares one row
local function ButtonRow(parent, items, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetHeight(ROW)
  local gap = 8
  local bw = math.min(190, (width - gap * (#items - 1)) / #items)
  local buttons = {}
  for i, item in ipairs(items) do
    local b = (item.accent and W.AccentButton or W.Button)(f, Resolve(item.label), bw, 28, function()
      if Off(item) then
        return
      end
      local function Run()
        item.func()
        if Z.Panel then
          Z.Panel.Refresh()
        end
      end
      if item.confirm then
        Z.Panel.Confirm(Resolve(item.confirm), Run)
      else
        Run()
      end
    end)
    b:SetPoint("LEFT", (i - 1) * (bw + gap), 0)
    W.Tip(b, function()
      return Resolve(item.label)
    end, function()
      return Resolve(item.desc)
    end)
    buttons[i] = {b, item}
  end
  function f.Refresh()
    for _, pair in ipairs(buttons) do
      pair[1]:SetLabel(Resolve(pair[2].label))
      Dim(pair[1], pair[2])
    end
  end
  return f, ROW
end

---------------------------------------------------------------------------
-- Section: a heading, an optional note and a stack of rows
---------------------------------------------------------------------------
function W.Card(parent, card, width, refreshers)
  local f = CreateFrame("Frame", nil, parent)
  local y = 0
  if card.title then
    local t = W.Text(f, 11)
    t:SetPoint("TOPLEFT", 2, y - 4)
    t:SetText(W.AccentHex() .. tostring(Resolve(card.title)):upper() .. "|r")
    local rule = f:CreateTexture(nil, "ARTWORK")
    rule:SetHeight(1)
    rule:SetPoint("TOPLEFT", 0, y - 22)
    rule:SetPoint("TOPRIGHT", 0, y - 22)
    rule:SetColorTexture(1, 1, 1, 0.1)
    y = y - 28
  end
  if card.note then
    local n = W.Text(f, 11, C.muted)
    n:SetWordWrap(true)
    n:SetWidth(width - 4)
    n:SetPoint("TOPLEFT", 2, y)
    n:SetText(Resolve(card.note))
    local approx = math.ceil(#Resolve(card.note) * 6 / (width - 4)) * 14
    y = y - math.max(approx, n:GetStringHeight() or 0) - 8
  end

  local items = card.items or {}
  local i = 1
  while i <= #items do
    local item = items[i]
    local ctrl, h
    if item.type == "button" then
      local run = {}
      while items[i] and items[i].type == "button" and #run < 4 do
        run[#run + 1] = items[i]
        i = i + 1
      end
      ctrl, h = ButtonRow(f, run, width)
    else
      i = i + 1
      local maker = Make[item.type]
      if maker then
        ctrl, h = maker(f, item, width)
      end
    end
    if ctrl then
      ctrl:SetWidth(width)
      ctrl:ClearAllPoints()
      ctrl:SetPoint("TOPLEFT", 0, y)
      if ctrl.Refresh then
        refreshers[#refreshers + 1] = ctrl.Refresh
      end
      if item.visible then
        refreshers[#refreshers + 1] = function()
          ctrl:SetShown(item.visible())
        end
      end
      y = y - (h or ctrl:GetHeight()) - 2
    end
  end
  local height = -y + 6
  f:SetSize(width, height)
  return f, height
end
