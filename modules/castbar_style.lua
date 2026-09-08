-- modules/castbar_style.lua
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L
local DB = NS.DB

local M = {}
M.displayName = (L and L.CASTBAR_STYLE) or "Blizzard cast bars"
M.events = {
  "PLAYER_LOGIN",
  "PLAYER_SPECIALIZATION_CHANGED",
  "SPELL_UPDATE_COOLDOWN",
  "NAME_PLATE_UNIT_ADDED",
  "NAME_PLATE_UNIT_REMOVED",
  "UNIT_SPELLCAST_START",
  "UNIT_SPELLCAST_CHANNEL_START",
  "UNIT_SPELLCAST_EMPOWER_START",
  "UNIT_SPELLCAST_DELAYED",
  "UNIT_SPELLCAST_CHANNEL_UPDATE",
  "UNIT_SPELLCAST_EMPOWER_UPDATE",
  "UNIT_SPELLCAST_INTERRUPTIBLE",
  "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
  "UNIT_SPELLCAST_STOP",
  "UNIT_SPELLCAST_CHANNEL_STOP",
  "UNIT_SPELLCAST_EMPOWER_STOP",
  "UNIT_SPELLCAST_FAILED",
  "UNIT_SPELLCAST_INTERRUPTED",
}

local defaults = {
  enabled = false,
  normal_color = { 1.00, 0.70, 0.00, 1.00 },
  important_color = { 1.00, 0.16, 0.12, 1.00 },
  glow_enabled = true,
  glow_color = { 0.15, 0.85, 1.00, 1.00 },
  glow_lines = 8,
  glow_thickness = 2,
  glow_speed = 4,
}

-- Only this table is maintained locally. Spell importance remains Blizzard-owned.
local INTERRUPTS_BY_SPEC = {
  [250] = { 47528 }, [251] = { 47528 }, [252] = { 47528 },
  [577] = { 183752 }, [581] = { 183752 },
  [102] = { 78675 }, [103] = { 106839 }, [104] = { 106839 },
  [1467] = { 351338 }, [1473] = { 351338 },
  [253] = { 147362 }, [254] = { 147362 }, [255] = { 187707 },
  [62] = { 2139 }, [63] = { 2139 }, [64] = { 2139 },
  [268] = { 116705 }, [269] = { 116705 },
  [66] = { 96231 }, [70] = { 96231 },
  [258] = { 15487 },
  [259] = { 1766 }, [260] = { 1766 }, [261] = { 1766 },
  [262] = { 57994 }, [263] = { 57994 }, [264] = { 57994 },
  [265] = { 119910, 19647 }, [266] = { 119910, 19647 }, [267] = { 119910, 19647 },
  [71] = { 6552 }, [72] = { 6552 }, [73] = { 6552 },
}

local function applyDefaults(db)
  DB:ApplyDefaults(db, defaults)
end

local function colorValue(color, index, fallback)
  return type(color) == "table" and tonumber(color[index]) or fallback
end

local function currentSpecID()
  if not (GetSpecialization and GetSpecializationInfo) then return nil end
  local index = GetSpecialization()
  return index and select(1, GetSpecializationInfo(index)) or nil
end

local function isKnownSpell(spellID)
  if not spellID then return false end
  if C_SpellBook and C_SpellBook.IsSpellKnownOrInSpellBook then
    local ok, known = pcall(C_SpellBook.IsSpellKnownOrInSpellBook, spellID)
    if ok and known then return true end
  end
  if IsPlayerSpell then
    local ok, known = pcall(IsPlayerSpell, spellID)
    if ok and known then return true end
  end
  return false
end

local function getInterruptSpellID()
  local candidates = INTERRUPTS_BY_SPEC[currentSpecID()]
  if not candidates then return nil end
  for _, spellID in ipairs(candidates) do
    if isKnownSpell(spellID) then return spellID end
  end
  -- Some pet interrupts are queryable even when the spellbook API cannot see them.
  return candidates[1]
