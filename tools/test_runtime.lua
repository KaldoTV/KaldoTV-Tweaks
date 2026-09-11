-- Run from the repository root with Lua 5.1 or newer.
unpack = unpack or table.unpack
local NS = { L = { MODULE_ERROR = 'error', ADDON_LOADED = 'loaded' } }
SlashCmdList = {}
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
local subscriptions = {}
CreateFrame = function()
  return {
    RegisterEvent = function(_, event) subscriptions[event] = true end,
    RegisterUnitEvent = function(_, event, unit) subscriptions[event] = unit end,
    UnregisterEvent = function(_, event) subscriptions[event] = nil end,
    SetScript = function() end,
  }
end
assert(loadfile('db.lua'))('kaldo_tweaks', NS)
KaldoDB = { modules = { Keep = { enabled = true, custom = 42 }, Broken = false } }
NS.DB:RunMigrations()
NS.DB:RunMigrations()
assert(KaldoDB.modules.Keep.custom == 42 and KaldoDB.modules.Keep.enabled)
assert(KaldoDB.modules.Broken == nil and KaldoDB.schema_version == 1)
local reset = NS.DB:ResetModuleState('Keep', { nested = { value = 1 } })
assert(reset.enabled and reset.nested.value == 1 and reset.custom == nil)
assert(loadfile('core.lua'))('kaldo_tweaks', NS)
local petCalls, broadCalls = 0, 0
NS.Kaldo:RegisterModule('Pet', { events = { 'UNIT_HEALTH', 'NEW_EVENT' },
  unitEvents = { UNIT_HEALTH = 'pet' }, OnEvent = function() petCalls = petCalls + 1 end })
KaldoDB.modules.Pet = { enabled = true }
NS.Kaldo:RefreshEventSubscriptions()
assert(subscriptions.UNIT_HEALTH == 'pet' and subscriptions.NEW_EVENT)
NS.Kaldo:RegisterModule('Broad', { events = { 'UNIT_HEALTH' }, OnEvent = function() broadCalls = broadCalls + 1 end })
KaldoDB.modules.Broad = { enabled = true }
NS.Kaldo:RefreshEventSubscriptions()
assert(subscriptions.UNIT_HEALTH == true, 'Broad subscriber lost unit events')
NS.Kaldo:Dispatch('UNIT_HEALTH', 'target')
assert(petCalls == 0 and broadCalls == 1, 'Per-module unit filtering failed')
KaldoDB.modules.Broad.enabled = false
NS.Kaldo:RefreshEventSubscriptions()
assert(subscriptions.UNIT_HEALTH == 'pet')
KaldoDB.modules.Pet.enabled = false
NS.Kaldo:RefreshEventSubscriptions()
assert(not subscriptions.NEW_EVENT and not subscriptions.UNIT_HEALTH, 'Disabled event leaked')
assert(subscriptions.PLAYER_LOGIN and subscriptions.ADDON_LOADED)

