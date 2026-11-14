-- Crosshair Z
-- The settings window: a top bar with groups, a strip of pages under it, one
-- smooth-scrolling column of settings, and a footer.

local _, Z = ...
local W = Z.W
local C = W.C
local P = {}
Z.Panel = P

local WIDTH, HEIGHT = 880, 660
local PAD = 28
local COLUMN = WIDTH - PAD * 2 - 14
local TOP, STRIP, HEAD, FOOT = 56, 38, 58, 46

local frame
local pages = {}
local current, currentGroup
local groups, groupTabs, strips = {}, {}, {}

function P.IsOpen()
  return frame ~= nil and frame:IsShown()
end

---------------------------------------------------------------------------
-- Confirm dialog
---------------------------------------------------------------------------
local confirm
function P.Confirm(text, onYes)
  if not confirm then
    confirm = CreateFrame("Frame", "CrosshairZConfirm", UIParent)
    confirm:SetSize(400, 150)
    confirm:SetPoint("CENTER", 0, 100)
    confirm:SetFrameStrata("FULLSCREEN_DIALOG")
    confirm:EnableMouse(true)
    W.Fill(confirm, {0.03, 0.034, 0.044, 0.99})
    W.Outline(confirm, C.line)
    confirm.text = W.Text(confirm, 13, C.text, "CENTER")
    confirm.text:SetWordWrap(true)
    confirm.text:SetPoint("TOPLEFT", 22, -24)
    confirm.text:SetPoint("TOPRIGHT", -22, -24)
    confirm.yes = W.AccentButton(confirm, "Yes", 130, 30)
    confirm.yes:SetPoint("BOTTOMRIGHT", confirm, "BOTTOM", -6, 18)
    confirm.no = W.Button(confirm, "Cancel", 130, 30, function()
      confirm:Hide()
    end)
    confirm.no:SetPoint("BOTTOMLEFT", confirm, "BOTTOM", 6, 18)
    table.insert(UISpecialFrames, "CrosshairZConfirm")
  end
  confirm.text:SetText(text)
  confirm.yes:SetScript("OnClick", function()
    confirm:Hide()
    onYes()
  end)
  confirm:Show()
end

---------------------------------------------------------------------------
-- Pages
---------------------------------------------------------------------------
local function PageByKey(key)
  for _, page in ipairs(Z.Pages) do
    if page.key == key then
      return page
    end
  end
end