end

local function isInterruptReady(spellID)
  if not (spellID and C_Spell and C_Spell.GetSpellCooldown) then return false end
  local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
  if not ok or type(info) ~= "table" then return false end
  local readyOK, ready = pcall(function()
    local duration = tonumber(info.duration)
    local enabled = info.isEnabled
    return duration ~= nil and duration <= 0 and enabled ~= false
  end)
  return readyOK and ready == true
end

local function positionGlowLine(texture, owner, distance, thickness)
  local width = math.max(owner:GetWidth() or 0, 20)
  local height = math.max(owner:GetHeight() or 0, 8)
  local perimeter = (2 * width) + (2 * height)
  local point = distance % perimeter
  local x, y
  if point < width then
    x, y = point, 0
  elseif point < width + height then
    x, y = width, -(point - width)
  elseif point < (2 * width) + height then
    x, y = width - (point - width - height), -height
  else
    x, y = 0, -(height - (point - (2 * width) - height))
  end
  texture:ClearAllPoints()
  texture:SetPoint("CENTER", owner, "TOPLEFT", x, y)
  texture:SetSize(math.max(2, thickness * 2.4), math.max(2, thickness))
end

local function createPixelGlow(owner)
  local glow = CreateFrame("Frame", nil, owner)
  glow:SetAllPoints(owner)
  glow:SetFrameLevel(owner:GetFrameLevel() + 8)
  glow:EnableMouse(false)
  glow.lines = {}
  glow.elapsed = 0

  for i = 1, 12 do
    local line = glow:CreateTexture(nil, "OVERLAY")
    line:SetTexture("Interface\\Buttons\\WHITE8x8")
    line:SetBlendMode("ADD")
    glow.lines[i] = line
  end

  function glow:Apply(db)
    self.lineCount = math.max(4, math.min(12, tonumber(db.glow_lines) or defaults.glow_lines))
    self.thickness = math.max(1, math.min(5, tonumber(db.glow_thickness) or defaults.glow_thickness))
    self.speed = math.max(1, math.min(8, tonumber(db.glow_speed) or defaults.glow_speed))
    local r = colorValue(db.glow_color, 1, 0.15)
    local g = colorValue(db.glow_color, 2, 0.85)
    local b = colorValue(db.glow_color, 3, 1.00)
    local a = colorValue(db.glow_color, 4, 1.00)
    for i, line in ipairs(self.lines) do
      line:SetVertexColor(r, g, b, a)
      line:SetShown(i <= self.lineCount)
    end
  end

  glow:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed + elapsed * self.speed * 28) % 100000
    local width = math.max(owner:GetWidth() or 0, 20)
    local height = math.max(owner:GetHeight() or 0, 8)
    local perimeter = (2 * width) + (2 * height)
    local count = self.lineCount or defaults.glow_lines
    for i = 1, count do
      positionGlowLine(self.lines[i], owner, self.elapsed + ((i - 1) * perimeter / count), self.thickness or 2)
    end
  end)

  glow:Hide()
  return glow
end

local function findBlizzardCastBar(unit)
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
  local secure = issecure and issecure() or false
  local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit, secure)
  if not ok or not plate then return nil end
  local unitFrame = plate.UnitFrame or plate.unitFrame
  local castBarsContainer = unitFrame and unitFrame.CastBarsContainer
  local bar = unitFrame and (
    unitFrame.castBar
    or unitFrame.CastBar
    or (castBarsContainer and (castBarsContainer.castBar or castBarsContainer.CastBar))
  )
  return plate, bar
end

local function getCastInfo(unit)
  if not unit then return nil end
  local name, _, _, _, _, _, _, notInterruptible, spellID = UnitCastingInfo(unit)
  if type(name) ~= "nil" then return spellID, notInterruptible end
  name, _, _, _, _, _, notInterruptible, spellID = UnitChannelInfo(unit)
  if type(name) ~= "nil" then return spellID, notInterruptible end
  return nil
