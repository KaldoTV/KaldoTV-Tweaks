-- modules/mm_keys.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
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

local defaults = {
  enabled = false,
  auto_insert = true,
  respond_keys = true,
  accept_reminder_chat = true,
  accept_reminder_screen = false,
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

local function isKeysCommand(msg)
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return end
  local currentRunID = C_MythicPlus.GetCurrentRunID and C_MythicPlus.GetCurrentRunID()
  if currentRunID then
    return
  end
  msg = normalizeMsg(msg)
  return msg == "!key" or msg == "!keys"
end

function M:GetOptions()
  return {
    { type="header", text=self.displayName },
    { type="toggle", key="auto_insert", label=(L and L.MM_KEYS_AUTO_INSERT) or "Auto insert keystone on frame open" },
    { type="toggle", key="respond_keys", label=(L and L.MM_KEYS_RESPOND) or "Respond to !key/!keys" },
    { type="header", text=(L and L.MM_KEYS_ACCEPT_HEADER) or "Group accepted reminder" },
    { type="toggle", key="accept_reminder_chat", label=(L and L.MM_KEYS_ACCEPT_CHAT) or "Reminder in chat" },
    { type="toggle", key="accept_reminder_screen", label=(L and L.MM_KEYS_ACCEPT_SCREEN) or "Reminder on screen" },
  }
end

function M:OnRegister()
  self.db = self:EnsureDB()
  self._hooked = false
  self._lastInsert = 0
  self._wasInGroup = nil
  self._pendingAcceptedGroupData = nil
  self._pendingAcceptedAt = 0
  self._lastReminder = 0
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
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

local function tryHookChallengesFrame(self)
  if self._hooked then return end
  if not ChallengesKeystoneFrame then return end

  self._hooked = true

  ChallengesKeystoneFrame:HookScript("OnShow", function()
    local db = self.db or self:EnsureDB()
    if not (db.enabled and db.auto_insert) then return end

    
    DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r " .. L.AUTOINSERT_MESSAGE)
    -- anti spam
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


function M:RespondKeys(event)
  local db = self.db or self:EnsureDB()
  if not db.respond_keys then return end
  if IsInRaid and IsInRaid() then return end
  
  if C_ChallengeMode and C_ChallengeMode.IsChallengeModeActive and C_ChallengeMode.IsChallengeModeActive() then return end
  local currentRunID = C_MythicPlus.GetCurrentRunID and C_MythicPlus.GetCurrentRunID()
  if currentRunID then
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
    SendChatMessage((L and L.MM_KEYS_NONE) or "[Kaldo Tweaks] No keystone.", channel)
    return
  end

  SendChatMessage("[Kaldo Tweaks] " .. link, channel)
end

function M:OnEvent(event, ...)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    if IsAddOnLoaded and IsAddOnLoaded("Blizzard_ChallengesUI") then
      tryHookChallengesFrame(self)
    end
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
    local msg = ...
    if isKeysCommand(msg) then
      self:RespondKeys(event)
    end
  end
end

Kaldo:RegisterModule("MMKeys", M)
