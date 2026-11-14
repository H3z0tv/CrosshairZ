-- Crosshair Z
-- The crosshair: style, size, color by what you aim at (or by range), when it
-- shows, and how it reacts to your casts.

local _, Z = ...
local R = Z.Module("Reticle")

R.STYLES = {
  {"iris", "Iris"},
  {"bead", "Bead"},
  {"spur", "Spur"},
  {"needle", "Needle"},
  {"compass", "Compass"},
  {"talon", "Talon"},
  {"prong", "Prong"},
  {"orbit", "Orbit"},
  {"ripple", "Ripple"},
  {"gate", "Gate"},
  {"wings", "Wings"},
  {"kite", "Kite"},
  {"delta", "Delta"},
  {"pulse", "Pulse"},
  {"split", "Split"},
  {"frame", "Frame"},
  {"anchor", "Anchor"},
  {"petal", "Petal"},
  {"shard", "Shard"},
  {"notch", "Notch"},
  {"comb", "Comb"},
  {"wedge", "Wedge"},
  {"lance", "Lance"},
  {"pixel", "Pixel"}
}

function R.Texture(style)
  return Z.MEDIA .. "cross_" .. (style or "iris")
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------
local f = CreateFrame("Frame", "CrosshairZReticle", UIParent)
f:SetFrameStrata("HIGH")
f:SetSize(32, 32)
f:SetPoint("CENTER")
f.tex = f:CreateTexture(nil, "OVERLAY")
f.tex:SetAllPoints()
f.preview = f:CreateFontString(nil, "OVERLAY")
f.preview:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
f.preview:SetPoint("TOP", f, "BOTTOM", 0, -40)
f.preview:SetText("PREVIEW")
f.preview:SetTextColor(1, 0.82, 0.2)
f.preview:Hide()
R.frame = f

local alpha, scale = 0, 1
local castScale, pulseK, shakeK = 1, 0, 0
local casting = false

---------------------------------------------------------------------------
-- Position
---------------------------------------------------------------------------
local function HeadOffset()
  if not Z.P.cross.head or not GetCameraZoom then
    return 0
  end
  local zoom = Z.Call(GetCameraZoom) or 15
  return 180 / (zoom + 3)
end

function Z.CrosshairY()
  if not Z.P then
    return 0
  end
  return Z.P.cross.y + HeadOffset()
end

---------------------------------------------------------------------------
-- Range (Crosshair Rules)
---------------------------------------------------------------------------
local rangedSpell
local function FindRangedSpell()
  rangedSpell = nil
  if not GetActionInfo or not C_Spell or not C_Spell.GetSpellInfo then
    return
  end
  for slot = 1, 120 do
    local kind, id = Z.CallAll(GetActionInfo, slot)
    if kind == "spell" and id then
      local info = Z.Call(C_Spell.GetSpellInfo, id)
      local harmful = C_Spell.IsSpellHarmful and Z.Call(C_Spell.IsSpellHarmful, id)
      if info and harmful and (info.maxRange or 0) >= 20 then
        rangedSpell = id
        return
      end
    end
  end
end

local function InRange(spell, unit)
  if not spell or spell == "" or not C_Spell or not C_Spell.IsSpellInRange then
    return nil
  end
  local v = Z.Call(C_Spell.IsSpellInRange, tonumber(spell) or spell, unit)
  if v == nil then
    return nil
  end
  return v == true or v == 1
end

-- "melee", "ranged", "out" or nil when there's nothing to measure
function R.Range(unit)
  if not unit then
    return nil
  end
  local s = Z.P.smart
  local melee = s.meleeSpell ~= "" and s.meleeSpell or 6603
  local ranged = s.rangedSpell ~= "" and s.rangedSpell or rangedSpell
  local inMelee = InRange(melee, unit)
  if inMelee then
    return "melee"
  end
  local inRanged = InRange(ranged, unit)
  if inRanged then
    return "ranged"
  end
  if inMelee == false or inRanged == false then
    return "out"
  end
  return nil
end

---------------------------------------------------------------------------
-- Color and visibility
---------------------------------------------------------------------------
local function EnemyUnit()
  if Z.Truthy(UnitExists, "softenemy") then
    return "softenemy"
  end
  if Z.Truthy(UnitExists, "target") and Z.Call(UnitCanAttack, "player", "target") then
    return "target"
  end
end