end

function M:EnsureDB()
  local db = DB:EnsureModuleState("CastbarStyle", defaults)
  applyDefaults(db)
  -- SavedVariables replace the table created while addon files are loading.
  self.db = db
  return db
end

function M:ResetDB()
  self.db = DB:ResetModuleState("CastbarStyle", defaults)
  self:RefreshAllNameplates()
  self:UpdatePreview()
end

function M:GetDisplayName()
  return self.displayName
end

function M:GetOptions()
  return {
    { type = "header", text = (L and L.CASTBAR_STYLE_COLORS) or "Colors" },
    { type = "color", key = "normal_color", label = (L and L.CASTBAR_STYLE_NORMAL_COLOR) or "Normal cast color" },
    { type = "color", key = "important_color", label = (L and L.CASTBAR_STYLE_IMPORTANT_COLOR) or "Important cast color" },
    { type = "header", text = (L and L.CASTBAR_STYLE_GLOW) or "Interrupt glow" },
    { type = "toggle", key = "glow_enabled", label = (L and L.CASTBAR_STYLE_GLOW_ENABLED) or "Show glow when your interrupt is ready" },
    { type = "color", key = "glow_color", label = (L and L.CASTBAR_STYLE_GLOW_COLOR) or "Glow color" },
    { type = "number", key = "glow_lines", label = (L and L.CASTBAR_STYLE_GLOW_LINES) or "Glow lines", min = 4, max = 12, step = 1 },
    { type = "number", key = "glow_thickness", label = (L and L.CASTBAR_STYLE_GLOW_THICKNESS) or "Glow thickness", min = 1, max = 5, step = 1 },
    { type = "number", key = "glow_speed", label = (L and L.CASTBAR_STYLE_GLOW_SPEED) or "Glow speed", min = 1, max = 8, step = 1 },
    { type = "header", text = (L and L.CASTBAR_STYLE_PREVIEW) or "Preview" },
    { type = "preview", height = 154, create = function(parent, db) self:CreatePreview(parent, db) end },
  }
end

function M:GetOrCreateState(unit, plate, bar)
  self.states = self.states or {}
  self.barUnits = self.barUnits or setmetatable({}, { __mode = "k" })
  self.barUnits[bar] = unit
  local state = self.states[unit]
  if state and state.bar == bar then return state end
  if state and state.glow then state.glow:Hide() end
  self.barGlows = self.barGlows or setmetatable({}, { __mode = "k" })
  local glow = self.barGlows[bar]
  if not glow then
    glow = createPixelGlow(bar)
    self.barGlows[bar] = glow
    if bar.UpdateBarFillTexture and hooksecurefunc then
      hooksecurefunc(bar, "UpdateBarFillTexture", function()
        local currentUnit = self.barUnits[bar]
        local active = currentUnit and self.states and self.states[currentUnit]
        if active and active.bar == bar then self:ApplyCastStyle(currentUnit) end
      end)
    end
  end
  state = { unit = unit, plate = plate, bar = bar, glow = glow }
  self.states[unit] = state
  return state
end