local function BuildPage(page)
  local host = CreateFrame("Frame", nil, frame.view)
  host:SetWidth(COLUMN)
  local list = {}
  local y = 0
  if page.build then
    y = -(page.build(host, COLUMN, list) or 0)
  else
    for _, card in ipairs(W.Resolve(page.cards) or {}) do
      local f, h = W.Card(host, card, COLUMN, list)
      f:SetPoint("TOPLEFT", 0, y)
      if card.visible then
        list[#list + 1] = function()
          f:SetShown(card.visible())
        end
      end
      y = y - h - 14
    end
  end
  host:SetHeight(math.max(10, -y + 10))
  host.tall = math.max(10, -y + 10)
  host.refreshers = list
  host.key = {}
  return host
end

-- smooth scrolling
local scrollKey = {}
local function ScrollTo(target, snap)
  local view = frame.view
  local host = current and pages[current]
  local range = math.max(0, (host and host.tall or 0) - (HEIGHT - TOP - STRIP - HEAD - FOOT))
  view.goal = Z.Clamp(target, 0, range)
  W.Glide(scrollKey, view.goal, function(v)
    view:SetVerticalScroll(v)
    if range > 0 then
      local space = (HEIGHT - TOP - STRIP - HEAD - FOOT)
      local size = math.max(30, space * space / (space + range))
      frame.thumb:SetHeight(size)
      frame.thumb:ClearAllPoints()
      frame.thumb:SetPoint("TOPRIGHT", view, "TOPRIGHT", 10, -(space - size) * (v / range))
      frame.thumb:Show()
    else
      frame.thumb:Hide()
    end
  end, 12, snap)
end

function P.Refresh()
  if not P.IsOpen() then
    return
  end
  if current and pages[current] then
    for _, fn in ipairs(pages[current].refreshers) do
      pcall(fn)
    end
  end
  frame.profile:SetText("Profile  " .. W.AccentHex() .. (Z.profileName or "Default") .. "|r")
end

local function Remember(key)
  local recent = Z.G.recent
  for i = #recent, 1, -1 do
    if recent[i] == key then
      table.remove(recent, i)
    end
  end
  table.insert(recent, 1, key)
  while #recent > 4 do
    table.remove(recent)
  end
end

local markKey = {}
local function SelectGroup(name)
  local tab = groupTabs[name]
  local fromX, fromW = frame.mark.x or tab.x, frame.mark.w or tab.w
  local function Paint(k)
    local x = fromX + (tab.x - fromX) * k
    local w = fromW + (tab.w - fromW) * k
    frame.mark.x, frame.mark.w = x, w
    frame.mark:ClearAllPoints()
    frame.mark:SetPoint("BOTTOMLEFT", frame.tabs, "BOTTOMLEFT", x, 0)
    frame.mark:SetWidth(math.max(1, w))
  end
  W.Glide(markKey, 0, Paint, 14, true)
  W.Glide(markKey, 1, Paint, 14, currentGroup == nil)
  currentGroup = name
  for n, t in pairs(groupTabs) do
    if n == name then
      t.text:SetTextColor(1, 1, 1)
    else
      t.text:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    end
  end
  for n, s in pairs(strips) do
    s:SetShown(n == name)
  end
end

function P.Show(key)
  local page = PageByKey(key) or Z.Pages[1]
  key = page.key
  for _, f in pairs(pages) do
    f:Hide()
  end
  if not pages[key] then
    pages[key] = BuildPage(page)
  end
  local host = pages[key]
  host:ClearAllPoints()
  host:SetPoint("TOPLEFT")
  host:Show()
  frame.view:SetScrollChild(host)
  current = key
  SelectGroup(page.section)
  for _, pill in ipairs(strips[page.section].pills) do
    pill:Update()
  end
  frame.title:SetText(page.title)
  frame.subtitle:SetText(page.subtitle or "")
  ScrollTo(0, true)
  W.Glide(host.key, 0, function(v)
    host:SetAlpha(v)
  end, 10, true)
  W.Glide(host.key, 1, function(v)
    host:SetAlpha(v)
  end, 10)
  if key ~= "home" and key ~= "notes" then
    Remember(key)
  end
  P.Refresh()
end

-- Profile and theme changes rebuild pages so every value and color is fresh
function P.Rebuild()
  for k, f in pairs(pages) do
    f:Hide()
    f:SetParent(nil)
    pages[k] = nil
  end
  if frame then
    frame.mark:SetColorTexture(W.Accent())
    frame.thumb:SetColorTexture(1, 1, 1, 0.25)
  end
  if P.IsOpen() then
    P.Show(current)
  end
end
Z.Listen("PROFILE", function()
  P.Rebuild()
end)

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local function Pill(parent, page, x)
  local b = CreateFrame("Button", nil, parent)
  local text = W.Text(b, 12, C.text, "CENTER")
  text:SetPoint("CENTER")
  text:SetText(page.title)
  local w = W.TextWidth(text, page.title) + 26
  b:SetSize(w, 24)
  b:SetPoint("LEFT", x, 0)
  W.Wash(b, 0.04, 0.12)
  b.on = b:CreateTexture(nil, "BACKGROUND", nil, 1)
  b.on:SetAllPoints()
  b:SetScript("OnClick", function()
    P.Show(page.key)
  end)
  function b:Update()
    local r, g, bl = W.Accent()
    if current == page.key then
      self.on:SetColorTexture(r, g, bl, 0.22)
      text:SetTextColor(1, 1, 1)
    else
      self.on:SetColorTexture(0, 0, 0, 0)
      text:SetTextColor(C.muted[1] + 0.12, C.muted[2] + 0.12, C.muted[3] + 0.12)
    end
  end
  return b, w
end

local function Build()
  frame = CreateFrame("Frame", "CrosshairZPanel", UIParent)
  frame:SetSize(WIDTH, HEIGHT)
  frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 0)
  frame:SetFrameStrata("DIALOG")
  frame:SetClampedToScreen(true)
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  W.Fill(frame, C.bg)
  W.Outline(frame, C.line)
  table.insert(UISpecialFrames, "CrosshairZPanel")
  frame.key = {}

  -- top bar: logo, name, groups
  local top = CreateFrame("Frame", nil, frame)
  top:SetPoint("TOPLEFT")
  top:SetPoint("TOPRIGHT")
  top:SetHeight(TOP)
  W.Fill(top, C.bar)
  local logo = top:CreateTexture(nil, "ARTWORK")
  logo:SetSize(34, 34)
  logo:SetPoint("LEFT", PAD - 8, 0)
  logo:SetTexture(Z.MEDIA .. "logo")
  local name = W.Text(top, 15)
  name:SetPoint("LEFT", logo, "RIGHT", 10, 6)
  name:SetText("Crosshair " .. Z.GREEN .. "Z|r")
  local ver = W.Text(top, 10, C.muted)
  ver:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -2)
  ver:SetText("v" .. Z.version)
  local close = W.Button(top, "X", 28, 28, function()
    P.Hide()
  end)
  close:SetPoint("RIGHT", -14, 0)

  frame.tabs = CreateFrame("Frame", nil, top)
  frame.tabs:SetPoint("BOTTOMLEFT", 190, 0)
  frame.tabs:SetPoint("BOTTOMRIGHT", -60, 0)
  frame.tabs:SetHeight(TOP)

  for _, page in ipairs(Z.Pages) do
    if not strips[page.section] then
      groups[#groups + 1] = page.section
      local strip = CreateFrame("Frame", nil, frame)
      strip:SetPoint("TOPLEFT", PAD, -TOP - 7)
      strip:SetPoint("TOPRIGHT", -PAD, -TOP - 7)
      strip:SetHeight(24)
      strip.pills, strip.x = {}, 0
      strips[page.section] = strip
    end
    local strip = strips[page.section]
    local pill, w = Pill(strip, page, strip.x)
    strip.x = strip.x + w + 6
    strip.pills[#strip.pills + 1] = pill
  end

  local x = 0
  for _, group in ipairs(groups) do
    local b = CreateFrame("Button", nil, frame.tabs)
    b.text = W.Text(b, 13, C.muted, "CENTER")
    b.text:SetPoint("CENTER", 0, -2)
    b.text:SetText(group)
    b.w = W.TextWidth(b.text, group) + 30
    b.x = x
    b:SetSize(b.w, TOP)
    b:SetPoint("BOTTOMLEFT", x, 0)
    W.Wash(b, 0, 0.05)
    local first = strips[group].pills[1]
    b:SetScript("OnClick", function()
      first:GetScript("OnClick")()
    end)
    groupTabs[group] = b
    x = x + b.w
  end
  frame.mark = frame.tabs:CreateTexture(nil, "OVERLAY")
  frame.mark:SetHeight(2)
  frame.mark:SetColorTexture(W.Accent())

  -- page heading
  frame.title = W.Text(frame, 20)
  frame.title:SetPoint("TOPLEFT", PAD, -TOP - STRIP - 12)
  frame.subtitle = W.Text(frame, 11, C.muted)
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)

  -- the column
  frame.view = CreateFrame("ScrollFrame", "CrosshairZPanelScroll", frame)
  frame.view:SetPoint("TOPLEFT", PAD, -TOP - STRIP - HEAD)
  frame.view:SetPoint("BOTTOMRIGHT", -PAD - 14, FOOT)
  frame.view:EnableMouseWheel(true)
  frame.view.goal = 0
  frame.view:SetScript("OnMouseWheel", function(self, delta)
    ScrollTo((self.goal or 0) - delta * 90)
  end)
  frame.thumb = frame:CreateTexture(nil, "OVERLAY")
  frame.thumb:SetWidth(3)
  frame.thumb:SetColorTexture(1, 1, 1, 0.25)
  frame.thumb:Hide()

  -- footer
  local foot = CreateFrame("Frame", nil, frame)
  foot:SetPoint("BOTTOMLEFT")
  foot:SetPoint("BOTTOMRIGHT")
  foot:SetHeight(FOOT - 6)
  W.Fill(foot, C.bar)
  frame.profile = W.Text(foot, 12, C.muted)
  frame.profile:SetPoint("LEFT", PAD, 0)
  local done = W.AccentButton(foot, "Close", 100, 26, function()
    P.Hide()
  end)
  done:SetPoint("RIGHT", -14, 0)
  local wizard = W.Button(foot, "Setup Wizard", 120, 26, function()
    P.Hide()
    Z.Wizard.Open()
  end)
  wizard:SetPoint("RIGHT", done, "LEFT", -8, 0)

  frame:SetScript("OnHide", function()
    if _G.CrosshairZDropdown then
      _G.CrosshairZDropdown:Hide()
    end
    Z.ApplyAll()
  end)
end

function P.Open(key)
  if InCombatLockdown() then
    Z.Print("Settings can't open in combat.")
    return
  end
  if not frame then
    Build()
  end
  frame:SetScale(Z.G.panelScale or 1)
  local wasOpen = frame:IsShown()
  frame:Show()
  if not wasOpen then
    W.Glide(frame.key, 0, function(v)
      frame:SetAlpha(v)
    end, 12, true)
    W.Glide(frame.key, 1, function(v)
      frame:SetAlpha(v)
    end, 12)
  end
  P.Show(key or current or "home")
  Z.ApplyAll()
end

function P.Hide()
  if frame then
    frame:Hide()
  end
end

function P.Toggle(key)
  if P.IsOpen() and (not key or key == current) then
    P.Hide()
  else
    P.Open(key)
  end
end

function P.Rescale()
  if frame then
    frame:SetScale(Z.G.panelScale or 1)
  end
end

-- close when combat starts (nothing in here may change in combat anyway)
Z.On("PLAYER_REGEN_DISABLED", function()
  if P.IsOpen() then
    P.Hide()
    Z.Print("Settings closed for combat.")
  end
end)
