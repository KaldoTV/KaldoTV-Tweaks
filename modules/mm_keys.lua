-- modules/mm_keys.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
local tryHookChallengesFrame
local ensureChallengesUILoaded
local isLikelySeasonBestButton
local isLikelySeasonBestFallbackButton
M.displayName = (L and L.MM_KEYS) or "MM+ Keys"
M.events = {
  "PLAYER_LOGIN",
  "ADDON_LOADED",
  "PLAYER_ENTERING_WORLD",
  "GROUP_ROSTER_UPDATE",
  "PLAYER_ROLES_ASSIGNED",
  "PARTY_LEADER_CHANGED",
  "PLAYER_SPECIALIZATION_CHANGED",
  "LFG_PROPOSAL_SUCCEEDED",
  "LFG_LIST_APPLICATION_STATUS_UPDATED",
  "LFG_LIST_JOINED_GROUP",
  "CHAT_MSG_PARTY",
  "CHAT_MSG_PARTY_LEADER",
  "CHAT_MSG_INSTANCE_CHAT",
  "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local C_MythicPlus = C_MythicPlus or {}

-- Keystone item IDs (historical + current)
local KEYSTONE_ITEM_IDS = {
  [138019] = true, -- Legion (older)
  [151086] = true, -- Legion (older)
  [158923] = true, -- BFA
  [180653] = true, -- SL/DF/TWW
}

-- Fill this table with your preferred dungeon acronyms keyed by mapChallengeModeID.
local DUNGEON_ACRONYMS = {
  [402] = "AA",
  [556] = "POS",
  [558] = "MT",
  [161] = "SR",
  [557] = "WS",
  [559] = "NPX",
  [560] = "MC",
  [239] = "SEAT",
}

-- Edit these rules directly in code. Highest matching minLevel wins.
local KEY_LEVEL_COLOR_RULES = {
  { minLevel = 12, color = { 0.85, 0.60, 1.00, 1.00 } },
  { minLevel = 10, color = { 0.29, 0.95, 0.55, 1.00 } },
  { minLevel = 0, color = { 1.00, 0.95, 0.84, 1.00 } },
}

local DEFAULT_OVERLAY_FONT = "Fonts\\FRIZQT__.TTF"

local defaults = {
  enabled = false,
  auto_insert = true,
  respond_keys = true,
  accept_reminder_chat = true,
  accept_reminder_screen = false,
  season_best_overlay = true,
  score_color = { 1.00, 0.82, 0.00, 1.00 },
  timer_color_in_time = { 0.82, 0.92, 1.00, 1.00 },
  timer_color_over_time = { 1.00, 0.43, 0.43, 1.00 },
  acronym_font = DEFAULT_OVERLAY_FONT,
  acronym_size = 11,
  level_font = DEFAULT_OVERLAY_FONT,
  level_size = 18,
  score_font = DEFAULT_OVERLAY_FONT,
  score_size = 11,
  timer_font = DEFAULT_OVERLAY_FONT,
  timer_size = 10,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

function M:EnsureDB()
  return DB:EnsureModuleState("MMKeys", defaults)
end

function M:ResetDB()
  self.db = DB:ResetModuleState("MMKeys", defaults)
end

local function getKeystoneLinkFromBags()
  if not (C_Container and C_Container.GetContainerNumSlots) then return nil end
  for bag = 0, NUM_BAG_FRAMES do
    local slots = C_Container.GetContainerNumSlots(bag)
    for slot = 1, slots do
      local info = C_Container.GetContainerItemInfo(bag, slot)
      if info and info.itemID and KEYSTONE_ITEM_IDS[info.itemID] then
        local link = C_Container.GetContainerItemLink(bag, slot)
        if link then return link end
      end
    end
  end
  return nil
end

local function getOwnedKeystoneLink()
  if C_MythicPlus and C_MythicPlus.GetOwnedKeystoneLink then
    local link = C_MythicPlus.GetOwnedKeystoneLink()
    if link then return link end
  end
  return getKeystoneLinkFromBags()
end

local function normalizeMsg(msg)
  if type(msg) ~= "string" then return nil end
  msg = msg:lower()
  msg = msg:gsub("^%s+", ""):gsub("%s+$", "")
  return msg
end

local function shouldSuppressKeysChat()
  if InCombatLockdown and InCombatLockdown() then
    return true
  end

  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then
    return true
  end

  local currentRunID = C_MythicPlus.GetCurrentRunID and C_MythicPlus.GetCurrentRunID()
  if currentRunID then
    return true
  end

  if GetInstanceInfo then
    local _, instanceType = GetInstanceInfo()
    if instanceType == "pvp" or instanceType == "arena" then
      return true
    end
  end

  return false
end

local function isKeysCommand(msg)
  if shouldSuppressKeysChat() then return end
  if type(msg) ~= "string" then return false end
  if msg:find("|", 1, true) or msg:find("[%c\r\n]") then
    return false
  end
  msg = normalizeMsg(msg)
  if not msg or #msg > 5 then
    return false
  end
  return msg == "!key" or msg == "!keys"
end

local function isTrustedKeysSender(author)
  return type(author) == "string" and author ~= ""
end

function M:GetOptions()
  return {
    { type="header", text=self.displayName },
    { type="toggle", key="auto_insert", label=(L and L.MM_KEYS_AUTO_INSERT) or "Auto insert keystone on frame open" },
    { type="toggle", key="respond_keys", label=(L and L.MM_KEYS_RESPOND) or "Respond to !key/!keys" },
    { type="header", text=(L and L.MM_KEYS_SEASON_OVERLAY_HEADER) or "Season best overlay" },
    { type="toggle", key="season_best_overlay", label=(L and L.MM_KEYS_SEASON_OVERLAY_ENABLED) or "Show overlay on dungeon tiles" },
    { type="label", text=(L and L.MM_KEYS_LEVEL_RULES_HINT) or "Level colors are configured in modules/mm_keys.lua" },
    { type="select", key="acronym_font", label=(L and L.MM_KEYS_ACRONYM_FONT) or "Acronym font", values=function() return Kaldo.Media:GetFonts() end },
    { type="number", key="acronym_size", min=8, max=20, step=1, label=(L and L.MM_KEYS_ACRONYM_SIZE) or "Acronym size" },
    { type="select", key="level_font", label=(L and L.MM_KEYS_LEVEL_FONT) or "Level font", values=function() return Kaldo.Media:GetFonts() end },
    { type="number", key="level_size", min=10, max=28, step=1, label=(L and L.MM_KEYS_LEVEL_SIZE) or "Level size" },
    { type="select", key="score_font", label=(L and L.MM_KEYS_SCORE_FONT) or "Score font", values=function() return Kaldo.Media:GetFonts() end },
    { type="number", key="score_size", min=8, max=20, step=1, label=(L and L.MM_KEYS_SCORE_SIZE) or "Score size" },
    { type="select", key="timer_font", label=(L and L.MM_KEYS_TIMER_FONT) or "Timer font", values=function() return Kaldo.Media:GetFonts() end },
    { type="number", key="timer_size", min=8, max=20, step=1, label=(L and L.MM_KEYS_TIMER_SIZE) or "Timer size" },
    { type="color", key="score_color", label=(L and L.MM_KEYS_SCORE_COLOR) or "Fallback score color" },
    { type="color", key="timer_color_in_time", label=(L and L.MM_KEYS_TIMER_COLOR_INTIME) or "Timer color in time" },
    { type="color", key="timer_color_over_time", label=(L and L.MM_KEYS_TIMER_COLOR_OVERTIME) or "Timer color overtime" },
    { type="header", text=(L and L.MM_KEYS_ACCEPT_HEADER) or "Group accepted reminder" },
    { type="toggle", key="accept_reminder_chat", label=(L and L.MM_KEYS_ACCEPT_CHAT) or "Reminder in chat" },
    { type="toggle", key="accept_reminder_screen", label=(L and L.MM_KEYS_ACCEPT_SCREEN) or "Reminder on screen" },
  }
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self._hooked = false
  self._seasonBestHooked = false
  self._lastInsert = 0
  self._wasInGroup = nil
  self._pendingAcceptedGroupData = nil
  self._pendingAcceptedAt = 0
  self._lastReminder = 0
  self._lastKeysResponseAt = 0
  self._seasonBestOverlays = {}
  self._seasonBestTickerElapsed = 0
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  tryHookChallengesFrame(self)
  self:RefreshSeasonBestOverlays()
end

local function setFontSize(fs, size, flags)
  if not fs or not fs.GetFont or not fs.SetFont then return end
  local font, _, existingFlags = fs:GetFont()
  if not font then return end
  fs:SetFont(font, size, flags or existingFlags or "OUTLINE")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

local function applyConfiguredFont(fs, fontPath, size, flags)
  if not fs or not fs.SetFont then return end
  local _, currentSize, currentFlags = fs:GetFont()
  local finalPath = fontPath or DEFAULT_OVERLAY_FONT
  local finalSize = tonumber(size) or currentSize or 12
  fs:SetFont(finalPath, finalSize, flags or currentFlags or "OUTLINE")
  fs:SetShadowColor(0, 0, 0, 1)
  fs:SetShadowOffset(1, -1)
end

local function setTextColorFromRGBA(fs, rgba)
  if not fs then return end
  local r = type(rgba) == "table" and rgba[1] or 1
  local g = type(rgba) == "table" and rgba[2] or 1
  local b = type(rgba) == "table" and rgba[3] or 1
  local a = type(rgba) == "table" and rgba[4] or 1
  fs:SetTextColor(r, g, b, a)
end

local function setTextColorFromColorObject(fs, color, fallback)
  if not fs then return end
  if type(color) == "table" and color.r and color.g and color.b then
    fs:SetTextColor(color.r, color.g, color.b, color.a or 1)
    return
  end
  setTextColorFromRGBA(fs, fallback)
end

ensureChallengesUILoaded = function()
  if ChallengesFrame or ChallengesKeystoneFrame then
    return true
  end

  if C_AddOns and C_AddOns.LoadAddOn then
    pcall(C_AddOns.LoadAddOn, "Blizzard_ChallengesUI")
  elseif UIParentLoadAddOn then
    pcall(UIParentLoadAddOn, "Blizzard_ChallengesUI")
  end

  return not not (ChallengesFrame or ChallengesKeystoneFrame)
end

local function buildDungeonAcronym(name)
  if type(name) ~= "string" or name == "" then return "?" end
  local words = {}
  for word in name:gmatch("[%a%d]+") do
    local lower = word:lower()
    if lower ~= "the" and lower ~= "of" and lower ~= "and" and lower ~= "de" and lower ~= "du" and lower ~= "des" and lower ~= "la" and lower ~= "le" and lower ~= "les" then
      words[#words + 1] = word
    end
  end

  if #words >= 2 then
    local out = {}
    for i = 1, math.min(3, #words) do
      out[#out + 1] = words[i]:sub(1, 1):upper()
    end
    return table.concat(out)
  end

  local compact = name:gsub("[%s%p]+", ""):upper()
  if compact == "" then
    return "?"
  end
  return compact:sub(1, math.min(3, #compact))
end

local function getDungeonAcronym(mapChallengeModeID, dungeonName)
  if mapChallengeModeID and DUNGEON_ACRONYMS[mapChallengeModeID] then
    return DUNGEON_ACRONYMS[mapChallengeModeID]
  end
  if mapChallengeModeID then
    return tostring(mapChallengeModeID)
  end
  return buildDungeonAcronym(dungeonName)
end

local function getLevelColor(level)
  level = tonumber(level) or 0
  for _, rule in ipairs(KEY_LEVEL_COLOR_RULES) do
    if level >= (tonumber(rule.minLevel) or 0) then
      return rule.color
    end
  end
  return { 1.00, 1.00, 1.00, 1.00 }
end

local function hideBaseTileText(frame, visited)
  if type(frame) ~= "table" then return end
  visited = visited or {}
  if visited[frame] then return end
  visited[frame] = true

  if frame.GetRegions then
    for _, region in ipairs({ frame:GetRegions() }) do
      if region and region.GetObjectType and region:GetObjectType() == "FontString" then
        region:Hide()
        if region.SetAlpha then region:SetAlpha(0) end
      end
    end
  end

  if frame.GetChildren then
    for _, child in ipairs({ frame:GetChildren() }) do
      hideBaseTileText(child, visited)
    end
  end
end

local function trimNumber(value)
  local text = string.format("%.1f", tonumber(value) or 0)
  text = text:gsub("%.0$", "")
  return text
end

local function formatDurationSeconds(totalSeconds)
  totalSeconds = math.max(0, math.floor(tonumber(totalSeconds) or 0))
  local hours = math.floor(totalSeconds / 3600)
  local minutes = math.floor((totalSeconds % 3600) / 60)
  local seconds = totalSeconds % 60
  if hours > 0 then
    return string.format("%d:%02d:%02d", hours, minutes, seconds)
  end
  return string.format("%d:%02d", minutes, seconds)
end

local function getMapTimeLimit(mapChallengeModeID)
  if not (C_ChallengeMode and C_ChallengeMode.GetMapUIInfo) then return nil end
  local _, _, timeLimit = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
  return tonumber(timeLimit)
end

local function chooseSeasonBestRun(mapChallengeModeID)
  if C_MythicPlus and C_MythicPlus.GetSeasonBestAffixScoreInfoForMap then
    local affixScores = C_MythicPlus.GetSeasonBestAffixScoreInfoForMap(mapChallengeModeID)
    if type(affixScores) == "table" then
      local best
      for _, info in ipairs(affixScores) do
        if type(info) == "table" and tonumber(info.level) and tonumber(info.level) > 0 then
          if (not best)
            or (tonumber(info.level) > tonumber(best.level))
            or (tonumber(info.level) == tonumber(best.level) and (tonumber(info.score) or 0) > (tonumber(best.score) or 0))
            or (tonumber(info.level) == tonumber(best.level) and (tonumber(info.score) or 0) == (tonumber(best.score) or 0) and (tonumber(info.durationSec) or math.huge) < (tonumber(best.durationSec) or math.huge)) then
            best = info
          end
        end
      end
      if best then
        return {
          level = tonumber(best.level) or 0,
          score = tonumber(best.score) or 0,
          durationSec = tonumber(best.durationSec) or 0,
          overTime = not not best.overTime,
        }
      end
    end
  end

  if C_MythicPlus and C_MythicPlus.GetSeasonBestForMap then
    local intimeInfo, overtimeInfo = C_MythicPlus.GetSeasonBestForMap(mapChallengeModeID)
    local chosen, overTime = nil, false
    local function consider(info, isOverTime)
      if type(info) ~= "table" or not tonumber(info.level) then return end
      if (not chosen)
        or (tonumber(info.level) > tonumber(chosen.level))
        or (tonumber(info.level) == tonumber(chosen.level) and (tonumber(info.dungeonScore) or 0) > (tonumber(chosen.dungeonScore) or 0))
        or (tonumber(info.level) == tonumber(chosen.level) and (tonumber(info.dungeonScore) or 0) == (tonumber(chosen.dungeonScore) or 0) and (tonumber(info.durationSec) or math.huge) < (tonumber(chosen.durationSec) or math.huge)) then
        chosen = info
        overTime = not not isOverTime
      end
    end
    consider(intimeInfo, false)
    consider(overtimeInfo, true)
    if chosen then
      return {
        level = tonumber(chosen.level) or 0,
        score = tonumber(chosen.dungeonScore) or 0,
        durationSec = tonumber(chosen.durationSec) or 0,
        overTime = overTime,
      }
    end
  end

  return nil
end

local function getScoreColor(score, fallback)
  if C_ChallengeMode and C_ChallengeMode.GetSpecificDungeonScoreRarityColor and tonumber(score) and tonumber(score) > 0 then
    return C_ChallengeMode.GetSpecificDungeonScoreRarityColor(score)
  end
  return fallback
end

isLikelySeasonBestButton = function(frame)
  if type(frame) ~= "table" or not frame.GetObjectType then return false end
  local objectType = frame:GetObjectType()
  if objectType ~= "Button" and objectType ~= "Frame" then return false end
  if frame.IsForbidden and frame:IsForbidden() then return false end
  if frame.IsVisible and not frame:IsVisible() then return false end
  if (frame.GetWidth and frame:GetWidth() or 0) < 40 then return false end
  if (frame.GetHeight and frame:GetHeight() or 0) < 40 then return false end
  return true
end

isLikelySeasonBestFallbackButton = function(frame, parentLeft, parentRight, parentTop, parentBottom)
  if not isLikelySeasonBestButton(frame) then return false end
  local width = frame.GetWidth and frame:GetWidth() or 0
  local height = frame.GetHeight and frame:GetHeight() or 0
  if width > 96 or height > 96 then return false end

  local left = frame.GetLeft and frame:GetLeft() or nil
  local right = frame.GetRight and frame:GetRight() or nil
  local top = frame.GetTop and frame:GetTop() or nil
  local bottom = frame.GetBottom and frame:GetBottom() or nil
  if not (left and right and top and bottom and parentLeft and parentRight and parentTop and parentBottom) then
    return false
  end

  local parentWidth = parentRight - parentLeft
  local parentHeight = parentTop - parentBottom
  if parentWidth <= 0 or parentHeight <= 0 then
    return false
  end

  local centerX = (left + right) / 2
  local centerY = (top + bottom) / 2
  local relX = (centerX - parentLeft) / parentWidth
  local relY = (centerY - parentBottom) / parentHeight

  return relX >= 0.02 and relX <= 0.98 and relY >= 0.00 and relY <= 0.30
end

local function getPositionTarget(entry)
  if type(entry) == "table" and entry.frame then
    return entry.frame
  end
  return entry
end

local function sortFramesByPosition(frames)
  table.sort(frames, function(a, b)
    local aframe = getPositionTarget(a)
    local bframe = getPositionTarget(b)
    local atop = aframe and aframe.GetTop and aframe:GetTop() or 0
    local btop = bframe and bframe.GetTop and bframe:GetTop() or 0
    if math.abs((atop or 0) - (btop or 0)) > 4 then
      return (atop or 0) > (btop or 0)
    end
    local aleft = aframe and aframe.GetLeft and aframe:GetLeft() or 0
    local bleft = bframe and bframe.GetLeft and bframe:GetLeft() or 0
    return (aleft or 0) < (bleft or 0)
  end)
end

function M:GetSeasonBestRoot()
  if not ChallengesFrame then return nil end
  local candidates = {
    ChallengesFrame.WeeklyInfo and ChallengesFrame.WeeklyInfo.Child and ChallengesFrame.WeeklyInfo.Child.SeasonBest,
    ChallengesFrame.WeeklyInfo and ChallengesFrame.WeeklyInfo.SeasonBest,
    ChallengesFrame.WeeklyInfo and ChallengesFrame.WeeklyInfo.Child,
    ChallengesFrame.WeeklyInfo,
    ChallengesFrame,
  }
  for _, frame in ipairs(candidates) do
    if type(frame) == "table" and frame.GetObjectType then
      local objectType = frame:GetObjectType()
      if objectType == "Frame" or objectType == "Button" or objectType == "ScrollFrame" then
        return frame
      end
    end
  end
  if ChallengesFrame.GetObjectType and ChallengesFrame:GetObjectType() == "Frame" then
    return ChallengesFrame
  end
  return nil
end

function M:ResolveSeasonBestButtons()
  local root = self:GetSeasonBestRoot() or ChallengesFrame
  if not root then return {} end

  local explicit, implicit, seenFrames, seenCandidates, usedMapIDs = {}, {}, {}, {}, {}
  local parentFrame = ChallengesFrame or root
  local parentLeft = parentFrame and parentFrame.GetLeft and parentFrame:GetLeft() or nil
  local parentRight = parentFrame and parentFrame.GetRight and parentFrame:GetRight() or nil
  local parentTop = parentFrame and parentFrame.GetTop and parentFrame:GetTop() or nil
  local parentBottom = parentFrame and parentFrame.GetBottom and parentFrame:GetBottom() or nil

  local function recurse(frame, depth)
    if not frame or seenFrames[frame] or depth > 4 then return end
    seenFrames[frame] = true

    if frame ~= root and isLikelySeasonBestButton(frame) then
      local mapChallengeModeID = frame.mapChallengeModeID or frame.challengeModeID or frame.challengeModeId or frame.mapID or frame.id
      if tonumber(mapChallengeModeID) and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local mapName = C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
        if mapName then
          explicit[#explicit + 1] = { frame = frame, mapChallengeModeID = tonumber(mapChallengeModeID) }
          usedMapIDs[tonumber(mapChallengeModeID)] = true
          seenCandidates[frame] = true
        end
      elseif not seenCandidates[frame] and isLikelySeasonBestFallbackButton(frame, parentLeft, parentRight, parentTop, parentBottom) then
        implicit[#implicit + 1] = frame
        seenCandidates[frame] = true
      end
    end

    if not frame.GetChildren then return end
    for _, child in ipairs({ frame:GetChildren() }) do
      recurse(child, depth + 1)
    end
  end

  recurse(root, 0)
  if #implicit == 0 and ChallengesFrame and ChallengesFrame ~= root and ChallengesFrame.GetChildren then
    for _, child in ipairs({ ChallengesFrame:GetChildren() }) do
      if not seenCandidates[child] and isLikelySeasonBestFallbackButton(child, parentLeft, parentRight, parentTop, parentBottom) then
        implicit[#implicit + 1] = child
        seenCandidates[child] = true
      end
    end
  end
  sortFramesByPosition(implicit)

  local mapIDs = {}
  if C_ChallengeMode and C_ChallengeMode.GetMapTable then
    local ids = C_ChallengeMode.GetMapTable()
    if type(ids) == "table" then
      for _, mapChallengeModeID in ipairs(ids) do
        if not usedMapIDs[mapChallengeModeID] then
          mapIDs[#mapIDs + 1] = mapChallengeModeID
        end
      end
    end
  end

  local out = {}
  for _, entry in ipairs(explicit) do
    out[#out + 1] = entry
  end
  for index, frame in ipairs(implicit) do
    if mapIDs[index] then
      out[#out + 1] = { frame = frame, mapChallengeModeID = mapIDs[index] }
    end
  end

  sortFramesByPosition(out)
  return out
end

function M:EnsureSeasonBestOverlay(button)
  if button.KaldoSeasonBestOverlay then
    return button.KaldoSeasonBestOverlay
  end

  hideBaseTileText(button)

  local overlay = CreateFrame("Frame", nil, button)
  overlay:SetAllPoints(button)
  overlay:SetFrameLevel(math.max((button.GetFrameLevel and button:GetFrameLevel() or 0) + 5, 5))
  overlay:EnableMouse(true)

  overlay.acronym = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  overlay.acronym:SetPoint("TOPLEFT", 4, -4)
  overlay.acronym:SetJustifyH("LEFT")
  applyConfiguredFont(overlay.acronym, DEFAULT_OVERLAY_FONT, 11, "OUTLINE")

  overlay.level = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  overlay.level:SetPoint("TOP", 0, -16)
  overlay.level:SetJustifyH("CENTER")
  applyConfiguredFont(overlay.level, DEFAULT_OVERLAY_FONT, 18, "THICKOUTLINE")

  overlay.score = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  overlay.score:SetPoint("BOTTOM", 0, 14)
  overlay.score:SetJustifyH("CENTER")
  applyConfiguredFont(overlay.score, DEFAULT_OVERLAY_FONT, 11, "OUTLINE")

  overlay.timer = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  overlay.timer:SetPoint("BOTTOM", 0, 3)
  overlay.timer:SetJustifyH("CENTER")
  applyConfiguredFont(overlay.timer, DEFAULT_OVERLAY_FONT, 10, "OUTLINE")

  button.KaldoSeasonBestOverlay = overlay
  self._seasonBestOverlays[button] = overlay
  return overlay
end

function M:HideSeasonBestOverlays()
  for _, overlay in pairs(self._seasonBestOverlays or {}) do
    overlay:Hide()
  end
end

function M:RefreshSeasonBestOverlays()
  local db = self.db or self:EnsureDB()
  if not (db.enabled and db.season_best_overlay) then
    self:HideSeasonBestOverlays()
    return
  end

  local buttons = self:ResolveSeasonBestButtons()
  if #buttons == 0 then
    self:HideSeasonBestOverlays()
    return
  end

  local active = {}
  for _, entry in ipairs(buttons) do
    local button = entry.frame
    local mapChallengeModeID = entry.mapChallengeModeID
    local mapName = C_ChallengeMode and C_ChallengeMode.GetMapUIInfo and C_ChallengeMode.GetMapUIInfo(mapChallengeModeID)
    local bestRun = mapName and chooseSeasonBestRun(mapChallengeModeID) or nil

    if button and mapName and bestRun and bestRun.level and bestRun.level > 0 then
      local overlay = self:EnsureSeasonBestOverlay(button)
      overlay:Show()

      applyConfiguredFont(overlay.acronym, db.acronym_font, db.acronym_size, "OUTLINE")
      applyConfiguredFont(overlay.level, db.level_font, db.level_size, "THICKOUTLINE")
      applyConfiguredFont(overlay.score, db.score_font, db.score_size, "OUTLINE")
      applyConfiguredFont(overlay.timer, db.timer_font, db.timer_size, "OUTLINE")

      overlay.acronym:SetText(getDungeonAcronym(mapChallengeModeID, mapName))
      overlay.level:SetText("+" .. tostring(bestRun.level))
      overlay.score:SetText(trimNumber(bestRun.score))
      overlay.timer:SetText(formatDurationSeconds(bestRun.durationSec))

      setTextColorFromRGBA(overlay.level, getLevelColor(bestRun.level))
      setTextColorFromColorObject(overlay.score, getScoreColor(bestRun.score, db.score_color), db.score_color)
      if bestRun.overTime then
        setTextColorFromRGBA(overlay.timer, db.timer_color_over_time)
      else
        setTextColorFromRGBA(overlay.timer, db.timer_color_in_time)
      end

      local timeLimit = getMapTimeLimit(mapChallengeModeID)
      overlay:SetScript("OnEnter", function(selfFrame)
        if not GameTooltip then return end
        GameTooltip:SetOwner(selfFrame, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(mapName, 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(((L and L.MM_KEYS_TOOLTIP_LEVEL) or "Best level") .. ": +" .. tostring(bestRun.level), 1, 0.82, 0)
        GameTooltip:AddLine(((L and L.MM_KEYS_TOOLTIP_SCORE) or "Score gained") .. ": " .. trimNumber(bestRun.score), 1, 1, 1)
        if timeLimit then
          GameTooltip:AddLine(((L and L.MM_KEYS_TOOLTIP_TIMER) or "Timer") .. ": " .. formatDurationSeconds(bestRun.durationSec) .. " / " .. formatDurationSeconds(timeLimit), 0.85, 0.85, 0.85)
        else
          GameTooltip:AddLine(((L and L.MM_KEYS_TOOLTIP_TIMER) or "Timer") .. ": " .. formatDurationSeconds(bestRun.durationSec), 0.85, 0.85, 0.85)
        end
        GameTooltip:Show()
      end)
      overlay:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
      end)

      active[button] = true
    elseif button and button.KaldoSeasonBestOverlay then
      button.KaldoSeasonBestOverlay:Hide()
    end
  end

  for button, overlay in pairs(self._seasonBestOverlays or {}) do
    if not active[button] then
      overlay:Hide()
    end
  end
end

local function trim(s)
  if type(s) ~= "string" then return nil end
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  if s == "" then return nil end
  return s
end

local function textHasKeystoneHint(s)
  if type(s) ~= "string" then return false end
  return s:find("%+%s*%d+") ~= nil
end

local function extractKeystoneLevel(s)
  if type(s) ~= "string" then return nil end
  local lvl = s:match("%+%s*(%d+)")
  if not lvl then return nil end
  lvl = tonumber(lvl)
  if not lvl then return nil end
  return lvl
end

local function getSearchResultInfoByID(searchResultID)
  if not (searchResultID and C_LFGList and C_LFGList.GetSearchResultInfo) then return nil end
  local ri = C_LFGList.GetSearchResultInfo(searchResultID)
  if type(ri) == "table" then return ri end
  return nil
end

local function getActivityNameFromInfo(ri)
  if type(ri) ~= "table" then return nil end
  local activityID = ri.activityID
  if (not activityID) and type(ri.activityIDs) == "table" then
    activityID = ri.activityIDs[1]
  end
  if not (activityID and C_LFGList and C_LFGList.GetActivityInfoTable) then return nil end
  local ai = C_LFGList.GetActivityInfoTable(activityID)
  if type(ai) ~= "table" then return nil end
  return ai.fullName or ai.shortName or ai.name
end

local function extractKeyLabel(name, ri)
  local comment = type(ri) == "table" and ri.comment or nil
  local activityName = getActivityNameFromInfo(ri)

  -- Prefer real dungeon/activity name for key label.
  if type(activityName) == "string" and activityName ~= "" then
    local lvl = extractKeystoneLevel(comment) or extractKeystoneLevel(name)
    if lvl then
      return string.format("%s +%d", activityName, lvl)
    end
    return activityName
  end

  if textHasKeystoneHint(comment) then return comment end
  if textHasKeystoneHint(name) then return name end

  -- Fallback: use comment if author wrote key details there even without '+'.
  if type(comment) == "string" and comment ~= "" then return comment end
  return nil
end

local function getAcceptedGroupDataFromAppID(appID)
  if not (C_LFGList and C_LFGList.GetApplicationInfo) then return nil end
  if type(appID) ~= "number" then return nil end

  local info, b, c = C_LFGList.GetApplicationInfo(appID)
  local searchResultID, status, pendingStatus, name

  if type(info) == "table" then
    searchResultID = info.searchResultID or info.resultID
    status = info.applicationStatus or info.status
    pendingStatus = info.pendingStatus
    name = info.name
  else
    searchResultID = info
    status = b
    pendingStatus = c
  end

  local ri = getSearchResultInfoByID(searchResultID)
  if not name and ri then
    name = ri.name
  end

  local function isAccepted(st)
    return st == "invited" or st == "inviteaccepted"
  end

  if isAccepted(status) or isAccepted(pendingStatus) then
    if not name or name == "" then return nil end
    return {
      groupName = name,
      keyLabel = extractKeyLabel(name, ri),
    }
  end

  return nil
end

local function getGroupDataFromSearchResultID(searchResultID, fallbackGroupName)
  local ri = getSearchResultInfoByID(searchResultID)
  if not ri then return nil end

  local groupName = trim(fallbackGroupName) or ri.name
  if not groupName or groupName == "" then return nil end

  return {
    groupName = groupName,
    keyLabel = extractKeyLabel(groupName, ri),
  }
end

local function getAcceptedGroupDataFromEventArgs(searchResultID, status, pendingStatus, nameFromEvent)
  local function isAccepted(st)
    return st == "invited" or st == "inviteaccepted"
  end
  if not (isAccepted(status) or isAccepted(pendingStatus)) then return nil end

  local evName = trim(nameFromEvent)
  local fromSearch = getGroupDataFromSearchResultID(searchResultID, evName)
  if fromSearch then
    if (not fromSearch.keyLabel or fromSearch.keyLabel == "") and evName then
      fromSearch.keyLabel = evName
    end
    return fromSearch
  end

  -- Fallback when searchResultID lookup is unavailable.
  if evName then
    return {
      groupName = evName,
      keyLabel = evName,
    }
  end

  return nil
end

function M:ScanAcceptedGroupData()
  if not (C_LFGList and C_LFGList.GetApplications) then return nil end
  local apps = C_LFGList.GetApplications()
  if type(apps) ~= "table" then return nil end
  for _, appID in ipairs(apps) do
    local data = getAcceptedGroupDataFromAppID(appID)
    if data and data.groupName and data.groupName ~= "" then
      return data
    end
  end
  return nil
end

function M:AnnounceAcceptedGroup(groupData)
  local db = self.db or self:EnsureDB()
  if not (db.accept_reminder_chat or db.accept_reminder_screen) then return end
  local groupName = type(groupData) == "table" and groupData.groupName or groupData
  local keyLabel = type(groupData) == "table" and groupData.keyLabel or nil
  if not groupName or groupName == "" then return end

  local now = GetTime()
  if (now - (self._lastReminder or 0)) < 2 then return end
  self._lastReminder = now

  local msg
  if keyLabel and keyLabel ~= "" then
    local fmtWithKey = (L and L.MM_KEYS_ACCEPTED_WITH_KEY_FMT) or "Accepted in group: %s | Key: %s"
    msg = string.format(fmtWithKey, tostring(groupName), tostring(keyLabel))
  else
    local fmt = (L and L.MM_KEYS_ACCEPTED_FMT) or "Accepted in group: %s"
    msg = string.format(fmt, tostring(groupName))
  end

  if db.accept_reminder_chat and DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. msg)
  end

  if db.accept_reminder_screen then
    if RaidNotice_AddMessage and RaidWarningFrame then
      local info = ChatTypeInfo and (ChatTypeInfo["RAID_WARNING"] or ChatTypeInfo["SYSTEM"])
      if not info then info = { r = 1.0, g = 0.82, b = 0.0 } end
      RaidNotice_AddMessage(RaidWarningFrame, msg, info)
    elseif UIErrorsFrame and UIErrorsFrame.AddMessage then
      UIErrorsFrame:AddMessage(msg, 1.0, 0.82, 0.0, 2.0)
    end
  end
end

function M:CheckGroupJoinReminder()
  local inGroup = IsInGroup and IsInGroup() or false
  if self._wasInGroup == nil then
    self._wasInGroup = inGroup
    return
  end

  if inGroup and not self._wasInGroup then
    local now = GetTime and GetTime() or 0
    local isFreshPending = self._pendingAcceptedGroupData
      and self._pendingAcceptedAt
      and (now - self._pendingAcceptedAt) <= 30

    local groupData = nil
    if isFreshPending then
      groupData = self._pendingAcceptedGroupData
    else
      groupData = self:ScanAcceptedGroupData()
    end

    if groupData then
      self:AnnounceAcceptedGroup(groupData)
    end
    self._pendingAcceptedGroupData = nil
    self._pendingAcceptedAt = 0
  elseif not inGroup then
    self._pendingAcceptedGroupData = nil
    self._pendingAcceptedAt = 0
  end

  self._wasInGroup = inGroup
end

tryHookChallengesFrame = function(self)
  ensureChallengesUILoaded()

  if not self._hooked and ChallengesKeystoneFrame then
    self._hooked = true

    ChallengesKeystoneFrame:HookScript("OnShow", function()
      local db = self.db or self:EnsureDB()
      if not (db.enabled and db.auto_insert) then return end

      DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. L.AUTOINSERT_MESSAGE)
      if self._lastInsert and (GetTime() - self._lastInsert) < 1.0 then return end
      self._lastInsert = GetTime()

      if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemID and C_Container.UseContainerItem) then
        return
      end

      for bag = 0, NUM_BAG_FRAMES do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
          local id = C_Container.GetContainerItemID(bag, slot)
          if id and KEYSTONE_ITEM_IDS[id] then
            C_Container.UseContainerItem(bag, slot)
            return
          end
        end
      end
    end)
  end

  if self._seasonBestHooked then return end
  if not ChallengesFrame then return end

  self._seasonBestHooked = true
  ChallengesFrame:HookScript("OnShow", function()
    C_Timer.After(0, function()
      self:RefreshSeasonBestOverlays()
    end)
  end)

  local updater = CreateFrame("Frame", nil, ChallengesFrame)
  updater:SetScript("OnUpdate", function(_, elapsed)
    self._seasonBestTickerElapsed = (self._seasonBestTickerElapsed or 0) + elapsed
    if self._seasonBestTickerElapsed < 1.0 then
      return
    end
    self._seasonBestTickerElapsed = 0

    if ChallengesFrame:IsShown() then
      self:RefreshSeasonBestOverlays()
    end
  end)
  self._seasonBestUpdater = updater
end


function M:RespondKeys(event)
  local db = self.db or self:EnsureDB()
  if not db.respond_keys then return end
  if IsInRaid and IsInRaid() then return end
  if shouldSuppressKeysChat() then return end

  local now = GetTime and GetTime() or 0
  if (now - (self._lastKeysResponseAt or 0)) < 1.5 then
    return
  end

  local channel
  if event == "CHAT_MSG_PARTY" or event == "CHAT_MSG_PARTY_LEADER" then
    channel = "PARTY"
  elseif event == "CHAT_MSG_INSTANCE_CHAT" or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
    channel = "INSTANCE_CHAT"
  end
  if not channel then return end

  local link = getOwnedKeystoneLink()
  if not link then
    self._lastKeysResponseAt = now
    SendChatMessage((L and L.MM_KEYS_NONE) or "[Kaldo Tweaks] No keystone.", channel)
    return
  end

  self._lastKeysResponseAt = now
  SendChatMessage("[Kaldo Tweaks] " .. link, channel)
end

function M:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    tryHookChallengesFrame(self)
    self._wasInGroup = IsInGroup and IsInGroup() or false
    return
  end

  if event == "ADDON_LOADED" then
    local addon = ...
    if addon == "Blizzard_ChallengesUI" then
      tryHookChallengesFrame(self)
    end
    return
  end

  if event == "PLAYER_ENTERING_WORLD"
    or event == "GROUP_ROSTER_UPDATE"
    or event == "PLAYER_ROLES_ASSIGNED"
    or event == "PARTY_LEADER_CHANGED"
    or event == "PLAYER_SPECIALIZATION_CHANGED" then
    self:CheckGroupJoinReminder()
    return
  end

  if event == "LFG_PROPOSAL_SUCCEEDED" then
    local data = self:ScanAcceptedGroupData()
    if data then
      self._pendingAcceptedGroupData = data
      self._pendingAcceptedAt = GetTime and GetTime() or 0
    end
    return
  end

  if event == "LFG_LIST_APPLICATION_STATUS_UPDATED" then
    local searchResultID, status, oldStatus, groupName = ...
    local data = getAcceptedGroupDataFromEventArgs(searchResultID, status, oldStatus, groupName)
    if data and data.groupName and data.groupName ~= "" then
      self._pendingAcceptedGroupData = data
      self._pendingAcceptedAt = GetTime and GetTime() or 0
    else
      local fallback = self:ScanAcceptedGroupData()
      if fallback and fallback.groupName and fallback.groupName ~= "" then
        self._pendingAcceptedGroupData = fallback
        self._pendingAcceptedAt = GetTime and GetTime() or 0
      end
    end
    return
  end

  if event == "LFG_LIST_JOINED_GROUP" then
    local searchResultID, groupName = ...
    local data = getGroupDataFromSearchResultID(searchResultID, groupName)
    if data and data.groupName and data.groupName ~= "" then
      self._pendingAcceptedGroupData = data
      self._pendingAcceptedAt = GetTime and GetTime() or 0
      self:AnnounceAcceptedGroup(data)
      self._pendingAcceptedGroupData = nil
      self._pendingAcceptedAt = 0
    end
    return
  end

  if event == "CHAT_MSG_PARTY"
    or event == "CHAT_MSG_PARTY_LEADER"
    or event == "CHAT_MSG_INSTANCE_CHAT"
    or event == "CHAT_MSG_INSTANCE_CHAT_LEADER" then
    if shouldSuppressKeysChat() then
      return
    end
    local msg, author = ...
    if isTrustedKeysSender(author) and isKeysCommand(msg) then
      self:RespondKeys(event)
    end
  end
end

Kaldo:RegisterModule("MMKeys", M)
