-- modules/craft_order_received.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB
local TextAlert = NS.TextAlert

local M = {}
M.displayName = L.CRAFT_ORDER
M.events = {
  "PLAYER_LOGIN",
  "ADDON_LOADED",
  "CHAT_MSG_SYSTEM",
  "ZONE_CHANGED",
  "ZONE_CHANGED_NEW_AREA",
}

local defaults = {
  enabled = false,

  needle = L.NEW_CRAFT_NEEDLE,
  caseInsensitive = true,
  throttle = 2,

  text = L.NEW_CRAFT_ORDER,
  duration = 3,

  font = "Fonts\\FRIZQT__.TTF",
  fontSize = 72,
  outline = "OUTLINE",

  x = 0,
  y = 170,

  playSound = true,
  soundKit = 8959,

  color = {1,1,1,1},

  shadow = true,
  shadowColor = {0,0,0,1},
  shadowX = 1,
  shadowY = -1,

  completeWhisperEnabled = true,
  completeWhisperText = "Bonjour {client}, ta commande {item} est terminee. Merci !",
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local function trim(s)
  if type(s) ~= "string" then return "" end
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function applyTokens(text, context)
  if type(text) ~= "string" then return "" end
  context = context or {}
  local player = UnitName and UnitName("player") or ""
  text = text:gsub("{player}", tostring(player or ""))
  text = text:gsub("{client}", tostring(context.customerName or ""))
  text = text:gsub("{item}", tostring(context.itemName or ""))
  return text
end

local function getOrderView()
  return ProfessionsFrame
    and ProfessionsFrame.OrdersPage
    and ProfessionsFrame.OrdersPage.OrderView
end

local function getOrderCustomerName(orderView)
  local order = orderView and orderView.order
  local name = order and order.customerName
  if (not name or name == "") and orderView and orderView.OrderInfo and orderView.OrderInfo.PostedByValue then
    name = orderView.OrderInfo.PostedByValue:GetText()
  end
  if type(name) ~= "string" then return nil end
  name = trim(name)
  if name == "" or name == "-" then return nil end
  return name
end

local function isPlayerCraftingOrder(orderView)
  local order = orderView and orderView.order
  if not order then return false end
  if order.npcCustomerCreatureID then return false end

  local npcOrderType = Enum and Enum.CraftingOrderType and Enum.CraftingOrderType.Npc
  if npcOrderType ~= nil and order.orderType == npcOrderType then return false end

  return true
end

local function stripTextureMarkup(text)
  if type(text) ~= "string" then return "" end
  text = text:gsub("|A.-|a", "")
  text = text:gsub("|T.-|t", "")
  text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
  text = text:gsub("|r", "")
  text = text:gsub("|H.-|h(.-)|h", "%1")
  return trim(text)
end

local function getOrderItemName(orderView)
  local order = orderView and orderView.order
  local link = order and order.outputItemHyperlink
  if type(link) == "string" then
    local itemName = link:match("%[(.-)%]")
    if itemName and itemName ~= "" then return stripTextureMarkup(itemName) end
  end
  return ""
end

local function sendChatMessage(message, chatType, language, target)
  if C_ChatInfo and C_ChatInfo.SendChatMessage then
    return pcall(C_ChatInfo.SendChatMessage, message, chatType, language, target)
  elseif SendChatMessage then
    return pcall(SendChatMessage, message, chatType, language, target)
  end
  return false
end

local function sendWhisper(target, message)
  if not target or target == "" or not message or message == "" then return false end
  return sendChatMessage(message, "WHISPER", nil, target)
end

function M:EnsureDB()
  local key = (self and self.name) or "CraftOrder"
  return DB:EnsureModuleState(key, defaults)
end

function M:ResetDB()
  local key = (self and self.name) or "CraftOrder"
  local db = DB:ResetModuleState(key, defaults)
  self:ApplyStyle(db)
end

local function contains(hay, needle, ci)
  if type(hay) ~= "string" or type(needle) ~= "string" or needle == "" then return false end
  local ok, res = pcall(function()
    if ci then
      hay = string.lower(hay)
      needle = string.lower(needle)
    end
    return string.find(hay, needle, 1, true) ~= nil
  end)
  if not ok then return false end
  return res == true
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
    { type="header", text=self.displayName },

    { type="input",  key="needle", label=L.NEEDLE },
    { type="toggle", key="caseInsensitive", label=L.CASE_INSENSITIVE},
    { type="number", key="throttle", label=L.THROTTLE, min=0, max=10, step=1 },

    { type="input",  key="text", label=L.TEXT },
    { type="number", key="duration", label=L.DURATION , min=1, max=10, step=1 },

    { type="select", key="font", label=L.FONT,
      values=function() return Kaldo.Media:GetFonts() end },

    { type="number", key="fontSize", label=L.FONT_SIZE, min=10, max=120, step=1 },

    { type="select", key="outline", label=L.OUTLINE,
      values={{"NONE","None"},{"OUTLINE","Outline"},{"THICKOUTLINE","Thick"},{"MONOCHROMEOUTLINE","Mono"}} },

    { type="color", key="color", label=L.COLOR},

    { type="toggle", key="shadow", label=L.SHADOW },
    { type="color",  key="shadowColor", label=L.SHADOW_COLOR},
    { type="number", key="shadowX", label=L.SHADOW_X, min=-5, max=5, step=1 },
    { type="number", key="shadowY", label=L.SHADOW_Y or "Ombre Y", min=-5, max=5, step=1 },

    { type="toggle", key="playSound", label=L.PLAY_SOUND },
    { type="input", key="soundKit", label="SoundKit ID" },
    { type="label", text=(L and L.WOWHEAD_SOUNDKIT_HELP) or "Find SoundKit IDs on Wowhead." },
    { type="button", label=L.TEST_SOUND, onClick=function(_, db)
      TextAlert:Show(self.alert, {
        text = "",
        duration = 0.01,
        playSound = db.playSound,
        soundKit = db.soundKit,
      })
    end },

    { type="number", key="x", label="X", min=function() return -screenHalfW() end, max=screenHalfW, step=1 },
    { type="number", key="y", label="Y", min=function() return -screenHalfH() end, max=screenHalfH, step=1 },

    { type="button", label=L.TEST_ALERT, onClick=function(m)
      if m.ShowAlert then m:ShowAlert(true) end
    end },

    { type="header", text="Validation de commande" },
    { type="toggle", key="completeWhisperEnabled", label="Afficher le bouton MP + Envoyer" },
    { type="input", key="completeWhisperText", label="Message de validation" },
    { type="label", text="Variables disponibles : {client}, {item}, {player}" },
  }
