-- modules/pet_alert.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB
local TextAlert = NS.TextAlert

local M = {}
M.displayName = (L and L.PET_ALERT) or "Pet Alert"

M.events = {
  "PLAYER_LOGIN",
  "UNIT_PET",
  "UNIT_HEALTH",
  "UNIT_FLAGS",
  "PLAYER_SPECIALIZATION_CHANGED",
}

local defaults = {
  enabled = false,

  -- DEAD section
  deadEnabled = true,
  deadText = L.PET_DEAD_CAPS,
  deadDuration = 3,
  deadFont = "Fonts\\FRIZQT__.TTF",
  deadFontSize = 72,
  deadOutline = "OUTLINE",
  deadX = 0,
  deadY = 170,
  deadPlaySound = true,
  deadSoundKit = 37733,
  deadColor = {1, 0.2, 0.2, 1},
  deadShadow = true,
  deadShadowColor = {0, 0, 0, 1},
  deadShadowX = 1,
  deadShadowY = -1,

  -- ABSENT section
  absentEnabled = true,
  absentText = L.PET_ABSENT_CAPS,
  absentDuration = 3,
  absentFont = "Fonts\\FRIZQT__.TTF",
  absentFontSize = 72,
  absentOutline = "OUTLINE",
  absentX = 0,
  absentY = 170,
  absentPlaySound = true,
  absentSoundKit = 9036,
  absentColor = {1, 1, 1, 1},
  absentShadow = true,
  absentShadowColor = {0, 0, 0, 1},
  absentShadowX = 1,
  absentShadowY = -1,
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local PET_CLASS_LIST = { "HUNTER", "WARLOCK", "DEATHKNIGHT", "MAGE" }
local PET_CLASS_SET = {}
for _, c in ipairs(PET_CLASS_LIST) do PET_CLASS_SET[c] = true end

local PET_SPEC_IDS = {
  HUNTER = { 253, 255 },
  WARLOCK = { 265, 266, 267 },
  DEATHKNIGHT = { 252 },
  MAGE = { 64 },
}

local function GetClassInfoByFile()
  if M._classInfo then return M._classInfo end
  local out = {}
  for id = 1, 13 do
    local name, file = GetClassInfo(id)
    if file then out[file] = { id = id, name = name } end
  end
  M._classInfo = out
  return out
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("PetAlert", defaults)
  applyDefaults(db)
  db.specs = db.specs or {}

  local classInfo = GetClassInfoByFile()
  for _, classFile in ipairs(PET_CLASS_LIST) do
    local info = classInfo[classFile]
    if info and GetNumSpecializationsForClassID and GetSpecializationInfoForClassID then
      db.specs[classFile] = db.specs[classFile] or {}
      for _, specID in ipairs(PET_SPEC_IDS[classFile] or {}) do
        local skey = tostring(specID)
        if db.specs[classFile][skey] == nil then
          db.specs[classFile][skey] = true
        end
      end
    end
  end

  return db
end

function M:ResetDB()
  DB:ResetModuleState("PetAlert", defaults)
  self.db = self:EnsureDB()
  self:RefreshStateAndMaybeAlert()
end

local function PlayerClassEnabled(db)
  local _, classFile = UnitClass("player")
  if not classFile then return true end
  if not PET_CLASS_SET[classFile] then return false end

  local specIndex = GetSpecialization and GetSpecialization()
  if not (specIndex and GetSpecializationInfo) then
    return false
  end

  local specID = select(1, GetSpecializationInfo(specIndex))
  local specTable = db.specs and db.specs[classFile]
  local skey = specID and tostring(specID)
  if specTable and skey then
    return specTable[skey] == true
  end

  return false
end

local function PetExists()
  return UnitExists("pet") == true
end

local function PetDead()
  if not PetExists() then return false end
  return UnitIsDeadOrGhost("pet") == true
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
    { type="header", text=L.PET_ALERT },
  }

  local classInfo = GetClassInfoByFile()
  opts[#opts + 1] = { type="header", text=L.SPECS }
  for _, classFile in ipairs(PET_CLASS_LIST) do
    local name = (classInfo[classFile] and classInfo[classFile].name) or classFile
    opts[#opts + 1] = { type="header", text=name }
    local allowed = PET_SPEC_IDS[classFile] or {}
    if GetSpecializationInfoByID then
      for _, specID in ipairs(allowed) do
        local _, specName = GetSpecializationInfoByID(specID)
        if specName then
          opts[#opts + 1] = { type="toggle", key="specs." .. classFile .. "." .. tostring(specID), label=specName }
        end
      end
    else
      for _, specID in ipairs(allowed) do
        opts[#opts + 1] = { type="toggle", key="specs." .. classFile .. "." .. tostring(specID), label=tostring(specID) }
      end
    end
  end

  -- DEAD section
  opts[#opts + 1] = { type="header", text=L.DEAD }
  opts[#opts + 1] = { type="toggle", key="deadEnabled", label=L.ALERT_IF_PET_DEAD }

  opts[#opts + 1] = { type="input",  key="deadText", label=L.TEXT}
  opts[#opts + 1] = { type="number", key="deadDuration", label=L.DURATION, min=1, max=10, step=1 }

  opts[#opts + 1] = { type="select", key="deadFont", label=L.FONT,
    values=function() return Kaldo.Media:GetFonts() end }

  opts[#opts + 1] = { type="number", key="deadFontSize", label=L.FONT_SIZE, min=10, max=120, step=1 }

  opts[#opts + 1] = { type="select", key="deadOutline", label=L.OUTLINE,
    values={{"NONE","None"},{"OUTLINE","Outline"},{"THICKOUTLINE","Thick"},{"MONOCHROMEOUTLINE","Mono"}} }

  opts[#opts + 1] = { type="color", key="deadColor", label=L.COLOR }

  opts[#opts + 1] = { type="toggle", key="deadShadow", label=L.SHADOW }
  opts[#opts + 1] = { type="color",  key="deadShadowColor", label=L.SHADOW_COLOR }
  opts[#opts + 1] = { type="number", key="deadShadowX", label=L.SHADOW_X, min=-5, max=5, step=1 }
  opts[#opts + 1] = { type="number", key="deadShadowY", label=L.SHADOW_Y, min=-5, max=5, step=1 }

  opts[#opts + 1] = { type="toggle", key="deadPlaySound", label=L.PLAY_SOUND }
  opts[#opts + 1] = { type="input", key="deadSoundKit", label="SoundKit ID" }
  opts[#opts + 1] = { type="label", text=(L and L.WOWHEAD_SOUNDKIT_HELP) or "Find SoundKit IDs on Wowhead." }

  opts[#opts + 1] = { type="button", label=L.TEST_SOUND, onClick=function(_, db)
    TextAlert:Show(self.alert, {
      text = "",
      duration = 0.01,
      playSound = true,
      soundKit = db.deadSoundKit,
    })
  end }

  opts[#opts + 1] = { type="number", key="deadX", label="X", min=function() return -screenHalfW() end, max=screenHalfW, step=1 }
  opts[#opts + 1] = { type="number", key="deadY", label="Y", min=function() return -screenHalfH() end, max=screenHalfH, step=1 }

  opts[#opts + 1] = { type="button", label=L.TEST_ALERT, onClick=function(m)
    if m.ShowDeadAlert then m:ShowDeadAlert() end
  end }

  -- ABSENT section
  opts[#opts + 1] = { type="header", text=L.MISSING }
  opts[#opts + 1] = { type="toggle", key="absentEnabled", label=L.ALERT_IF_PET_ABSENT }

  opts[#opts + 1] = { type="input",  key="absentText", label=L.TEXT }
  opts[#opts + 1] = { type="number", key="absentDuration", label=L.DURATION, min=1, max=10, step=1 }

  opts[#opts + 1] = { type="select", key="absentFont", label=L.FONT,
    values=function() return Kaldo.Media:GetFonts() end }

  opts[#opts + 1] = { type="number", key="absentFontSize", label=L.FONT_SIZE, min=10, max=120, step=1 }

  opts[#opts + 1] = { type="select", key="absentOutline", label=L.OUTLINE,
    values={{"NONE","None"},{"OUTLINE","Outline"},{"THICKOUTLINE","Thick"},{"MONOCHROMEOUTLINE","Mono"}} }

  opts[#opts + 1] = { type="color", key="absentColor", label=L.COLOR }

  opts[#opts + 1] = { type="toggle", key="absentShadow", label=L.SHADOW }
  opts[#opts + 1] = { type="color",  key="absentShadowColor", label=L.SHADOW_COLOR }
  opts[#opts + 1] = { type="number", key="absentShadowX", label=L.SHADOW_X, min=-5, max=5, step=1 }
  opts[#opts + 1] = { type="number", key="absentShadowY", label=L.SHADOW_Y, min=-5, max=5, step=1 }

  opts[#opts + 1] = { type="toggle", key="absentPlaySound", label=L.PLAY_SOUND }
  opts[#opts + 1] = { type="input", key="absentSoundKit", label="SoundKit ID" }
  opts[#opts + 1] = { type="label", text=(L and L.WOWHEAD_SOUNDKIT_HELP) or "Find SoundKit IDs on Wowhead." }

  opts[#opts + 1] = { type="button", label=L.TEST_SOUND, onClick=function(_, db)
    TextAlert:Show(self.alert, {
      text = "",
      duration = 0.01,
      playSound = true,
      soundKit = db.absentSoundKit,
    })
  end }

  opts[#opts + 1] = { type="number", key="absentX", label="X", min=function() return -screenHalfW() end, max=screenHalfW, step=1 }
  opts[#opts + 1] = { type="number", key="absentY", label="Y", min=function() return -screenHalfH() end, max=screenHalfH, step=1 }

  opts[#opts + 1] = { type="button", label=L.TEST_ALERT, onClick=function(m)
    if m.ShowAbsentAlert then m:ShowAbsentAlert() end
  end }

  return opts
end

function M:ApplyStyle(section)
  local db = self.db
  local p = (section == "dead") and "dead" or "absent"
  TextAlert:Apply(self.alert, {
    text = db[p.."Text"],
    duration = db[p.."Duration"],
    font = db[p.."Font"],
    fontSize = db[p.."FontSize"],
    outline = db[p.."Outline"],
    x = db[p.."X"],
    y = db[p.."Y"],
    playSound = db[p.."PlaySound"],
    soundKit = db[p.."SoundKit"],
    color = db[p.."Color"],
    shadow = db[p.."Shadow"],
    shadowColor = db[p.."ShadowColor"],
    shadowX = db[p.."ShadowX"],
    shadowY = db[p.."ShadowY"],
  })
end

function M:ShowSectionAlert(section)
  local db = self.db
  local p = (section == "dead") and "dead" or "absent"
  TextAlert:Show(self.alert, {
    text = db[p.."Text"],
    duration = db[p.."Duration"],
    font = db[p.."Font"],
    fontSize = db[p.."FontSize"],
    outline = db[p.."Outline"],
    x = db[p.."X"],
    y = db[p.."Y"],
    playSound = db[p.."PlaySound"],
    soundKit = db[p.."SoundKit"],
    color = db[p.."Color"],
    shadow = db[p.."Shadow"],
    shadowColor = db[p.."ShadowColor"],
    shadowX = db[p.."ShadowX"],
    shadowY = db[p.."ShadowY"],
  })
  self.currentAlert = section
end

function M:ShowDeadAlert()
  self:ShowSectionAlert("dead")
end

function M:ShowAbsentAlert()
  self:ShowSectionAlert("absent")
end

function M:HideAlert()
  TextAlert:Hide(self.alert)
  self.currentAlert = nil
end

function M:OnRegister(core)
  self.core = core
  self.db = self:EnsureDB()
  self.alert = TextAlert:Create("HIGH")

  self.lastHadPet = nil
  self.lastPetDead = nil
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
end

local function ShouldRun(db)
  if not (db and db.enabled) then return false end
  return PlayerClassEnabled(db)
end

function M:RefreshStateAndMaybeAlert()
  local db = self.db
  if IsMounted and IsMounted() then
    self:HideAlert()
    return
  end
  if not ShouldRun(db) then
    self.lastHadPet = PetExists()
    self.lastPetDead = PetDead()
    self:HideAlert()
    return
  end

  local hadPet = PetExists()
  local isDead = PetDead()

  if self.lastHadPet == nil then
    self.lastHadPet = hadPet
    self.lastPetDead = isDead
    if db.absentEnabled and hadPet == false then
      self:ShowAbsentAlert()
    elseif db.deadEnabled and isDead == true then
      self:ShowDeadAlert()
    end
    return
  end

  if db.absentEnabled and self.lastHadPet == true and hadPet == false then
    self:ShowAbsentAlert()
  end

  if db.deadEnabled and self.lastPetDead == false and isDead == true then
    self:ShowDeadAlert()
  end

  if self.currentAlert == "absent" and hadPet == true then
    self:HideAlert()
  elseif self.currentAlert == "dead" and isDead == false then
    self:HideAlert()
  end

  self.lastHadPet = hadPet
  self.lastPetDead = isDead
end

function M:OnEvent(event, arg1)
  if event == "PLAYER_LOGIN" then
    self.db = self:EnsureDB()
    self:RefreshStateAndMaybeAlert()
    return
  end

  if event == "PLAYER_SPECIALIZATION_CHANGED" then
    if arg1 == "player" then
      self:RefreshStateAndMaybeAlert()
    end
    return
  end

  if event == "UNIT_PET" then
    if arg1 == "player" then
      self:RefreshStateAndMaybeAlert()
    end
    return
  end

  if event == "UNIT_HEALTH" or event == "UNIT_FLAGS" then
    if arg1 == "pet" then
      self:RefreshStateAndMaybeAlert()
    end
    return
  end
end

Kaldo:RegisterModule("PetAlert", M)
