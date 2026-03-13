-- modules/buff_check.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
M.displayName = L.BUFF_CHECK
M.events = {
  "PLAYER_LOGIN",
  "UNIT_AURA",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_LEADER_CHANGED",
  "PLAYER_ENTERING_WORLD",
}

local BUFFS = {
  { spellId=21562, icon=135987, sources={ "PRIEST" } },
  { spellId=381748, icon=4622448, sources={ "EVOKER" } },
  { spellId=462854, icon=4630367, sources={ "SHAMAN" } },
  { spellId=1126, icon=136078, sources={ "DRUID" } },
  { spellId=1459, icon=135932, sources={ "MAGE" } },
  { spellId=6673, icon=132333, sources={ "WARRIOR" } },
}

local defaults = {
  enabled = false,
  onlyPlayer = true,
  highlightOwn = true,
  highlightStyle = "blizzard", -- blizzard | pixel | none
  iconSize = 32,
  spacing = 6,
  alpha = 1,
  x = 0,
  y = 200,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("BuffCheck", defaults)
  db.buffsEnabled = db.buffsEnabled or {}
  for _, entry in ipairs(BUFFS) do
    local spellId = entry.spellId or entry[1]
    if spellId then
      local key = tostring(spellId)
      if db.buffsEnabled[key] == nil then db.buffsEnabled[key] = true end
    end
  end
  return db
end

function M:ResetDB()
  local db = DB:ResetModuleState("BuffCheck", defaults)
  self.db = db
  self:EnsureDB()
  self:ApplyStyle()
  self:UpdateDisplay()
end

local function GetGroupUnits()
  local units = { "player" }
  if IsInRaid and IsInRaid() then
    local n = GetNumGroupMembers() or 0
    for i = 1, n do units[#units + 1] = "raid" .. i end
  elseif IsInGroup and IsInGroup() then
    local n = GetNumSubgroupMembers() or 0
    for i = 1, n do units[#units + 1] = "party" .. i end
  end
  return units
end

local function BuildGroupSnapshot()
  local units = GetGroupUnits()
  local classes = {}

  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      local _, classFile = UnitClass(unit)
      if classFile then
        classes[classFile] = true
      end
    end
  end

  return units, classes
end

local function HasBuff(unit, spellId, auraName)
  if InCombatLockdown and InCombatLockdown() then return false end
  local ok, res = pcall(function()
    if AuraUtil and AuraUtil.FindAuraByName and auraName then
      local name = AuraUtil.FindAuraByName(auraName, unit, "HELPFUL")
      if name ~= nil then return true end
    end
    if AuraUtil and AuraUtil.FindAuraBySpellId and spellId then
      local name = AuraUtil.FindAuraBySpellId(spellId, unit, "HELPFUL")
      if name ~= nil then return true end
    end
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
      local i = 1
      while true do
        local aura = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not aura then break end
        local auraSpellId = aura.spellId
        local auraNameVal = aura.name
        if spellId and auraSpellId == spellId then return true end
        if auraName and auraNameVal == auraName then return true end
        i = i + 1
      end
      return false
    end
    if UnitBuff then
      local i = 1
      while true do
        local name2, _, _, _, _, _, _, _, _, spellID = UnitBuff(unit, i, "HELPFUL")
        if not name2 then break end
        if spellId and spellID == spellId then return true end
        if auraName and name2 == auraName then return true end
        i = i + 1
      end
    end
    return false
  end)
  if not ok then return false end
  return res == true
end

local function IsMythicKeyInProgress()
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return true
  end
  if C_MythicPlus and C_MythicPlus.GetCurrentRunID then
    local runID = C_MythicPlus.GetCurrentRunID()
    if runID and runID > 0 then
      return true
    end
  end
  return false
end

local function GetSpellNameSafe(spellId)
  if C_Spell and C_Spell.GetSpellInfo then
    local info = C_Spell.GetSpellInfo(spellId)
    if info and info.name then return info.name end
  end
  if GetSpellInfo then
    return select(1, GetSpellInfo(spellId))
  end
  return nil
end

local function IsMissingForGroup(spellId, auraName, sources, onlyPlayer, playerClass, units, classes)
  if sources and #sources > 0 then
    local anySource = false
    for _, classFile in ipairs(sources) do
      if classes[classFile] then
        anySource = true
        break
      end
    end
    if not anySource then return false end
    if onlyPlayer and playerClass then
      local canCast = false
      for _, classFile in ipairs(sources) do
        if classFile == playerClass then
          canCast = true
          break
        end
      end
      if not canCast then return false end
    end
  end

  if onlyPlayer then
    return not HasBuff("player", spellId, auraName)
  end

  for _, unit in ipairs(units) do
    if UnitExists(unit) and not UnitIsDeadOrGhost(unit) then
      if not HasBuff(unit, spellId, auraName) then return true end
    end
  end
  return false
end

local function CreateIcon(parent)
  local f = CreateFrame("Frame", nil, parent)
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
  return f
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

function M:UpdateDisplay()
  local db = self.db or self:EnsureDB()
  if not db.enabled then
    self:ClearIcons()
    return
  end
  if IsMythicKeyInProgress() then
    self:ClearIcons()
    return
  end
  if InCombatLockdown and InCombatLockdown() then
    self:ClearIcons()
    return
  end

  local missing = {}
  local _, playerClass = UnitClass("player")
  local units, classes = BuildGroupSnapshot()
  for _, entry in ipairs(BUFFS) do
    local spellId = entry.spellId or entry[1]
    local iconId = entry.icon or entry.iconId or entry[2]
    local sources = entry.sources or entry[3]
    local auraName = entry.auraName
    if not auraName and spellId then
      auraName = GetSpellNameSafe(spellId)
    end
    local key = spellId and tostring(spellId) or nil
    if key and db.buffsEnabled and db.buffsEnabled[key] == false then
      -- disabled
    elseif spellId and IsMissingForGroup(spellId, auraName, sources, db.onlyPlayer, playerClass, units, classes) then
      local own = false
      if db.highlightOwn and sources and playerClass then
        for _, classFile in ipairs(sources) do
          if classFile == playerClass then own = true; break end
        end
      end
      missing[#missing + 1] = { spellId = spellId, icon = iconId, auraName = auraName, highlight = own }
    end
  end

  self:ApplyStyle()
  self:ClearIcons()

  if #missing == 0 then return end

  for i, entry in ipairs(missing) do
    local spellId = entry.spellId
    local iconId = entry.icon or spellId
    local icon = self.icons[i]
    if not icon then
      icon = CreateIcon(self.frame)
      self.icons[i] = icon
    end
    local size = self.iconSize
    icon:SetSize(size, size)
    local total = (#missing * size) + ((#missing - 1) * self.spacing)
    local x = (i - 1) * (size + self.spacing) - (total / 2) + (size / 2)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", self.frame, "CENTER", x, 0)
    local tex
    if iconId then
      tex = iconId
    else
      tex = GetSpellTexture and GetSpellTexture(spellId) or nil
    end
    icon.tex:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    local style = db.highlightStyle or "blizzard"
    if entry.highlight and style ~= "none" then
      if style == "pixel" then
        local size = self.iconSize or 32
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
        for _, t in pairs(icon.pixel) do t:Show() end
        icon.border:Hide()
      else
        local size = self.iconSize or 32
        icon.border:SetSize(size * 2.2, size * 2.2)
        icon.border:Show()
        for _, t in pairs(icon.pixel) do t:Hide() end
      end
    else
      icon.border:Hide()
      for _, t in pairs(icon.pixel) do t:Hide() end
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
    { type="header", text=self.displayName },
    { type="toggle", key="onlyPlayer", label=L.ONLY_PLAYER_BUFFS },
    { type="toggle", key="highlightOwn", label=L.HIGHLIGHT_MY_BUFFS },
    { type="select", key="highlightStyle", label=L.HIGHLIGHT_STYLE,
      values={{"blizzard",L.HIGHLIGHT_STYLE_BLIZZARD},
              {"pixel",L.HIGHLIGHT_STYLE_PIXEL},
              {"none",L.HIGHLIGHT_STYLE_NONE}} },
    { type="number", key="iconSize", label=L.ICON_SIZE, min=12, max=64, step=1 },
    { type="number", key="spacing", label=L.SPACING, min=0, max=20, step=1 },
    { type="number", key="alpha", label=L.ALPHA or "Alpha", min=0.2, max=1, step=0.05 },
    { type="number", key="x", label="X", min=function() return -screenHalfW() end, max=screenHalfW, step=1 },
    { type="number", key="y", label="Y", min=function() return -screenHalfH() end, max=screenHalfH, step=1 },
  }

  opts[#opts + 1] = { type="header", text=L.BUFFS_LIST }
  for _, entry in ipairs(BUFFS) do
    local spellId = entry.spellId or entry[1]
    if spellId then
      local name = entry.displayName or GetSpellNameSafe(spellId) or tostring(spellId)
      opts[#opts + 1] = { type="toggle", key="buffsEnabled." .. tostring(spellId), label=name }
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

function M:OnEvent(event)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    self:ApplyStyle()
    self:UpdateDisplay()
    return
  end

  if not self.db or not self.db.enabled then return end

  local now = GetTime()
  if now - (self._last or 0) < 0.2 then return end
  self._last = now
  self:UpdateDisplay()
end

Kaldo:RegisterModule("BuffCheck", M)
