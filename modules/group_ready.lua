local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
M.displayName = (L and L.GROUP_READY) or "Group Checks"
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

local DEFAULT_FONT = "Fonts\\FRIZQT__.TTF"

local BUFF_SUMMARY_RULES = {
  { label = "Arcane Intellect", icon = 135932, providers = { "MAGE" } },
  { label = "Battle Shout", icon = 132333, providers = { "WARRIOR" } },
  { label = "Blessing of the Bronze", icon = 4622448, providers = { "EVOKER" } },
  { label = "Mark of the Wild", icon = 136078, providers = { "DRUID" } },
  { label = "Power Word: Fortitude", icon = 135987, providers = { "PRIEST" } },
  { label = "Skyfury", icon = 4630367, providers = { "SHAMAN" } },
  { label = "Bloodlust", icon = 136012, providers = { "MAGE", "SHAMAN", "EVOKER", "HUNTER" }, critical = true, shortLabel = "BL" },
  { label = "Combat Resurrection", icon = 136080, providers = { "DRUID", "DEATHKNIGHT", "WARLOCK", "PALADIN" }, critical = true, shortLabel = "BR" },
}

local RANGED_CLASS_FALLBACK = {
  MAGE = true,
  PRIEST = true,
  WARLOCK = true,
  EVOKER = true,
}

local RANGED_SPEC_IDS = {
  [102] = true, -- Balance Druid
  [105] = true, -- Restoration Druid
  [253] = true, -- Beast Mastery Hunter
  [254] = true, -- Marksmanship Hunter
  [62] = true, -- Arcane Mage
  [63] = true, -- Fire Mage
  [64] = true, -- Frost Mage
  [256] = true, -- Discipline Priest
  [257] = true, -- Holy Priest
  [258] = true, -- Shadow Priest
  [262] = true, -- Elemental Shaman
  [264] = true, -- Restoration Shaman
  [265] = true, -- Affliction Warlock
  [266] = true, -- Demonology Warlock
  [267] = true, -- Destruction Warlock
  [1467] = true, -- Devastation Evoker
  [1468] = true, -- Preservation Evoker
  [1473] = true, -- Augmentation Evoker
}

local SHORT_KICK_SECONDS_BY_SPEC = {
  -- Death Knight
  [250] = 15, -- Blood Death Knight
  [251] = 15, -- Frost Death Knight
  [252] = 15, -- Unholy Death Knight

  -- Demon Hunter
  [577] = 15, -- Havoc Demon Hunter
  [581] = 15, -- Vengeance Demon Hunter

  -- Druid
  [102] = 60, -- Balance Druid
  [103] = 15, -- Feral Druid
  [104] = 15, -- Guardian Druid
  -- [105] Restoration Druid: no interrupt in Midnight.

  -- Evoker
  [1467] = 20, -- Devastation Evoker
  -- [1468] Preservation Evoker: no interrupt in Midnight.
  [1473] = 20, -- Augmentation Evoker

  -- Hunter
  [253] = 24, -- Beast Mastery Hunter
  [254] = 24, -- Marksmanship Hunter
  [255] = 15, -- Survival Hunter

  -- Mage
  [62] = 24, -- Arcane Mage
  [63] = 24, -- Fire Mage
  [64] = 24, -- Frost Mage

  -- Monk
  [268] = 15, -- Brewmaster Monk
  [269] = 15, -- Windwalker Monk
  -- [270] Mistweaver Monk: no interrupt in Midnight.

  -- Paladin
  -- [65] Holy Paladin: no interrupt in Midnight.
  [66] = 15, -- Protection Paladin
  [70] = 15, -- Retribution Paladin

  -- Priest
  -- [256] Discipline Priest: no interrupt in Midnight.
  -- [257] Holy Priest: no interrupt in Midnight.
  [258] = 45, -- Shadow Priest

  -- Rogue
  [259] = 15, -- Assassination Rogue
  [260] = 15, -- Outlaw Rogue
  [261] = 15, -- Subtlety Rogue

  -- Shaman
  [262] = 12, -- Elemental Shaman
  [263] = 12, -- Enhancement Shaman
  [264] = 30, -- Restoration Shaman

  -- Warlock
  [265] = 24, -- Affliction Warlock
  [266] = 24, -- Demonology Warlock
  [267] = 24, -- Destruction Warlock

  -- Warrior
  [71] = 15, -- Arms Warrior
  [72] = 15, -- Fury Warrior
  [73] = 15, -- Protection Warrior
}

