-- modules/auto_macros.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB
local MacroUtils = NS.MacroUtils

local M = {}
M.displayName = (L and L.AUTO_MACROS) or "Auto Macros"
M.events = {
  "PLAYER_LOGIN",
  "PLAYER_REGEN_ENABLED",
  "PLAYER_ENTERING_WORLD",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "PARTY_LEADER_CHANGED",
}

local SPELL_SCARLET_SCALE = 360827
local SPELL_SOURCE_OF_MAGIC = 369459
local SPELL_MISDIRECTION = 34477
local SPELL_TRICKS = 57934
local SPELL_EARTH_SHIELD = 974

local RAID_MARK_ICONS = {
  { 1, "{rt1} Star" },
  { 2, "{rt2} Circle" },
  { 3, "{rt3} Diamond" },
  { 4, "{rt4} Triangle" },
  { 5, "{rt5} Moon" },
  { 6, "{rt6} Square" },
  { 7, "{rt7} Cross" },
  { 8, "{rt8} Skull" },
}

local defaults = {
  enabled = false,
  notify = true,
  tank_mark_macro_enabled = true,
  tank_mark_icon = 1,
  tank_mark_macro_name = "KaldoMarkTank",
  evoker_scales_enabled = true,
  evoker_scales_macro_name = "KaldoScalesTank",
  evoker_source_enabled = true,
  evoker_source_macro_name = "KaldoSourceHeal",
  evoker_combo_enabled = false,
  evoker_combo_macro_name = "KaldoEvoSupport",
  hunter_misdirection_enabled = true,
  hunter_misdirection_macro_name = "KaldoMisdirection",
  rogue_tricks_enabled = true,
  rogue_tricks_macro_name = "KaldoTricks",
  shaman_earth_shield_enabled = true,
  shaman_earth_shield_macro_name = "KaldoEarthShield",
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
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

local function getSpellLabel(spellID)
  local spellName
  if C_Spell and C_Spell.GetSpellName then
    spellName = C_Spell.GetSpellName(spellID)
  elseif GetSpellInfo then
    spellName = GetSpellInfo(spellID)
  end
  if not spellName or spellName == "" then
    return string.format("Spell ID %d", spellID)
  end
  return string.format("%s (ID %d)", spellName, spellID)
end

local function getSpellCastToken(spellID)
  local spellName
  if C_Spell and C_Spell.GetSpellName then
    spellName = C_Spell.GetSpellName(spellID)
  elseif GetSpellInfo then
    spellName = GetSpellInfo(spellID)
  end
  if spellName and spellName ~= "" then
    return spellName
  end
  return tostring(spellID)
end

local function findGroupUnitByRole(role)
  if not role then return nil end

  if UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == role then
    return "player"
  end

  if UnitGroupRolesAssigned and UnitGroupRolesAssigned("player") == "NONE"
    and GetSpecialization and GetSpecializationRole then
    local specIndex = GetSpecialization()
    if specIndex and GetSpecializationRole(specIndex) == role then
      return "player"
    end
  end

  local n = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
  for i = 1, n do
    local unit = "party" .. i
    if UnitExists and UnitExists(unit) and UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) == role then
      return unit
    end
  end

  return nil
end

local function getUnitNameExact(unit)
  if not unit then return nil end
  local name = (GetUnitName and GetUnitName(unit, true)) or (UnitName and UnitName(unit))
  return trim(name)
end

local function playerKnowsSpell(spellID)
  if not spellID then return false end
  if IsSpellKnown and IsSpellKnown(spellID) then return true end
  if IsPlayerSpell and IsPlayerSpell(spellID) then return true end
  return false
end

local function buildTankMarkMacroBody(tankName, icon)
  local safeName = tostring(tankName or "")
  local safeIcon = tonumber(icon) or 1
  if safeIcon < 1 or safeIcon > 8 then safeIcon = 1 end
  return table.concat({
    "#showtooltip",
    "/targetexact " .. safeName,
    "/tm " .. tostring(safeIcon),
    "/targetlasttarget [exists]",
  }, "\n")
