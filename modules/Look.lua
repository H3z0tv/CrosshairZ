-- Crosshair Z
-- Aim Mode: the camera follows the mouse without holding a button. Frees the
-- cursor on its own while game windows are open, then takes it back.

local _, Z = ...
local L = Z.Module("Look")

local wanted = false -- the player turned Aim Mode on
local holding = false -- the hold key is down
local looking = false -- what we last told the game
local lastWhy = nil

---------------------------------------------------------------------------
-- What frees the cursor
---------------------------------------------------------------------------
local PANELS = {
  "GameMenuFrame", "SettingsPanel", "InterfaceOptionsFrame", "VideoOptionsFrame", "KeyBindingFrame",
  "CharacterFrame", "SpellBookFrame", "PlayerSpellsFrame", "ClassTalentFrame", "PlayerTalentFrame",
  "WorldMapFrame", "QuestLogFrame", "QuestFrame", "GossipFrame", "MerchantFrame", "TaxiFrame",
  "FlightMapFrame", "MailFrame", "OpenMailFrame", "BankFrame", "GuildBankFrame", "AuctionHouseFrame",
  "AuctionFrame", "ProfessionsFrame", "TradeSkillFrame", "TradeFrame", "LootFrame", "PVEFrame",
  "CollectionsJournal", "EncounterJournal", "AchievementFrame", "CommunitiesFrame", "FriendsFrame",
  "MacroFrame", "ItemTextFrame", "ChatConfigFrame", "ContainerFrameCombinedBags", "BagnonInventory1",
  "ItemInteractionFrame", "ClassTrainerFrame", "PetStableFrame", "BarberShopFrame", "TransmogFrame",
  "WardrobeFrame", "GarrisonLandingPage", "ExpansionLandingPage", "StaticPopup1", "StaticPopup2",
  "StaticPopup3", "LFGDungeonReadyPopup", "ReadyCheckFrame", "PlayerChoiceFrame", "GenericTraitFrame",
  "HousingDashboardFrame", "WeeklyRewardsFrame", "DelvesCompanionConfigurationFrame"
}
-- our own windows always free the cursor
local OWN = {"CrosshairZShare", "CrosshairZPanel", "CrosshairZWizard", "CrosshairZWhatsNew", "CrosshairZConfirm", "CrosshairZMoveDone"}
for i = 1, 13 do
  PANELS[#PANELS + 1] = "ContainerFrame" .. i
end

local watch = {}

local function Visible(name)
  local f = _G[name]
  if type(f) == "table" and f.IsVisible then
    local ok, shown = pcall(f.IsVisible, f)
    if not ok or Z.Secret(shown) or not shown then
      return false
    end
    local okA, alpha = pcall(f.GetAlpha, f)
    local okW, width = pcall(f.GetWidth, f)
    if okA and type(alpha) == "number" and not Z.Secret(alpha) and alpha < 0.05 then
      return false
    end
    if okW and type(width) == "number" and not Z.Secret(width) and width < 2 then
      return false
    end
    return true
  end
end

local VENDOR_MOUNT_SPELLS = {61425, 61447, 122708, 264058, 465235, 457485}

local function OnVendorMount()
  if not IsMounted() then
    return false
  end
  local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
  if not get then
    return false
  end
  for _, id in ipairs(VENDOR_MOUNT_SPELLS) do
    if Z.Call(get, id) then
      return true
    end
  end
  return false
end

local conditionText, conditionFn
local function Condition()
  local text = Z.P.look.condition
  if not text or text:match("^%s*$") then
    return false
  end
  if text ~= conditionText then
    conditionText = text
    local loader = _G.loadstring or load
    local fn = loader(text)
    if not fn then
      fn = loader("return " .. text)
    end
    conditionFn = fn
  end
  if not conditionFn then
    return false
  end
  local ok, result = pcall(conditionFn)
  return ok and result and true or false
end

local function Blocked()
  local p = Z.P.look
  if SpellIsTargeting and SpellIsTargeting() then
    return "targeting"
  end
  if (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene()) then
    return "cinematic"
  end
  if C_PetBattles and C_PetBattles.IsInBattle and C_PetBattles.IsInBattle() then
    return "pet battle"
  end
  if Z.Radial and Z.Radial.IsOpen and Z.Radial.IsOpen() then
    return "menu"
  end
  for _, name in ipairs(OWN) do
    if Visible(name) then
      return name
    end
  end
  if p.unlockPanels then
    for _, name in ipairs(PANELS) do
      if Visible(name) then
        return name
      end
    end
    for _, name in ipairs(watch) do
      if Visible(name) then
        return name
      end
    end
  end
  if p.vendorMount and OnVendorMount() then
    return "vendor mount"
  end
  if Condition() then
    return "condition"
  end
  return nil
end

local function MouseHeld()
  return IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton"))
end

---------------------------------------------------------------------------
-- Turning it on and off
---------------------------------------------------------------------------
local pulse
local function Pulse()
  if not pulse then
    pulse = CreateFrame("Frame", nil, UIParent)
    pulse:SetFrameStrata("TOOLTIP")
    pulse:SetSize(64, 64)
    pulse.t = pulse:CreateTexture(nil, "OVERLAY")
    pulse.t:SetAllPoints()
    pulse.t:SetTexture(Z.MEDIA .. "cross_ripple")
    pulse.t:SetVertexColor(0.49, 1, 0.31)
    pulse:Hide()
    pulse:SetScript("OnUpdate", function(self, e)
      self.age = self.age + e
      local k = self.age / 0.45
      if k >= 1 then
        self:Hide()
        return
      end
      self:SetSize(80 - 56 * k, 80 - 56 * k)
      self:SetAlpha(1 - k)
    end)
  end
  local x, y = GetCursorPosition()
  local s = UIParent:GetEffectiveScale()
  pulse:ClearAllPoints()
  pulse:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
  pulse.age = 0
  pulse:Show()
end

local function SetLooking(on)
  if on == looking then
    return
  end
  looking = on
  if on then
    MouselookStart()
    -- the hidden cursor sits on the crosshair only while Aim Mode runs
    Z.SetCVar("CursorFreelookCentering", 1)
  else
    -- let go of the center first, so the cursor comes back where you left it
    Z.SetCVar("CursorFreelookCentering", 0)
    MouselookStop()
    if Z.P.look.pulse then
      Pulse()
    end
  end
  Z.Send("LOOK", on)
end

local function HoldKeyStillDown()
  if not IsKeyDown then
    return true
  end
  local k1, k2 = GetBindingKey("CROSSHAIRZ_HOLD")
  for _, key in ipairs({k1, k2}) do
    if key then
      local base = key:match("[^%-]+$")
      local map = {BUTTON1 = "LeftButton", BUTTON2 = "RightButton", BUTTON3 = "MiddleButton", BUTTON4 = "Button4",
                   BUTTON5 = "Button5"}
      local ok, down = pcall(IsKeyDown, map[base] or base)
      if ok and down then
        return true
      end
      if map[base] and IsMouseButtonDown and IsMouseButtonDown(map[base]) then
        return true
      end
    end
  end
  return false
end

local function Update()
  if not Z.P then
    return
  end
  if holding and not HoldKeyStillDown() then
    holding = false
  end
  local want = wanted ~= holding -- the hold key flips whatever the toggle says
  local why = want and Blocked() or nil
  if why ~= lastWhy then
    Z.Debug("Aim Mode %s", why and ("paused: " .. why) or "free to run")
  end
  if why and why == lastWhy and why ~= "CrosshairZPanel" then
    L.told = L.told or {}
    if not L.told[why] and GetTime() - (L.whySince or GetTime()) > 4 then
      L.told[why] = true
      Z.Print("Aim Mode is paused by: %s. If nothing like that is open, send this line to H3z0.", why)
    end
  else
    L.whySince = GetTime()
  end
  lastWhy = why
  if want and why then
    want = false
  end
  if want == looking then
    -- the game can stop mouse look by itself (e.g. right-click drag ends)
    if looking and not IsMouselooking() and not MouseHeld() then
      Z.Debug("Aim Mode was stopped by the game, starting it again")
      MouselookStart()
    end
    return
  end
  if MouseHeld() then
    return -- never fight a held mouse button
  end
  SetLooking(want)
end

function L.IsOn()
  return looking
end

function L.IsWanted()
  return wanted
end

function L.Why()
  return lastWhy
end

-- /cz status
function L.Status()
  Z.Print("Version %s%s", Z.version, L.oldCopy and " |cffff5050(an older copy is also loaded)|r" or " (no older copy loaded)")
  Z.Print("Aim Mode wanted: %s, hold key: %s, on: %s, game mouse look: %s",
    tostring(wanted), tostring(holding), tostring(looking), tostring(IsMouselooking()))
  Z.Print("Paused by: %s", lastWhy or "nothing")
  Z.Print("Mouse button held: %s, spell targeting: %s, hold key down: %s",
    tostring(MouseHeld() and true or false), tostring(SpellIsTargeting and SpellIsTargeting() or false),
    tostring(HoldKeyStillDown()))
  Z.Print("Aim Mode key: %s", GetBindingKey("CROSSHAIRZ_LOOK") or "not bound")
  local r = Z.Reticle and Z.Reticle.frame
  if r then
    local x, y = r:GetCenter()
    Z.Print("Crosshair: shown %s, visible %s, opacity %.2f, size %d, at %s, %s, style %s",
      tostring(r:IsShown()), tostring(r:IsVisible()), r:GetAlpha(), math.floor(r:GetWidth() + 0.5),
      x and math.floor(x) or "?", y and math.floor(y) or "?", tostring(Z.P.cross.style))
  end
  local h = Z.HUD and Z.HUD.world
  if h then
    Z.Print("HUD: opacity %.2f (shows: %s)", h:GetAlpha(), Z.P.hud.show)
  end
end

function L.Set(on)
  wanted = on and true or false
  Update()
  Z.Send("LOOKMODE")
end

function L.KeyToggle()
  wanted = not wanted
  holding = false
  Update()
  Z.Send("LOOKMODE")
end

function L.KeyHold(state)
  holding = (state == "down")
  Update()
end

---------------------------------------------------------------------------
-- Weapons follow Aim Mode
---------------------------------------------------------------------------
local sheatheToken = 0
Z.Listen("LOOK", function(on)
  if not Z.P.look.sheathe or not GetSheathState or not ToggleSheath then
    return
  end
  sheatheToken = sheatheToken + 1
  local token = sheatheToken
  if on then
    if GetSheathState() == 1 then
      ToggleSheath()
    end
  else
    Z.After(1.2, function()
      if token == sheatheToken and not looking and not Z.InCombat() and GetSheathState() ~= 1 then
        ToggleSheath()
      end
    end)
  end
end)

---------------------------------------------------------------------------
-- Vignette
---------------------------------------------------------------------------
local vignette = CreateFrame("Frame", "CrosshairZVignette", UIParent)
vignette:SetAllPoints(UIParent)
vignette:SetFrameStrata("BACKGROUND")
vignette.t = vignette:CreateTexture(nil, "BACKGROUND")
vignette.t:SetAllPoints()
vignette.t:SetTexture(Z.MEDIA .. "vignette")
vignette:SetAlpha(0)
vignette.cur = 0
vignette:SetScript("OnUpdate", function(self, e)
  local target = 0
  if Z.P and Z.P.look.vignette and looking then
    target = Z.P.look.vignetteStrength
  end
  if Z.Panel and Z.Panel.IsOpen() and Z.P and Z.P.look.vignette then
    target = Z.P.look.vignetteStrength
  end
  self.cur = self.cur + (target - self.cur) * math.min(1, e * 6)
  self:SetAlpha(self.cur)
end)

---------------------------------------------------------------------------
-- Module hooks
---------------------------------------------------------------------------
local guard = CreateFrame("Frame")
guard:SetScript("OnUpdate", function()
  if looking and not IsMouselooking() and not MouseHeld() and not (SpellIsTargeting and SpellIsTargeting()) then
    MouselookStart()
  end
end)

function L:Setup()
  wanted = Z.P.look.startOn and true or false
  Z.Every(0.1, Update)
  Z.Send("LOOKMODE")
  -- an older copy of the addon running next to this one fights over the mouse
  if _G.CrosshairZ_ToggleKey or _G.CrosshairZRadial1 or _G.CrosshairZFrame then
    L.oldCopy = true
    Z.After(6, function()
      Z.Print("|cffff5050An older Crosshair Z is also loaded and will break this one.|r Close the game, delete the CrosshairZ folder in Interface\\AddOns, and install 1.0.0 again.")
    end)
  end
  Z.On("PLAYER_REGEN_DISABLED", Update)
  Z.On("CINEMATIC_STOP", Update)
  Z.On("STOP_MOVIE", Update)
  if Z.firstRun then
    -- keys from earlier versions move to the new key names
    local moved = false
    local RENAMED = {
      CROSSHAIRZ_TOGGLE = "CROSSHAIRZ_LOOK",
      ["CLICK CrosshairZCycleNext:LeftButton"] = "CLICK CrosshairZNextEnemy:LeftButton",
      ["CLICK CrosshairZCyclePrevious:LeftButton"] = "CLICK CrosshairZPrevEnemy:LeftButton"
    }
    for old, new in pairs(RENAMED) do
      local keys = {Z.CallAll(GetBindingKey, old)}
      for _, key in ipairs(keys) do
        if type(key) == "string" and not GetBindingKey(new) then
          pcall(SetBinding, key, new)
          moved = true
        end
      end
    end
    -- new players get middle mouse as the toggle, if it's free
    if not GetBindingKey("CROSSHAIRZ_LOOK") and GetBindingAction and GetBindingAction("BUTTON3") == "" then
      pcall(SetBinding, "BUTTON3", "CROSSHAIRZ_LOOK")
      moved = true
    end
    if moved then
      pcall(SaveBindings, GetCurrentBindingSet())
    end
  end
end

function L:Apply()
  wipe(watch)
  for name in (Z.P.look.watchlist or ""):gmatch("[%w_]+") do
    watch[#watch + 1] = name
  end
  if not (Z.Camera and Z.Camera.Yield()) then
    local speed = Z.P.look.turnSpeed
    Z.SetCVar("cameraYawMoveSpeed", speed)
    Z.SetCVar("cameraPitchMoveSpeed", math.floor(speed / 2))
  end
  -- park the hidden cursor on the crosshair so @mouseover and @cursor work
  local h = UIParent:GetHeight()
  if h and h > 0 then
    local y = 0.5 + (Z.CrosshairY and Z.CrosshairY() or 0) / h
    Z.SetCVar("CursorCenteredYPos", string.format("%.3f", Z.Clamp(y, 0.05, 0.95)))
  end
end

function L:Stop()
  wanted = false
  SetLooking(false)
end
