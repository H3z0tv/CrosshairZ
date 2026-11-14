-- Crosshair Z
-- Home page, Patch Notes page, Setup Wizard, What's New popup and the button
-- in the game's own AddOns options.

local _, Z = ...
local W = Z.W
local C = W.C
local Home = {}
Z.Home = Home

local function Card(parent, width, height)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, height)
  W.Fill(f, C.card)
  W.Outline(f, C.line)
  return f
end

local function KeyText(binding)
  local key = GetBindingKey(binding)
  if not key then
    return "|cff909090not bound|r"
  end
  return (GetBindingText and GetBindingText(key)) or key
end

local function OnOff(v)
  return v and (W.AccentHex() .. "On|r") or "|cff909090Off|r"
end

---------------------------------------------------------------------------
-- Home
---------------------------------------------------------------------------
function Home.Build(host, width, refreshers)
  local y = 0
  -- player card
  local player = Card(host, width, 76)
  player:SetPoint("TOPLEFT", 0, y)
  local name = W.Text(player, 18)
  name:SetPoint("TOPLEFT", 16, -14)
  local info = W.Text(player, 12, C.muted)
  info:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -6)
  local logo = player:CreateTexture(nil, "ARTWORK")
  logo:SetSize(52, 52)
  logo:SetPoint("RIGHT", -14, 0)
  logo:SetTexture(Z.MEDIA .. "logo")
  refreshers[#refreshers + 1] = function()
    local r, g, b = Z.ClassColor()
    name:SetText(UnitName("player") or "")
    name:SetTextColor(r, g, b)
    local spec = ""
    if GetSpecialization and GetSpecializationInfo then
      local idx = Z.Call(GetSpecialization)
      if idx then
        spec = select(2, Z.CallAll(GetSpecializationInfo, idx)) or ""
      end
    end
    info:SetText(string.format("Level %s %s %s   ·   Profile %s%s|r", UnitLevel("player") or "?", spec,
      UnitClass("player") or "", W.AccentHex(), Z.profileName or "Default"))
  end
  y = y - 86

  -- status cards
  local status = {
    {"Aim Mode Key", function()
      return KeyText("CROSSHAIRZ_LOOK")
    end, "look"},
    {"Crosshair Aim", function()
      return OnOff(Z.P.aim.enabled)
    end, "aim"},
    {"Crosshair HUD", function()
      return OnOff(Z.P.hud.enabled)
    end, "hud"},
    {"Mouse Actions", function()
      return OnOff(Z.P.clicks.enabled)
    end, "clicks"}
  }
  local gap = 8
  local cw = (width - gap * 3) / 4
  for i, s in ipairs(status) do
    local f = CreateFrame("Button", nil, host)
    f:SetSize(cw, 64)
    f:SetPoint("TOPLEFT", (i - 1) * (cw + gap), y)
    W.Fill(f, C.card)
    W.Outline(f, C.line)
    local t = W.Text(f, 11, C.muted)
    t:SetPoint("TOPLEFT", 12, -12)
    t:SetText(s[1])
    local v = W.Text(f, 15)
    v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
    v:SetPoint("RIGHT", -8, 0)
    f:SetScript("OnClick", function()
      Z.Panel.Show(s[3])
    end)
    W.Tip(f, s[1], "Click to open its page.")
    refreshers[#refreshers + 1] = function()
      v:SetText(s[2]())
    end
  end
  y = y - 74

  -- quick actions
  local qa = Card(host, width, 92)
  qa:SetPoint("TOPLEFT", 0, y)
  local qt = W.Text(qa, 13)
  qt:SetPoint("TOPLEFT", 12, -12)
  qt:SetText(W.AccentHex() .. "Quick Actions|r")
  local actions = {
    {"Setup Wizard", function()
      Z.Panel.Hide()
      Z.Wizard.Open()
    end},
    {"Move Prompts", function()
      Z.Panel.Hide()
      Z.Assist.SetMoving(true)
    end},
    {"Patch Notes", function()
      Z.Panel.Show("notes")
    end},
    {"Undo All Changes", function()
      Z.Panel.Confirm("Put back your game settings and turn Crosshair Z off? The UI will reload.", Z.Undo)
    end}
  }
  local bw = (width - 24 - gap * 3) / 4
  for i, a in ipairs(actions) do
    local b = W.Button(qa, a[1], bw, 32, a[2])
    b:SetPoint("TOPLEFT", 12 + (i - 1) * (bw + gap), -42)
  end
  y = y - 102

  -- recent pages
  local rc = Card(host, width, 92)
  rc:SetPoint("TOPLEFT", 0, y)
  local rt = W.Text(rc, 13)
  rt:SetPoint("TOPLEFT", 12, -12)
  rt:SetText(W.AccentHex() .. "Recent Pages|r")
  local slots = {}
  for i = 1, 4 do
    local b = W.Button(rc, "", bw, 32)
    b:SetPoint("TOPLEFT", 12 + (i - 1) * (bw + gap), -42)
    slots[i] = b
  end
  local empty = W.Text(rc, 12, C.muted)
  empty:SetPoint("TOPLEFT", 12, -50)
  empty:SetText("Pages you open show up here.")
  refreshers[#refreshers + 1] = function()
    local recent = Z.G.recent
    empty:SetShown(#recent == 0)
    for i, b in ipairs(slots) do
      local key = recent[i]
      local page
      for _, pg in ipairs(Z.Pages) do
        if pg.key == key then
          page = pg
        end
      end
      if page then
        b:SetLabel(page.title)
        b:SetScript("OnClick", function()
          Z.Panel.Show(page.key)
        end)
        b:Show()
      else
        b:Hide()
      end
    end
  end
  y = y - 102

  local tip = W.Text(host, 11, C.muted)
  tip:SetPoint("TOPLEFT", 2, y)
  tip:SetWidth(width)
  tip:SetWordWrap(true)
  tip:SetText("Commands: /cz opens this window (/cz look, /cz crosshair, /cz hud... open a page), /cz wizard, /cz move, /cz status, /cz export, /cz import, /czundo.")
  return -y + 20
end

---------------------------------------------------------------------------
-- Patch Notes
---------------------------------------------------------------------------
local function NotesInto(host, width, notes)
  local y = 0
  for _, entry in ipairs(notes) do
    local head = W.Text(host, 15)
    head:SetPoint("TOPLEFT", 0, y)
    head:SetText(W.AccentHex() .. entry.version .. "|r  |cff909090" .. entry.date .. "|r")
    y = y - 24
    for _, line in ipairs(entry.lines) do
      local fs = W.Text(host, 12)
      fs:SetWordWrap(true)
      fs:SetWidth(width - 16)
      fs:SetPoint("TOPLEFT", 12, y)
      fs:SetText("- " .. line)
      y = y - math.max(14, fs:GetStringHeight()) - 6
    end
    y = y - 12
  end
  return -y
end

function Home.BuildNotes(host, width)
  return NotesInto(host, width, Z.NOTES)
end

---------------------------------------------------------------------------
-- Small window helper for the wizard and What's New
---------------------------------------------------------------------------
local function Window(name, w, h)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(w, h)
  f:SetPoint("CENTER", 0, 60)
  f:SetFrameStrata("DIALOG")
  f:EnableMouse(true)
  f:SetMovable(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  W.Fill(f, C.bg)
  W.Outline(f, C.line)
  f.title = W.Text(f, 16)
  f.title:SetPoint("TOPLEFT", 18, -16)
  table.insert(UISpecialFrames, name)
  f:Hide()
  return f
end

---------------------------------------------------------------------------
-- Setup Wizard
---------------------------------------------------------------------------
local Wizard = {}
Z.Wizard = Wizard
local wiz

local STEPS = {
  {title = "Aim Mode Key", text = "Pick the key that turns Aim Mode on and off. Middle mouse works well.", items = function()
    return {{type = "key", label = "Aim Mode - Toggle", binding = "CROSSHAIRZ_LOOK", full = true},
            {type = "key", label = "Interact With Target", binding = "INTERACTTARGET", full = true}}
  end},
  {title = "Crosshair", text = "Pick a style. It turns red on enemies and green on friendly units.", items = function()
    local out = {}
    for _, s in ipairs(Z.Reticle.STYLES) do
      out[#out + 1] = {s[1], s[2]}
    end
    return {{type = "select", label = "Crosshair Style", path = "cross.style", choices = out, full = true},
            {type = "slider", label = "Size", path = "cross.size", min = 12, max = 96, step = 1, full = true}}
  end},
  {title = "Crosshair HUD", text = "Arcs around the crosshair for health, power, your target and its cast, plus your class resources.", items = function()
    return {{type = "toggle", label = "Show Crosshair HUD", path = "hud.enabled", full = true},
            {type = "select", label = "Show HUD", path = "hud.show", full = true,
             choices = {{"combat", "Only in combat"}, {"target", "In combat or with a target"}, {"always", "Always"}}}}
  end},
  {title = "Camera", text = "An over-the-shoulder camera, or keep it centered if camera movement makes you uncomfortable.", items = function()
    return {{type = "toggle", label = "Over The Shoulder", path = "camera.actionCam", full = true},
            {type = "slider", label = "Shoulder Offset", path = "camera.shoulder", min = 0, max = 3, step = 0.05, full = true},
            {type = "toggle", label = "Motion Sickness Protection", path = "camera.safe", full = true}}
  end}
}

local function ShowStep(i)
  wiz.step = i
  if wiz.body then
    wiz.body:Hide()
    wiz.body:SetParent(nil)
  end
  local step = STEPS[i]
  wiz.title:SetText(string.format("Setup Wizard  |cff909090%d / %d|r", i, #STEPS))
  local refreshers = {}
  local body, h = W.Card(wiz, {title = step.title, note = step.text, items = step.items()}, 420, refreshers)
  body:SetPoint("TOP", 0, -48)
  wiz.body = body
  wiz.refreshers = refreshers
  for _, fn in ipairs(refreshers) do
    fn()
  end
  wiz:SetHeight(h + 110)
  wiz.back:SetShown(i > 1)
  wiz.next:SetLabel(i == #STEPS and "Finish" or "Next")
end

function Wizard.Open()
  if InCombatLockdown() then
    Z.Print("The wizard can't open in combat.")
    return
  end
  if not wiz then
    wiz = Window("CrosshairZWizard", 456, 300)
    wiz.next = W.AccentButton(wiz, "Next", 110, 28, function()
      if wiz.step == #STEPS then
        wiz:Hide()
        Z.G.wizardDone = true
        Z.Print("All set. Open /cz any time for more.")
      else
        ShowStep(wiz.step + 1)
      end
    end)
    wiz.next:SetPoint("BOTTOMRIGHT", -16, 14)
    wiz.back = W.Button(wiz, "Back", 90, 28, function()
      ShowStep(wiz.step - 1)
    end)
    wiz.back:SetPoint("RIGHT", wiz.next, "LEFT", -8, 0)
    local skip = W.Button(wiz, "Skip", 90, 28, function()
      wiz:Hide()
      Z.G.wizardDone = true
    end)
    skip:SetPoint("BOTTOMLEFT", 16, 14)
  end
  wiz:Show()
  ShowStep(1)
end

-- the wizard refreshes its controls through the same call as the panel
local panelRefresh
Z.Listen("READY", function()
  panelRefresh = Z.Panel.Refresh
  Z.Panel.Refresh = function()
    panelRefresh()
    if wiz and wiz:IsShown() and wiz.refreshers then
      for _, fn in ipairs(wiz.refreshers) do
        pcall(fn)
      end
    end
  end
end)

---------------------------------------------------------------------------
-- What's New
---------------------------------------------------------------------------
local function WhatsNew()
  local f = Window("CrosshairZWhatsNew", 520, 400)
  f.title:SetText("What's New in Crosshair " .. Z.GREEN .. "Z|r " .. Z.version)
  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 18, -48)
  scroll:SetPoint("BOTTOMRIGHT", -36, 56)
  local host = CreateFrame("Frame", nil, scroll)
  host:SetWidth(460)
  local h = NotesInto(host, 460, {Z.NOTES[1]})
  host:SetHeight(h)
  scroll:SetScrollChild(host)
  local ok = W.AccentButton(f, "Got It", 110, 28, function()
    f:Hide()
  end)
  ok:SetPoint("BOTTOMRIGHT", -16, 14)
  local all = W.Button(f, "Open Settings", 120, 28, function()
    f:Hide()
    Z.Panel.Open("notes")
  end)
  all:SetPoint("RIGHT", ok, "LEFT", -8, 0)
  f:Show()
end

Z.Listen("READY", function()
  local last = Z.G.lastSeen
  Z.G.lastSeen = Z.version
  if Z.firstRun or not Z.G.wizardDone then
    Z.After(3, function()
      if not InCombatLockdown() then
        Wizard.Open()
      end
    end)
  elseif last and last ~= Z.version then
    Z.After(3, function()
      if not InCombatLockdown() then
        WhatsNew()
      end
    end)
  end
end)

---------------------------------------------------------------------------
-- Game Options > AddOns
---------------------------------------------------------------------------
Z.Listen("READY", function()
  local f = CreateFrame("Frame")
  f.name = "Crosshair Z"
  local logo = f:CreateTexture(nil, "ARTWORK")
  logo:SetSize(64, 64)
  logo:SetPoint("TOPLEFT", 16, -16)
  logo:SetTexture(Z.MEDIA .. "logo")
  local t = W.Text(f, 20)
  t:SetPoint("LEFT", logo, "RIGHT", 12, 8)
  t:SetText("Crosshair " .. Z.GREEN .. "Z|r")
  local v = W.Text(f, 12, C.muted)
  v:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -4)
  v:SetText("Version " .. Z.version .. "  ·  by H3z0")
  local b = W.AccentButton(f, "Open Crosshair Z", 180, 32, function()
    if SettingsPanel and SettingsPanel:IsShown() then
      HideUIPanel(SettingsPanel)
    end
    Z.Panel.Open()
  end)
  b:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -16)
  if Settings and Settings.RegisterCanvasLayoutCategory then
    local cat = Settings.RegisterCanvasLayoutCategory(f, "Crosshair Z")
    Settings.RegisterAddOnCategory(cat)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(f)
  end
end)