local defaults = {
  enabled = false,
  auto_show = true,
  show_scores = true,
  show_warnings = true,
  short_kick_threshold = 15,
  short_kick_min_count = 2,
  alpha = 1,
  scale = 1,
  x = -360,
  y = 140,
  font_family = DEFAULT_FONT,
  font_size = 11,
  title_font_size = 15,
  row_height = 22,
  bg_color = { 0.030, 0.040, 0.045, 0.94 },
  accent_color = { 0.000, 0.860, 0.700, 1.00 },
}

local function copyColor(color, fallback)
  local source = type(color) == "table" and color or fallback
  return {
    source and source[1] or 1,
    source and source[2] or 1,
    source and source[3] or 1,
    source and source[4] or 1,
  }
end

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local function unpackColor(color)
  return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

local function SetBackdrop(frame, bg, border)
  if not frame or not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(unpackColor(bg))
  frame:SetBackdropBorderColor(unpackColor(border))
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

local function GetPlayerEquippedItemLevel()
  if not GetAverageItemLevel then return nil end
  local avgItemLevel, avgEquipped = GetAverageItemLevel()
  if avgEquipped and avgEquipped > 0 then
    return avgEquipped
  end
  return avgItemLevel
end

local function GetPlayerSpecID()
  if not (GetSpecialization and GetSpecializationInfo) then return nil end
  local specIndex = GetSpecialization()
  if not specIndex then return nil end
  return select(1, GetSpecializationInfo(specIndex))
end

local function ApplyFont(fs, db, sizeOffset, templateFallback)
  if not fs or not fs.SetFont then return end
  local font = db.font_family or DEFAULT_FONT
  local size = (tonumber(db.font_size) or defaults.font_size) + (sizeOffset or 0)
  fs:SetFont(font, math.max(8, size), templateFallback or "OUTLINE")
  fs:SetShadowColor(0, 0, 0, 0.95)
  fs:SetShadowOffset(1, -1)
end

local function GetWarningText(key, ...)
  local value = L and L[key]
  if type(value) == "string" then
    return string.format(value, ...)
  end
  local fallbacks = {
    GROUP_READY_WARNING_NO_RANGED = "No ranged player",
    GROUP_READY_WARNING_SHORT_KICKS_FMT = "Only %d short kick(s)",
  }
  return string.format(fallbacks[key] or key, ...)
end

local function StyleCloseButton(button, accent, hovered)
  if not button then return end
  local bgAlpha = hovered and 0.95 or 0.72
  local borderAlpha = hovered and 1.00 or 0.70
  SetBackdrop(
    button,
    { 0.045, 0.055, 0.060, bgAlpha },
    { accent[1], accent[2], accent[3], borderAlpha }
  )
  if button.text then
    button.text:SetTextColor(hovered and 1 or accent[1], hovered and 1 or accent[2], hovered and 1 or accent[3], 1)
  end
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("GroupReady", defaults)
  applyDefaults(db)
  return db
end

