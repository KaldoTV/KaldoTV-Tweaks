-- modules/auto_potion.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB
local MacroUtils = NS.MacroUtils

local M = {}
M.displayName = (L and L.AUTO_POTION) or "Auto Potion"
M.events = {
  "PLAYER_LOGIN",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_SPECIALIZATION_CHANGED",
  "BAG_UPDATE_DELAYED",
  "UNIT_INVENTORY_CHANGED",
  "GET_ITEM_INFO_RECEIVED",
}

local MAX_PRIORITY_SLOTS = 8
local MAX_MACRO_LENGTH = 256
local SPELL_RECUPERATION = 1231411

local ACTION_CONFIG = {
  { key = "racial_auto", kind = "racial_auto" },
  { key = "crimson_vial", kind = "spell", spellID = 185311, classes = { "ROGUE" } },
  { key = "exhilaration", kind = "spell", spellID = 109304, classes = { "HUNTER" } },
  { key = "last_stand", kind = "spell", spellID = 12975, classes = { "WARRIOR" } },
  { key = "bitter_immunity", kind = "spell", spellID = 383762, classes = { "WARRIOR" } },
  { key = "desperate_prayer", kind = "spell", spellID = 19236, classes = { "PRIEST" } },
  { key = "expel_harm", kind = "spell", spellID = 322101, classes = { "MONK" } },
  { key = "healing_elixir", kind = "spell", spellID = 122281, classes = { "MONK" } },
  { key = "dark_pact", kind = "spell", spellID = 108416, classes = { "WARLOCK" } },
  { key = "vampiric_blood", kind = "spell", spellID = 55233, classes = { "DEATHKNIGHT" } },
  { key = "powerful_potion", kind = "item", rank1 = 258138 },
  { key = "silvermoon_potion", kind = "item", rank1 = 241305, rank2 = 241304 },
  { key = "refreshing_serum", kind = "item", rank1 = 241307, rank2 = 241306 },
  { key = "healthstone", kind = "item", rank1 = 5512, rank2 = 224464}
}

local DEFAULT_PRIORITY_ORDER = {
  "racial_auto",
  "crimson_vial",
  "exhilaration",
  "last_stand",
  "bitter_immunity",
  "desperate_prayer",
  "expel_harm",
  "healing_elixir",
  "dark_pact",
  "vampiric_blood",
  "healthstone",
  "silvermoon_potion",
  "powerful_potion",
  "refreshing_serum",
}

local KNOWN_RACIAL_SPELLS = {
  --Gift of the Naaru
  59545,
  59543,
  54548,
  416250,
  121093,
  59542,
  59544,
  370626,
  29547,
  28880,

  255647, -- Light's Judgment
  312411, -- Bag of Tricks
}

