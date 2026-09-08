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
    if key == 'GetFrameLevel' then return function() return 1 end end
    if key == 'CreateTexture' then return widget end
    return function() end
  end })
end
CreateFrame = widget
local casting = true
UnitCastingInfo = function()
  if casting then return 'Cast', nil, nil, 0, 1000, false, 1, false, 123 end
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
KaldoDB.modules.CastbarStyle.enabled = false
module:OnOptionChanged()
assert(module.states.nameplate1 == nil, 'Disabled module retained its state')
print('PASS: saved settings, normal/important colors, Blizzard refresh, removal, disable')