function M:ApplyCastStyle(unit)
  local db = self.db or self:EnsureDB()
  if not db.enabled then return end
  local plate, bar = findBlizzardCastBar(unit)
  if not (bar and bar.SetStatusBarColor) then return end
  local spellID, notInterruptible = getCastInfo(unit)
  if type(spellID) == "nil" then return end

  local state = self:GetOrCreateState(unit, plate, bar)
  if not state.originalColor then
    local ok, r, g, b, a = pcall(bar.GetStatusBarColor, bar)
    if ok then state.originalColor = { r, g, b, a } end
  end

  local normal = db.normal_color or defaults.normal_color
  local important = db.important_color or defaults.important_color
  local r, g, b = colorValue(normal, 1, 1), colorValue(normal, 2, 0.7), colorValue(normal, 3, 0)
  if C_Spell and C_Spell.IsSpellImportant and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
    local ok, isImportant = pcall(C_Spell.IsSpellImportant, spellID)
    if ok then
      local evaluate = C_CurveUtil.EvaluateColorValueFromBoolean
      r = evaluate(isImportant, colorValue(important, 1, 1), r)
      g = evaluate(isImportant, colorValue(important, 2, 0.16), g)
      b = evaluate(isImportant, colorValue(important, 3, 0.12), b)
    end
  end
  -- Modern Blizzard atlases contain their own hue; use a neutral fill for tinting.
  if not state.textureCaptured then
    local texture = bar:GetStatusBarTexture()
    if texture then
      state.originalAtlas = texture:GetAtlas()
      state.originalTexture = texture:GetTexture()
    end
    state.textureCaptured = true
  end
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetStatusBarColor(r, g, b)

  state.glow:Apply(db)
  if not db.glow_enabled or not isInterruptReady(getInterruptSpellID()) then
    state.glow:Hide()
  else
    state.glow:Show()
    if type(notInterruptible) == "nil" then notInterruptible = false end
    if state.glow.SetAlphaFromBoolean then
      state.glow:SetAlphaFromBoolean(notInterruptible, 0, 1)
    else
      local ok, alpha = pcall(function() return notInterruptible and 0 or 1 end)
      state.glow:SetAlpha(ok and alpha or 0)
    end
  end
end

function M:ScheduleCastStyle(unit)
  if type(unit) ~= "string" then return end
  self.pendingStyles = self.pendingStyles or {}
  local revision = {}
  self.pendingStyles[unit] = revision
  C_Timer.After(0, function()
    if not self.pendingStyles or self.pendingStyles[unit] ~= revision then return end
    self.pendingStyles[unit] = nil
    if UnitExists(unit) then self:ApplyCastStyle(unit) end
  end)
end

function M:ClearUnit(unit, restore)
  local state = self.states and self.states[unit]
  if not state then return end
  if self.barUnits and self.barUnits[state.bar] == unit then self.barUnits[state.bar] = nil end
  if state.glow then state.glow:Hide() end
  if restore and state.bar then
    if state.originalAtlas then
      state.bar:SetStatusBarTexture(state.originalAtlas)
    elseif state.originalTexture then
      state.bar:SetStatusBarTexture(state.originalTexture)
    end
  end
  if restore and state.originalColor and state.bar and state.bar.SetStatusBarColor then
    pcall(state.bar.SetStatusBarColor, state.bar, unpack(state.originalColor))
  end
  self.states[unit] = nil
end

