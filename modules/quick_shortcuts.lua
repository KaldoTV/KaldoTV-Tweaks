-- modules/quick_shortcuts.lua
local _, NS = ...
local Kaldo, L, DB = NS.Kaldo, NS.L, NS.DB
local MacroUtils = NS.MacroUtils

local M = {}
M.displayName = (L and L.QUICK_SHORTCUTS) or "Quick shortcuts"
M.events = {
  "PLAYER_LOGIN", "PLAYER_REGEN_ENABLED", "PLAYER_ENTERING_WORLD",
  "NEW_TOY_ADDED", "TOYS_UPDATED", "COMPANION_LEARNED", "MOUNT_JOURNAL_USABILITY_CHANGED",
  "SPELLS_CHANGED", "PLAYER_SPECIALIZATION_CHANGED",
}

local REPAIR_MOUNTS = { yak = 122708, bear = 457485 }
local AH_MOUNTS = { caravan = 264058, gilded = 465235 }
local ARCANTINA_TOY = 253629
local ASTRAL_RECALL = 556
local HEARTHSTONE_TOYS = {
  263933, 264367, 265100, 245970, 246565, 257736, 235016, 54452, 64488,
  93672, 162973, 163045, 165669, 165670, 165802, 166746, 166747, 168907,
  172179, 188952, 190196, 190237, 193588, 200630, 206195, 208704, 209035,
  212337, 228940, 236687, 263489, 210455, 184353, 183716, 180290, 182773,
  140192,
}

local defaults = {
  enabled = false,
  notify = true,
  create_macros = false,
  repair_mode = "random",
  auction_mode = "random",
  hearth_random = true,
  hearth_selected = {},
  hearth_astral = true,
  hearth_arcantina = true,
  repair_macro_name = "KaldoRepairMt",
  auction_macro_name = "KaldoBruto",
  hearth_macro_name = "KaldoHearth",
  bindings = { repair = "", auction = "", hearth = "" },
}

local function knownSpell(spellID)
  return (IsSpellKnown and IsSpellKnown(spellID)) or (IsPlayerSpell and IsPlayerSpell(spellID))
    or (C_SpellBook and C_SpellBook.IsSpellInSpellBook and C_SpellBook.IsSpellInSpellBook(spellID))
end

