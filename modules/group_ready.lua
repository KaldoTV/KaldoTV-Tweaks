local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
M.displayName = (L and L.GROUP_READY) or "Group Ready"
M.events = {
  "PLAYER_LOGIN",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_LEADER_CHANGED",
  "PLAYER_ENTERING_WORLD",
  "PLAYER_REGEN_DISABLED",
  "PLAYER_REGEN_ENABLED",
  "INSPECT_READY",
}

local BUFF_SUMMARY_RULES = {
  { label = "Arcane Intellect", icon = 135932, providers = { "MAGE" } },
  { label = "Battle Shout", icon = 132333, providers = { "WARRIOR" } },
  { label = "Blessing of the Bronze", icon = 4622448, providers = { "EVOKER" } },
  { label = "Mark of the Wild", icon = 136078, providers = { "DRUID" } },
  { label = "Power Word: Fortitude", icon = 135987, providers = { "PRIEST" } },
  { label = "Skyfury", icon = 4630367, providers = { "SHAMAN" } },
  { label = "Bloodlust", icon = 136012, providers = { "MAGE", "SHAMAN", "EVOKER", "HUNTER" } },
  { label = "Combat Resurrection", icon = 136080, providers = { "DRUID", "DEATHKNIGHT", "WARLOCK", "PALADIN" } },
}