function M:ResetDB()
  self.db = DB:ResetModuleState("GroupReady", defaults)
  self.manualHidden = false
  self:ApplyStyle()
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
    { type = "toggle", key = "show_scores", label = (L and L.GROUP_READY_SHOW_SCORES) or "Show Mythic+ score" },
    { type = "toggle", key = "show_warnings", label = (L and L.GROUP_READY_SHOW_WARNINGS) or "Show composition warnings" },
    { type = "number", key = "short_kick_threshold", label = (L and L.GROUP_READY_SHORT_KICK_THRESHOLD) or "Short kick threshold", min = 10, max = 30, step = 1 },
    { type = "number", key = "short_kick_min_count", label = (L and L.GROUP_READY_SHORT_KICK_MIN_COUNT) or "Minimum short kicks", min = 0, max = 5, step = 1 },

    { type = "header", text = (L and L.DISPLAY) or "Display" },
    { type = "select", key = "font_family", label = (L and L.FONT) or "Font", values = function() return Kaldo.Media:GetFonts() end },
    { type = "number", key = "font_size", label = (L and L.FONT_SIZE) or "Font size", min = 8, max = 18, step = 1 },
    { type = "number", key = "title_font_size", label = (L and L.GROUP_READY_TITLE_SIZE) or "Title size", min = 11, max = 24, step = 1 },
    { type = "number", key = "row_height", label = (L and L.GROUP_READY_ROW_HEIGHT) or "Row height", min = 18, max = 30, step = 1 },
    { type = "number", key = "scale", label = (L and L.GROUP_READY_SCALE) or "Scale", min = 0.75, max = 1.4, step = 0.05 },
    { type = "number", key = "alpha", label = L.ALPHA or "Alpha", min = 0.2, max = 1, step = 0.05 },
    { type = "color", key = "bg_color", label = (L and L.GROUP_READY_BG_COLOR) or "Background color" },
    { type = "color", key = "accent_color", label = (L and L.GROUP_READY_ACCENT_COLOR) or "Accent color" },
    { type = "number", key = "x", label = "X", min = function() return -screenHalfW() end, max = screenHalfW, step = 1 },
    { type = "number", key = "y", label = "Y", min = function() return -screenHalfH() end, max = screenHalfH, step = 1 },
    { type = "button", label = (L and L.GROUP_READY_OPEN) or "Open popup", onClick = function() self.manualHidden = false self:Refresh(true) end },
  }
end

function M:ApplyStyle()
  if not self.frame then return end
  local db = self.db or self:EnsureDB()
  local accent = copyColor(db.accent_color, defaults.accent_color)
  local bg = copyColor(db.bg_color, defaults.bg_color)

  self.frame:ClearAllPoints()
  self.frame:SetPoint("CENTER", UIParent, "CENTER", db.x or defaults.x, db.y or defaults.y)
  self.frame:SetAlpha(db.alpha or 1)
  self.frame:SetScale(db.scale or 1)
  SetBackdrop(self.frame, bg, { accent[1], accent[2], accent[3], 0.75 })

  if self.frame.accent then
    self.frame.accent:SetColorTexture(accent[1], accent[2], accent[3], 0.95)
  end
  StyleCloseButton(self.frame.closeButton, accent, false)

  if self.frame.title then
    self.frame.title:SetFont(db.font_family or DEFAULT_FONT, tonumber(db.title_font_size) or defaults.title_font_size, "OUTLINE")
    self.frame.title:SetTextColor(0.94, 0.98, 1, 1)
  end
  if self.frame.subtitle then
    ApplyFont(self.frame.subtitle, db, -2)
    self.frame.subtitle:SetTextColor(0.62, 0.68, 0.68, 1)
  end
  if self.frame.summary then
    ApplyFont(self.frame.summary, db, 0)
  end
  if self.frame.warningTitle then
    ApplyFont(self.frame.warningTitle, db, 0)
  end

  for _, fs in ipairs(self.frame.headers or {}) do
    ApplyFont(fs, db, -1)
    fs:SetTextColor(accent[1], accent[2], accent[3], 1)
  end

  for _, row in ipairs(self.frame.rows or {}) do
    row:SetHeight(tonumber(db.row_height) or defaults.row_height)
    ApplyFont(row.role, db, -1)
    ApplyFont(row.name, db, 0)
    ApplyFont(row.status, db, -2)
    ApplyFont(row.ilvl, db, 0)
    ApplyFont(row.score, db, 0)
  end

  for _, warning in ipairs(self.frame.warnings or {}) do
    ApplyFont(warning.text, db, -1)
  end
end