end

local function buildTargetCastMacroBody(spellID, targetName)
  local safeName = tostring(targetName or "")
  local spellToken = getSpellCastToken(spellID)
  return table.concat({
    "#showtooltip",
    "/cast [@" .. safeName .. ",help,nodead] " .. spellToken,
  }, "\n")
end

local function buildHunterMisdirectionMacroBody(tankName)
  local spellToken = getSpellCastToken(SPELL_MISDIRECTION)
  local conditions = {
    "[@focus,help,nodead] " .. spellToken,
  }
  if tankName and tankName ~= "" then
    conditions[#conditions + 1] = "[@" .. tostring(tankName) .. ",help,nodead] " .. spellToken
  end
  conditions[#conditions + 1] = "[help,nodead] " .. spellToken
  conditions[#conditions + 1] = "[@pet,exists,nodead] " .. spellToken

  return table.concat({
    "#showtooltip " .. spellToken,
    "/cast " .. table.concat(conditions, "; "),
  }, "\n")
end

local function buildEvokerComboBody(healName, tankName, knowsSource, knowsScales)
  local lines = {}
  local sourceToken = getSpellCastToken(SPELL_SOURCE_OF_MAGIC)
  local scalesToken = getSpellCastToken(SPELL_SCARLET_SCALE)
  local showToken = knowsSource and sourceToken or scalesToken
  lines[#lines + 1] = "#showtooltip " .. showToken

  if knowsSource and knowsScales and healName and tankName then
    -- Normal press = healer buff, Shift press = tank buff.
    lines[#lines + 1] = "/cast [mod:shift,@" .. tostring(tankName) .. ",help,nodead] " .. scalesToken
      .. "; [@" .. tostring(healName) .. ",help,nodead] " .. sourceToken
    return table.concat(lines, "\n")
  end

  if knowsSource and healName then
    lines[#lines + 1] = "/cast [@" .. tostring(healName) .. ",help,nodead] " .. sourceToken
  end
  if knowsScales and tankName then
    lines[#lines + 1] = "/cast [@" .. tostring(tankName) .. ",help,nodead] " .. scalesToken
  end

  if #lines <= 1 then return nil end
  return table.concat(lines, "\n")
end

function M:EnsureDB()
  return DB:EnsureModuleState("AutoMacros", defaults)
end

function M:ResetDB()
  self.db = DB:ResetModuleState("AutoMacros", defaults)
  self._lastByMacroName = {}
end

function M:GetOptions()
  local tankSpellTooltip = function() return (L and L.AUTO_MACROS_TOOLTIP_TANK_MARK) or "Create/update a macro that marks your group tank with a raid icon." end
  local scalesTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_TARGET_FMT) or "%s | target: %s"
    return string.format(fmt, getSpellLabel(SPELL_SCARLET_SCALE), (L and L.AUTO_MACROS_TARGET_TANK) or "tank")
  end
  local sourceTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_TARGET_FMT) or "%s | target: %s"
    return string.format(fmt, getSpellLabel(SPELL_SOURCE_OF_MAGIC), (L and L.AUTO_MACROS_TARGET_HEALER) or "healer")
  end
  local comboTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_COMBO_FMT) or "Single macro for %s then %s"
    return string.format(fmt, getSpellLabel(SPELL_SOURCE_OF_MAGIC), getSpellLabel(SPELL_SCARLET_SCALE))
  end
  local misdirectionTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_TARGET_FMT) or "%s | target: %s"
    return string.format(fmt, getSpellLabel(SPELL_MISDIRECTION), (L and L.AUTO_MACROS_TARGET_TANK) or "tank")
  end
  local tricksTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_TARGET_FMT) or "%s | target: %s"
    return string.format(fmt, getSpellLabel(SPELL_TRICKS), (L and L.AUTO_MACROS_TARGET_TANK) or "tank")
  end
  local earthShieldTooltip = function()
    local fmt = (L and L.AUTO_MACROS_TOOLTIP_TARGET_FMT) or "%s | target: %s"
    return string.format(fmt, getSpellLabel(SPELL_EARTH_SHIELD), (L and L.AUTO_MACROS_TARGET_TANK) or "tank")
  end

  return {
    { type="header", text=(L and L.AUTO_MACROS_SECTION_TANK_MARK) or "Tank mark macro" },
    { type="toggle", key="tank_mark_macro_enabled", label=(L and L.AUTO_MACROS_TANK_MARK_ENABLED) or "Enable tank mark macro", tooltip=tankSpellTooltip },
    { type="select", key="tank_mark_icon", label=(L and L.AUTO_MACROS_TANK_MARK_ICON) or "Raid mark icon", values=RAID_MARK_ICONS, tooltip=tankSpellTooltip },
    { type="input", key="tank_mark_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=tankSpellTooltip },

    { type="header", text=(L and L.AUTO_MACROS_SECTION_EVOKER) or "Evoker" },
    { type="toggle", key="evoker_scales_enabled", label=(L and L.AUTO_MACROS_EVOKER_SCALES) or "Enable tank buff macro", tooltip=scalesTooltip },
    { type="input", key="evoker_scales_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=scalesTooltip },
    { type="toggle", key="evoker_source_enabled", label=(L and L.AUTO_MACROS_EVOKER_SOURCE) or "Enable healer buff macro", tooltip=sourceTooltip },
    { type="input", key="evoker_source_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=sourceTooltip },
    { type="toggle", key="evoker_combo_enabled", label=(L and L.AUTO_MACROS_EVOKER_COMBO) or "Enable combined macro", tooltip=comboTooltip },
    { type="input", key="evoker_combo_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=comboTooltip },

    { type="header", text=(L and L.AUTO_MACROS_SECTION_HUNTER) or "Hunter" },
    { type="toggle", key="hunter_misdirection_enabled", label=(L and L.AUTO_MACROS_HUNTER_MISDIRECTION) or "Enable Misdirection macro", tooltip=misdirectionTooltip },
    { type="input", key="hunter_misdirection_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=misdirectionTooltip },

    { type="header", text=(L and L.AUTO_MACROS_SECTION_ROGUE) or "Rogue" },
    { type="toggle", key="rogue_tricks_enabled", label=(L and L.AUTO_MACROS_ROGUE_TRICKS) or "Enable Tricks of the Trade macro", tooltip=tricksTooltip },
    { type="input", key="rogue_tricks_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=tricksTooltip },

    { type="header", text=(L and L.AUTO_MACROS_SECTION_SHAMAN) or "Shaman" },
    { type="toggle", key="shaman_earth_shield_enabled", label=(L and L.AUTO_MACROS_SHAMAN_EARTH_SHIELD) or "Enable Earth Shield macro (tank)", tooltip=earthShieldTooltip },
    { type="input", key="shaman_earth_shield_macro_name", label=(L and L.AUTO_MACROS_MACRO_NAME) or "Macro name", tooltip=earthShieldTooltip },

    { type="header", text=(L and L.AUTO_MACROS_SECTION_MISC) or "Misc" },
    { type="toggle", key="notify", label=(L and L.AUTO_MACROS_NOTIFY) or "Notify macro create/update in chat" },
  }
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self._pendingUpdate = false
  self._lastByMacroName = {}
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:QueueUpdate()
end

function M:NotifyMacroUpdate(action, macroName)
  local db = self.db or self:EnsureDB()
  if not db.notify then return end
  if not DEFAULT_CHAT_FRAME then return end

  local fmt
  if action == "created" then
    fmt = (L and L.AUTO_MACROS_CREATED_FMT) or "Macro '%s' created."
  else
    fmt = (L and L.AUTO_MACROS_UPDATED_FMT) or "Macro '%s' updated."
  end
  DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. string.format(fmt, macroName))
end

function M:ApplyMacro(macroName, macroBody)
  if not macroName or macroName == "" or not macroBody or macroBody == "" then return end
  if self._lastByMacroName[macroName] == macroBody then return end

  local ok, actionOrErr = MacroUtils.CreateOrUpdateMacro(macroName, macroBody)
  if not ok then return end

  self._lastByMacroName[macroName] = macroBody
  self:NotifyMacroUpdate(actionOrErr, macroName)
end

function M:QueueUpdate()
  if InCombatLockdown and InCombatLockdown() then
    self._pendingUpdate = true
    return
  end
  self._pendingUpdate = false
  self:UpdateAllMacros()
end

function M:UpdateAllMacros()
  local db = self.db or self:EnsureDB()

  local tankName = getUnitNameExact(findGroupUnitByRole("TANK"))
  local healName = getUnitNameExact(findGroupUnitByRole("HEALER"))
  local knowsScales = playerKnowsSpell(SPELL_SCARLET_SCALE)
  local knowsSource = playerKnowsSpell(SPELL_SOURCE_OF_MAGIC)
  local knowsMisdirection = playerKnowsSpell(SPELL_MISDIRECTION)
  local knowsTricks = playerKnowsSpell(SPELL_TRICKS)
  local knowsEarthShield = playerKnowsSpell(SPELL_EARTH_SHIELD)

  if db.tank_mark_macro_enabled and tankName then
    local macroName = normalizeMacroName(db.tank_mark_macro_name, "KaldoMarkTank")
    local macroBody = buildTankMarkMacroBody(tankName, db.tank_mark_icon)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.evoker_scales_enabled and knowsScales and tankName then
    local macroName = normalizeMacroName(db.evoker_scales_macro_name, "KaldoScalesTank")
    local macroBody = buildTargetCastMacroBody(SPELL_SCARLET_SCALE, tankName)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.evoker_source_enabled and knowsSource and healName then
    local macroName = normalizeMacroName(db.evoker_source_macro_name, "KaldoSourceHeal")
    local macroBody = buildTargetCastMacroBody(SPELL_SOURCE_OF_MAGIC, healName)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.evoker_combo_enabled and (knowsSource or knowsScales) then
    local macroName = normalizeMacroName(db.evoker_combo_macro_name, "KaldoEvoSupport")
    local macroBody = buildEvokerComboBody(healName, tankName, knowsSource, knowsScales)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.hunter_misdirection_enabled and knowsMisdirection then
    local macroName = normalizeMacroName(db.hunter_misdirection_macro_name, "KaldoMisdirection")
    local macroBody = buildHunterMisdirectionMacroBody(tankName)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.rogue_tricks_enabled and knowsTricks and tankName then
    local macroName = normalizeMacroName(db.rogue_tricks_macro_name, "KaldoTricks")
    local macroBody = buildTargetCastMacroBody(SPELL_TRICKS, tankName)
    self:ApplyMacro(macroName, macroBody)
  end

  if db.shaman_earth_shield_enabled and knowsEarthShield and tankName then
    local macroName = normalizeMacroName(db.shaman_earth_shield_macro_name, "KaldoEarthShield")
    local macroBody = buildTargetCastMacroBody(SPELL_EARTH_SHIELD, tankName)
    self:ApplyMacro(macroName, macroBody)
  end
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
    or event == "GROUP_ROSTER_UPDATE"
    or event == "PLAYER_ROLES_ASSIGNED"
    or event == "PLAYER_SPECIALIZATION_CHANGED"
    or event == "PARTY_LEADER_CHANGED" then
    self:QueueUpdate()
    return
  end
end

Kaldo:RegisterModule("AutoMacros", M)
