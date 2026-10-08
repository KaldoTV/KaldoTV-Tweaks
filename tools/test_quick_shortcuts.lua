-- Run from the repository root with Lua 5.1 or newer.
local state, module
local secret = {}
local frames, macros = {}, {}
local NS = {
  L = {},
  Kaldo = { RegisterModule = function(_, _, value) module = value end },
  DB = { EnsureModuleState = function() return state.db end },
}

local function reset()
  state = {
    db = {
      enabled = true, hearth_selected = {}, hearth_random = false,
      hearth_astral = true, hearth_arcantina = true,
      repair_mode = "random", auction_mode = "random", bindings = {},
      create_macros = true, notify = false,
    },
    owned = { [54452] = true, [64488] = true, [253629] = true, [140192] = true, [118427] = true },
    hearthCount = 1, cooldowns = {}, unusable = {}, class = "MAGE", astralKnown = true,
    knownSpells = {}, spellCooldowns = {}, spellUnusable = {},
    astralCooldown = { startTime = 0, duration = 0, isEnabled = true, modRate = 1 },
  }
  if module then module.db = state.db end
end
reset()

issecretvalue = function(value) return rawequal(value, secret) end
GetTime = function() return 100 end
InCombatLockdown = function() return state.inCombat end
IsInGroup = function() return state.group ~= nil end
UnitClass = function() return state.class, state.class end
IsSpellKnown = function(id)
  if id == 556 then return state.astralKnown end
  return state.knownSpells[id] or false
end
PlayerHasToy = function(id) return state.owned[id] or false end
C_ToyBox = { IsToyUsable = function(id)
  if state.unusable[id] == secret then return secret end
  return not state.unusable[id]
end }
C_Item = {
  GetItemCount = function(id) return id == 6948 and state.hearthCount or 0 end,
  IsUsableItem = function()
    if state.hearthUnusable == secret then return secret end
    return not state.hearthUnusable
  end,
  GetItemCooldown = function(id)
    local cooldown = state.cooldowns[id] or { 0, 0, true }
    return cooldown[1], cooldown[2], cooldown[3]
  end,
}
C_Spell = {
  IsSpellUsable = function(id)
    local unusable = id == 556 and state.astralUnusable or state.spellUnusable[id]
    if unusable == secret then return secret end
    return not unusable
  end,
  GetSpellCooldown = function(id) return state.spellCooldowns[id] or state.astralCooldown end,
}
CreateFrame = function(_, name)
  local frame = { attributes = {}, scripts = {} }
  frame.SetAttribute = function(self, key, value)
    assert(not state.inCombat, "Protected attribute changed in combat")
    self.attributes[key] = value
  end
  frame.GetAttribute = function(self, key) return self.attributes[key] end
  frame.SetScript = function(self, event, callback) self.scripts[event] = callback end
  frame.RegisterForClicks = function(self, value) self.clicks = value end
  for _, method in ipairs({ "SetSize", "SetPoint", "SetAlpha", "EnableMouse", "Show" }) do
    frame[method] = function() end
  end
  if name then frames[name] = frame end
  return frame
end
GetMacroIndexByName = function(name) return macros[name] and 1 or 0 end
CreateMacro = function(name, _, body) macros[name] = body end
EditMacro = function(_, name, _, body) macros[name] = body end
assert(loadfile("macro_utils.lua"))("kaldo_tweaks", NS)
assert(loadfile("modules/quick_shortcuts.lua"))("kaldo_tweaks", NS)
module:OnRegister()
local button = frames.KaldoQuickHearthButton

local function click()
  button.scripts.PreClick(button, "LeftButton", true)
end
local function expectAction(kind, id)
  assert(button:GetAttribute("type") == kind, "Wrong hearth action type")
  assert(button:GetAttribute("type1") == kind, "Left click differs from the default action")
  assert(button:GetAttribute("item") == (kind == "item" and "item:" .. tostring(id) or nil))
  assert(button:GetAttribute("toy") == (kind == "toy" and id or nil), "Wrong hearth/fallback toy")
  assert(button:GetAttribute("spell") == (kind == "spell" and id or nil), "Wrong fallback spell")
  assert(button:GetAttribute("macrotext") == nil, "Hearth button still chains macro text")