function M:CreateFrame()
  if self.frame then return end

  local frame = CreateFrame("Frame", "KaldoGroupReadyFrame", UIParent, "BackdropTemplate")
  frame:SetSize(430, 300)
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

  frame.accent = frame:CreateTexture(nil, "ARTWORK")
  frame.accent:SetPoint("TOPLEFT", 1, -1)
  frame.accent:SetPoint("TOPRIGHT", -1, -1)
  frame.accent:SetHeight(2)

  frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  frame.title:SetPoint("TOPLEFT", 16, -14)
  frame.title:SetText((L and L.GROUP_READY_POPUP_TITLE) or "Party checklist")

  frame.subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.subtitle:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
  frame.subtitle:SetText((L and L.GROUP_READY_POPUP_SUBTITLE) or "Buff coverage, iLvl and score")

  local close = CreateFrame("Button", nil, frame, "BackdropTemplate")
  close:SetSize(22, 22)
  close:SetPoint("TOPRIGHT", -8, -8)
  close.text = close:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  close.text:SetPoint("CENTER", 0, 1)
  close.text:SetText("x")
  close.text:SetFont(DEFAULT_FONT, 14, "OUTLINE")
  close:SetScript("OnEnter", function(button)
    local db = self.db or self:EnsureDB()
    StyleCloseButton(button, copyColor(db.accent_color, defaults.accent_color), true)
  end)
  close:SetScript("OnLeave", function(button)
    local db = self.db or self:EnsureDB()
    StyleCloseButton(button, copyColor(db.accent_color, defaults.accent_color), false)
  end)
  close:SetScript("OnClick", function()
    self.manualHidden = true
    frame:Hide()
  end)
  frame.closeButton = close

  frame.buffHeader = CreateFrame("Frame", nil, frame)
  frame.buffHeader:SetSize(398, 32)
  frame.buffHeader:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -50)
  frame.buffIcons = {}

  frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  frame.summary:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -88)
  frame.summary:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
  frame.summary:SetJustifyH("LEFT")
  frame.summary:SetText("")

  frame.headers = {}
  local function addHeader(name, text, x, width, justify)
    local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -116)
    fs:SetWidth(width)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetText(text)
    frame[name] = fs
    frame.headers[#frame.headers + 1] = fs
    return fs
  end

  addHeader("headerRole", (L and L.GROUP_READY_ROLE) or "Role", 16, 40)
  addHeader("headerName", (L and L.GROUP_READY_NAME) or "Name", 62, 160)
  addHeader("headerIlvl", (L and L.GROUP_READY_ILVL) or "iLvl", 246, 56, "RIGHT")
  addHeader("headerScore", (L and L.GROUP_READY_SCORE) or "Score", 326, 72, "RIGHT")

  frame.rows = {}
  for i = 1, 5 do
    local row = CreateFrame("Frame", nil, frame)
    row:SetSize(398, 22)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -134 - ((i - 1) * 24))

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints()
    row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.025 or 0.055)

    row.role = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.role:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.role:SetWidth(40)
    row.role:SetJustifyH("LEFT")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row, "LEFT", 50, 0)
    row.name:SetWidth(154)
    row.name:SetJustifyH("LEFT")
    row.name:SetWordWrap(false)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.status:SetPoint("LEFT", row.name, "RIGHT", 4, 0)
    row.status:SetWidth(34)
    row.status:SetJustifyH("LEFT")

    row.ilvl = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.ilvl:SetPoint("RIGHT", row, "LEFT", 286, 0)
    row.ilvl:SetWidth(56)
    row.ilvl:SetJustifyH("RIGHT")

    row.score = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.score:SetPoint("RIGHT", row, "RIGHT", -4, 0)
    row.score:SetWidth(72)
    row.score:SetJustifyH("RIGHT")

    frame.rows[i] = row
  end

  frame.warningTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  frame.warningTitle:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -258)
  frame.warningTitle:SetText((L and L.GROUP_READY_WARNINGS) or "Warnings")

  frame.warnings = {}
  for i = 1, 2 do
    local warning = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    warning:SetSize(190, 24)
    warning:SetPoint("TOPLEFT", frame, "TOPLEFT", 16 + ((i - 1) * 204), -276)
    SetBackdrop(warning, { 0.22, 0.08, 0.06, 0.88 }, { 0.95, 0.40, 0.18, 0.85 })
    warning.text = warning:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    warning.text:SetPoint("LEFT", 8, 0)
    warning.text:SetPoint("RIGHT", -8, 0)
    warning.text:SetJustifyH("LEFT")
    warning.text:SetTextColor(1.0, 0.74, 0.44, 1)
    warning:Hide()
    frame.warnings[i] = warning
  end

  self.frame = frame
  self:ApplyStyle()
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