local timers = {}
C_Timer = { After = function(_, callback) timers[#timers + 1] = callback end }
local function flush()
  local pending = timers; timers = {}
  for _, callback in ipairs(pending) do callback() end
end
local function loadModule(path)
  local mod
  NS.Kaldo.RegisterModule = function(_, _, value) mod = value end
  assert(loadfile(path))('kaldo_tweaks', NS)
  mod.db = { enabled = true }
  return mod
end
local buff = loadModule('modules/buff_check.lua')
local updates = 0
buff.UpdateDisplay = function() updates = updates + 1 end
buff:OnEvent('UNIT_AURA', 'nameplate1')
assert(#timers == 0, 'Unrelated aura queued work')
buff:OnEvent('UNIT_AURA', 'party1')
buff:OnEvent('UNIT_AURA', 'player')
buff:OnEvent('GROUP_ROSTER_UPDATE')
assert(#timers == 1)
flush()
assert(updates == 1, 'Burst lost its trailing update')
buff:OnEvent('UNIT_AURA', 'pet')
buff.db.enabled = false
flush()
assert(updates == 1, 'Disabled buff module updated')

local potion = loadModule('modules/auto_potion.lua')
local inCombat = false
InCombatLockdown = function() return inCombat end
local macroUpdates, optionUpdates = 0, 0
potion.UpdateMacro = function() macroUpdates = macroUpdates + 1 end
NS.UI = { mainFrame = { IsShown = function() return true end }, selectedModule = 'AutoPotion',
  RefreshModuleOptions = function() optionUpdates = optionUpdates + 1 end }
potion:OnEvent('GET_ITEM_INFO_RECEIVED', 999999)
potion:OnEvent('UNIT_INVENTORY_CHANGED', 'target')
assert(#timers == 0)
potion:OnEvent('GET_ITEM_INFO_RECEIVED', 5512)
potion:OnEvent('BAG_UPDATE_DELAYED')
assert(#timers == 1)
inCombat = true
flush()
assert(macroUpdates == 0 and potion._pendingUpdate)
inCombat = false
potion:OnEvent('PLAYER_REGEN_ENABLED')
flush()
assert(macroUpdates == 1 and optionUpdates == 1)
potion:QueueUpdate()
potion.db.enabled = false
flush()
assert(macroUpdates == 1)

local equipment = loadModule('modules/equipment_info.lua')
local equipmentUpdates = 0
equipment.UpdateDisplay = function() equipmentUpdates = equipmentUpdates + 1 end
equipment.playerSlotItems = { [1] = { [100] = true, [200] = true }, [2] = { [300] = true } }
equipment.inspectSlotItems = { [1] = { [100] = true } }
equipment.playerSlotCache = { [1] = {}, [2] = {} }
equipment.inspectSlotCache = { [1] = {} }
equipment:OnEvent('GET_ITEM_INFO_RECEIVED', 999)
assert(#timers == 0 and equipment.playerSlotCache[1])
equipment:OnEvent('GET_ITEM_INFO_RECEIVED', 200) -- socketed gem
assert(not equipment.playerSlotCache[1] and equipment.playerSlotCache[2] and equipment.inspectSlotCache[1])
equipment:OnEvent('GET_ITEM_INFO_RECEIVED', 100)
assert(not equipment.inspectSlotCache[1] and #timers == 1)
flush()
assert(equipmentUpdates == 1)
local inspectCache = equipment.inspectSlotCache
equipment:InvalidateRenderCache('player')
assert(equipment.inspectSlotCache == inspectCache)
local originalGuild, originalPVP = function() end, function() end
InspectGuildFrame_Update, InspectPVPFrame_Update = originalGuild, originalPVP
equipment:OnEvent('ADDON_LOADED', 'Blizzard_InspectUI')
assert(InspectGuildFrame_Update == originalGuild and InspectPVPFrame_Update == originalPVP)
equipment:ScheduleInspectRetry()
equipment:ScheduleInspectRetry()
assert(equipment._inspectRetryCount == 1 and #timers == 1)
equipment.db.enabled = false
flush()
assert(equipmentUpdates == 1)

local mm = loadModule('modules/mm_keys.lua')
local shown, refreshes = true, 0
ChallengesFrame = { IsShown = function() return shown end }
mm.RefreshSeasonBestOverlays = function() refreshes = refreshes + 1 end
mm:OnEvent('CHALLENGE_MODE_MAPS_UPDATE')
mm:OnEvent('SPELLS_CHANGED')
assert(#timers == 1)
flush()
assert(refreshes == 1)
mm:QueueChallengesRefresh()
shown = false
flush()
assert(refreshes == 1, 'Hidden Challenges window refreshed')
shown = true
mm:QueueChallengesRefresh()
mm.db.enabled = false
flush()
assert(refreshes == 1, 'Disabled MM module refreshed')
print('PASS: migrations, subscriptions, unit filters, buff bursts, potion combat deferral, item/gem caches, inspect isolation, MM refresh lifecycle')