local function learnedMounts(spells)
  local found = {}
  if not (C_MountJournal and C_MountJournal.GetMountIDs and C_MountJournal.GetMountInfoByID) then return found end
  local wanted = {}
  for key, spellID in pairs(spells) do wanted[spellID] = key end
  for _, mountID in ipairs(C_MountJournal.GetMountIDs() or {}) do
    local _, spellID, _, _, _, _, _, _, _, _, isCollected = C_MountJournal.GetMountInfoByID(mountID)
    local key = wanted[spellID]
    if key and (isCollected or knownSpell(spellID)) then found[#found + 1] = spellID end
  end
  table.sort(found)
  return found
end

local function hasToy(itemID)
  if PlayerHasToy then return PlayerHasToy(itemID) end
  return C_ToyBox and C_ToyBox.PlayerHasToy and C_ToyBox.PlayerHasToy(itemID) or false
end

local function hearthstoneToyItems()
  local found, seen = {}, {}
  local function addIfAvailable(itemID)
    if seen[itemID] then return end
    local available = itemID == 6948 or hasToy(itemID)
    if available and itemID ~= 6948 and C_ToyBox and C_ToyBox.IsToyUsable then
      local usable = C_ToyBox.IsToyUsable(itemID)
      if issecretvalue and issecretvalue(usable) then usable = nil end
      if usable == false then available = false end
    end
    if available then seen[itemID] = true; found[#found + 1] = itemID end
  end

  addIfAvailable(6948)
  for _, itemID in ipairs(HEARTHSTONE_TOYS) do addIfAvailable(itemID) end
  local toyIDs
  if C_ToyBox and C_ToyBox.GetAllToyIDs then
    toyIDs = C_ToyBox.GetAllToyIDs()
  elseif C_ToyBox and C_ToyBox.GetNumToys and C_ToyBox.GetToyFromIndex then
    toyIDs = {}
    for index = 1, C_ToyBox.GetNumToys() do
      local itemID = C_ToyBox.GetToyFromIndex(index)
      if itemID then toyIDs[#toyIDs + 1] = itemID end
    end
  elseif GetNumToy and GetToyFromIndex then
    toyIDs = {}
    for index = 1, GetNumToy() do
      local itemID = GetToyFromIndex(index)
      if itemID then toyIDs[#toyIDs + 1] = itemID end
    end
  end
  if toyIDs then
    for _, itemID in ipairs(toyIDs) do
      if hasToy(itemID) then
        local name
        if C_ToyBox and C_ToyBox.GetToyInfo then _, name = C_ToyBox.GetToyInfo(itemID) end
        if not name and C_Item and C_Item.GetItemInfo then name = C_Item.GetItemInfo(itemID) end
        name = tostring(name or ""):lower()
        if itemID ~= 118427 and (name:find("hearthstone", 1, true) or name:find("pierre de foyer", 1, true)
          or name:find("stone of the hearth", 1, true)) then
          addIfAvailable(itemID)
        end
      end
    end
  end
  table.sort(found)
  return found
end

local function listMacro(ids, command, random)
  if #ids == 0 then return nil end
  local tokens = {}
  for _, id in ipairs(ids) do
    local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(id)
    if not name and GetSpellInfo then name = GetSpellInfo(id) end
    tokens[#tokens + 1] = name or tostring(id)
  end
  if random and #ids > 1 then
    return "#showtooltip\n/castrandom " .. table.concat(tokens, ",")
  end
  return "#showtooltip " .. tokens[1] .. "\n" .. command .. " " .. tokens[1]
end

function M:EnsureDB()
  return DB:EnsureModuleState("QuickShortcuts", defaults)
end

function M:GetOptions()
  local options = {
    { type="header", text=(L and L.QUICK_SHORTCUTS_MOUNTS) or "Utility mounts" },
    { type="keybind", key="bindings.repair", buttonName="KaldoQuickRepairButton", label=(L and L.QUICK_SHORTCUTS_BIND_REPAIR) or "Repair mount shortcut" },
    { type="keybind", key="bindings.auction", buttonName="KaldoQuickAuctionButton", label=(L and L.QUICK_SHORTCUTS_BIND_AUCTION) or "Auction mount shortcut" },
    { type="select", key="repair_mode", label=(L and L.QUICK_SHORTCUTS_REPAIR_MODE) or "Repair mount", values={
      { "yak", (L and L.QUICK_SHORTCUTS_YAK) or "Yak" },
      { "bear", (L and L.QUICK_SHORTCUTS_BEAR) or "Bear" },
      { "random", (L and L.QUICK_SHORTCUTS_RANDOM) or "Random owned" },
    } },
    { type="input", key="repair_macro_name", label=(L and L.QUICK_SHORTCUTS_REPAIR_MACRO) or "Repair macro name" },
    { type="select", key="auction_mode", label=(L and L.QUICK_SHORTCUTS_AUCTION_MODE) or "Auction mount", values={
      { "caravan", (L and L.QUICK_SHORTCUTS_OLD_BRUTO) or "Mighty Caravan Brutosaur" },
      { "gilded", (L and L.QUICK_SHORTCUTS_GILDED_BRUTO) or "Trader's Gilded Brutosaur" },
      { "random", (L and L.QUICK_SHORTCUTS_RANDOM) or "Random owned" },
    } },
    { type="input", key="auction_macro_name", label=(L and L.QUICK_SHORTCUTS_AUCTION_MACRO) or "Auction macro name" },
    { type="header", text=(L and L.QUICK_SHORTCUTS_HEARTH) or "Hearthstone" },
    { type="keybind", key="bindings.hearth", buttonName="KaldoQuickHearthButton", label=(L and L.QUICK_SHORTCUTS_BIND_HEARTH) or "Hearthstone shortcut" },
    { type="toggle", key="hearth_random", label=(L and L.QUICK_SHORTCUTS_HEARTH_RANDOM) or "Randomly choose from checked hearthstones" },
    { type="toggle", key="hearth_astral", label=(L and L.QUICK_SHORTCUTS_ASTRAL) or "Shaman Astral Recall fallback" },
    { type="toggle", key="hearth_arcantina", label=(L and L.QUICK_SHORTCUTS_ARCANTINA) or "Personal Key to the Arcantina fallback" },
    { type="input", key="hearth_macro_name", label=(L and L.QUICK_SHORTCUTS_HEARTH_MACRO) or "Hearthstone macro name" },
    { type="header", text=(L and L.QUICK_SHORTCUTS_HEARTH_LIST) or "Included hearthstones" },
    { type="label", text=(L and L.QUICK_SHORTCUTS_HEARTH_LIST_HINT) or "Choose which collected hearthstone toys may be used." },
  }
  local names = { [6948] = (L and L.QUICK_SHORTCUTS_HOME_HEARTH) or "Hearthstone" }
  for _, itemID in ipairs(hearthstoneToyItems()) do
    local name
    if C_ToyBox and C_ToyBox.GetToyInfo then _, name = C_ToyBox.GetToyInfo(itemID) end
    if not name and C_Item and C_Item.GetItemInfo then name = C_Item.GetItemInfo(itemID) end
    options[#options + 1] = {
      type="toggle", key="hearth_selected." .. tostring(itemID),
      label=itemID == 6948 and names[itemID] or name or ("Item " .. tostring(itemID)),
    }
  end
  options[#options + 1] = { type="header", text=(L and L.QUICK_SHORTCUTS_MISC) or "Miscellaneous" }
  options[#options + 1] = { type="toggle", key="create_macros", label=(L and L.QUICK_SHORTCUTS_CREATE_MACROS) or "Also create optional macros" }
  options[#options + 1] = { type="toggle", key="notify", label=(L and L.QUICK_SHORTCUTS_NOTIFY) or "Notify macro updates" }
  return options
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self.last = {}
  self.buttons = {
    repair = CreateFrame("Button", "KaldoQuickRepairButton", UIParent, "SecureActionButtonTemplate"),
    auction = CreateFrame("Button", "KaldoQuickAuctionButton", UIParent, "SecureActionButtonTemplate"),
    hearth = CreateFrame("Button", "KaldoQuickHearthButton", UIParent, "SecureActionButtonTemplate"),
  }
  self.bindingOwner = CreateFrame("Frame", "KaldoQuickShortcutsBindingOwner", UIParent, "SecureFrameTemplate")
  for _, button in pairs(self.buttons) do
    button:SetSize(1, 1)
    button:SetPoint("CENTER", UIParent, "CENTER", 0, -10000)
    button:SetAlpha(0)
    button:EnableMouse(false)
    button:RegisterForClicks("AnyDown")
    button:SetAttribute("type", "macro")
    button:SetAttribute("type1", "macro")
    button:SetAttribute("pressAndHoldAction", true)
    button:Show()
  end
  self.buttons.hearth:SetAttribute("macrotext", "/use item:6948")
  self.buttons.hearth:SetAttribute("macrotext1", "/use item:6948")
  self.buttons.hearth:SetScript("PreClick", function(button)
    if InCombatLockdown and InCombatLockdown() then return end
    self:PrepareHearthAction(button)
  end)
end

local function selectedHearthstones(db)
  local selected = {}
  for _, itemID in ipairs(hearthstoneToyItems()) do
    if db.hearth_selected[tostring(itemID)] ~= false then selected[#selected + 1] = itemID end
  end
  return selected
end

local function chooseHearthstone(db)
  local choices = selectedHearthstones(db)
  if #choices == 0 then return nil end
  if db.hearth_random and #choices > 1 then return choices[math.random(#choices)] end
  return choices[1]
end

local function getHearthstoneName(itemID)
  if not itemID then return "Hearthstone" end
  local name
  if itemID ~= 6948 and C_ToyBox and C_ToyBox.GetToyInfo then _, name = C_ToyBox.GetToyInfo(itemID) end
  if not name and C_Item and C_Item.GetItemInfo then name = C_Item.GetItemInfo(itemID) end
  return name or "Hearthstone"
end

function M:BuildHearthMacro(db, itemID)
  local lines = { "#showtooltip " .. getHearthstoneName(itemID) }
  if itemID then lines[#lines + 1] = "/use item:" .. tostring(itemID) end
  if db.hearth_astral and select(2, UnitClass("player")) == "SHAMAN" and knownSpell(ASTRAL_RECALL) then
    local astralName = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(ASTRAL_RECALL)
    if not astralName and GetSpellInfo then astralName = GetSpellInfo(ASTRAL_RECALL) end
    lines[#lines + 1] = "/cast " .. (astralName or tostring(ASTRAL_RECALL))
  end
  if db.hearth_arcantina and hasToy(ARCANTINA_TOY) then
    lines[#lines + 1] = "/use item:" .. tostring(ARCANTINA_TOY)
  end
  return table.concat(lines, "\n")
end

function M:PrepareHearthAction(button)
  local db = self.db or self:EnsureDB()
  local itemID = chooseHearthstone(db)
  local body = self:BuildHearthMacro(db, itemID)
  button:SetAttribute("macrotext", body)
  button:SetAttribute("macrotext1", body)
end

function M:Apply(name, body)
  if not body or #body > 255 or self.last[name] == body then return end
  local ok, action = MacroUtils.CreateOrUpdateMacro(name, body)
  if ok then
    self.last[name] = body
    if self.db.notify and DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. string.format(
        action == "created" and ((L and L.AUTO_MACROS_CREATED_FMT) or "Macro '%s' created.")
          or ((L and L.AUTO_MACROS_UPDATED_FMT) or "Macro '%s' updated."), name))
    end
  end
end

function M:UpdateMacros()
  local db = self.db or self:EnsureDB()
  if not db.enabled then
    if InCombatLockdown and InCombatLockdown() then self.pending = true; return end
    if ClearOverrideBindings then ClearOverrideBindings(self.bindingOwner) end
    for _, button in pairs(self.buttons) do
      button:SetAttribute("type", nil)
      button:SetAttribute("type1", nil)
      button:SetAttribute("macrotext", nil)
      button:SetAttribute("macrotext1", nil)
    end
    return
  end
  local repair = learnedMounts(REPAIR_MOUNTS)
  if db.repair_mode ~= "random" then
    local selected, out = REPAIR_MOUNTS[db.repair_mode], {}
    for _, spellID in ipairs(repair) do if spellID == selected then out[1] = spellID end end
    repair = out
  end
  local auction = learnedMounts(AH_MOUNTS)
  if db.auction_mode ~= "random" then
    local selected, out = AH_MOUNTS[db.auction_mode], {}
    for _, spellID in ipairs(auction) do if spellID == selected then out[1] = spellID end end
    auction = out
  end
  local repairBody = listMacro(repair, "/cast", db.repair_mode == "random")
  local auctionBody = listMacro(auction, "/cast", db.auction_mode == "random")

  local selectedItem = chooseHearthstone(db)
  local hearthBody = (selectedItem or (db.hearth_astral and select(2, UnitClass("player")) == "SHAMAN" and knownSpell(ASTRAL_RECALL))
    or (db.hearth_arcantina and hasToy(ARCANTINA_TOY))) and self:BuildHearthMacro(db, selectedItem) or nil
  if InCombatLockdown and InCombatLockdown() then self.pending = true; return end
  local function setSecure(button, body)
    button:SetAttribute("type", body and "macro" or nil)
    button:SetAttribute("type1", body and "macro" or nil)
    button:SetAttribute("macrotext", body)
    button:SetAttribute("macrotext1", body)
  end
  setSecure(self.buttons.repair, repairBody)
  setSecure(self.buttons.auction, auctionBody)
  setSecure(self.buttons.hearth, hearthBody)
  if ClearOverrideBindings then ClearOverrideBindings(self.bindingOwner) end
  if SetOverrideBindingClick then
    local bindings = db.bindings or {}
    for action, buttonName in pairs({
      repair = "KaldoQuickRepairButton",
      auction = "KaldoQuickAuctionButton",
      hearth = "KaldoQuickHearthButton",
    }) do
      local key = bindings[action]
      if key and key ~= "" then SetOverrideBindingClick(self.bindingOwner, true, key, buttonName, "LeftButton") end
    end
  end
  if db.create_macros then
    self:Apply(MacroUtils.NormalizeMacroName(db.repair_macro_name, "KaldoRepairMt"), repairBody)
    self:Apply(MacroUtils.NormalizeMacroName(db.auction_macro_name, "KaldoBruto"), auctionBody)
    self:Apply(MacroUtils.NormalizeMacroName(db.hearth_macro_name, "KaldoHearth"), hearthBody)
  end
end

function M:QueueUpdate()
  if InCombatLockdown and InCombatLockdown() then self.pending = true; return end
  self.pending = false
  self:UpdateMacros()
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:QueueUpdate()
end

function M:OnEvent(event)
  if event == "PLAYER_REGEN_ENABLED" and not self.pending then return end
  self.db = self:EnsureDB()
  self:QueueUpdate()
end

function M:GetBindingMacros()
  return {
    { name="KALDO_QUICK_REPAIR", label=(L and L.QUICK_SHORTCUTS_BIND_REPAIR) or "Repair mount" },
    { name="KALDO_QUICK_AUCTION", label=(L and L.QUICK_SHORTCUTS_BIND_AUCTION) or "Auction mount" },
    { name="KALDO_QUICK_HEARTH", label=(L and L.QUICK_SHORTCUTS_BIND_HEARTH) or "Hearthstone" },
  }
end

Kaldo:RegisterModule("QuickShortcuts", M)