function M:GetCachedSpecID(guid)
  local entry = self.inspectCache and self.inspectCache[guid]
  if not entry then return nil end
  if (GetTime() - (entry.ts or 0)) > 600 then
    self.inspectCache[guid] = nil
    return nil
  end
  return entry.specID
end

function M:GetCachedScore(guid)
  local entry = self.inspectCache and self.inspectCache[guid]
  if not entry then return nil end
  if (GetTime() - (entry.ts or 0)) > 600 then
    self.inspectCache[guid] = nil
    return nil
  end
  return entry.score
end

function M:StoreCachedInspectData(guid, ilvl, specID, score)
  if not guid then return end
  local entry = self.inspectCache[guid] or {}
  if ilvl and ilvl > 0 then entry.ilvl = ilvl end
  if specID and specID > 0 then entry.specID = specID end
  if score and score > 0 then entry.score = score end
  entry.ts = GetTime()
  self.inspectCache[guid] = entry
end

function M:GetUnitMythicPlusScore(unit, guid)
  if not unit or not UnitExists(unit) then return nil end
  if guid then
    local cached = self:GetCachedScore(guid)
    if cached then return cached end
  end

  if UnitIsUnit and UnitIsUnit(unit, "player") and C_ChallengeMode and C_ChallengeMode.GetOverallDungeonScore then
    local ok, score = pcall(C_ChallengeMode.GetOverallDungeonScore)
    score = ok and tonumber(score) or nil
    if score and score > 0 then return score end
  end

  if not (C_PlayerInfo and C_PlayerInfo.GetPlayerMythicPlusRatingSummary) then
    return nil
  end

  local tokens, seen = {}, {}
  local function addToken(token)
    if type(token) ~= "string" or token == "" or seen[token] then return end
    seen[token] = true
    tokens[#tokens + 1] = token
  end

  addToken(unit)
  if GetUnitName then addToken(GetUnitName(unit, true)) end
  if UnitFullName then
    local name, realm = UnitFullName(unit)
    if name and realm and realm ~= "" then
      addToken(name .. "-" .. realm)
    else
      addToken(name)
    end
  end
  if UnitName then addToken(UnitName(unit)) end

  for _, token in ipairs(tokens) do
    local ok, summary = pcall(C_PlayerInfo.GetPlayerMythicPlusRatingSummary, token)
    if ok and type(summary) == "table" then
      local score = tonumber(summary.currentSeasonScore or summary.mythicPlusScore or summary.overallDungeonScore)
      if score and score > 0 then
        if guid then self:StoreCachedInspectData(guid, nil, nil, score) end
        return score
      end
    end
  end

  return nil
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

function M:GetUnitSpecID(unit, guid)
  if UnitIsUnit and UnitIsUnit(unit, "player") then
    return GetPlayerSpecID()
  end
  local cached = guid and self:GetCachedSpecID(guid)
  if cached then return cached end
  if GetInspectSpecialization and unit and UnitExists(unit) then
    local ok, specID = pcall(GetInspectSpecialization, unit)
    specID = ok and tonumber(specID) or nil
    if specID and specID > 0 then return specID end
  end
  return nil
end

function M:BuildMembers()
  local members = {}
  for _, unit in ipairs(GetDetailedUnits()) do
    if UnitExists(unit) then
      local guid = UnitGUID(unit)
      local _, classFile = UnitClass(unit)
      local isPlayer = unit == "player"
      local score = self:GetUnitMythicPlusScore(unit, guid)
      if not isPlayer and not score then
        self:QueueInspect(unit, guid)
      end
      members[#members + 1] = {
        unit = unit,
        guid = guid,
        classFile = classFile,
        specID = self:GetUnitSpecID(unit, guid),
        name = GetUnitNameText(unit),
        roleText = GetRoleText(unit),
        isPlayer = isPlayer,
        score = score,
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
        local ilvl = GetPlayerEquippedItemLevel()
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

function M:GetGroupAverageScore(members)
  local total = 0
  local count = 0
  for _, member in ipairs(members or {}) do
    if member.score and member.score > 0 then
      total = total + member.score
      count = count + 1
    end
  end
  if count == 0 then return nil, 0 end
  return total / count, count
end

function M:UpdateLayout()
  if not self.frame then
    return
  end

  local db = self.db or self:EnsureDB()
  local rowHeight = tonumber(db.row_height) or defaults.row_height
  local compact = IsCompactMode()
  if compact then
    self.frame:SetSize(430, db.show_warnings and 148 or 112)
    self.frame.headerRole:Hide()
    self.frame.headerName:Hide()
    self.frame.headerIlvl:Hide()
    self.frame.headerScore:Hide()
    for _, row in ipairs(self.frame.rows or {}) do
      row:Hide()
    end
  else
    local warningsHeight = db.show_warnings and 48 or 0
    self.frame:SetSize(430, 148 + (5 * (rowHeight + 2)) + warningsHeight)
    self.frame.headerRole:Show()
    self.frame.headerName:Show()
    self.frame.headerIlvl:Show()
    if db.show_scores then
      self.frame.headerScore:Show()
    else
      self.frame.headerScore:Hide()
    end
    for i, row in ipairs(self.frame.rows or {}) do
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, -134 - ((i - 1) * (rowHeight + 2)))
    end
  end

  self:ApplyStyle()
end

function M:UpdateBuffSummary()
  if not self.frame then return end
  local classes = BuildClassPresence()
  for i, rule in ipairs(BUFF_SUMMARY_RULES) do
    local icon = self.frame.buffIcons[i]
    if not icon then
      icon = CreateFrame("Frame", nil, self.frame.buffHeader)
      icon.tex = icon:CreateTexture(nil, "ARTWORK")
      icon.tex:SetAllPoints()
      icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      icon.tex:SetTexture(rule.icon)
      icon.border = icon:CreateTexture(nil, "OVERLAY")
      icon.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
      icon.border:SetBlendMode("ADD")
      icon.border:SetPoint("CENTER", icon, "CENTER", 0, 0)
      icon.label = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
      icon.label:SetPoint("TOP", icon, "BOTTOM", 0, -1)
      self.frame.buffIcons[i] = icon
    end

    icon:ClearAllPoints()
    if rule.critical then
      local criticalIndex = (rule.shortLabel == "BL") and 0 or 1
      icon:SetSize(28, 28)
      icon:SetPoint("LEFT", self.frame.buffHeader, "LEFT", 282 + (criticalIndex * 42), 0)
      icon.border:SetSize(46, 46)
      icon.label:SetText(rule.shortLabel or "")
      icon.label:Show()
    else
      icon:SetSize(24, 24)
      icon:SetPoint("LEFT", self.frame.buffHeader, "LEFT", (i - 1) * 28, 2)
      icon.border:SetSize(38, 38)
      icon.label:Hide()
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

function M:UpdateRows(members)
  if not self.frame then return end
  if IsCompactMode() then
    for _, row in ipairs(self.frame.rows or {}) do
      row:Hide()
    end
    return
  end

  local db = self.db or self:EnsureDB()
  members = members or self:BuildMembers()

  for i, row in ipairs(self.frame.rows or {}) do
    local info = members[i]
    if info then
      row:Show()
      row.role:SetText(info.roleText or "-")
      row.name:SetText(info.name or UNKNOWN)
      row.name:SetTextColor(GetClassColor(info.unit))
      if db.show_scores == true then
        row.score:Show()
      else
        row.score:Hide()
      end

      if info.score and info.score > 0 then
        row.score:SetFormattedText("%d", math.floor(info.score + 0.5))
      else
        row.score:SetText("-")
      end

      if info.isPlayer then
        local ilvl = GetPlayerEquippedItemLevel()
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

function M:BuildWarnings(members)
  local db = self.db or self:EnsureDB()
  if not db.show_warnings then return {} end

  local hasRanged = false
  local shortKicks = 0
  local threshold = tonumber(db.short_kick_threshold) or defaults.short_kick_threshold

  for _, member in ipairs(members or {}) do
    local specID = tonumber(member.specID)
    local classFile = member.classFile
    if (specID and RANGED_SPEC_IDS[specID]) or ((not specID) and classFile and RANGED_CLASS_FALLBACK[classFile]) then
      hasRanged = true
    end

    local kickSeconds = specID and SHORT_KICK_SECONDS_BY_SPEC[specID]
    if kickSeconds and kickSeconds <= threshold then
      shortKicks = shortKicks + 1
    end
  end

  local warnings = {}
  if not hasRanged then
    warnings[#warnings + 1] = GetWarningText("GROUP_READY_WARNING_NO_RANGED")
  end
  if shortKicks < (tonumber(db.short_kick_min_count) or defaults.short_kick_min_count) then
    warnings[#warnings + 1] = GetWarningText("GROUP_READY_WARNING_SHORT_KICKS_FMT", shortKicks)
  end
  return warnings
end

function M:UpdateWarnings(members)
  if not self.frame then return end
  local db = self.db or self:EnsureDB()
  local warnings = self:BuildWarnings(members)
  local rowHeight = tonumber(db.row_height) or defaults.row_height
  local baseY = IsCompactMode() and -106 or (-144 - (5 * (rowHeight + 2)))

  if not db.show_warnings then
    self.frame.warningTitle:Hide()
    for _, warning in ipairs(self.frame.warnings or {}) do
      warning:Hide()
    end
    return
  end

  self.frame.warningTitle:ClearAllPoints()
  self.frame.warningTitle:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16, baseY)
  if #warnings > 0 then
    self.frame.warningTitle:Show()
  else
    self.frame.warningTitle:Hide()
  end

  for i, warningFrame in ipairs(self.frame.warnings or {}) do
    local text = warnings[i]
    warningFrame:ClearAllPoints()
    warningFrame:SetPoint("TOPLEFT", self.frame, "TOPLEFT", 16 + ((i - 1) * 204), baseY - 18)
    if text then
      warningFrame.text:SetText(text)
      warningFrame:Show()
    else
      warningFrame:Hide()
    end
  end
end

function M:UpdateSummary(members)
  if not self.frame or not self.frame.summary then
    return
  end

  local db = self.db or self:EnsureDB()
  local avg, inspected, count = self:GetGroupAverageIlvl()
  local avgText
  if avg then
    avgText = string.format((L and L.GROUP_READY_AVG_FMT) or "Avg %.1f", avg)
  else
    avgText = (L and L.GROUP_READY_AVG_UNKNOWN) or "Avg -"
  end

  local inspectedText = string.format((L and L.GROUP_READY_INSPECTED_FMT) or "%d/%d inspected", inspected or 0, count or 0)
  local text = avgText .. "  |  " .. inspectedText

  if db.show_scores then
    local avgScore, scored = self:GetGroupAverageScore(members)
    local scoreLabel = (L and L.GROUP_READY_AVG_SCORE) or "Score"
    if avgScore then
      text = text .. "  |  " .. scoreLabel .. " " .. tostring(math.floor(avgScore + 0.5)) .. " (" .. tostring(scored) .. ")"
    else
      text = text .. "  |  " .. scoreLabel .. " -"
    end
  end

  self.frame.summary:SetText(text)
end

function M:Refresh(forceShow)
  local db = self.db or self:EnsureDB()
  self.db = db
  self:CreateFrame()
  self:ApplyStyle()

  if not db.enabled or ((not forceShow) and not ShouldShowPopup()) or (forceShow and IsMythicPlusRunActive()) then
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

  local members = self:BuildMembers()
  self:UpdateLayout()
  self:UpdateBuffSummary()
  self:UpdateSummary(members)
  self:UpdateRows(members)
  self:UpdateWarnings(members)
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
  self:ApplyStyle()
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
      local specID
      if unit and GetInspectSpecialization then
        local ok, inspectedSpecID = pcall(GetInspectSpecialization, unit)
        specID = ok and inspectedSpecID or nil
      end
      local score = unit and self:GetUnitMythicPlusScore(unit, guid)
      self:StoreCachedInspectData(guid, tonumber(ilvl), tonumber(specID), tonumber(score))
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
