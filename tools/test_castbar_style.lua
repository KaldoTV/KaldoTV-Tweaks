-- Run from the repository root with Lua 5.1 or newer.
unpack = unpack or table.unpack
local NS = { L = {}, Kaldo = {} }
local module
function NS.Kaldo:RegisterModule(_, value)
  module = value
  value:OnRegister()
end
assert(loadfile('db.lua'))('kaldo_tweaks', NS)

local function widget()
  return setmetatable({}, { __index = function(_, key)
    if key:match('^[a-z]') then return nil end
    if key == 'GetFrameLevel' then return function() return 1 end end
    if key == 'CreateTexture' then return widget end
    if key == 'SetScript' then return function(self, event, callback)
      self.scripts = self.scripts or {}; self.scripts[event] = callback
    end end
    return function() end
  end })
end
CreateFrame = widget
local casting = true
local notInterruptible = false
UnitCastingInfo = function()
  if casting then return 'Cast', nil, nil, 0, 1000, false, 1, notInterruptible, 123 end
end
UnitChannelInfo = function() end
UnitExists = function() return true end
local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local bar = widget()
local color = { 1, 1, 1 }
local texturePath = 'original'
bar.GetStatusBarColor = function() return unpack(color) end
bar.SetStatusBarColor = function(_, r, g, b) color = { r, g, b } end
bar.SetStatusBarTexture = function(_, path) texturePath = path end
bar.GetStatusBarTexture = function()
  return { GetAtlas = function() end, GetTexture = function() return texturePath end }
end
bar.UpdateBarFillTexture = function() color = { 1, 1, 1 }; texturePath = 'original' end
hooksecurefunc = function(object, key, callback)
  local original = object[key]
  object[key] = function(...) original(...); callback(...) end
end
local plate = { namePlateUnitToken = 'nameplate1', UnitFrame = { CastBarsContainer = { castBar = bar } } }
C_NamePlate = {
  GetNamePlateForUnit = function() return plate end,
  GetNamePlates = function() return { plate } end,
}
assert(loadfile('modules/castbar_style.lua'))('kaldo_tweaks', NS)

-- Simulate file loading, followed by WoW replacing SavedVariables at login.
module:EnsureDB()
KaldoDB = { modules = { CastbarStyle = {
  enabled = true, normal_color = { 0.2, 0.3, 0.8 }, glow_enabled = false,
} } }
module:EnsureDB() -- core.lua refreshes module databases before PLAYER_LOGIN.
module:OnEvent('PLAYER_LOGIN')
assert(color[1] == 0.2 and color[3] == 0.8, 'Saved color not applied after login')
assert(module.db == KaldoDB.modules.CastbarStyle, 'Stale database reference')
bar:UpdateBarFillTexture()
assert(color[1] == 0.2 and color[3] == 0.8, 'Blizzard overwrote the color')

C_Spell = { IsSpellImportant = function() return true end }
C_CurveUtil = { EvaluateColorValueFromBoolean = function(flag, yes, no)
  if flag then return yes else return no end
end }
module:ApplyCastStyle('nameplate1')
assert(color[1] == 1 and color[2] == 0.16, 'Important color not applied')

module:ScheduleCastStyle('nameplate1')
module:OnEvent('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
for _, callback in ipairs(timers) do callback() end
assert(module.states.nameplate1 == nil, 'Removed plate was styled by a queued callback')

module:ApplyCastStyle('nameplate1')
local glow = module.states.nameplate1.glow
local reads, moves = 0, 0
local width, height = 120, 12
bar.GetWidth = function() reads = reads + 1; return width end
bar.GetHeight = function() reads = reads + 1; return height end
for _, line in ipairs(glow.lines) do
  line.SetPoint = function() moves = moves + 1 end
  line.SetShown = function(self, shown) self.shown = shown end
end
local update = glow.scripts.OnUpdate
update(glow, 0.01)
assert(reads == 0 and moves == 0, 'Glow updated before its interval')
update(glow, 0.03)
assert(reads == 2 and moves == 8, 'Dimensions must be read once per animation update')

-- Ordinary Lua cannot create WoW secrets; this sentinel fails if used as a number.
local secret = {}
issecretvalue = function(value) return rawequal(value, secret) end
width = secret
update(glow, 0.04)
assert(glow.staticBorder == true, 'Secret width did not select safe border')
assert(glow.lines[4].shown and not glow.lines[5].shown, 'Safe border needs four edges')
local previousMoves = moves
glow:Apply(module.db)
assert(glow.staticBorder == true, 'Unchanged settings reset the safe border')
update(glow, 0.04)
assert(moves == previousMoves, 'Static border was unnecessarily repositioned')
width, height = 120, secret
update(glow, 0.04)
assert(glow.staticBorder == true, 'Secret height did not select safe border')
width, height = 160, 16
update(glow, 0.04)
assert(not glow.staticBorder and glow.lines[8].shown, 'Animation did not resume')
assert(moves == previousMoves + 8, 'Resumed animation has wrong line count')

-- Survival Hunter: a secret numeric cooldown must not suppress a ready Muzzle.
GetSpecialization = function() return 3 end
GetSpecializationInfo = function() return 255 end
IsPlayerSpell = function(id) return id == 187707 end
local cooldown = { isActive = false, isEnabled = true, duration = secret }
C_Spell.GetSpellCooldown = function(id)
  assert(id == 187707, 'Survival Hunter selected the wrong interrupt')
  return cooldown
end
glow.Show = function(self) self.shown = true end
glow.Hide = function(self) self.shown = false end
glow.SetAlphaFromBoolean = function(self, flag, yes, no) self.alpha = flag and yes or no end
module.db.glow_enabled = true
module:ApplyCastStyle('nameplate1')
assert(glow.shown and glow.alpha == 1, 'Ready interrupt suppressed by secret duration')
cooldown.isActive = true
module:OnEvent('SPELL_UPDATE_COOLDOWN')
assert(not glow.shown, 'Interrupt on cooldown still highlighted')
cooldown.isActive = false
module:OnEvent('SPELL_UPDATE_COOLDOWN')
assert(glow.shown and glow.alpha == 1, 'Glow did not return when interrupt became ready')
cooldown.isEnabled = false
module:ApplyCastStyle('nameplate1')
assert(not glow.shown, 'Disabled cooldown highlighted')
cooldown.isEnabled = true
notInterruptible = true
module:ApplyCastStyle('nameplate1')
assert(glow.alpha == 0, 'Non-interruptible cast highlighted')
notInterruptible = false
cooldown = { duration = 0, isEnabled = true }
module:ApplyCastStyle('nameplate1')
assert(glow.shown and glow.alpha == 1, 'Legacy public cooldown stopped working')
cooldown.duration = secret
module:ApplyCastStyle('nameplate1')
assert(not glow.shown, 'Unknown legacy cooldown treated as ready')

KaldoDB.modules.CastbarStyle.enabled = false
module:OnOptionChanged()
assert(module.states.nameplate1 == nil, 'Disabled module retained its state')
print('PASS: saved settings, colors, Blizzard refresh, removal, disable, glow throttle, secret dimensions, recovery, Survival Hunter interrupt readiness')