function M:RestoreAll()
  if not self.states then return end
  local units = {}
  for unit in pairs(self.states) do units[#units + 1] = unit end
  for _, unit in ipairs(units) do self:ClearUnit(unit, true) end
end

function M:RefreshAllNameplates()
  local db = self.db or self:EnsureDB()
  if not db.enabled then
    self:RestoreAll()
    return
  end
  if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
  local secure = issecure and issecure() or false
  local ok, plates = pcall(C_NamePlate.GetNamePlates, secure)
  if not ok or type(plates) ~= "table" then return end
  for _, plate in ipairs(plates) do
    local unitFrame = plate and (plate.UnitFrame or plate.unitFrame)
    local unit = plate and (plate.namePlateUnitToken or (unitFrame and unitFrame.unit))
    if unit then self:ApplyCastStyle(unit) end
  end
end

function M:RefreshActiveCasts()
  if not self.states then return end
  local units = {}
  for unit in pairs(self.states) do units[#units + 1] = unit end
  for _, unit in ipairs(units) do
    if UnitExists(unit) then
      self:ApplyCastStyle(unit)
    else
      self:ClearUnit(unit, false)
    end
  end
end

local function createPreviewBar(parent, y, label)
  local holder = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  holder:SetSize(510, 36)
  holder:SetPoint("TOP", parent, "TOP", 0, y)
  holder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
  holder:SetBackdropColor(0.02, 0.02, 0.02, 0.95)
  holder:SetBackdropBorderColor(0, 0, 0, 1)

  local bar = CreateFrame("StatusBar", nil, holder)
  bar:SetPoint("TOPLEFT", 2, -2)
  bar:SetPoint("BOTTOMRIGHT", -2, 2)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
  bar:SetMinMaxValues(0, 1)
  bar:SetValue(0.68)
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetColorTexture(0.08, 0.08, 0.08, 1)
  local text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  text:SetPoint("CENTER")
  text:SetText(label)
  return holder, bar
end

function M:CreatePreview(parent, db)
  local title = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  title:SetPoint("TOPLEFT", 16, -12)
  title:SetText((L and L.CASTBAR_STYLE_PREVIEW) or "Preview")

  local _, normalBar = createPreviewBar(parent, -40, (L and L.CASTBAR_STYLE_PREVIEW_NORMAL) or "Normal cast")
  local _, importantBar = createPreviewBar(parent, -92, (L and L.CASTBAR_STYLE_PREVIEW_IMPORTANT) or "Important cast - interrupt ready")
  local glow = createPixelGlow(importantBar)
  glow:Show()
  self.preview = { frame = parent, normal = normalBar, important = importantBar, glow = glow, elapsed = 0 }
  parent:SetScript("OnUpdate", function(_, elapsed)
    if not self.preview or self.preview.frame ~= parent then return end
    self.preview.elapsed = (self.preview.elapsed + elapsed * 0.18) % 1
    local value = 1 - self.preview.elapsed
    normalBar:SetValue(value)
    importantBar:SetValue(value)
  end)
  self:UpdatePreview(db)
end

function M:UpdatePreview(db)
  local preview = self.preview
  if not (preview and preview.frame and preview.frame:IsShown()) then return end
  db = db or self.db or self:EnsureDB()
  local normal = db.normal_color or defaults.normal_color
  local important = db.important_color or defaults.important_color
  preview.normal:SetStatusBarColor(colorValue(normal, 1, 1), colorValue(normal, 2, 0.7), colorValue(normal, 3, 0))
  preview.important:SetStatusBarColor(colorValue(important, 1, 1), colorValue(important, 2, 0.16), colorValue(important, 3, 0.12))
  preview.glow:Apply(db)
  preview.glow:SetShown(db.glow_enabled == true)
end

function M:OnRegister()
  self.states = {}
  self.pendingStyles = {}
end

function M:OnOptionChanged()
  self.db = self:EnsureDB()
  self:RefreshAllNameplates()
  self:UpdatePreview()
end

function M:OnEvent(event, unit)
  if event == "SPELL_UPDATE_COOLDOWN" then
    self:RefreshActiveCasts()
    return
  end
  if event == "PLAYER_LOGIN" or event == "PLAYER_SPECIALIZATION_CHANGED" then
    self:RefreshAllNameplates()
    return
  end
  if event == "NAME_PLATE_UNIT_REMOVED" then
    if self.pendingStyles then self.pendingStyles[unit] = nil end
    self:ClearUnit(unit, false)
    return
  end
  if event == "NAME_PLATE_UNIT_ADDED" then
    self:ScheduleCastStyle(unit)
    return
  end
  if type(unit) ~= "string" or not unit:find("^nameplate") then return end
  if event == "UNIT_SPELLCAST_STOP"
    or event == "UNIT_SPELLCAST_CHANNEL_STOP"
    or event == "UNIT_SPELLCAST_EMPOWER_STOP"
    or event == "UNIT_SPELLCAST_FAILED"
    or event == "UNIT_SPELLCAST_INTERRUPTED" then
    local state = self.states and self.states[unit]
    if state then
      if state.glow then state.glow:Hide() end
      state.originalColor = nil
    end
    return
  end
  self:ScheduleCastStyle(unit)
end

Kaldo:RegisterModule("CastbarStyle", M)
