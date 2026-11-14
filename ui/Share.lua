-- Crosshair Z
-- Profile sharing: turns a profile into a text string to copy, and reads such
-- a string back in. The format is plain data (no code is ever run on import).

local _, Z = ...
local W = Z.W
local C = W.C
local S = {}
Z.Share = S

local HEADER = "CZ1!"

---------------------------------------------------------------------------
-- Writing
---------------------------------------------------------------------------
local function Quote(s)
  s = s:gsub("\\", "\\\\"):gsub('"', '\\"'):gsub("\n", "\\n"):gsub("\r", "")
  return '"' .. s .. '"'
end

local function Write(v, out)
  local t = type(v)
  if t == "number" then
    if v == math.floor(v) then
      out[#out + 1] = string.format("%d", v)
    else
      out[#out + 1] = string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", "")
    end
  elseif t == "boolean" then
    out[#out + 1] = v and "T" or "F"
  elseif t == "string" then
    out[#out + 1] = Quote(v)
  elseif t == "table" then
    out[#out + 1] = "{"
    local keys = {}
    for k in pairs(v) do
      if type(k) == "string" or type(k) == "number" then
        keys[#keys + 1] = k
      end
    end
    table.sort(keys, function(a, b)
      if type(a) == type(b) then
        return a < b
      end
      return type(a) == "number"
    end)
    for _, k in ipairs(keys) do
      local val = v[k]
      local vt = type(val)
      if vt == "number" or vt == "boolean" or vt == "string" or vt == "table" then
        if type(k) == "number" then
          out[#out + 1] = "#" .. k
        else
          out[#out + 1] = Quote(k)
        end
        out[#out + 1] = "="
        Write(val, out)
        out[#out + 1] = ";"
      end
    end
    out[#out + 1] = "}"
  end
end

-- Only settings that differ from the defaults are written, so strings stay short
function S.Export()
  local out = {}
  Write(Z.P, out)
  return HEADER .. table.concat(out)
end

---------------------------------------------------------------------------
-- Reading (a small parser for exactly the format above)
---------------------------------------------------------------------------
local function Read(text)
  local pos = 1
  local function Fail(why)
    error("bad profile string: " .. why, 0)
  end
  local function Peek()
    return text:sub(pos, pos)
  end
  local Value
  local function String()
    pos = pos + 1
    local buf = {}
    while true do
      local ch = Peek()
      if ch == "" then
        Fail("text ends inside a quote")
      elseif ch == '"' then
        pos = pos + 1
        return table.concat(buf)
      elseif ch == "\\" then
        local nxt = text:sub(pos + 1, pos + 1)
        buf[#buf + 1] = (nxt == "n") and "\n" or nxt
        pos = pos + 2
      else
        buf[#buf + 1] = ch
        pos = pos + 1
      end
    end
  end
  local function Number()
    local s, e = text:find("^%-?%d+%.?%d*", pos)
    if not s then
      Fail("expected a number at " .. pos)
    end
    pos = e + 1
    return tonumber(text:sub(s, e))
  end
  local depth = 0
  local function Table()
    depth = depth + 1
    if depth > 12 then
      Fail("too deep")
    end
    pos = pos + 1
    local t = {}
    while Peek() ~= "}" do
      local key
      if Peek() == '"' then
        key = String()
      elseif Peek() == "#" then
        pos = pos + 1
        key = Number()
      else
        Fail("expected a name at " .. pos)
      end
      if Peek() ~= "=" then
        Fail("expected = at " .. pos)
      end
      pos = pos + 1
      t[key] = Value()
      if Peek() ~= ";" then
        Fail("expected ; at " .. pos)
      end
      pos = pos + 1
    end
    pos = pos + 1
    depth = depth - 1
    return t
  end
  Value = function()
    local ch = Peek()
    if ch == "{" then
      return Table()
    elseif ch == '"' then
      return String()
    elseif ch == "T" then
      pos = pos + 1
      return true
    elseif ch == "F" then
      pos = pos + 1
      return false
    elseif ch:match("[%-%d]") then
      return Number()
    end
    Fail("unexpected '" .. ch .. "' at " .. pos)
  end
  local result = Value()
  if pos <= #text then
    Fail("extra text at the end")
  end
  return result
end

-- Returns the settings table, or nil and a reason
function S.Decode(text)
  -- line breaks from pasting go; spaces stay (they can be part of a setting)
  text = (text or ""):gsub("[\r\n]", ""):match("^%s*(.-)%s*$")
  if text:sub(1, #HEADER) ~= HEADER then
    return nil, "This is not a Crosshair Z profile string."
  end
  local ok, result = pcall(Read, text:sub(#HEADER + 1))
  if not ok then
    return nil, tostring(result)
  end
  if type(result) ~= "table" then
    return nil, "The string holds no settings."
  end
  return result
end

local function Merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" and #v == 0 then
      Merge(dst[k], v)
    else
      dst[k] = Z.Copy(v)
    end
  end
end

-- Imports into a new profile and switches to it
function S.Import(text)
  local data, why = S.Decode(text)
  if not data then
    Z.Print("|cffff5050%s|r", why)
    return false
  end
  local n, name = 1, "Imported"
  local taken = {}
  for _, p in ipairs(Z.ProfileList()) do
    taken[p] = true
  end
  while taken[name] do
    n = n + 1
    name = "Imported " .. n
  end
  Z.db:SetProfile(name)
  Z.db:ResetProfile()
  Merge(Z.db.profile, data)
  Z.Send("PROFILE")
  Z.ApplyAll()
  Z.Print("Imported the profile as %s and switched to it.", name)
  return true
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local win
local function Window()
  if win then
    return win
  end
  win = CreateFrame("Frame", "CrosshairZShare", UIParent)
  win:SetSize(520, 330)
  win:SetPoint("CENTER", 0, 60)
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  win:EnableMouse(true)
  win:SetMovable(true)
  win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  W.Fill(win, {0.03, 0.034, 0.044, 0.99})
  W.Outline(win, C.line)
  table.insert(UISpecialFrames, "CrosshairZShare")
  win.title = W.Text(win, 15)
  win.title:SetPoint("TOPLEFT", 18, -16)
  win.hint = W.Text(win, 11, C.muted)
  win.hint:SetPoint("TOPLEFT", win.title, "BOTTOMLEFT", 0, -5)
  win.hint:SetWidth(480)
  win.hint:SetWordWrap(true)

  local field = CreateFrame("Frame", nil, win)
  field:SetPoint("TOPLEFT", 18, -66)
  field:SetPoint("BOTTOMRIGHT", -18, 56)
  W.Fill(field, C.field)
  W.Outline(field, C.line)
  local scroll = CreateFrame("ScrollFrame", nil, field, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 8, -8)
  scroll:SetPoint("BOTTOMRIGHT", -28, 8)
  local eb = CreateFrame("EditBox", nil, scroll)
  eb:SetMultiLine(true)
  eb:SetAutoFocus(false)
  eb:SetFont("Fonts\\ARIALN.TTF", 12, "")
  eb:SetTextColor(C.text[1], C.text[2], C.text[3])
  eb:SetWidth(440)
  eb:SetScript("OnEscapePressed", function()
    win:Hide()
  end)
  scroll:SetScrollChild(eb)
  field:EnableMouse(true)
  field:SetScript("OnMouseDown", function()
    eb:SetFocus()
  end)
  win.box = eb

  win.action = W.AccentButton(win, "Import", 120, 28)
  win.action:SetPoint("BOTTOMRIGHT", -18, 16)
  win.close = W.Button(win, "Close", 100, 28, function()
    win:Hide()
  end)
  win.close:SetPoint("RIGHT", win.action, "LEFT", -8, 0)
  win:Hide()
  return win
end

function S.OpenExport()
  local w = Window()
  local text = S.Export()
  w.title:SetText("Export Profile: " .. (Z.profileName or "Default"))
  w.hint:SetText("Press Ctrl+C to copy. Key bindings are not part of a profile.")
  w.box:SetText(text)
  w.action:Hide()
  w.box:SetScript("OnTextChanged", function(self, user)
    if user then
      self:SetText(text)
      self:HighlightText()
    end
  end)
  w:Show()
  w.box:SetFocus()
  w.box:HighlightText()
end

function S.OpenImport()
  local w = Window()
  w.title:SetText("Import Profile")
  w.hint:SetText("Paste a Crosshair Z profile string (Ctrl+V), then press Import. It becomes a new profile.")
  w.box:SetScript("OnTextChanged", nil)
  w.box:SetText("")
  w.action:Show()
  w.action:SetScript("OnClick", function()
    if S.Import(w.box:GetText()) then
      w:Hide()
    end
  end)
  w:Show()
  w.box:SetFocus()
end

-- /cz export and /cz import
Z.Listen("READY", function()
  Z.slashExtra = Z.slashExtra or {}
  Z.slashExtra.export = S.OpenExport
  Z.slashExtra.import = S.OpenImport
end)
