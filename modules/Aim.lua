-- Crosshair Z
-- Crosshair Aim: whatever is under the crosshair becomes the unit your
-- spells go to. Built on the game's own soft targeting.

local _, Z = ...
local A = Z.Module("Aim")

local function FriendlyAllowed()
  local p = Z.P.aim
  if not p.friendly then
    return false
  end
  if p.friendlyCombat and Z.InCombat() then
    return false
  end
  return true
end

-- While a target is locked the aim must not replace it
local function Force()
  local p = Z.P.aim
  if not p.prioritize then
    return 0
  end
  if Z.Lock and Z.Lock.IsLocked() then
    return 0
  end
  return 1
end

function A.Update()
  local p = Z.P.aim
  if not p.enabled or not (Z.Look and Z.Look.IsWanted()) then
    -- aiming stops choosing targets; the set-up values stay as they are
    Z.SetCVar("SoftTargetFriend", 0)
    Z.SetCVar("SoftTargetForce", 0)
    return
  end
  -- 3 = soft targeting with any input; arc 0 = straight ahead only
  Z.SetCVar("SoftTargetEnemy", 3)
  Z.SetCVar("SoftTargetEnemyArc", p.sticky and 1 or 0)
  Z.SetCVar("SoftTargetEnemyRange", 60)
  Z.SetCVar("SoftTargetInteract", 3)
  Z.SetCVar("SoftTargetInteractArc", 1)
  Z.SetCVar("SoftTargetInteractRange", 15)
  Z.SetCVar("SoftTargetIconInteract", 1)
  Z.SetCVar("SoftTargetIconGameObject", 1)
  Z.SetCVar("SoftTargetFriend", FriendlyAllowed() and 3 or 0)
  Z.SetCVar("SoftTargetFriendArc", 0)
  Z.SetCVar("SoftTargetForce", Force())
  Z.SetCVar("SoftTargetMatchLocked", 1)
  Z.SetCVar("SoftTargetWithLocked", 2)
  Z.SetCVar("SoftTargetNameplateEnemy", 1)
  Z.SetCVar("enableMouseoverCast", 1)
  Z.SetCVar("deselectOnClick", 1)
  Z.SetCVar("SoftTargetIconEnemy", 0)
  Z.SetCVar("SoftTargetFriendRange", 60)
end

function A:Setup()
  Z.On("PLAYER_REGEN_DISABLED", function()
    if Z.P.aim.friendly and Z.P.aim.friendlyCombat then
      A.Update()
    end
  end)
  Z.On("PLAYER_REGEN_ENABLED", A.Update)
  Z.Listen("LOCK", A.Update)
  Z.Listen("LOOKMODE", A.Update)
end

function A:Apply()
  local p = Z.P.aim
  A.Update()
  -- the circle under the target and outlines around units
  Z.SetCVar("ObjectSelectionCircle", p.circle and 1 or 0)
  Z.SetCVar("Outline", p.outlines and 3 or 0)
end

-- Which unit is under the crosshair right now (enemy first)
function A.AimUnit()
  for _, unit in ipairs({"softenemy", "softfriend", "softinteract", "mouseover"}) do
    if Z.Truthy(UnitExists, unit) then
      return unit
    end
  end
end