end

function M:ApplyStyle(db)
  TextAlert:Apply(self.alert, {
    text = db.text,
    duration = db.duration,
    font = db.font,
    fontSize = db.fontSize,
    outline = db.outline,
    x = db.x,
    y = db.y,
    playSound = db.playSound,
    soundKit = db.soundKit,
    color = db.color,
    shadow = db.shadow,
    shadowColor = db.shadowColor,
    shadowX = db.shadowX,
    shadowY = db.shadowY,
  })
end

function M:SendCompletionWhisper(orderView)
  local db = self:EnsureDB()
  if not db.completeWhisperEnabled then return false end
  orderView = orderView or getOrderView()
  if not isPlayerCraftingOrder(orderView) then return false end
  local customerName = getOrderCustomerName(orderView)
  if not customerName then return false end
  local message = applyTokens(db.completeWhisperText, {
    customerName = customerName,
    itemName = getOrderItemName(orderView),
  })
  return sendWhisper(customerName, message)
end

function M:CreateCompleteWhisperButton(orderView)
  if not orderView or orderView.KaldoWhisperCompleteButton then return end
  if not orderView.CompleteOrderButton then return end

  local button = CreateFrame("Button", nil, orderView, "UIPanelButtonTemplate")
  button:SetSize(orderView.CompleteOrderButton:GetWidth() or 160, orderView.CompleteOrderButton:GetHeight() or 24)
  button:SetText("MP + Envoyer")
  button:SetPoint("BOTTOM", orderView.CompleteOrderButton, "TOP", 0, 6)
  button:SetScript("OnClick", function()
    self:SendCompletionWhisper(orderView)
    if orderView.CompleteOrderButton and orderView.CompleteOrderButton:IsEnabled() then
      orderView.CompleteOrderButton:Click()
    end
  end)
  button:SetScript("OnEnter", function(frame)
    if not GameTooltip then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Envoie le MP configure puis valide la commande.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  button:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  orderView.KaldoWhisperCompleteButton = button
end

function M:RefreshCompleteWhisperButton(orderView)
  local db = self:EnsureDB()
  orderView = orderView or getOrderView()
  if not orderView then return end
  self:CreateCompleteWhisperButton(orderView)
  local button = orderView.KaldoWhisperCompleteButton
  if not button then return end
  local complete = orderView.CompleteOrderButton
  local shouldShow = db.enabled
    and db.completeWhisperEnabled
    and isPlayerCraftingOrder(orderView)
    and complete
    and complete:IsShown()
    and getOrderCustomerName(orderView)
  if shouldShow then
    button:ClearAllPoints()
    button:SetPoint("BOTTOM", complete, "TOP", 0, 6)
    button:SetWidth(complete:GetWidth() or 160)
    button:SetEnabled(complete:IsEnabled())
    button:Show()
  else
    button:Hide()
  end
end

function M:HookCraftingOrderView()
  if self._orderViewHooked then return end
  local orderView = getOrderView()
  if not orderView then return end
  self._orderViewHooked = true
  self:CreateCompleteWhisperButton(orderView)

  orderView:HookScript("OnShow", function(frame)
    C_Timer.After(0, function() self:RefreshCompleteWhisperButton(frame) end)
  end)
  if orderView.CompleteOrderButton then
    orderView.CompleteOrderButton:HookScript("OnShow", function()
      C_Timer.After(0, function() self:RefreshCompleteWhisperButton(orderView) end)
    end)
    orderView.CompleteOrderButton:HookScript("OnEnable", function()
      self:RefreshCompleteWhisperButton(orderView)
    end)
    orderView.CompleteOrderButton:HookScript("OnDisable", function()
      self:RefreshCompleteWhisperButton(orderView)
    end)
  end
  if hooksecurefunc and orderView.SetOrder then
    hooksecurefunc(orderView, "SetOrder", function(frame)
      C_Timer.After(0, function() self:RefreshCompleteWhisperButton(frame) end)
    end)
  end
  C_Timer.After(0, function() self:RefreshCompleteWhisperButton(orderView) end)
end

function M:ShowAlert(force)
  local db = self:EnsureDB()
  TextAlert:Show(self.alert, {
    text = db.text,
    duration = db.duration,
    font = db.font,
    fontSize = db.fontSize,
    outline = db.outline,
    x = db.x,
    y = db.y,
    playSound = db.playSound,
    soundKit = db.soundKit,
    color = db.color,
    shadow = db.shadow,
    shadowColor = db.shadowColor,
    shadowX = db.shadowX,
    shadowY = db.shadowY,
  })
end

function M:OnRegister(core)
  self.core = core
  self.alert = TextAlert:Create("HIGH")
  self._last = 0
  self:EnsureDB()
end

function M:OnOptionChanged()
  local db = self:EnsureDB()
  self:ApplyStyle(db)
  self:RefreshCompleteWhisperButton()
end

function M:OnEvent(event, ...)
  local msg, addonName = ...
  local ok, err = pcall(function()
    local db = self:EnsureDB()

    if event == "PLAYER_LOGIN" then
      self._last = 0
      self:HookCraftingOrderView()
      C_Timer.After(1, function()
        self:HookCraftingOrderView()
        self:RefreshCompleteWhisperButton()
      end)
      return
    end

    if event == "ADDON_LOADED" then
      if addonName == "Blizzard_Professions" then
        self:HookCraftingOrderView()
        self:RefreshCompleteWhisperButton()
      end
      return
    end

    if event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
      self:HookCraftingOrderView()
      return
    end

    if not db.enabled then return end
    if event ~= "CHAT_MSG_SYSTEM" then return end
    if type(msg) ~= "string" then return end
    if type(db.needle) ~= "string" or db.needle == "" then return end

    if contains(msg, db.needle, db.caseInsensitive) then
      local now = GetTime()
      if now - (self._last or 0) >= (db.throttle or 0) then
        self._last = now
        if self.ShowAlert then self:ShowAlert() end
      end
    end
  end)

  if not ok then
    if Kaldo and Kaldo.dprint then
      Kaldo.dprint("CraftOrder error (suppressed): %s", tostring(err))
    end
  end
end

Kaldo:RegisterModule("CraftOrder", M)
