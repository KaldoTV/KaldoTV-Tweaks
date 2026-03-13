-- core.lua
local ADDON_NAME, NS = ...
Kaldo = Kaldo or {}
NS.Kaldo = Kaldo

local L = NS.L
local DB = NS.DB

Kaldo.modules = {}
Kaldo.moduleOrder = Kaldo.moduleOrder or {}
Kaldo.events = Kaldo.events or CreateFrame("Frame")
Kaldo._eventMap = Kaldo._eventMap or {}
Kaldo._legacyModules = Kaldo._legacyModules or {}

local BOOTSTRAP_EVENTS = {
  PLAYER_LOGIN = true,
  ADDON_LOADED = true,
}

local LEGACY_RUNTIME_EVENTS = {
  "CHAT_MSG_SYSTEM",
  "UNIT_PET",
  "UNIT_HEALTH",
  "UNIT_FLAGS",
  "INSPECT_READY",
  "GET_ITEM_INFO_RECEIVED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "UNIT_AURA",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_LEADER_CHANGED",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_ENABLED",
  "LFG_PROPOSAL_SUCCEEDED",
  "LFG_LIST_APPLICATION_STATUS_UPDATED",
  "LFG_LIST_JOINED_GROUP",
  "CHALLENGE_MODE_KEYSTONE_RECEPTABLE_OPEN",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER",
  "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED",
  "BAG_UPDATE_DELAYED",
  "SOCKET_INFO_UPDATE",
}

local function isSyntheticEvent(eventName)
  return type(eventName) == "string" and eventName:find("^KALDO") ~= nil
end

local function dprint(...)
  DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. string.format(...))
end
Kaldo.dprint = dprint

function Kaldo:RegisterModule(name, mod)
  if not name or not mod then return end
  mod.name = name
  self.modules[name] = mod
  self.moduleOrder[#self.moduleOrder + 1] = mod

  if type(mod.events) == "table" then
    for _, eventName in ipairs(mod.events) do
      if type(eventName) == "string" and eventName ~= "" then
        self._eventMap[eventName] = self._eventMap[eventName] or {}
        self._eventMap[eventName][name] = mod
      end
    end
  else
    self._legacyModules[name] = mod
  end

  if mod.OnRegister then mod:OnRegister(self) end
end

function Kaldo:IterModules()
  return pairs(self.modules)
end

local function isModuleEnabled(mod)
  local mname = mod and (mod.name)
  if not mname then return false end
  local moduleDB = DB and DB:EnsureModuleDB(mname) or nil
  return moduleDB and moduleDB.enabled == true
end

local function dispatchToModule(event, mod, ...)
  if mod.OnEvent and isModuleEnabled(mod) then
    local ok, err = pcall(mod.OnEvent, mod, event, ...)
    if not ok then
      dprint(L.MODULE_ERROR .." %s: %s", tostring(mod.name), tostring(err))
    end
  end
end

function Kaldo:RefreshEventSubscriptions()
  for eventName in pairs(BOOTSTRAP_EVENTS) do
    self.events:RegisterEvent(eventName)
  end

  for _, eventName in ipairs(LEGACY_RUNTIME_EVENTS) do
    self.events:UnregisterEvent(eventName)
  end

  local needed = {}

  for eventName, modules in pairs(self._eventMap) do
    for _, mod in pairs(modules) do
      if isModuleEnabled(mod) then
        needed[eventName] = true
        break
      end
    end
  end

  for legacyName in pairs(self._legacyModules) do
    if isModuleEnabled(self.modules[legacyName]) then
      for _, eventName in ipairs(LEGACY_RUNTIME_EVENTS) do
        needed[eventName] = true
      end
      break
    end
  end

  for eventName in pairs(needed) do
    if not BOOTSTRAP_EVENTS[eventName] and not isSyntheticEvent(eventName) then
      self.events:RegisterEvent(eventName)
    end
  end
end

function Kaldo:Dispatch(event, ...)
  local dispatched = {}
  local targeted = self._eventMap[event]

  if targeted then
    for moduleName, mod in pairs(targeted) do
      dispatched[moduleName] = true
      dispatchToModule(event, mod, ...)
    end
  end

  for moduleName, mod in pairs(self._legacyModules) do
    if not dispatched[moduleName] then
      dispatchToModule(event, mod, ...)
    end
  end
end

Kaldo.events:SetScript("OnEvent", function(_, event, ...)
  if event == "PLAYER_LOGIN" then
    DB:RunMigrations()
    dprint(L.ADDON_LOADED)
    for name, mod in Kaldo:IterModules() do
      if mod and mod.EnsureDB then
        mod:EnsureDB()
      elseif DB then
        DB:EnsureModuleDB(name)
      end
    end
    Kaldo:RefreshEventSubscriptions()
  end
  Kaldo:Dispatch(event, ...)
end)


SLASH_KALDODEBUG1 = "/kaldostatus"
SlashCmdList["KALDODEBUG"] = function()
  DB:EnsureRoot()

  DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r Status modules")
  for name, mod in Kaldo:IterModules() do
    local db = KaldoDB.modules[name]
    local en = db and db.enabled
    DEFAULT_CHAT_FRAME:AddMessage(string.format(" - %s : enabled=%s (dbkey=%s, hasDB=%s)",
      tostring(name),
      tostring(en),
      tostring(name),
      tostring(db ~= nil)
    ))
  end
end



Kaldo.events:RegisterEvent("PLAYER_LOGIN")
Kaldo.events:RegisterEvent("ADDON_LOADED")