local function Color()
  local c, s = Z.P.cross, Z.P.smart
  local enemy = EnemyUnit()
  if enemy then
    if s.enabled and s.range then
      local r = R.Range(enemy)
      if r == "melee" then
        return s.colorMelee
      elseif r == "ranged" then
        return s.colorRanged
      elseif r == "out" then
        return s.colorOut
      end
    end
    return c.colorEnemy
  end
  if Z.Truthy(UnitExists, "softfriend") then
    return c.colorFriend
  end
  return c.colorNeutral
end

local idleSince = 0
local function Wanted()
  local c, s = Z.P.cross, Z.P.smart
  if not c.enabled then
    return 0
  end
  if Z.Previewing() then
    return c.opacity
  end
  local combat = Z.InCombat()
  local a = combat and c.opacity or c.opacityOut
  local looking = Z.Look and Z.Look.IsOn()
  if not looking then
    if c.offLook == "hide" then
      return 0
    elseif c.offLook == "faint" then
      a = a * 0.35
    end
  end
  if IsMounted() then
    if c.mounted == "hide" then
      return 0
    elseif c.mounted == "dim" then
      a = a * 0.4
    end
  end
  if s.enabled then
    local enemy = EnemyUnit()
    if s.show == "combat" and not combat then
      return 0
    elseif s.show == "enemy" and not enemy then
      return 0
    end
    if s.hideFlight and ((UnitOnTaxi and UnitOnTaxi("player")) or (IsFlying and IsFlying())) then
      return 0
    end
    if s.hideNoTarget and not enemy and not Z.Truthy(UnitExists, "target") then
      return 0
    end
    local hasTarget = Z.Truthy(UnitExists, "target")
    if s.hideFriendly and hasTarget and Z.Call(UnitIsFriend, "player", "target") then
      return 0
    end
    if s.hideDead and hasTarget and Z.Call(UnitIsDead, "target") then
      return 0
    end
    if s.hideRange and enemy and R.Range(enemy) == "out" then
      return 0
    end
    if s.hideIdle then
      local moving = (Z.Call(GetUnitSpeed, "player") or 0) > 0
      if moving or combat or casting then
        idleSince = GetTime()
      elseif GetTime() - idleSince > 5 then
        return 0
      end
    end
  end
  return a
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local colorTimer = 0
f:SetScript("OnUpdate", function(self, e)
  if not Z.P then
    return
  end
  local c = Z.P.cross
  -- fade
  local want = Wanted()
  alpha = alpha + (want - alpha) * math.min(1, e * 10)
  self:SetAlpha(alpha)
  -- color (four times a second is plenty)
  colorTimer = colorTimer - e
  if colorTimer <= 0 then
    colorTimer = 0.25
    local col = Color()
    self.tex:SetVertexColor(col[1], col[2], col[3])
  end
  -- cast feedback
  local target = (casting and c.castGrow) and 1.25 or 1
  castScale = castScale + (target - castScale) * math.min(1, e * 6)
  if pulseK > 0 then
    pulseK = math.max(0, pulseK - e * 3)
  end
  if shakeK > 0 then
    shakeK = math.max(0, shakeK - e * 2.5)
  end
  local s = castScale + pulseK * 0.45
  local size = c.size * s
  self:SetSize(size, size)
  local dx = shakeK > 0 and math.sin(GetTime() * 60) * 6 * shakeK or 0
  self:ClearAllPoints()
  self:SetPoint("CENTER", UIParent, "CENTER", dx, Z.CrosshairY())
  self.preview:SetShown(Z.Panel and Z.Panel.IsOpen() or false)
end)

local function PlayerCast(event)
  if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" or event ==
    "UNIT_SPELLCAST_EMPOWER_START" then
    casting = true
  elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
    if Z.P.cross.castPulse then
      pulseK = 1
    end
  elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
    casting = false
    if Z.P.cross.castShake then
      shakeK = 1
    end
  else
    casting = false
  end
end

function R.Test(kind)
  if kind == "pulse" then
    pulseK = 1
  elseif kind == "shake" then
    shakeK = 1
  end
end

function R:Setup()
  for _, ev in ipairs({"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_EMPOWER_START",
                       "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_EMPOWER_STOP",
                       "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED"}) do
    Z.OnUnit(ev, {"player"}, PlayerCast)
  end
  Z.On("ACTIONBAR_SLOT_CHANGED", function()
    rangedSpell = nil
    Z.After(0.5, FindRangedSpell)
  end)
  Z.On("SPELLS_CHANGED", FindRangedSpell)
  Z.On("PLAYER_ENTERING_WORLD", FindRangedSpell)
end

function R:Apply()
  f.tex:SetTexture(R.Texture(Z.P.cross.style))
  colorTimer = 0
end

function R:Stop()
  f:Hide()
end