local defaults = {
  enabled = false,
  notify = true,
  macro_name = "KaldoPotion",
  replace_with_recuperation_out_of_combat = true,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
  db.characters = db.characters or {}
end

local function applyCharacterDefaults(charDB)
  for i = 1, MAX_PRIORITY_SLOTS do
    local key = "priority_" .. i
    if charDB[key] == nil then
      charDB[key] = DEFAULT_PRIORITY_ORDER[i] or ""
    end
  end
end

local function trim(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil end
  return s
end

local function normalizeMacroName(name, fallback)
  return MacroUtils.NormalizeMacroName(trim(name), fallback)
end

local function getCharacterKey()
  local name = UnitName and UnitName("player") or nil
  local realm = GetRealmName and GetRealmName() or nil
  name = trim(name) or "player"
  realm = trim(realm) or "realm"
  return name .. "-" .. realm
end

local function getPlayerClassToken()
  if not UnitClass then return nil end
  local _, classToken = UnitClass("player")
  return trim(classToken)
end

local function parseNumericID(value)
  if type(value) == "number" then
    if value > 0 then return math.floor(value) end
    return nil
  end
  value = trim(value)
  if not value then return nil end
  value = value:gsub("[^0-9]", "")
  if value == "" then return nil end
  value = tonumber(value)
  if not value or value <= 0 then return nil end
  return math.floor(value)
end

local function playerKnowsSpell(spellID)
  if not spellID then return false end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
  return false
end

local function getSpellName(spellID)
  if not spellID then return nil end
  if C_Spell and C_Spell.GetSpellName then
    return C_Spell.GetSpellName(spellID)
  end
  if GetSpellInfo then
    return GetSpellInfo(spellID)
  end
  return nil
end

local function getItemName(itemID)
  if not itemID then return nil end
  if C_Item and C_Item.GetItemNameByID then
    local name = C_Item.GetItemNameByID(itemID)
    if name and name ~= "" then return name end
  end
  if GetItemInfo then
    local name = GetItemInfo(itemID)
    if name and name ~= "" then return name end
  end
  return nil
end

local function getItemCountByID(itemID)
  if not itemID then return 0 end
  if C_Item and C_Item.GetItemCount then
    return C_Item.GetItemCount(itemID, false, false, false) or 0
  end
  if GetItemCount then
    return GetItemCount(itemID, false, false) or 0
  end
  return 0
end

local function requestConfiguredItemData()
  if not (C_Item and C_Item.RequestLoadItemDataByID) then return end
  for _, action in ipairs(ACTION_CONFIG) do
    if action.kind == "item" then
      local rank2 = parseNumericID(action.rank2)
      local rank1 = parseNumericID(action.rank1)
      if rank2 and not getItemName(rank2) then
        C_Item.RequestLoadItemDataByID(rank2)
      end
      if rank1 and not getItemName(rank1) then
        C_Item.RequestLoadItemDataByID(rank1)
      end
    end
  end
end

local function getItemLabel(action, preferredItemID)
  local name = getItemName(preferredItemID)
  if name and name ~= "" then return name end
  name = getItemName(parseNumericID(action.rank2))
  if name and name ~= "" then return name end
  name = getItemName(parseNumericID(action.rank1))
  if name and name ~= "" then return name end
  return trim(action.label) or trim(action.key) or "Item"
end

local function getActionDisplayLabel(action, fallbackSpellID)
  if action.kind == "spell" then
    return getSpellName(fallbackSpellID or parseNumericID(action.spellID))
      or trim(action.label)
      or trim(action.key)
      or "Spell"
  end
  if action.kind == "racial_auto" then
    return getSpellName(fallbackSpellID) or (L and L.AUTO_POTION_RACIAL_AUTO) or "Auto racial"
  end
  if action.kind == "item" then
    return getItemLabel(action, fallbackSpellID)
  end
  return trim(action.label) or trim(action.key) or "Action"
end

local function getKnownRacialSpellID()
  for _, spellID in ipairs(KNOWN_RACIAL_SPELLS) do
    if playerKnowsSpell(spellID) then
      return spellID
    end
  end
  return nil
end

local function shouldShowInPriority(action)
  if not action then return false end
  if action.kind == "item" then
    return parseNumericID(action.rank2) ~= nil or parseNumericID(action.rank1) ~= nil
  end
  if action.kind == "spell" then
    local spellID = parseNumericID(action.spellID)
    if not spellID then return false end

    if type(action.classes) == "table" and #action.classes > 0 then
      local classToken = getPlayerClassToken()
      if not classToken then return false end
      for _, allowedClass in ipairs(action.classes) do
        if tostring(allowedClass) == classToken then
          return true
        end
      end
      return false
    end

    return playerKnowsSpell(spellID)
  end
  if action.kind == "racial_auto" then
    return getKnownRacialSpellID() ~= nil
  end
  return false
end

local function buildAllowedPriorityMap()
  local allowed = {}
  for _, action in ipairs(ACTION_CONFIG) do
    local key = trim(action.key)
    if key and shouldShowInPriority(action) then
      allowed[key] = true
    end
  end
  return allowed
end

local function sanitizeCharacterPriorities(charDB, fillMissing)
  local allowed = buildAllowedPriorityMap()
  local nextValues = {}
  local seen = {}

  for i = 1, MAX_PRIORITY_SLOTS do
    local key = trim(charDB["priority_" .. i])
    if key and allowed[key] and not seen[key] then
      nextValues[#nextValues + 1] = key
      seen[key] = true
    end
  end

  if fillMissing then
    for _, key in ipairs(DEFAULT_PRIORITY_ORDER) do
      key = trim(key)
      if key and key ~= "" and allowed[key] and not seen[key] then
        nextValues[#nextValues + 1] = key
        seen[key] = true
        if #nextValues >= MAX_PRIORITY_SLOTS then break end
      end
    end
  end

  for i = 1, MAX_PRIORITY_SLOTS do
    charDB["priority_" .. i] = nextValues[i] or ""
  end
end

local function getPriorityValues(actions)
  local values = {
    { "", (L and L.AUTO_POTION_NONE) or "None" },
  }

  for _, action in ipairs(ACTION_CONFIG) do
    local key = trim(action.key)
    if key and shouldShowInPriority(action) then
      local label = (actions[key] and actions[key].label)
        or getActionDisplayLabel(action)
        or key
      values[#values + 1] = { tostring(key), label }
    end
  end
  return values
end

local function getAvailableActions()
  local actions = {}

  local racialSpellID = getKnownRacialSpellID()

  for _, action in ipairs(ACTION_CONFIG) do
    local key = trim(action.key)
    if key then
      if action.kind == "item" then
        local rank2 = parseNumericID(action.rank2)
        local rank1 = parseNumericID(action.rank1)
        local rank2Count = getItemCountByID(rank2)
        local rank1Count = getItemCountByID(rank1)
        local activeRank2 = rank2Count > 0 and rank2 or nil
        local activeRank1 = rank1Count > 0 and rank1 or nil
        if activeRank2 or activeRank1 then
          actions[key] = {
            kind = "item",
            label = getActionDisplayLabel(action, activeRank2 or activeRank1),
            rank2 = activeRank2,
            rank1 = activeRank1,
          }
        end
      elseif action.kind == "spell" then
        local spellID = parseNumericID(action.spellID)
        if spellID and playerKnowsSpell(spellID) then
          actions[key] = {
            kind = "spell",
            label = getActionDisplayLabel(action, spellID),
            spellID = spellID,
          }
        end
      elseif action.kind == "racial_auto" then
        if racialSpellID then
          actions[key] = {
            kind = "spell",
            label = getActionDisplayLabel(action, racialSpellID),
            spellID = racialSpellID,
            forceSelf = true,
          }
        end
      end
    end
  end

  return actions
end

local function appendActionLines(lines, action)
  if not action then return end
  if action.kind == "item" then
    if action.rank2 then
      lines[#lines + 1] = "/use [combat] item:" .. tostring(action.rank2)
    end
    if action.rank1 then
      lines[#lines + 1] = "/use [combat] item:" .. tostring(action.rank1)
    end
    return
  end

  if action.kind == "spell" and action.spellID then
    local spellName = getSpellName(action.spellID)
    if spellName and spellName ~= "" then
      if action.forceSelf then
        lines[#lines + 1] = "/cast [combat,@player] " .. spellName
      else
        lines[#lines + 1] = "/cast [combat] " .. spellName
      end
    end
  end
end

local function buildMacroBody(db, charDB)
  local actions = getAvailableActions()
  local seen = {}
  local lines = { "#showtooltip" }
  local knowsRecuperation = playerKnowsSpell(SPELL_RECUPERATION)

  if db.replace_with_recuperation_out_of_combat and knowsRecuperation then
    local recuperationName = getSpellName(SPELL_RECUPERATION)
    if recuperationName and recuperationName ~= "" then
      lines[#lines + 1] = "/cast [nocombat] " .. recuperationName
    end
  end

  for i = 1, MAX_PRIORITY_SLOTS do
    local key = trim(charDB["priority_" .. i])
    if key and not seen[key] then
      local before = #lines
      appendActionLines(lines, actions[key])
      if #lines > before then
        seen[key] = true
      end
    end
  end

  if #lines <= 1 then
    return nil, "empty"
  end

  local macroBody = table.concat(lines, "\n")
  if string.len(macroBody) > MAX_MACRO_LENGTH then
    return nil, "too_long"
  end
  return macroBody, nil
end

function M:GetCharacterDB()
  local db = self.db or self:EnsureDB()
  local charKey = getCharacterKey()
  local isNewCharacter = (db.characters[charKey] == nil)
  db.characters[charKey] = db.characters[charKey] or {}
  local charDB = db.characters[charKey]
  applyCharacterDefaults(charDB)
  sanitizeCharacterPriorities(charDB, isNewCharacter or charDB._priority_initialized ~= true)
  charDB._priority_initialized = true
  return charDB
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("AutoPotion", defaults)
  applyDefaults(db)
  requestConfiguredItemData()
  if db.priority_1 ~= nil then
    local charKey = getCharacterKey()
    db.characters[charKey] = db.characters[charKey] or {}
    local charDB = db.characters[charKey]
    for i = 1, MAX_PRIORITY_SLOTS do
      local key = "priority_" .. i
      if charDB[key] == nil and db[key] ~= nil then
        charDB[key] = db[key]
      end
      db[key] = nil
    end
    applyCharacterDefaults(charDB)
    sanitizeCharacterPriorities(charDB, true)
    charDB._priority_initialized = true
  end
  return db
end

function M:ResetDB()
  self.db = DB:ResetModuleState("AutoPotion", defaults)
  local charDB = self:GetCharacterDB()
  charDB._priority_initialized = true
  self._lastMacroBody = nil
  self._lastMacroName = nil
end

function M:GetOptions()
  local db = self.db or self:EnsureDB()
  local actions = getAvailableActions()
  local opts = {
    { type="header", text=self.displayName },
    { type="input", key="macro_name", label=(L and L.AUTO_POTION_MACRO_NAME) or "Macro name" },
    { type="toggle", key="notify", label=(L and L.AUTO_POTION_NOTIFY) or "Notify macro create/update in chat" },
    { type="toggle", key="replace_with_recuperation_out_of_combat", label=(L and L.AUTO_POTION_RECUPERATION_TOGGLE) or "Replace with Recuperation out of combat" },
    { type="header", text=(L and L.AUTO_POTION_PRIORITY_HEADER) or "Macro priority" },
  }

  for i = 1, MAX_PRIORITY_SLOTS do
    local slotIndex = i
    opts[#opts + 1] = {
      type = "select",
      key = "priority_" .. slotIndex,
      label = string.format((L and L.AUTO_POTION_PRIORITY_FMT) or "Priority %d", slotIndex),
      values = function() return getPriorityValues(actions) end,
      getValue = function()
        local currentCharDB = self:GetCharacterDB()
        return currentCharDB["priority_" .. slotIndex]
      end,
      setValue = function(v)
        local currentCharDB = self:GetCharacterDB()
        currentCharDB["priority_" .. slotIndex] = v
      end,
    }
  end
  return opts
end

function M:OnRegister()
  self.db = self:EnsureDB()
  requestConfiguredItemData()
  self._pendingUpdate = false
  self._lastMacroBody = nil
  self._lastMacroName = nil
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:QueueUpdate()
end

function M:Notify(action, macroName, err)
  local db = self.db or self:EnsureDB()
  if not db.notify or not DEFAULT_CHAT_FRAME then return end

  local msg
  if action == "created" then
    msg = string.format((L and L.AUTO_POTION_CREATED_FMT) or "Macro '%s' created.", macroName)
  elseif action == "updated" then
    msg = string.format((L and L.AUTO_POTION_UPDATED_FMT) or "Macro '%s' updated.", macroName)
  elseif action == "too_long" then
    msg = string.format((L and L.AUTO_POTION_TOO_LONG_FMT) or "Macro '%s' is too long and was not updated.", macroName)
  elseif action == "empty" then
    msg = string.format((L and L.AUTO_POTION_EMPTY_FMT) or "Macro '%s' was not updated because no valid action is configured.", macroName)
  elseif err then
    msg = string.format((L and L.AUTO_POTION_ERROR_FMT) or "Macro '%s' update failed: %s", macroName, err)
  end

  if msg then
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. msg)
  end
end

function M:UpdateMacro()
  local db = self.db or self:EnsureDB()
  if not db.enabled then return end

  local charDB = self:GetCharacterDB()
  local macroName = normalizeMacroName(db.macro_name, "KaldoPotion")
  local macroBody, err = buildMacroBody(db, charDB)

  if not macroBody then
    self:Notify(err, macroName)
    return
  end

  if self._lastMacroBody == macroBody and self._lastMacroName == macroName then return end

  local ok, actionOrErr = MacroUtils.CreateOrUpdateMacro(macroName, macroBody)
  if not ok then
    self:Notify(nil, macroName, actionOrErr)
    return
  end

  self._lastMacroBody = macroBody
  self._lastMacroName = macroName
  self:Notify(actionOrErr, macroName)
end

function M:QueueUpdate()
  if InCombatLockdown and InCombatLockdown() then
    self._pendingUpdate = true
    return
  end
  self._pendingUpdate = false
  self:UpdateMacro()
end

function M:OnEvent(event)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    self:QueueUpdate()
    return
  end

  if event == "PLAYER_REGEN_ENABLED" then
    if self._pendingUpdate then
      self:QueueUpdate()
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "BAG_UPDATE_DELAYED"
    or event == "UNIT_INVENTORY_CHANGED" then
    self:QueueUpdate()
    return
  end

  if event == "GET_ITEM_INFO_RECEIVED" then
    self:QueueUpdate()
    if NS.UI and NS.UI.RefreshModuleOptions then
      NS.UI:RefreshModuleOptions("AutoPotion")
    end
    return
  end
end

Kaldo:RegisterModule("AutoPotion", M)