local defaults = {
  enabled = false,
  auto_show = true,
  alpha = 1,
  x = -360,
  y = 140,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local function IsMythicPlusRunActive()
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return true
  end

  local currentRunID = C_MythicPlus and C_MythicPlus.GetCurrentRunID and C_MythicPlus.GetCurrentRunID()
  return type(currentRunID) == "number" and currentRunID > 0
end

local function GetDetailedUnits()
  local units = { "player" }
  if IsInRaid and IsInRaid() then
    return units
  end
  if IsInGroup and IsInGroup() then
    local count = GetNumSubgroupMembers and GetNumSubgroupMembers() or 0
    for i = 1, count do
      units[#units + 1] = "party" .. i
    end
  end
  return units
end

local function GetAllGroupUnits()
  if IsInRaid and IsInRaid() then
    local units = {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    for i = 1, count do
      units[#units + 1] = "raid" .. i
    end
    return units
  end
  return GetDetailedUnits()
end

local function IsCompactMode()
  return IsInRaid and IsInRaid()
end

local function ShouldShowPopup()
  if not (IsInGroup and IsInGroup()) then
    return false
  end
  if IsMythicPlusRunActive() then
    return false
  end
  return true
end

local function BuildGroupFingerprint()
  local guids = {}
  for _, unit in ipairs(GetAllGroupUnits()) do
    if UnitExists(unit) then
      guids[#guids + 1] = UnitGUID(unit) or unit
    end
  end
  table.sort(guids)
  return table.concat(guids, ":")
end

local function BuildClassPresence()
  local classes = {}
  for _, unit in ipairs(GetAllGroupUnits()) do
    if UnitExists(unit) then
      local _, classFile = UnitClass(unit)
      if classFile then
        classes[classFile] = true
      end
    end
  end
  return classes
end

local function HasCoverage(rule, classes)
  for _, classFile in ipairs(rule.providers or {}) do
    if classes[classFile] then
      return true
    end
  end
  return false
end

local function GetRoleText(unit)
  local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(unit) or "NONE"
  if role == "TANK" then return "TANK" end
  if role == "HEALER" then return "HEAL" end
  if role == "DAMAGER" then return "DPS" end
  return "-"
end

local function GetUnitNameText(unit)
  local name = GetUnitName and GetUnitName(unit, true)
  if not name or name == "" then
    name = UnitName and UnitName(unit) or UNKNOWN
  end
  return name or UNKNOWN
end

local function GetClassColor(unit)
  local _, classFile = UnitClass(unit)
  local color = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if color then
    return color.r, color.g, color.b
  end
  return 1, 1, 1
end

local function CreateBackdropFrame(name, parent)
  local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
  })
  frame:SetBackdropColor(0.04, 0.04, 0.04, 0.94)
  frame:SetBackdropBorderColor(0.45, 0.45, 0.45, 1)
  return frame
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("GroupReady", defaults)
  applyDefaults(db)
  return db
end

function M:ResetDB()
  self.db = DB:ResetModuleState("GroupReady", defaults)
  self.manualHidden = false
  self:ApplyPosition()
  self:Refresh()
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

  return {
    { type = "header", text = self.displayName },
    { type = "toggle", key = "auto_show", label = (L and L.GROUP_READY_AUTO_SHOW) or "Auto show while forming a party" },
    { type = "number", key = "alpha", label = L.ALPHA or "Alpha", min = 0.2, max = 1, step = 0.05 },
    { type = "number", key = "x", label = "X", min = function() return -screenHalfW() end, max = screenHalfW, step = 1 },
    { type = "number", key = "y", label = "Y", min = function() return -screenHalfH() end, max = screenHalfH, step = 1 },
    { type = "button", label = (L and L.GROUP_READY_OPEN) or "Open popup", onClick = function() self.manualHidden = false self:Refresh(true) end },
  }
end

function M:ApplyPosition()
  if not self.frame then return end
  local db = self.db or self:EnsureDB()
  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", db.x or defaults.x, db.y or defaults.y)
  self.frame:SetAlpha(db.alpha or 1)
end

function M:CreateFrame()
  if self.frame then return end

  local frame = CreateBackdropFrame("KaldoGroupReadyFrame", UIParent)
  frame:SetSize(360, 212)
  frame:SetFrameStrata("MEDIUM")
  frame:EnableMouse(true)
  frame:SetMovable(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetClampedToScreen(true)
  frame:SetScript("OnDragStart", function(f)
    if not InCombatLockdown or not InCombatLockdown() then
      f:StartMoving()
    end
  end)
  frame:SetScript("OnDragStop", function(f)
    f:StopMovingOrSizing()
    local db = self.db or self:EnsureDB()
    db.x = math.floor((f:GetLeft() or 0) + (f:GetWidth() / 2) - ((UIParent:GetWidth() or 0) / 2))
    db.y = math.floor((f:GetBottom() or 0) + (f:GetHeight() / 2) - ((UIParent:GetHeight() or 0) / 2))
  end)
  frame:Hide()

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 16, -14)
  frame.title:SetText((L and L.GROUP_READY_POPUP_TITLE) or "Party checklist")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
  frame.subtitle:SetText((L and L.GROUP_READY_POPUP_SUBTITLE) or "Buff coverage and member iLvl")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -4, -4)
  close:SetScript("OnClick", function()
    self.manualHidden = true
    frame:Hide()
  end)

  frame.buffHeader = CreateFrame("Frame", nil, frame)
  frame.buffHeader:SetSize(328, 24)
  frame.buffHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48)
  frame.buffIcons = {}

  frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -78)
  frame.summary:SetJustifyH("LEFT")
  frame.summary:SetText("")

  frame.headerRole = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.headerRole:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -104)
  frame.headerRole:SetText((L and L.GROUP_READY_ROLE) or "Role")

  frame.headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.headerName:SetPoint("TOPLEFT", frame, "TOPLEFT", 62, -104)
  frame.headerName:SetText((L and L.GROUP_READY_NAME) or "Name")

  frame.headerIlvl = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.headerIlvl:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -50, -104)
  frame.headerIlvl:SetText((L and L.GROUP_READY_ILVL) or "iLvl")

  frame.rows = {}
  for i = 1, 5 do
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(328, 20)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -122 - ((i - 1) * 22))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0.07)

    row.role = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.role:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.role:SetWidth(42)
    row.role:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row, "LEFT", 50, 0)
    row.name:SetWidth(180)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.status:SetWidth(50)
    row.status:SetJustifyH("LEFT")

    row.ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.ilvl:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.ilvl:SetWidth(44)
    row.ilvl:SetJustifyH("RIGHT")

    frame.rows[i] = row
  end

  self.frame = frame
  self:ApplyPosition()
end

function M:EnsureInspectState()
  self.inspectCache = self.inspectCache or {}
  self.inspectQueue = self.inspectQueue or {}
  self.inspectQueued = self.inspectQueued or {}
end

function M:GetCachedIlvl(guid)
  local entry = self.inspectCache and self.inspectCache[guid]
  if not entry then return nil end
  if (GetTime() - (entry.ts or 0)) > 600 then
    self.inspectCache[guid] = nil
    return nil
  end
  return entry.ilvl
end

function M:StoreCachedIlvl(guid, ilvl)
  if not guid or not ilvl or ilvl <= 0 then return end
  self.inspectCache[guid] = { ilvl = ilvl, ts = GetTime() }
end

