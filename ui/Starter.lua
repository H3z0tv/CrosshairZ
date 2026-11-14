-- Crosshair Z
-- The setup every new install starts with (H3z0's own profile). Only settings
-- the addon knows are taken; anything else in the string is ignored.

local _, Z = ...

local STARTER = [[
CZ1!{"aim"={"circle"=T;"enabled"=T;"friendly"=F;"friendlyCombat"=F;"outlines"=T;"prioritize"=T;"sticky"=F;};"assist"={"enabled"=T;"keybind"=T;"opacity"=1;"prompt"=T;"promptGlow"=T;"promptName"=F;"promptSize"=0.75;"promptX"=119;"promptY"=30;"spell"=T;"spellCombat"=T;"spellSize"=47;"spellX"=-127;"spellY"=54;};"camera"={"actionCam"=T;"flipped"=F;"focus"=T;"focusStrength"=0.7;"fov"=90;"headMove"=0;"maxZoom"=2.6;"pitch"=T;"safe"=F;"shoulder"=1.2;"sitOrbit"=T;"situational"=F;"situations"={"boss"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=20;};"combat"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=14;};"dead"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=8;};"dialog"={"fov"=80;"head"=0;"on"=T;"shoulder"=0;"zoom"=4;};"dungeon"={"fov"=90;"head"=0;"on"=F;"shoulder"=0;"zoom"=16;};"fishing"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=6;};"indoors"={"fov"=90;"head"=0;"on"=F;"shoulder"=0;"zoom"=8;};"mounted"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=14;};"pvp"={"fov"=90;"head"=0;"on"=F;"shoulder"=0;"zoom"=14;};"sitting"={"fov"=80;"head"=0;"on"=T;"shoulder"=0;"zoom"=6;};"skyriding"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=18;};"stealth"={"fov"=90;"head"=0;"on"=F;"shoulder"=0;"zoom"=8;};"swimming"={"fov"=90;"head"=0;"on"=F;"shoulder"=0;"zoom"=10;};"taxi"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=18;};"vehicle"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=18;};"world"={"fov"=90;"head"=0;"on"=T;"shoulder"=0;"zoom"=12;};};"skyZoom"=T;"zoomSpeed"=20;};"clicks"={"binds"={"ALT-BUTTON1"="ACTIONBUTTON7";"ALT-BUTTON2"="ACTIONBUTTON8";"BUTTON1"="MACRO";"BUTTON2"="ACTIONBUTTON2";"CTRL-BUTTON1"="ACTIONBUTTON5";"CTRL-BUTTON2"="ACTIONBUTTON6";"SHIFT-BUTTON1"="ACTIONBUTTON3";"SHIFT-BUTTON2"="ACTIONBUTTON4";};"enabled"=T;"macros"={"BUTTON1"="TARGET";};};"composer"={"name"="CZ Cast";"spell"="";"target"="crosshair";};"cross"={"castGrow"=T;"castPulse"=T;"castShake"=T;"colorEnemy"={#1=1;#2=0.25;#3=0.25;};"colorFriend"={#1=0.35;#2=1;#3=0.4;};"colorNeutral"={#1=1;#2=1;#3=1;};"enabled"=T;"head"=F;"mounted"="dim";"offLook"="hide";"opacity"=1;"opacityOut"=0.8;"size"=40;"style"="bead";"y"=89;};"hud"={"arcStyle"="smooth";"enabled"=T;"execute"=T;"executePct"=50;"hits"=F;"kills"=F;"lowHealth"=T;"lowHealthPct"=35;"neon"=T;"numbers"=F;"opacity"=1;"orbAnim"=T;"orbColor"="red";"orbGlow"=T;"orbs"=T;"pipDistance"=76;"pipPlace"="below";"pipSize"=21;"pipSpread"=21;"pips"=T;"scale"=0.6;"show"="combat";"stealthEdges"=T;"thick"=6;"thickness"="thick";"track"=1;"x"=0;"y"=0;};"lock"={"auto"=F;"behavior"="toggle";"castFlash"=T;"channel"="SFX";"cycleLocks"=T;"pulse"=T;"soundCast"="alert";"soundClear"="soft";"soundCycle"="ping";"soundLock"="click";"sounds"=F;};"look"={"condition"="";"pulse"=T;"sheathe"=F;"startOn"=T;"tooltip"="show";"tooltipAt"="crosshair";"turnSpeed"=90;"unlockPanels"=T;"vendorMount"=T;"vignette"=T;"vignetteStrength"=0.45;"watchlist"="";};"smart"={"colorMelee"={#1=0.35;#2=1;#3=0.4;};"colorOut"={#1=1;#2=0.25;#3=0.25;};"colorRanged"={#1=1;#2=0.85;#3=0.2;};"enabled"=T;"hideDead"=F;"hideFlight"=F;"hideFriendly"=F;"hideIdle"=F;"hideNoTarget"=F;"hideRange"=F;"meleeSpell"="";"range"=T;"rangedSpell"="";"show"="always";};}
]]

local function Known(dst, src)
  for k, v in pairs(src) do
    local d = dst[k]
    if type(d) == "table" and type(v) == "table" and next(d) == nil then
      dst[k] = Z.Copy(v) -- open lists (like click macros) take whatever is given
    elseif d ~= nil and type(d) == type(v) then
      if type(v) == "table" and #v == 0 and next(v) ~= nil then
        Known(d, v)
      else
        dst[k] = Z.Copy(v)
      end
    end
  end
end

local data = Z.Share.Decode(STARTER)
if data then
  Known(Z.PROFILE_DEFAULTS, data)
end