end
local function hearthOnCooldown()
  for _, id in ipairs({ 6948, 54452, 64488 }) do state.cooldowns[id] = { 90, 1800, true } end
end

-- Regression: a cooldown must select Arcantina on this very keypress.
hearthOnCooldown()
click()
expectAction("toy", 253629)

-- A ready Hearthstone always takes priority over Arcantina and Astral Recall.
reset()
state.class = "SHAMAN"
click()
expectAction("item", 6948)
state.hearthCount = 0
click()
expectAction("toy", 54452)

-- A single mage toggle chooses Teleport solo and Portal in a party or raid.
for _, context in ipairs({ { id = 1259190 }, { group = "party", id = 1259194 }, { group = "raid", id = 1259194 } }) do
  reset()
  local id = context.id
  state.group = context.group
  state.knownSpells = { [1259190] = true, [1259194] = true }
  state.db.hearth_mage = true
  click()
  expectAction("spell", id)
  state.db.hearth_mage = false
  click()
  expectAction("item", 6948)
  state.db.hearth_mage = true
  state.class = "WARRIOR"
  click()
  expectAction("item", 6948)
  state.class, state.knownSpells[id] = "MAGE", nil
  click()
  expectAction("item", 6948)
  state.knownSpells[id], state.spellUnusable[id] = true, true
  click()
  expectAction("item", 6948)
  state.spellUnusable[id] = false
  state.spellCooldowns[id] = { startTime = 90, duration = 60, isEnabled = true, modRate = 1 }
  click()
  expectAction("item", 6948)
  hearthOnCooldown()
  click()
  expectAction("toy", 253629)
  state.spellCooldowns[id] = { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
  for _, field in ipairs({ "startTime", "duration", "isEnabled", "modRate" }) do
    local previous = state.spellCooldowns[id][field]
    state.spellCooldowns[id][field] = secret
    click()
    expectAction("toy", 253629)
    state.spellCooldowns[id][field] = previous
  end
  state.spellUnusable[id] = secret
  click()
  expectAction("toy", 253629)
  state.spellUnusable[id] = false
  state.db.enabled = false
  click()
  expectAction(nil)
end

-- Reevaluate the group on each click, including leaving a raid for solo play.
reset()
state.db.hearth_mage = true
state.knownSpells = { [1259190] = true, [1259194] = true }
click()
expectAction("spell", 1259190)
state.group = "party"
click()
expectAction("spell", 1259194)
state.group = "raid"
click()
expectAction("spell", 1259194)
state.group = nil
click()
expectAction("spell", 1259190)

-- Expose a single checkbox in the settings.
reset()
local mageOption
for _, option in ipairs(module:GetOptions()) do
  if option.key == "hearth_mage" then mageOption = option end
end
assert(mageOption and mageOption.type == "toggle" and not mageOption.values)

-- Restore the previous selection scenario for the toy readiness checks.
state.hearthCount = 0

-- Pick only ready, checked toys, including when randomness is enabled.
state.db.hearth_random = true
state.cooldowns[54452] = { 90, 1800, true }
for _ = 1, 20 do click(); expectAction("toy", 64488) end
state.db.hearth_selected["64488"] = false
state.db.hearth_astral = false
click()
expectAction("toy", 253629)

reset()
state.hearthUnusable = true
state.unusable[54452], state.unusable[64488] = true, true
click()
expectAction("toy", 253629)

-- Known, usable Astral Recall precedes Arcantina, but cooldowns do not.
reset()
state.class = "SHAMAN"
hearthOnCooldown()
click()
expectAction("spell", 556)
state.astralCooldown = { startTime = 90, duration = 900, isEnabled = true, modRate = 1 }
click()
expectAction("toy", 253629)
state.astralCooldown = { startTime = 1, duration = 150, isEnabled = true, modRate = 2 }
click()
expectAction("spell", 556)
state.astralUnusable = true
click()
expectAction("toy", 253629)
state.astralUnusable, state.astralKnown = false, false
click()
expectAction("toy", 253629)
state.astralKnown, state.db.hearth_astral = true, false
click()
expectAction("toy", 253629)

-- An unchecked/missing Hearthstone can also use the configured fallback.
reset()
state.hearthCount = 0
state.db.hearth_selected = { ["54452"] = false, ["64488"] = false }
click()
expectAction("toy", 253629)

-- Never bypass an unavailable, unowned, disabled or cooling down key.
for _, reason in ipairs({ "disabled", "missing", "unusable", "cooldown", "timerDisabled" }) do
  reset()
  hearthOnCooldown()
  if reason == "disabled" then state.db.hearth_arcantina = false end
  if reason == "missing" then state.owned[253629] = nil end
  if reason == "unusable" then state.unusable[253629] = true end
  if reason == "cooldown" then state.cooldowns[253629] = { 90, 1800, true } end
  if reason == "timerDisabled" then state.cooldowns[253629] = { 0, 0, false } end
  click()
  expectAction(nil)
end

-- Clear stale actions when nothing is available; reevaluate on the next click.
reset()
hearthOnCooldown()
click()
expectAction("toy", 253629)
state.cooldowns[253629] = { 90, 1800, true }
click()
expectAction(nil)
state.cooldowns[6948] = { 1, 10, true } -- expired, not yet reset to zero by the API
click()
expectAction("item", 6948)

-- Secret cooldown/usable values must never be compared or used for arithmetic.
for _, field in ipairs({ "startTime", "duration", "isEnabled", "modRate" }) do
  reset()
  hearthOnCooldown()
  state.class = "SHAMAN"
  state.astralCooldown[field] = secret
  click()
  expectAction("toy", 253629)
end
reset()
state.hearthCount = secret
state.unusable[54452] = secret
state.cooldowns[64488] = { secret, secret, secret }
state.class, state.astralUnusable = "SHAMAN", secret
click()
expectAction("toy", 253629)

-- Combat clicks must leave the secure action untouched; disabled modules do nothing.
state.inCombat = true
click()
expectAction("toy", 253629)
state.inCombat, state.db.enabled = false, false
click()
expectAction(nil)

-- Generated macros invoke the same direct action, with a key-down click.
reset()
module:UpdateMacros()
assert(button.clicks == "AnyDown")
assert(macros.KaldoHearth == "#showtooltip item:6948\n/click KaldoQuickHearthButton LeftButton 1")
assert(not macros.KaldoHearth:find("/use", 1, true), "Macro bypasses fallback selection")
hearthOnCooldown()
click()
expectAction("toy", 253629)
assert(macros.KaldoHearth == module:BuildHearthMacro(), "Generated macro changed with the cooldown")

-- Keep the legacy cooldown APIs functional as well.
GetItemCount, GetItemCooldown = C_Item.GetItemCount, C_Item.GetItemCooldown
IsUsableSpell = C_Spell.IsSpellUsable
GetSpellCooldown = function(id)
  local info = state.spellCooldowns[id] or state.astralCooldown
  return info.startTime, info.duration, info.isEnabled, info.modRate
end
C_Item, C_Spell = nil, nil
state.class = "SHAMAN"
click()
expectAction("spell", 556)
state.astralCooldown.duration, state.astralCooldown.startTime = 900, 90
click()
expectAction("toy", 253629)
state.db.hearth_mage, state.class = true, "MAGE"
state.knownSpells[1259190] = true
state.spellCooldowns[1259190] = { startTime = 0, duration = 0, isEnabled = true, modRate = 1 }
click()
expectAction("spell", 1259190)
print("PASS: Hearthstone readiness, Arcantina regression, Mage Midnight priority, Astral Recall priority, selection, secrets, combat, generated macro, legacy APIs")
