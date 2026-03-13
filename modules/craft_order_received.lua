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
  "CHAT_MSG_SYSTEM",
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
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
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
end

function M:OnEvent(event, msg)
  local ok, err = pcall(function()
    local db = self:EnsureDB()

    if event == "PLAYER_LOGIN" then
      self._last = 0
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