function M:QueueInspect(unit, guid)
  if not unit or not guid or unit == "player" then return end
  self:EnsureInspectState()
  if self.inspectQueued[guid] then return end
  self.inspectQueue[#self.inspectQueue + 1] = { unit = unit, guid = guid }
  self.inspectQueued[guid] = true
end

function M:ResetInspectQueue()
  self:EnsureInspectState()
  self.inspectQueue = {}
  self.inspectQueued = {}
  self.inspectPending = nil
  if ClearInspectPlayer then
    ClearInspectPlayer()
  end
end

function M:RequestNextInspect()
  self:EnsureInspectState()
  if self.inspectPending then return end
  if InCombatLockdown and InCombatLockdown() then return end

  while #self.inspectQueue > 0 do
    local entry = table.remove(self.inspectQueue, 1)
    if entry and entry.guid then
      self.inspectQueued[entry.guid] = nil
      if entry.unit and UnitExists(entry.unit) and CanInspect and CanInspect(entry.unit, false) then
        self.inspectPending = { unit = entry.unit, guid = entry.guid }
        if NotifyInspect then
          NotifyInspect(entry.unit)
        end
        C_Timer.After(1.5, function()
          if self.inspectPending and self.inspectPending.guid == entry.guid then
            self.inspectPending = nil
            if ClearInspectPlayer then ClearInspectPlayer() end
            self:Refresh()
            self:RequestNextInspect()
          end
        end)
        return
      end
    end
  end
end

function M:BuildMembers()
  local members = {}
  for _, unit in ipairs(GetDetailedUnits()) do
    if UnitExists(unit) then
      members[#members + 1] = {
        unit = unit,
        guid = UnitGUID(unit),
        name = GetUnitNameText(unit),
        roleText = GetRoleText(unit),
        isPlayer = unit == "player",
      }
    end
  end

  table.sort(members, function(a, b)
    if a.isPlayer ~= b.isPlayer then
      return a.isPlayer
    end
    return tostring(a.name) < tostring(b.name)
  end)

  return members
end

function M:GetGroupAverageIlvl()
  local total = 0
  local inspected = 0
  local units = GetAllGroupUnits()

  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      if UnitIsUnit and UnitIsUnit(unit, "player") then
        local equipped, avg = GetAverageItemLevel and GetAverageItemLevel()
        local ilvl = equipped or avg
        if ilvl and ilvl > 0 then
          total = total + ilvl
          inspected = inspected + 1
        end
      else
        local guid = UnitGUID(unit)
        local ilvl = guid and self:GetCachedIlvl(guid)
        if ilvl and ilvl > 0 then
          total = total + ilvl
          inspected = inspected + 1
        else
          self:QueueInspect(unit, guid)
        end
      end
    end
  end

  local count = #units
  local avg = inspected > 0 and (total / inspected) or nil
  return avg, inspected, count
end

function M:UpdateLayout()
  if not self.frame then
    return
  end

  local compact = IsCompactMode()
  if compact then
    self.frame:SetSize(360, 104)
    self.frame.headerRole:Hide()
    self.frame.headerName:Hide()
    self.frame.headerIlvl:Hide()
    for _, row in ipairs(self.frame.rows or {}) do
      row:Hide()
    end
  else
    self.frame:SetSize(360, 236)
    self.frame.headerRole:Show()
    self.frame.headerName:Show()
    self.frame.headerIlvl:Show()
  end
end

function M:UpdateBuffSummary()
  if not self.frame then return end
  local classes = BuildClassPresence()
  for i, rule in ipairs(BUFF_SUMMARY_RULES) do
    local icon = self.frame.buffIcons[i]
    if not icon then
      icon = CreateFrame("Frame", nil, self.frame.buffHeader)
      icon:SetSize(22, 22)
      icon:SetPoint("LEFT", self.frame.buffHeader, "LEFT", (i - 1) * 26, 0)
      icon.tex = icon:CreateTexture(nil, "ARTWORK")
      icon.tex:SetAllPoints()
      icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      icon.tex:SetTexture(rule.icon)
      icon.border = icon:CreateTexture(nil, "OVERLAY")
      icon.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      icon.border:SetBlendMode("ADD")
      icon.border:SetPoint("CENTER", icon, "CENTER", 0, 0)
      icon.border:SetSize(36, 36)
      self.frame.buffIcons[i] = icon
    end

    local covered = HasCoverage(rule, classes)
    icon:SetAlpha(covered and 1 or 0.28)
    icon:SetScript("OnEnter", function(selfIcon)
      if not GameTooltip then return end
      GameTooltip:SetOwner(selfIcon, "ANCHOR_RIGHT")
      GameTooltip:ClearLines()
      GameTooltip:AddLine(rule.label, 1, 1, 1)
      GameTooltip:AddLine(
        covered and ((L and L.GROUP_READY_BUFF_COVERED) or "Covered by group") or ((L and L.GROUP_READY_BUFF_MISSING) or "Missing from group"),
        covered and 0.3 or 1,
        covered and 1 or 0.3,
        0.3,
        true
      )
      GameTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
      if GameTooltip then GameTooltip:Hide() end
    end)
  end
end

function M:UpdateRows()
  if not self.frame then return end
  if IsCompactMode() then
    for _, row in ipairs(self.frame.rows or {}) do
      row:Hide()
    end
    return
  end

  local members = self:BuildMembers()

  for i, row in ipairs(self.frame.rows or {}) do
    local info = members[i]
    if info then
      row:Show()
      row.role:SetText(info.roleText or "-")
      row.name:SetText(info.name or UNKNOWN)
      row.name:SetTextColor(GetClassColor(info.unit))

      if info.isPlayer then
        local equipped, avg = GetAverageItemLevel and GetAverageItemLevel()
        local ilvl = equipped or avg
        if ilvl and ilvl > 0 then
          row.ilvl:SetFormattedText("%.1f", ilvl)
        else
          row.ilvl:SetText("-")
        end
        row.status:SetText((L and L.GROUP_READY_SELF) or "You")
      else
        local cached = self:GetCachedIlvl(info.guid)
        if cached then
          row.ilvl:SetFormattedText("%.1f", cached)
          row.status:SetText("")
        else
          row.ilvl:SetText("...")
          row.status:SetText((L and L.GROUP_READY_PENDING) or "Scan")
          self:QueueInspect(info.unit, info.guid)
        end
      end
    else
      row:Hide()
    end
  end
end

function M:UpdateSummary()
  if not self.frame or not self.frame.summary then
    return
  end

  local avg, inspected, count = self:GetGroupAverageIlvl()
  local avgText
  if avg then
    avgText = string.format((L and L.GROUP_READY_AVG_FMT) or "Avg %.1f", avg)
  else
    avgText = (L and L.GROUP_READY_AVG_UNKNOWN) or "Avg -"
  end

  local inspectedText = string.format((L and L.GROUP_READY_INSPECTED_FMT) or "%d/%d inspected", inspected or 0, count or 0)
  self.frame.summary:SetText(avgText .. "  |  " .. inspectedText)
end

function M:Refresh(forceShow)
  local db = self.db or self:EnsureDB()
  self.db = db
  self:CreateFrame()
  self:ApplyPosition()

  if not db.enabled or not ShouldShowPopup() then
    self.frame:Hide()
    return
  end
  if self.manualHidden and not forceShow then
    return
  end
  if not db.auto_show and not forceShow then
    self.frame:Hide()
    return
  end

  self:UpdateLayout()
  self:UpdateBuffSummary()
  self:UpdateSummary()
  self:UpdateRows()
  self.frame:Show()
  self:RequestNextInspect()
end

function M:OpenWindow()
  self.manualHidden = false
  self:Refresh(true)
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self:EnsureInspectState()
  self.groupFingerprint = ""

  SLASH_KALDOGROUPREADY1 = "/kaldoinspect"
  SlashCmdList["KALDOGROUPREADY"] = function()
    if not self.db then
      self.db = self:EnsureDB()
    end
    if not self.db.enabled then
      print("|cff7fd1ffKaldo Tweaks:|r Group Ready module is disabled.")
      return
    end
    self:OpenWindow()
  end
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:ApplyPosition()
  self:Refresh()
end

function M:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    self:CreateFrame()
    self:Refresh()
    return
  end

  if not self.db or not self.db.enabled then
    if self.frame then self.frame:Hide() end
    return
  end

  if event == "INSPECT_READY" then
    local guid = ...
    if self.inspectPending and guid and guid == self.inspectPending.guid then
      local unit = self.inspectPending.unit
      local ilvl = unit and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel and C_PaperDollInfo.GetInspectItemLevel(unit)
      if ilvl and ilvl > 0 then
        self:StoreCachedIlvl(guid, ilvl)
      end
      self.inspectPending = nil
      if ClearInspectPlayer then ClearInspectPlayer() end
      self:Refresh()
      self:RequestNextInspect()
    end
    return
  end

  local fingerprint = BuildGroupFingerprint()
  if fingerprint ~= self.groupFingerprint then
    self.groupFingerprint = fingerprint
    self.manualHidden = false
    self:ResetInspectQueue()
  end

  if event == "PLAYER_REGEN_ENABLED" then
    self:RequestNextInspect()
  end

  self:Refresh()
end

Kaldo:RegisterModule("GroupReady", M)
