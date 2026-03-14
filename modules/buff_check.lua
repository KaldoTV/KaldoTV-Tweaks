local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
M.displayName = L.BUFF_CHECK
M.events = {
  "PLAYER_LOGIN",
  "UNIT_AURA",
  "PLAYER_EQUIPMENT_CHANGED",
  "UNIT_INVENTORY_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_LEADER_CHANGED",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
}

local CATEGORY_ORDER = {
  "raid_buffs",
  "targeted_buffs",
  "self_buffs",
  "pet_reminders",
}

local CATEGORY_LABELS = {
  raid_buffs = "Raid Buffs",
  targeted_buffs = "Targeted Buffs",
  self_buffs = "Self Buffs",
  consumables = "Consumables",
  pet_reminders = "Pet Reminders",
  custom_buffs = "Custom Buffs",
}

local CATEGORY_DESCRIPTIONS = {
  raid_buffs = "Buffs expected on the whole group.",
  targeted_buffs = "Buffs expected on a specific target.",
  self_buffs = "Buffs expected only on yourself.",
  consumables = "Consumable or temporary player buffs.",
  pet_reminders = "Pet-related reminders.",
  custom_buffs = "Custom placeholders to extend later.",
}

local REMINDER_RULES = {
  {
    key = "arcane_intellect",
    category = "raid_buffs",
    mode = "raid",
    label = "Arcane Intellect",
    auraSpellID = 1459,
    castSpellID = 1459,
    icon = 135932,
    providers = { classes = { "MAGE" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },
  {
    key = "battle_shout",
    category = "raid_buffs",
    mode = "raid",
    label = "Battle Shout",
    auraSpellID = 6673,
    castSpellID = 6673,
    icon = 132333,
    providers = { classes = { "WARRIOR" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },
  {
    key = "blessing_of_the_bronze",
    category = "raid_buffs",
    mode = "raid",
    label = "Blessing of the Bronze",
    auraSpellID = 381748,
    castSpellID = 364342,
    icon = 4622448,
    providers = { classes = { "EVOKER" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },
  {
    key = "mark_of_the_wild",
    category = "raid_buffs",
    mode = "raid",
    label = "Mark of the Wild",
    auraSpellID = 1126,
    castSpellID = 1126,
    icon = 136078,
    providers = { classes = { "DRUID" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },
  {
    key = "power_word_fortitude",
    category = "raid_buffs",
    mode = "raid",
    label = "Power Word: Fortitude",
    auraSpellID = 21562,
    castSpellID = 21562,
    icon = 135987,
    providers = { classes = { "PRIEST" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },
  {
    key = "skyfury",
    category = "raid_buffs",
    mode = "raid",
    label = "Skyfury",
    auraSpellID = 462854,
    castSpellID = 462854,
    icon = 4630367,
    providers = { classes = { "SHAMAN" } },
    target = { type = "group" },
    onlyIfProviderPresent = true,
    restrictedGlowFallback = true,
  },

  -- Targeted
  {
    key = "earth_shield_any_one",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Earth Shield",
    auraSpellID = 974,
    icon = 136089,
    providers = { classes = { "SHAMAN" } },
    target = { type = "any_one", excludePlayer = true },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        974,
      },
    },
  },
  {
    key = "source_of_magic_healer",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Source of Magic",
    auraSpellID = 369459,
    icon = 4622469,
    providers = { classes = { "EVOKER" } },
    target = { type = "role", role = "HEALER" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        369459,
      },
    },
  },
  {
    key = "blistering_scale_tank",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Blistering Scale",
    auraSpellID = 360827,
    icon = 5199621,
    providers = { classes = { "EVOKER" } },
    target = { type = "role", role = "TANK" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        360827,
      },
    },
  },
  {
    key = "beacon_of_light",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Beacon of light",
    auraSpellID = 53563,
    icon = 236247,
    providers = { classes = { "PALADIN" } },
    target = { type = "any_one" },
    onlyIfProviderPresent = true,  
    requirements = {
      missingTalentSpellIDs = {
        200025,
      },
      talentSpellIDs = {
        20473,
      },
    }
  },
  {
    key = "beacon_of_faith",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Beacon of faith",
    auraSpellID = 156910,
    icon = 1030095,
    providers = { classes = { "PALADIN" } },
    target = { type = "any_one" },
    onlyIfProviderPresent = true,  
    requirements = {
      talentSpellIDs = {
        156910,
      },
    },
  },
  {
    key = "symbiotic_link",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Symbiotic Link",
    auraSpellID = 474750,
    icon = 1408837,
    providers = { classes = { "DRUID" } },
    target = { type = "any_one" },
    onlyIfProviderPresent = true,  
    requirements = {
      talentSpellIDs = {
        474750,
      },
    },
  },

  -- Self
  {
    key = "earth_shield_self",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Earth Shield",
    auraSpellID = 383648,
    icon = 136089,
    providers = { classes = { "SHAMAN" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        383010,
      },
    },
  },
  {
    key = "shadow_form",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Shadow form",
    auraSpellID = 232698,
    icon = 136200,
    providers = { classes = { "PRIEST" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        335467,
      },
    },
  },
  {
    key = "water_shield",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Water Shield",
    auraSpellID = 52127,
    icon = 132315,
    providers = { classes = { "SHAMAN" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        61295,
      },
    },
  },
  {
    key = "lightning_shield",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Lightning Shield",
    auraSpellID = 192106,
    icon = 136051,
    providers = { classes = { "SHAMAN" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      missingTalentSpellIDs = {
        61295,
      },
    },
  },
  {
    key = "earthliving_weapon",
    category = "self_buffs",
    mode = "weapon_enchant",
  label = "Earthliving Weapon",
  icon = 237578,
  providers = { classes = { "SHAMAN" } },
  target = { type = "mainhand" },
  weaponEnchantIDs = { 6498 },
  onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        382021,
      },
    }
  },  
  {
    key = "flametongue_weapon",
    category = "self_buffs",
    mode = "weapon_enchant",
    label = "Flametongue Weapon",
    icon = 135814,
    providers = { classes = { "SHAMAN" } },
    target = { type = "offhand" },
    weaponEnchantIDs = {
      5400
    },
    requirements = {
      talentSpellIDs = {
        318038,
      },
    },
    onlyIfProviderPresent = true,
  },
  {
    key = "windfury_weapon",
    category = "self_buffs",
    mode = "weapon_enchant",
    label = "Windfury Weapon",
    icon = 462329,
    providers = { classes = { "SHAMAN" } },
    target = { type = "mainhand" },
    weaponEnchantIDs = {
      5401
    },
    requirements = {
      talentSpellIDs = {
        33757,
      },
    },
    onlyIfProviderPresent = true,
  },
  {
    key = "tidecallers_guard",
    category = "self_buffs",
    mode = "weapon_enchant",
    label = "Tidecaller's Guard",
    icon = 538567,
    providers = { classes = { "SHAMAN" } },
    target = { type = "offhand" },
    weaponEnchantIDs = {
      7528
    },
    requirements = {
      talentSpellIDs = {
        445033,
      },
    },
    onlyIfProviderPresent = true,
  },
  {
    key = "rite_of_sanctification",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Rite of sanctification",
    auraSpellID = 433550,
    icon = 237172,
    providers = { classes = { "PALADIN" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        433568,
      },
    },
  },
  {
    key = "rite_of_supplication",
    category = "targeted_buffs",
    mode = "targeted",
    label = "Rite of supplication",
    auraSpellID = 433584,
    icon = 237051,
    providers = { classes = { "PALADIN" } },
    target = { type = "self" },
    onlyIfProviderPresent = true,
    requirements = {
      talentSpellIDs = {
        433583,
      },
    },
  },

  -- Pet
  {
    key = "pet_summoned",
    category = "pet_reminders",
    mode = "pet",
    label = "Pet Summoned",
    auraSpellID = nil,
    icon = 132599,
    providers = { classes = { "HUNTER", "WARLOCK", "DEATHKNIGHT" } },
    target = { type = "pet_exists" },
    onlyIfProviderPresent = false,
    requirements = {
      missingTalentSpellIDs = {
        466867,
      },
    },
  }
}

local defaults = {
  enabled = false,
  onlyPlayer = true,
  highlightOwn = true,
  highlightStyle = "blizzard",
  growth = "center",
  iconSize = 40,
  spacing = 8,
  alpha = 1,
  x = 0,
  y = 200,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local function GetGroupUnits()
  local units = { "player" }
  if IsInRaid and IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do
      units[#units + 1] = "raid" .. i
    end
  elseif IsInGroup and IsInGroup() then
    local n = GetNumSubgroupMembers() or 0
    for i = 1, n do
      units[#units + 1] = "party" .. i
    end
  end
  return units
end

local function BuildGroupSnapshot()
  local units = GetGroupUnits()
  local classes = {}
  local roles = {}

  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      local _, classFile = UnitClass(unit)
      if classFile then
        classes[classFile] = true
      end

      local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
      if role and role ~= "NONE" and roles[role] == nil then
        roles[role] = unit
      end
    end
  end

  return units, classes, roles
end

local function FindRoleUnit(role, roles)
  if not role then
    return nil
  end
  return roles and roles[role] or nil
end

local function HasBuff(unit, spellId, auraName)
  if not unit then
    return false
  end

  local ok, res = pcall(function()
    if AuraUtil and AuraUtil.FindAuraBySpellId and spellId then
      local name = AuraUtil.FindAuraBySpellId(spellId, unit, "HELPFUL")
      if name ~= nil then
        return true
      end
    end
    if AuraUtil and AuraUtil.FindAuraByName and auraName then
      local name = AuraUtil.FindAuraByName(auraName, unit, "HELPFUL")
      if name ~= nil then
        return true
      end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local i = 1
      while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then
          break
        end
        if spellId and aura.spellId == spellId then
          return true
        end
        if auraName and aura.name == auraName then
          return true
        end
        i = i + 1
      end
    end
    return false
  end)

  return ok and res == true or false
end

local function GetSpellNameSafe(spellId)
  if not spellId then
    return nil
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if info and info.name then
      return info.name
    end
  end
  if GetSpellInfo then
    return select(1, GetSpellInfo(spellId))
  end
  return nil
end

local function GetRuleDisplayLabel(rule)
  if not rule then
    return ""
  end

  local spellName = GetSpellNameSafe(rule.auraSpellID)
  if spellName and spellName ~= "" then
    return spellName
  end

  return rule.label or rule.key or ""
end

local function RuleAppliesToPlayer(rule, playerClass)
  local providers = rule.providers and rule.providers.classes
  if type(providers) ~= "table" or #providers == 0 then
    return true
  end

  for _, classFile in ipairs(providers) do
    if classFile == playerClass then
      return true
    end
  end

  return false
end

local function PlayerMeetsRequirements(rule)
  local requirements = rule and rule.requirements
  if type(requirements) ~= "table" then
    return true
  end

  local function playerKnowsRequirementSpell(spellID)
    if type(spellID) ~= "number" or spellID <= 0 then
      return false
    end
    if IsPlayerSpell and IsPlayerSpell(spellID) then
      return true
    end
    if IsSpellKnown and IsSpellKnown(spellID) then
      return true
    end
    return false
  end

  local function playerHasActiveTalentNode(nodeID)
    if type(nodeID) ~= "number" or nodeID <= 0 then
      return false
    end
    if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetNodeInfo) then
      return false
    end

    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then
      return false
    end

    local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)
    return nodeInfo and nodeInfo.activeRank and nodeInfo.activeRank > 0 or false
  end

  local talentSpellIDs = requirements.talentSpellIDs
  if type(talentSpellIDs) == "table" and #talentSpellIDs > 0 then
    local hasAnyTalent = false
    for _, spellID in ipairs(talentSpellIDs) do
      if playerKnowsRequirementSpell(spellID) then
        hasAnyTalent = true
        break
      end
    end
    if not hasAnyTalent then
      return false
    end
  end

  local talentNodeIDs = requirements.talentNodeIDs
  if type(talentNodeIDs) == "table" and #talentNodeIDs > 0 then
    local hasAnyNode = false
    for _, nodeID in ipairs(talentNodeIDs) do
      if playerHasActiveTalentNode(nodeID) then
        hasAnyNode = true
        break
      end
    end
    if not hasAnyNode then
      return false
    end
  end

  local missingTalentSpellIDs = requirements.missingTalentSpellIDs
  if type(missingTalentSpellIDs) == "table" and #missingTalentSpellIDs > 0 then
    for _, spellID in ipairs(missingTalentSpellIDs) do
      if playerKnowsRequirementSpell(spellID) then
        return false
      end
    end
  end

  local missingTalentNodeIDs = requirements.missingTalentNodeIDs
  if type(missingTalentNodeIDs) == "table" and #missingTalentNodeIDs > 0 then
    for _, nodeID in ipairs(missingTalentNodeIDs) do
      if playerHasActiveTalentNode(nodeID) then
        return false
      end
    end
  end

  return true
end

local function IsProviderPresent(rule, classes)
  local providers = rule.providers and rule.providers.classes
  if type(providers) ~= "table" or #providers == 0 then
    return true
  end

  for _, classFile in ipairs(providers) do
    if classes[classFile] then
      return true
    end
  end

  return false
end

local function ResolveTargetUnit(rule, roles)
  local targetType = rule.target and rule.target.type or "self"
  if targetType == "self" then
    return "player"
  end
  if targetType == "role" then
    return FindRoleUnit(rule.target.role, roles)
  end
  return nil
end

local function HasAuraOnAnyUnit(units, spellId, auraName, options)
  local excludePlayer = options and options.excludePlayer
  for _, unit in ipairs(units or {}) do
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
      if not (excludePlayer and unit == "player") then
        if HasBuff(unit, spellId, auraName) then
          return true
        end
      end
    end
  end
  return false
end

local function EvaluateRaidRule(rule, context)
  if context.db.onlyPlayer then
    return not HasBuff("player", rule.auraSpellID, context.auraNames[rule.key])
  end

  for _, unit in ipairs(context.units) do
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
      if not HasBuff(unit, rule.auraSpellID, context.auraNames[rule.key]) then
        return true
      end
    end
  end

  return false
end

local function EvaluateTargetedRule(rule, context)
  local targetType = rule.target and rule.target.type or "self"
  if targetType == "any_one" then
    return not HasAuraOnAnyUnit(context.units, rule.auraSpellID, context.auraNames[rule.key], rule.target)
  end

  local unit = ResolveTargetUnit(rule, context.roles)
  if not (unit and UnitExists(unit)) then
    return false
  end
  return not HasBuff(unit, rule.auraSpellID, context.auraNames[rule.key])
end

local function EvaluateSelfRule(rule, context)
  return not HasBuff("player", rule.auraSpellID, context.auraNames[rule.key])
end

local function GetWeaponEnchantState()
  if not GetWeaponEnchantInfo then
    return {
      mainhand = false,
      offhand = false,
      mainhandEnchantID = nil,
      offhandEnchantID = nil,
    }
  end

  local hasMainHandEnchant, _, _, mainhandEnchantID, hasOffHandEnchant, _, _, offhandEnchantID = GetWeaponEnchantInfo()
  return {
    mainhand = hasMainHandEnchant == true,
    offhand = hasOffHandEnchant == true,
    mainhandEnchantID = mainhandEnchantID,
    offhandEnchantID = offhandEnchantID,
  }
end

local function IsExpectedWeaponEnchant(activeEnchantID, expectedEnchantIDs)
  if type(expectedEnchantIDs) ~= "table" or #expectedEnchantIDs == 0 then
    return activeEnchantID ~= nil
  end

  if type(activeEnchantID) ~= "number" or activeEnchantID <= 0 then
    return false
  end

  for _, expectedID in ipairs(expectedEnchantIDs) do
    if type(expectedID) == "number" and expectedID > 0 and expectedID == activeEnchantID then
      return true
    end
  end

  return false
end

local function EvaluateWeaponEnchantRule(rule)
  local state = GetWeaponEnchantState()
  local targetType = rule.target and rule.target.type or "mainhand"
  local expectedEnchantIDs = rule.weaponEnchantIDs

  if targetType == "mainhand" then
    return not (state.mainhand and IsExpectedWeaponEnchant(state.mainhandEnchantID, expectedEnchantIDs))
  end
  if targetType == "offhand" then
    return not (state.offhand and IsExpectedWeaponEnchant(state.offhandEnchantID, expectedEnchantIDs))
  end
  if targetType == "either" then
    local mainhandOK = state.mainhand and IsExpectedWeaponEnchant(state.mainhandEnchantID, expectedEnchantIDs)
    local offhandOK = state.offhand and IsExpectedWeaponEnchant(state.offhandEnchantID, expectedEnchantIDs)
    return not (mainhandOK or offhandOK)
  end
  if targetType == "both" then
    local mainhandOK = state.mainhand and IsExpectedWeaponEnchant(state.mainhandEnchantID, expectedEnchantIDs)
    local offhandOK = state.offhand and IsExpectedWeaponEnchant(state.offhandEnchantID, expectedEnchantIDs)
    return not (mainhandOK and offhandOK)
  end

  return false
end

local function EvaluatePetRule(rule)
  local targetType = rule.target and rule.target.type or "pet_exists"
  if targetType == "pet_exists" then
    return not UnitExists("pet")
  end

  if not UnitExists("pet") then
    return true
  end

  return not HasBuff("pet", rule.auraSpellID, GetSpellNameSafe(rule.auraSpellID))
end

local function RuleRequiresPlayerProvider(rule)
  if not rule then
    return false
  end

  if rule.mode == "pet" or rule.mode == "weapon_enchant" then
    return true
  end

  local targetType = rule.target and rule.target.type
  return targetType == "self"
end

local function IsMythicPlusRunActive()
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return true
  end

  local currentRunID = C_MythicPlus and C_MythicPlus.GetCurrentRunID and C_MythicPlus.GetCurrentRunID()
  return type(currentRunID) == "number" and currentRunID > 0
end

local function IsRestrictedBuffCheckContext()
  return (InCombatLockdown and InCombatLockdown()) or IsMythicPlusRunActive()
end

local function IsSpellGlowActive(spellID)
  if type(spellID) ~= "number" or spellID <= 0 then
    return false
  end

  if IsSpellOverlayed and IsSpellOverlayed(spellID) then
    return true
  end

  if C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed and C_SpellActivationOverlay.IsSpellOverlayed(spellID) then
    return true
  end

  return false
end

local function ShouldEvaluateRule(rule, context)
  if not rule.auraSpellID and rule.mode ~= "pet" and rule.mode ~= "weapon_enchant" then
    return false
  end

  if rule.onlyIfProviderPresent and not IsProviderPresent(rule, context.classes) then
    return false
  end

  if RuleRequiresPlayerProvider(rule) and not RuleAppliesToPlayer(rule, context.playerClass) then
    return false
  end

  if context.db.onlyPlayer and not RuleAppliesToPlayer(rule, context.playerClass) then
    return false
  end

  if not PlayerMeetsRequirements(rule) then
    return false
  end

  return true
end

local function EvaluateRule(rule, context)
  if not ShouldEvaluateRule(rule, context) then
    return false
  end

  if rule.mode == "raid" then
    return EvaluateRaidRule(rule, context)
  end
  if rule.mode == "targeted" then
    return EvaluateTargetedRule(rule, context)
  end
  if rule.mode == "self" then
    return EvaluateSelfRule(rule, context)
  end
  if rule.mode == "weapon_enchant" then
    return EvaluateWeaponEnchantRule(rule)
  end
  if rule.mode == "pet" then
    return EvaluatePetRule(rule)
  end

  return false
end

local function ShouldEvaluateRestrictedRule(rule, context)
  if not (rule and rule.restrictedGlowFallback) then
    return false
  end

  if rule.mode ~= "raid" then
    return false
  end

  if not RuleAppliesToPlayer(rule, context.playerClass) then
    return false
  end

  if not PlayerMeetsRequirements(rule) then
    return false
  end

  return true
end

local function EvaluateRestrictedRule(rule, context)
  if not ShouldEvaluateRestrictedRule(rule, context) then
    return false
  end

  return IsSpellGlowActive(rule.castSpellID or rule.auraSpellID)
end

local function StopHighlightAnimation(icon)
  if not icon then
    return
  end
  icon.highlightAnimMode = nil
  icon.highlightAnimPhase = 0
  if icon:GetScript("OnUpdate") then
    icon:SetScript("OnUpdate", nil)
  end
end

local function HideAutoCastHighlight(icon)
  if not icon then
    return
  end
  StopHighlightAnimation(icon)
  if icon.autoCast then
    icon.autoCast:Hide()
  end
end

local function HideProcHighlight(icon)
  if not icon then
    return
  end
  StopHighlightAnimation(icon)
  if icon.proc then
    icon.proc:Hide()
  end
end

local function StartHighlightAnimation(icon, mode, size)
  if not icon then
    return
  end
  icon.highlightAnimMode = mode
  icon.highlightAnimPhase = icon.highlightAnimPhase or 0
  icon:SetScript("OnUpdate", function(self, elapsed)
    self.highlightAnimPhase = ((self.highlightAnimPhase or 0) + elapsed * 3) % (math.pi * 2)
    local wave = (math.sin(self.highlightAnimPhase) + 1) * 0.5
    if self.highlightAnimMode == "autocast" and self.autoCast then
      local base = size * 1.95
      local scale = 1 + (wave * 0.12)
      local alpha = 0.55 + (wave * 0.35)
      self.autoCast:SetSize(base * scale, base * scale)
      self.autoCast:SetAlpha(alpha)
    elseif self.highlightAnimMode == "proc" and self.proc then
      local scale = 1.6 + (wave * 0.45)
      local alpha = 0.45 + (wave * 0.55)
      self.proc:SetSize(size * scale, size * scale)
      self.proc:SetAlpha(alpha)
    end
  end)
end

local function ShowAutoCastHighlight(icon, size)
  if not icon or not icon.autoCast then
    return
  end
  icon.autoCast:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.autoCast:SetSize(size * 1.95, size * 1.95)
  icon.autoCast:SetAlpha(0.85)
  icon.autoCast:Show()
  StartHighlightAnimation(icon, "autocast", size)
end

local function ShowProcHighlight(icon, size)
  if not icon or not icon.proc then
    return
  end
  icon.proc:SetPoint("CENTER", icon, "CENTER", 0, 0)
  icon.proc:SetSize(size * 1.9, size * 1.9)
  icon.proc:SetAlpha(0.95)
  icon.proc:Show()
  StartHighlightAnimation(icon, "proc", size)
end

local function HideHighlightEffects(icon)
  if not icon then
    return
  end
  HideAutoCastHighlight(icon)
  HideProcHighlight(icon)
  if icon.pixel then
    for _, t in pairs(icon.pixel) do
      t:Hide()
    end
  end
  if icon.border then
    icon.border:Hide()
  end
end

local function CreateIcon(parent)
  local f = CreateFrame("Button", nil, parent)
  f:SetSize(32, 32)
  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints()
  f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.border:SetBlendMode("ADD")
  f.border:SetPoint("CENTER", f, "CENTER", 0, 0)
  f.border:SetSize(70, 70)
  f.border:Hide()
  f.pixel = {
    top = f:CreateTexture(nil, "OVERLAY"),
    bottom = f:CreateTexture(nil, "OVERLAY"),
    left = f:CreateTexture(nil, "OVERLAY"),
    right = f:CreateTexture(nil, "OVERLAY"),
  }
  for _, t in pairs(f.pixel) do
    t:SetColorTexture(1, 1, 0.4, 1)
    t:Hide()
  end
  f.autoCast = f:CreateTexture(nil, "OVERLAY")
  f.autoCast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
  f.autoCast:SetBlendMode("ADD")
  f.autoCast:Hide()
  f.proc = f:CreateTexture(nil, "OVERLAY")
  f.proc:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.proc:SetBlendMode("ADD")
  f.proc:Hide()
  f.badgeBG = f:CreateTexture(nil, "OVERLAY")
  f.badgeBG:SetColorTexture(0.05, 0.05, 0.05, 0.85)
  f.badgeBG:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
  f.badgeBG:Hide()

  f.badge = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  f.badge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, 3)
  f.badge:SetJustifyH("RIGHT")
  f.badge:SetTextColor(1, 0.95, 0.7, 1)
  f.badge:SetShadowColor(0, 0, 0, 1)
  f.badge:SetShadowOffset(1, -1)
  f.badge:Hide()
  return f
end

local function GetRuleBadgeText(rule)
  local targetType = rule and rule.target and rule.target.type or "group"
  if targetType == "self" then
    return "SELF"
  end
  if targetType == "mainhand" then
    return "MH"
  end
  if targetType == "offhand" then
    return "OH"
  end
  if targetType == "either" then
    return "WPN"
  end
  if targetType == "both" then
    return "BOTH"
  end
  if targetType == "pet_exists" or targetType == "pet_aura" then
    return "PET"
  end
  if targetType == "any_one" then
    return "ANY"
  end
  if targetType == "role" then
    local role = rule.target.role
    if role == "TANK" then
      return "TANK"
    end
    if role == "HEALER" then
      return "HEAL"
    end
  end
  return nil
end

function M:ApplyStyle()
  local db = self.db or self:EnsureDB()
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", db.x or 0, db.y or 200)
  self.frame:SetAlpha(db.alpha or 1)
  self.iconSize = db.iconSize or 32
  self.spacing = db.spacing or 6
end

function M:ClearIcons()
  for _, f in ipairs(self.icons) do
    f:Hide()
  end
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("BuffCheck", defaults)
  db.rulesEnabled = db.rulesEnabled or {}

  -- Backward-compatible migration from the old spellId keyed config.
  local legacy = db.buffsEnabled
  if type(legacy) == "table" then
    for _, rule in ipairs(REMINDER_RULES) do
      if rule.auraSpellID then
        local legacyKey = tostring(rule.auraSpellID)
        if db.rulesEnabled[rule.key] == nil and legacy[legacyKey] ~= nil then
          db.rulesEnabled[rule.key] = legacy[legacyKey]
        end
      end
    end
    db.buffsEnabled = nil
  end

  for _, rule in ipairs(REMINDER_RULES) do
    if db.rulesEnabled[rule.key] == nil then
      db.rulesEnabled[rule.key] = (rule.defaultEnabled ~= false)
    end
  end

  return db
end

function M:ResetDB()
  self.db = DB:ResetModuleState("BuffCheck", defaults)
  self:EnsureDB()
  self:ApplyStyle()
  self:UpdateDisplay()
end

function M:UpdateDisplay()
  local db = self.db or self:EnsureDB()
  if not db.enabled then
    self:ClearIcons()
    return
  end

  local _, playerClass = UnitClass("player")
  local units, classes, roles = BuildGroupSnapshot()
  local restrictedContext = IsRestrictedBuffCheckContext()
  local context = {
    db = db,
    units = units,
    classes = classes,
    roles = roles,
    playerClass = playerClass,
    auraNames = {},
    restricted = restrictedContext,
  }

  if not restrictedContext then
    for _, rule in ipairs(REMINDER_RULES) do
      context.auraNames[rule.key] = GetSpellNameSafe(rule.auraSpellID)
    end
  end

  local missing = {}
  for _, rule in ipairs(REMINDER_RULES) do
    local isMissing = false
    if db.rulesEnabled[rule.key] ~= false then
      if restrictedContext then
        isMissing = EvaluateRestrictedRule(rule, context)
      else
        isMissing = EvaluateRule(rule, context)
      end
    end

    if isMissing then
      local own = db.highlightOwn and RuleAppliesToPlayer(rule, playerClass)
      missing[#missing + 1] = {
        key = rule.key,
        rule = rule,
        icon = rule.icon or (rule.auraSpellID and GetSpellTexture(rule.auraSpellID)) or 134400,
        highlight = own,
      }
    end
  end

  self:ApplyStyle()
  self:ClearIcons()
  if #missing == 0 then
    return
  end

  for i, entry in ipairs(missing) do
    local icon = self.icons[i]
    if not icon then
      icon = CreateIcon(self.frame)
      self.icons[i] = icon
    end

    local size = self.iconSize
    icon:SetSize(size, size)
    local total = (#missing * size) + ((#missing - 1) * self.spacing)
    local growth = db.growth or "center"
    local x
    if growth == "right" then
      x = (i - 1) * (size + self.spacing)
    elseif growth == "left" then
      x = -((i - 1) * (size + self.spacing))
    else
      x = (i - 1) * (size + self.spacing) - (total / 2) + (size / 2)
    end
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self.frame, "CENTER", x, 0)
    icon.tex:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")

    local style = db.highlightStyle or "blizzard"
    local badgeText = GetRuleBadgeText(entry.rule)
    if badgeText then
      icon.badge:SetText(badgeText)
      icon.badge:SetFont("Fonts\\FRIZQT__.TTF", math.max(10, math.floor(size * 0.28)), "OUTLINE")
      local textWidth = icon.badge:GetStringWidth() or 0
      local textHeight = icon.badge:GetStringHeight() or 0
      icon.badgeBG:SetSize(textWidth + 6, textHeight + 2)
      icon.badgeBG:Show()
      icon.badge:Show()
    else
      icon.badgeBG:Hide()
      icon.badge:Hide()
      icon.badge:SetText("")
    end

    if style == "blizzard" then
      style = "proc"
    end

    if entry.highlight and style ~= "none" then
      HideHighlightEffects(icon)
      if style == "pixel" then
        local thick = math.max(1, math.floor(size / 16))
        icon.pixel.top:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        icon.pixel.top:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        icon.pixel.top:SetHeight(thick)
        icon.pixel.bottom:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        icon.pixel.bottom:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        icon.pixel.bottom:SetHeight(thick)
        icon.pixel.left:SetPoint("TOPLEFT", icon, "TOPLEFT", 0, 0)
        icon.pixel.left:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", 0, 0)
        icon.pixel.left:SetWidth(thick)
        icon.pixel.right:SetPoint("TOPRIGHT", icon, "TOPRIGHT", 0, 0)
        icon.pixel.right:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 0)
        icon.pixel.right:SetWidth(thick)
        for _, t in pairs(icon.pixel) do
          t:Show()
        end
      elseif style == "autocast" then
        ShowAutoCastHighlight(icon, size)
      elseif style == "border" then
        icon.border:SetSize(size * 1.55, size * 1.55)
        icon.border:Show()
      elseif style == "proc" then
        ShowProcHighlight(icon, size)
      else
        icon.border:SetSize(size * 2.2, size * 2.2)
        icon.border:Show()
      end
    else
      HideHighlightEffects(icon)
    end

    icon:Show()
  end
end

function M:GetDisplayName()
  return self.displayName
end

function M:GetOptions()
  local function screenHalfW()
    local w = UIParent and UIParent.GetWidth and UIParent:GetWidth() or 0
    return math.floor((w > 0 and w or 2000) / 2)
  end

  local function screenHalfH()
    local h = UIParent and UIParent.GetHeight and UIParent:GetHeight() or 0
    return math.floor((h > 0 and h or 1200) / 2)
  end

  local opts = {
    { type = "header", text = self.displayName },
    { type = "toggle", key = "onlyPlayer", label = L.ONLY_PLAYER_BUFFS },
    { type = "toggle", key = "highlightOwn", label = L.HIGHLIGHT_MY_BUFFS },
    { type = "select", key = "highlightStyle", label = L.HIGHLIGHT_STYLE,
      values = {
        { "pixel", L.HIGHLIGHT_STYLE_PIXEL },
        { "autocast", L.HIGHLIGHT_STYLE_AUTOCAST or "AutoCast" },
        { "border", L.HIGHLIGHT_STYLE_BORDER or "Border" },
        { "proc", L.HIGHLIGHT_STYLE_PROC or "Proc" },
        { "none", L.HIGHLIGHT_STYLE_NONE },
      }
    },
    { type = "select", key = "growth", label = L.GROWTH_DIRECTION or "Growth direction",
      values = {
        { "left", L.GROWTH_LEFT or "Left" },
        { "center", L.GROWTH_CENTER or "Center" },
        { "right", L.GROWTH_RIGHT or "Right" },
      }
    },
    { type = "number", key = "iconSize", label = L.ICON_SIZE, min = 12, max = 64, step = 1 },
    { type = "number", key = "spacing", label = L.SPACING, min = 0, max = 20, step = 1 },
    { type = "number", key = "alpha", label = L.ALPHA or "Alpha", min = 0.2, max = 1, step = 0.05 },
    { type = "number", key = "x", label = "X", min = function() return -screenHalfW() end, max = screenHalfW, step = 1 },
    { type = "number", key = "y", label = "Y", min = function() return -screenHalfH() end, max = screenHalfH, step = 1 },
  }

  for _, category in ipairs(CATEGORY_ORDER) do
    opts[#opts + 1] = { type = "header", text = CATEGORY_LABELS[category] or category }
    opts[#opts + 1] = { type = "label", text = CATEGORY_DESCRIPTIONS[category] or "" }

    for _, rule in ipairs(REMINDER_RULES) do
      if rule.category == category then
        opts[#opts + 1] = {
          type = "toggle",
          key = "rulesEnabled." .. rule.key,
          label = GetRuleDisplayLabel(rule),
        }
      end
    end
  end

  return opts
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:ApplyStyle()
  self:UpdateDisplay()
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self.frame = CreateFrame("Frame", nil, UIParent)
  self.frame:SetSize(1, 1)
  self.frame:SetFrameStrata("MEDIUM")
  self.icons = {}
  self._last = 0
  self:ApplyStyle()
end

function M:OnEvent(event, unit)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    self:ApplyStyle()
    self:UpdateDisplay()
    return
  end

  if not self.db or not self.db.enabled then
    return
  end

  if event == "UNIT_AURA" and unit and unit ~= "player" then
    if not (IsInGroup and IsInGroup()) and not (IsInRaid and IsInRaid()) then
      return
    end
  end

  if event == "UNIT_INVENTORY_CHANGED" and unit and unit ~= "player" then
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" and unit and unit ~= "player" then
    return
  end

  local now = GetTime()
  if now - (self._last or 0) < 0.2 then
    return
  end
  self._last = now
  self:UpdateDisplay()
end

Kaldo:RegisterModule("BuffCheck", M)
