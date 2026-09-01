-- ui.lua (Retail 12.0.1) - dedicated Kaldo Tweaks configuration window
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo
local L = NS.L

local KALDO_CATEGORY_ID
local UI = { _sid = 0, _did = 0 }
UI._modulePanels = {}
UI._moduleButtons = {}
NS.UI = UI

local C = {
  bg = { 0.030, 0.040, 0.045, 0.96 },
  panel = { 0.055, 0.070, 0.075, 0.88 },
  panel2 = { 0.075, 0.092, 0.100, 0.86 },
  line = { 0.120, 0.390, 0.350, 0.55 },
  lineSoft = { 0.180, 0.260, 0.250, 0.35 },
  accent = { 0.000, 0.860, 0.700, 1.00 },
  accent2 = { 1.000, 0.430, 0.700, 1.00 },
  text = { 0.940, 0.965, 0.950, 1.00 },
  muted = { 0.610, 0.650, 0.650, 1.00 },
  off = { 0.180, 0.190, 0.200, 1.00 },
}

local ROW_W = 604
local RIGHT_PAD = 18
local CONTROL_W = 300
local TAB_H = 30

local function applyClassTheme()
  local classFile
  if UnitClass then
    local _, file = UnitClass("player")
    classFile = file
  end
  local classColor = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
  if not classColor then return end
  C.accent = { classColor.r or 0, classColor.g or 0.86, classColor.b or 0.7, 1 }
  C.line = { classColor.r or 0, classColor.g or 0.86, classColor.b or 0.7, 0.55 }
  C.accent2 = {
    math.min((classColor.r or 0) + 0.28, 1),
    math.min((classColor.g or 0.86) + 0.18, 1),
    math.min((classColor.b or 0.7) + 0.18, 1),
    1,
  }
end

local function unpackColor(color)
  return color[1], color[2], color[3], color[4]
end

local function setBackdrop(frame, color, borderColor)
  if not frame.SetBackdrop then return end
  frame:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
  })
  frame:SetBackdropColor(unpackColor(color or C.panel))
  frame:SetBackdropBorderColor(unpackColor(borderColor or C.lineSoft))
end

local function createPanel(parent, color, borderColor)
  local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  setBackdrop(frame, color, borderColor)
  return frame
end

local function createFont(parent, template, text, color)
  local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
  fs:SetText(text or "")
  fs:SetTextColor(unpackColor(color or C.text))
  fs:SetJustifyH("LEFT")
  return fs
end

local function addTexture(parent, color)
  local tex = parent:CreateTexture(nil, "ARTWORK")
  tex:SetColorTexture(unpackColor(color))
  return tex
end

Kaldo.Media = Kaldo.Media or {}
function Kaldo.Media:GetFonts()
  local out, seen = {}, {}
  local blizz = {
    { "Fonts\\FRIZQT__.TTF", "Blizzard - Frizqt" },
    { "Fonts\\ARIALN.TTF",  "Blizzard - ArialN" },
    { "Fonts\\MORPHEUS.TTF","Blizzard - Morpheus" },
    { "Fonts\\skurri.ttf",  "Blizzard - Skurri" },
  }
  for _, it in ipairs(blizz) do seen[it[1]] = true; out[#out+1] = it end
  local lsm = LibStub and LibStub("LibSharedMedia-3.0", true)
  if lsm then
    for _, name in ipairs(lsm:List("font") or {}) do
      local path = lsm:Fetch("font", name)
      if path and not seen[path] then
        seen[path] = true
        out[#out+1] = { path, name }
      end
    end
  end
  table.sort(out, function(a,b) return tostring(a[2]) < tostring(b[2]) end)
  return out
end

function Kaldo.Media:GetSounds()
  return {
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 0, "IG_MAINMENU_OPEN" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 0, "IG_MAINMENU_CLOSE" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 0, "CHECKBOX_ON" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 0, "CHECKBOX_OFF" },
  }
end

function Kaldo.Media:GetCDMSoundTree()
  if C_AddOns and C_AddOns.LoadAddOn then pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownManager") end
  if self._cdmTree then return self._cdmTree end

  local function looksLikeTree(t)
    if type(t) ~= "table" then return false end
    for _, list in pairs(t) do
      if type(list) == "table" and type(list[1]) == "table" then
        local e = list[1]
        if (e.soundKitID or e.id) and (e.name or e.label) then return true end
      end
    end
    return false
  end

  for _, v in pairs(_G) do
    if looksLikeTree(v) then
      self._cdmTree = v
      return v
    end
  end
  return nil
end

local function ensureModuleDB(modName, mod)
  KaldoDB = KaldoDB or {}
  KaldoDB.modules = KaldoDB.modules or {}
  KaldoDB.modules[modName] = KaldoDB.modules[modName] or {}
  local db = KaldoDB.modules[modName]
  if db.enabled == nil then db.enabled = false end
  if mod and mod.EnsureDB then
    mod:EnsureDB()
    db = KaldoDB.modules[modName] or db
  end
  return db
end

local function splitKey(key)
  if type(key) ~= "string" or not key:find("%.") then return nil end
  local parts = {}
  for part in key:gmatch("[^%.]+") do parts[#parts + 1] = part end
  return parts
end

local function getOptionValue(db, key)
  if not db or key == nil then return nil end
  local parts = splitKey(key)
  if not parts then return db[key] end
  local t = db
  for i = 1, #parts do
    t = t and t[parts[i]]
    if t == nil then return nil end
  end
  return t
end

local function setOptionValue(db, key, val)
  if not db or key == nil then return end
  local parts = splitKey(key)
  if not parts then
    db[key] = val
    return
  end
  local t = db
  for i = 1, #parts - 1 do
    local k = parts[i]
    if type(t[k]) ~= "table" then t[k] = {} end
    t = t[k]
  end
  t[parts[#parts]] = val
end

local function getModuleTitle(modName, mod)
  return (mod and mod.GetDisplayName and mod:GetDisplayName()) or (mod and mod.displayName) or modName
end

local function orderedModules()
  local out, seen = {}, {}
  for _, mod in ipairs(Kaldo.moduleOrder or {}) do
    local name = mod and mod.name
    if name and Kaldo.modules and Kaldo.modules[name] and not seen[name] then
      out[#out + 1] = { name = name, mod = Kaldo.modules[name] }
      seen[name] = true
    end
  end
  for name, mod in pairs(Kaldo.modules or {}) do
    if not seen[name] then out[#out + 1] = { name = name, mod = mod } end
  end
  return out
end

local function attachTooltip(widget, text)
  if not widget or not text or text == "" or type(widget.HookScript) ~= "function" then return end
  if widget.EnableMouse then widget:EnableMouse(true) end
  widget:HookScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.ClearLines then GameTooltip:ClearLines() end
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  widget:HookScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

local function addChild(frame, widget)
  frame._children = frame._children or {}
  frame._children[#frame._children + 1] = widget
end

local function clearCanvas(frame)
  if frame._children then
    for _, child in ipairs(frame._children) do
      if child.Hide then child:Hide() end
    end
  end
  frame._children = {}
  if frame._content and frame._content.GetRegions then
    for _, region in ipairs({ frame._content:GetRegions() }) do
      if region.Hide then region:Hide() end
    end
  end
end

local function makeButton(parent, label, width, height)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width or 160, height or 28)
  b:SetText("")
  setBackdrop(b, { 0.075, 0.085, 0.090, 0.94 }, C.lineSoft)
  b.text = createFont(b, "GameFontNormal", label or "Button", C.text)
  b.text:SetPoint("CENTER")
  b:SetScript("OnEnter", function(self)
    setBackdrop(self, { 0.085, 0.105, 0.110, 0.98 }, C.accent)
  end)
  b:SetScript("OnLeave", function(self)
    setBackdrop(self, { 0.075, 0.085, 0.090, 0.94 }, C.lineSoft)
  end)
  return b
end

local function updateToggleVisual(b, checked)
  b._checked = not not checked
  if b._checked then
    b.track:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.95)
    b.knob:SetColorTexture(0.810, 1.000, 0.950, 1)
    b.state:SetText("ON")
    b.state:SetTextColor(0.70, 1, 0.92, 1)
    b.knob:ClearAllPoints()
    b.knob:SetPoint("RIGHT", b, "RIGHT", -4, 0)
  else
    b.track:SetColorTexture(unpackColor(C.off))
    b.knob:SetColorTexture(0.45, 0.47, 0.48, 1)
    b.state:SetText("OFF")
    b.state:SetTextColor(unpackColor(C.muted))
    b.knob:ClearAllPoints()
    b.knob:SetPoint("LEFT", b, "LEFT", 4, 0)
  end
end

local function addToggle(parent, label, value, onChanged, x, y, emphasized)
  local row = createPanel(parent, emphasized and C.panel2 or C.panel, emphasized and C.line or C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, emphasized and 52 or 42)

  local title = createFont(row, emphasized and "GameFontNormalLarge" or "GameFontNormal", label or "", C.text)
  title:SetPoint("LEFT", 16, 0)
  title:SetPoint("RIGHT", -96, 0)
  title:SetWordWrap(false)

  local b = CreateFrame("Button", nil, row)
  b:SetSize(62, 26)
  b:SetPoint("RIGHT", -16, 0)
  b.track = b:CreateTexture(nil, "BACKGROUND")
  b.track:SetAllPoints()
  b.knob = b:CreateTexture(nil, "ARTWORK")
  b.knob:SetSize(18, 18)
  b.state = createFont(b, "GameFontHighlightSmall", "", C.muted)
  b.state:SetPoint("CENTER", 0, 0)
  updateToggleVisual(b, value)
  b:SetScript("OnClick", function(self)
    updateToggleVisual(self, not self._checked)
    onChanged(self._checked)
  end)
  row.toggle = b
  return row, y + (emphasized and 60 or 50)
end

local function addHeader(parent, text, x, y, first)
  if not first then y = y + 8 end
  local fs = createFont(parent, "GameFontNormalLarge", text or "", C.accent)
  fs:SetPoint("TOPLEFT", x, -y)
  local line = addTexture(parent, C.line)
  line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -8)
  line:SetSize(ROW_W, 1)
  return fs, line, y + 34
end

local function addLabelRow(parent, text, x, y)
  local row = createPanel(parent, C.panel, C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, 34)
  local fs = createFont(row, "GameFontHighlightSmall", text or "", C.muted)
  fs:SetPoint("LEFT", 16, 0)
  fs:SetPoint("RIGHT", -16, 0)
  return row, y + 42
end

local function addEdit(parent, label, value, onChanged, x, y)
  local row = createPanel(parent, C.panel, C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, 48)
  local fs = createFont(row, "GameFontNormal", label or "", C.text)
  fs:SetPoint("LEFT", 16, 0)
  fs:SetWidth(250)

  local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
  eb:SetSize(CONTROL_W, 24)
  eb:SetPoint("RIGHT", -RIGHT_PAD, 0)
  eb:SetAutoFocus(false)
  eb:SetText(value or "")
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); onChanged(self:GetText()) end)
  eb:SetScript("OnEditFocusLost", function(self) onChanged(self:GetText()) end)
  row.control = eb
  return row, y + 56
end

local function addSlider(parent, label, value, minv, maxv, step, onChanged, x, y)
  local row = createPanel(parent, C.panel, C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, 58)

  local fs = createFont(row, "GameFontNormal", label or "", C.text)
  fs:SetPoint("LEFT", 16, 8)
  fs:SetWidth(240)

  UI._sid = UI._sid + 1
  local s = CreateFrame("Slider", "KaldoUISlider"..UI._sid, row, "OptionsSliderTemplate")
  s:SetWidth(250)
  s:SetPoint("RIGHT", -62, -4)
  s:SetMinMaxValues(minv or 0, maxv or 100)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)
  s.Low:SetText(tostring(minv or 0))
  s.High:SetText(tostring(maxv or 100))
  local initial = value
  if initial == nil then initial = minv or 0 end
  s:SetValue(initial)
  s.Text:SetText("")

  local valueBox = createPanel(row, { 0.030, 0.035, 0.040, 0.95 }, C.lineSoft)
  valueBox:SetSize(42, 24)
  valueBox:SetPoint("RIGHT", -RIGHT_PAD, 4)
  local valueText = createFont(valueBox, "GameFontHighlightSmall", tostring(initial), C.text)
  valueText:SetPoint("CENTER")

  s:SetScript("OnValueChanged", function(_, v)
    local st = step or 1
    v = math.floor((v / st) + 0.5) * st
    valueText:SetText(tostring(v))
    onChanged(v)
  end)
  row.control = s
  return row, y + 66
end

local function addButton(parent, label, onClick, x, y)
  local b = makeButton(parent, label or "Button", 220, 30)
  b:SetPoint("TOPLEFT", x + 384, -y)
  b:SetScript("OnClick", onClick)
  return b, y + 40
end

local function compactTabLabel(label)
  label = tostring(label or "")
  if label == "Overlay du meilleur score" then return "Meilleur score" end
  if label == "Rappel d'acceptation du groupe" then return "Acceptation" end
  if #label <= 18 then return label end
  return label:sub(1, 15) .. "..."
end

local function addTab(parent, label, selected, onClick, x, y, width)
  local b = makeButton(parent, compactTabLabel(label), width or 120, TAB_H)
  b:SetPoint("TOPLEFT", x, -y)
  b.text:ClearAllPoints()
  b.text:SetPoint("LEFT", 8, 0)
  b.text:SetPoint("RIGHT", -8, 0)
  b.text:SetJustifyH("CENTER")
  b.text:SetWordWrap(false)
  if selected then
    setBackdrop(b, { C.accent[1] * 0.20, C.accent[2] * 0.20, C.accent[3] * 0.20, 0.96 }, C.accent)
    b.text:SetTextColor(1, 1, 1, 1)
  else
    b.text:SetTextColor(unpackColor(C.muted))
  end
  b:SetScript("OnClick", onClick)
  return b
end

local function addDropdown(parent, label, value, values, onChanged, x, y, isTree)
  local row = createPanel(parent, C.panel, C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, 50)

  local fs = createFont(row, "GameFontNormal", label or "", C.text)
  fs:SetPoint("LEFT", 16, 0)
  fs:SetWidth(240)

  UI._did = UI._did + 1
  local selector = makeButton(row, "", CONTROL_W, 28)
  selector:SetPoint("RIGHT", -RIGHT_PAD, 0)
  selector.text:ClearAllPoints()
  selector.text:SetPoint("LEFT", 12, 0)
  selector.text:SetPoint("RIGHT", -28, 0)
  selector.text:SetJustifyH("LEFT")
  local chevron = createFont(selector, "GameFontHighlightSmall", "v", C.accent)
  chevron:SetPoint("RIGHT", -10, 0)

  local dd = CreateFrame("Frame", "KaldoUIDropdown"..UI._did, row, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", -18, 0)
  dd:SetAlpha(0)
  UIDropDownMenu_SetWidth(dd, CONTROL_W - 30)

  local function setTextFor(val)
    local txt = tostring(val)
    for _, it in ipairs(values or {}) do
      if it[1] == val then txt = it[2] end
    end
    UIDropDownMenu_SetText(dd, txt)
    selector.text:SetText(txt)
  end

  local function setTreeTextFor(val)
    local tree = Kaldo.Media:GetCDMSoundTree()
    if tree then
      for _, entries in pairs(tree) do
        for _, entry in ipairs(entries or {}) do
          local id = entry.soundKitID or entry.id
          if id == val then
            local name = entry.name or tostring(id)
            UIDropDownMenu_SetText(dd, name)
            selector.text:SetText(name)
            return
          end
        end
      end
    end
    selector.text:SetText(val and tostring(val) or "Choisir...")
  end

  UIDropDownMenu_Initialize(dd, function(_, level)
    level = level or 1
    if isTree then
      local tree = Kaldo.Media:GetCDMSoundTree()
      if not tree then return end
      if level == 1 then
        local cats = {}
        for cat in pairs(tree) do cats[#cats+1] = cat end
        table.sort(cats)
        for _, cat in ipairs(cats) do
          local info = UIDropDownMenu_CreateInfo()
          info.text, info.hasArrow, info.notCheckable = cat, true, true
          info.value = cat
          UIDropDownMenu_AddButton(info, level)
        end
      else
        local cat = UIDROPDOWNMENU_MENU_VALUE
        for _, entry in ipairs(tree[cat] or {}) do
          local id = entry.soundKitID or entry.id
          local name = entry.name or tostring(id)
          local info = UIDropDownMenu_CreateInfo()
          info.text = name
          info.checked = (id == value)
          info.func = function()
            value = id
            UIDropDownMenu_SetText(dd, name)
            selector.text:SetText(name)
            onChanged(id)
          end
          UIDropDownMenu_AddButton(info, level)
        end
      end
    else
      for _, it in ipairs(values or {}) do
        local v, txt = it[1], it[2]
        local info = UIDropDownMenu_CreateInfo()
        info.text = txt
        info.checked = (v == value)
        info.func = function()
          value = v
          setTextFor(v)
          onChanged(v)
        end
        UIDropDownMenu_AddButton(info, level)
      end
    end
  end)

  if not isTree then
    setTextFor(value)
  else
    setTreeTextFor(value)
  end
  selector:SetScript("OnClick", function()
    ToggleDropDownMenu(1, nil, dd, selector, 0, 0)
  end)
  row.control = selector
  return row, y + 58
end

local function rgbaToObj(rgba)
  local r,g,b,a = 1,1,1,1
  if type(rgba) == "table" then
    r,g,b,a = rgba[1] or 1, rgba[2] or 1, rgba[3] or 1, rgba[4]
    if a == nil then a = 1 end
  end
  return r,g,b,a
end

local function addColorPicker(parent, label, rgba, onChanged, x, y)
  local row = createPanel(parent, C.panel, C.lineSoft)
  row:SetPoint("TOPLEFT", x, -y)
  row:SetSize(ROW_W, 48)

  local fs = createFont(row, "GameFontNormal", label or "", C.text)
  fs:SetPoint("LEFT", 16, 0)
  fs:SetWidth(250)

  local btn = makeButton(row, "Choisir", 150, 28)
  btn:SetPoint("RIGHT", -60, 0)
  local swatch = btn:CreateTexture(nil, "OVERLAY")
  swatch:SetSize(24, 24)
  swatch:SetPoint("LEFT", btn, "RIGHT", 12, 0)
  local r,g,b,a = rgbaToObj(rgba)
  swatch:SetColorTexture(r,g,b,a)

  btn:SetScript("OnClick", function()
    local cr,cg,cb,ca = rgbaToObj(rgba)
    local prev = { r=cr, g=cg, b=cb, a=ca }
    local function set(rr, gg, bb, aa)
      rgba = { rr, gg, bb, aa or 1 }
      swatch:SetColorTexture(rr, gg, bb, aa or 1)
      onChanged(rgba)
    end
    ColorPickerFrame:SetupColorPickerAndShow({
      r=cr, g=cg, b=cb,
      hasOpacity=true,
      opacity=1-ca,
      swatchFunc=function()
        local rr,gg,bb = ColorPickerFrame:GetColorRGB()
        set(rr, gg, bb, 1 - (ColorPickerFrame:GetColorAlpha() or 0))
      end,
      opacityFunc=function()
        local rr,gg,bb = ColorPickerFrame:GetColorRGB()
        set(rr, gg, bb, 1 - (ColorPickerFrame:GetColorAlpha() or 0))
      end,
      cancelFunc=function() set(prev.r, prev.g, prev.b, prev.a) end,
    })
  end)
  row.control = btn
  return row, y + 56
end

local function createScrollCanvas(frame)
  local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 0, 0)
  scroll:SetPoint("BOTTOMRIGHT", -28, 0)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(1, 1)
  scroll:SetScrollChild(content)

  frame._scroll = scroll
  frame._content = content
  frame._children = {}
  return content
end

local buildModuleOptionsOnCanvas

local function refreshModuleButton(modName)
  local entry = UI._moduleButtons and UI._moduleButtons[modName]
  if not entry then return end
  local db = ensureModuleDB(modName, entry.mod)
  if db.enabled then
    entry.power:SetText("ON")
    entry.power:SetTextColor(0.70, 1, 0.92, 1)
    entry.powerBg:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.88)
  else
    entry.power:SetText("OFF")
    entry.power:SetTextColor(unpackColor(C.muted))
    entry.powerBg:SetColorTexture(0.150, 0.160, 0.170, 0.90)
  end
end

local function setModuleEnabled(modName, mod, enabled)
  local db = ensureModuleDB(modName, mod)
  db.enabled = not not enabled
  if mod and mod.OnOptionChanged then mod:OnOptionChanged("enabled", db.enabled) end
  if Kaldo and Kaldo.RefreshEventSubscriptions then Kaldo:RefreshEventSubscriptions() end
  refreshModuleButton(modName)
  if UI.mainFrame and UI.mainFrame:IsShown() and UI.selectedModule == modName then
    buildModuleOptionsOnCanvas(UI.mainFrame.contentHost, modName, mod)
  end
end

local function addOptionToGroup(groups, groupById, id, title, opt)
  local group = groupById[id]
  if not group then
    group = { id = id, title = title, options = {} }
    groupById[id] = group
    groups[#groups + 1] = group
  end
  group.options[#group.options + 1] = opt
end

local function buildOptionGroups(modName, title, opts)
  local groups, groupById = {}, {}

  if modName == "CraftOrder" then
    local groupNames = {
      general = "General",
      detection = "Detection",
      message = "Message",
      style = "Style",
      sound = "Son",
      position = "Position",
      completion = "Validation",
    }
    local keyGroups = {
      enabled = "general",
      needle = "detection",
      caseInsensitive = "detection",
      throttle = "detection",
      text = "message",
      duration = "message",
      font = "style",
      fontSize = "style",
      outline = "style",
      color = "style",
      shadow = "style",
      shadowColor = "style",
      shadowX = "style",
      shadowY = "style",
      playSound = "sound",
      soundKit = "sound",
      x = "position",
      y = "position",
      completeWhisperEnabled = "completion",
      completeWhisperText = "completion",
    }
    local lastGroup = "general"
    for _, opt in ipairs(opts) do
      if opt.type ~= "header" then
        local groupId = keyGroups[opt.key] or (opt.key == nil and lastGroup) or "general"
        lastGroup = groupId
        addOptionToGroup(groups, groupById, groupId, groupNames[groupId] or groupId, opt)
      end
    end
    return groups
  end

  local currentId, currentTitle = "general", "General"
  for _, opt in ipairs(opts) do
    if opt.type == "header" then
      local h = opt.text or title
      if h ~= title then
        currentTitle = h
        currentId = tostring(h)
      end
    else
      addOptionToGroup(groups, groupById, currentId, currentTitle, opt)
    end
  end
  return groups
end

buildModuleOptionsOnCanvas = function(canvasFrame, modName, mod)
  clearCanvas(canvasFrame)
  local content = canvasFrame._content or createScrollCanvas(canvasFrame)
  local db = ensureModuleDB(modName, mod)
  local opts = (mod and mod.GetOptions and mod:GetOptions()) or {}
  local title = getModuleTitle(modName, mod)

  local injected = {
    { type="toggle", key="enabled", label=L.ENABLE_MODULE, emphasized=true },
  }
  if mod and mod.ResetDB then
    injected[#injected + 1] = {
      type = "button",
      label = (L and L.RESET_CONFIG) or "Reset config",
      onClick = function()
        mod:ResetDB()
        refreshModuleButton(modName)
        C_Timer.After(0, function() buildModuleOptionsOnCanvas(canvasFrame, modName, mod) end)
      end,
    }
  end
  for _, o in ipairs(opts) do
    if not (o.type == "header" and (o.text == title or o.text == mod.displayName)) then
      injected[#injected+1] = o
    end
  end
  opts = injected

  local y, x = 8, 16
  local groups = buildOptionGroups(modName, title, opts)
  local activeTab = UI.selectedTabs and UI.selectedTabs[modName]
  if not activeTab or not groups[1] then activeTab = groups[1] and groups[1].id end
  local activeGroup = groups[1]
  for _, group in ipairs(groups) do
    if group.id == activeTab then
      activeGroup = group
      break
    end
  end

  if #groups > 1 then
    UI.selectedTabs = UI.selectedTabs or {}
    UI.selectedTabs[modName] = activeGroup.id
    local tabX, tabY = x, y
    for _, group in ipairs(groups) do
      local tabId = group.id
      local tabW = math.max(96, math.min(145, 58 + (#tostring(group.title) * 6)))
      if tabX > x and (tabX + tabW) > (x + ROW_W) then
        tabX = x
        tabY = tabY + TAB_H + 8
      end
      local tab = addTab(content, group.title, group.id == activeGroup.id, function()
        UI.selectedTabs[modName] = tabId
        buildModuleOptionsOnCanvas(canvasFrame, modName, mod)
      end, tabX, tabY, tabW)
      addChild(canvasFrame, tab)
      tabX = tabX + tabW + 8
    end
    local line = addTexture(content, C.line)
    line:SetPoint("TOPLEFT", x, -(tabY + TAB_H + 8))
    line:SetSize(ROW_W, 1)
    addChild(canvasFrame, line)
    y = tabY + TAB_H + 24
  end

  opts = activeGroup and activeGroup.options or opts

  local firstHeaderSeen = false
  for _, opt in ipairs(opts) do
    local optValue = getOptionValue(db, opt.key)
    if opt.getValue then optValue = opt.getValue(db, mod) end

    local function applyOptionValue(v)
      if opt.setValue then
        opt.setValue(v, db, mod)
      else
        setOptionValue(db, opt.key, v)
      end
      if mod and mod.OnOptionChanged then mod:OnOptionChanged(opt.key, v) end
      if opt.key == "enabled" then
        refreshModuleButton(modName)
        if Kaldo and Kaldo.RefreshEventSubscriptions then Kaldo:RefreshEventSubscriptions() end
      end
    end

    local tooltip = opt.tooltip
    if type(tooltip) == "function" then tooltip = tooltip() end

    if opt.type == "header" then
      local fs, line
      fs, line, y = addHeader(content, opt.text or modName, x, y, not firstHeaderSeen)
      firstHeaderSeen = true
      addChild(canvasFrame, fs)
      addChild(canvasFrame, line)
    elseif opt.type == "toggle" then
      local w; w, y = addToggle(content, opt.label, optValue, applyOptionValue, x, y, opt.emphasized)
      attachTooltip(w, tooltip)
      attachTooltip(w.toggle, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "input" then
      local w; w, y = addEdit(content, opt.label, optValue, applyOptionValue, x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "number" then
      local minv, maxv = opt.min, opt.max
      if type(minv) == "function" then minv = minv() end
      if type(maxv) == "function" then maxv = maxv() end
      local w; w, y = addSlider(content, opt.label, optValue, minv, maxv, opt.step, applyOptionValue, x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "select" then
      local values = opt.values
      if type(values) == "function" then values = values() end
      local w; w, y = addDropdown(content, opt.label, optValue, values, applyOptionValue, x, y, opt.valuesTree == true)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "color" then
      local w; w, y = addColorPicker(content, opt.label, getOptionValue(db, opt.key), function(v)
        setOptionValue(db, opt.key, v)
        if mod and mod.OnOptionChanged then mod:OnOptionChanged(opt.key, v) end
      end, x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "label" then
      local labelText = opt.text
      if type(labelText) == "function" then labelText = labelText(db, mod) end
      local w; w, y = addLabelRow(content, labelText or "", x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "button" then
      local w; w, y = addButton(content, opt.label, function()
        if opt.onClick then opt.onClick(mod, db) end
      end, x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    end
  end

  content:SetHeight(y + 28)
end

local function selectModule(modName)
  local frame = UI.mainFrame
  if not frame or not modName or not Kaldo.modules[modName] then return end
  local title = getModuleTitle(modName, Kaldo.modules[modName])
  UI.selectedModule = modName
  if frame.headerTitle then frame.headerTitle:SetText(title) end
  if frame.headerSubtitle then frame.headerSubtitle:SetText("Modules, raccourcis et reglages d'affichage") end
  for name, entry in pairs(UI._moduleButtons or {}) do
    if name == modName then
      setBackdrop(entry.button, { C.accent[1] * 0.22, C.accent[2] * 0.22, C.accent[3] * 0.22, 0.95 }, C.accent)
      entry.text:SetTextColor(1, 1, 1, 1)
    else
      setBackdrop(entry.button, C.panel, C.lineSoft)
      entry.text:SetTextColor(unpackColor(C.text))
    end
  end
  buildModuleOptionsOnCanvas(frame.contentHost, modName, Kaldo.modules[modName])
end

local function moduleMatchesFilter(title, filter)
  if not filter or filter == "" then return true end
  return tostring(title):lower():find(filter:lower(), 1, true) ~= nil
end

local function rebuildSidebar()
  local frame = UI.mainFrame
  if not frame then return end
  if frame.sidebarChildren then
    for _, child in ipairs(frame.sidebarChildren) do child:Hide() end
  end
  frame.sidebarChildren = {}
  UI._moduleButtons = {}

  local filter = ""
  local y = 88
  for _, item in ipairs(orderedModules()) do
    local modName, mod = item.name, item.mod
    local title = getModuleTitle(modName, mod)
    if moduleMatchesFilter(title, filter) then
      local b = createPanel(frame.sidebar, C.panel, C.lineSoft)
      b:SetSize(238, 36)
      b:SetPoint("TOPLEFT", 14, -y)
      b:EnableMouse(true)

      local text = createFont(b, "GameFontNormal", title, C.text)
      text:SetPoint("LEFT", 12, 0)
      text:SetPoint("RIGHT", -58, 0)
      text:SetWordWrap(false)

      local powerBg = b:CreateTexture(nil, "ARTWORK")
      powerBg:SetSize(38, 20)
      powerBg:SetPoint("RIGHT", -10, 0)
      local power = createFont(b, "GameFontHighlightSmall", "", C.muted)
      power:SetPoint("CENTER", powerBg, "CENTER", 0, 0)
      local powerButton = CreateFrame("Button", nil, b)
      powerButton:SetAllPoints(powerBg)
      powerButton:SetScript("OnClick", function()
        local db = ensureModuleDB(modName, mod)
        setModuleEnabled(modName, mod, not db.enabled)
      end)

      b:SetScript("OnMouseDown", function() selectModule(modName) end)
      UI._moduleButtons[modName] = { button = b, text = text, power = power, powerBg = powerBg, mod = mod }
      refreshModuleButton(modName)
      frame.sidebarChildren[#frame.sidebarChildren + 1] = b
      y = y + 42
    end
  end

  if not UI.selectedModule or not UI._moduleButtons[UI.selectedModule] then
    for _, item in ipairs(orderedModules()) do
      if moduleMatchesFilter(getModuleTitle(item.name, item.mod), filter) then
        UI.selectedModule = item.name
        break
      end
    end
  end
  if UI.selectedModule then selectModule(UI.selectedModule) end
end

local function createMainFrame()
  if UI.mainFrame then return UI.mainFrame end
  applyClassTheme()

  local frame = CreateFrame("Frame", "KaldoTweaksConfigFrame", UIParent, "BackdropTemplate")
  frame:SetSize(980, 660)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:Hide()
  setBackdrop(frame, C.bg, C.line)

  local glow = addTexture(frame, { C.accent[1], C.accent[2], C.accent[3], 0.20 })
  glow:SetPoint("TOPLEFT", 268, -68)
  glow:SetPoint("TOPRIGHT", -18, -68)
  glow:SetHeight(2)

  local sidebar = createPanel(frame, { 0.035, 0.045, 0.050, 0.92 }, C.lineSoft)
  sidebar:SetPoint("TOPLEFT", 0, 0)
  sidebar:SetPoint("BOTTOMLEFT", 0, 0)
  sidebar:SetWidth(280)
  frame.sidebar = sidebar

  local logo = sidebar:CreateTexture(nil, "ARTWORK")
  logo:SetSize(48, 48)
  logo:SetPoint("TOPLEFT", 16, -15)
  logo:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\assets\\logo.tga")
  logo:SetTexCoord(0.03, 0.97, 0.03, 0.97)

  local title = createFont(sidebar, "GameFontNormalHuge", "Kaldo Tweaks", C.text)
  title:SetPoint("LEFT", logo, "RIGHT", 14, 0)

  local close = makeButton(frame, "X", 34, 34)
  close:SetPoint("TOPRIGHT", -10, -10)
  close:SetScript("OnClick", function() frame:Hide() end)

  local contentHost = CreateFrame("Frame", nil, frame)
  contentHost:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 14, -88)
  contentHost:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 54)
  createScrollCanvas(contentHost)
  frame.contentHost = contentHost

  local header = createFont(frame, "GameFontNormalHuge", "Kaldo Tweaks", C.text)
  header:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 44, -24)
  local sub = createFont(frame, "GameFontHighlightSmall", "Modules, raccourcis et reglages d'affichage", C.muted)
  sub:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 2, -8)
  frame.headerTitle = header
  frame.headerSubtitle = sub

  local footer = addTexture(frame, { 0.120, 0.140, 0.145, 0.92 })
  footer:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 0, 0)
  footer:SetPoint("BOTTOMRIGHT", 0, 0)
  footer:SetHeight(42)

  local reset = makeButton(frame, (L and L.RESET_CONFIG) or "Reset config", 180, 28)
  reset:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 24, 8)
  reset:SetScript("OnClick", function()
    local name = UI.selectedModule
    local mod = name and Kaldo.modules[name]
    if mod and mod.ResetDB then
      mod:ResetDB()
      refreshModuleButton(name)
      selectModule(name)
    end
  end)

  local done = makeButton(frame, "Fermer", 160, 28)
  done:SetPoint("BOTTOMRIGHT", -18, 8)
  done:SetScript("OnClick", function() frame:Hide() end)

  UI.mainFrame = frame
  return frame
end

function UI:Open()
  if InCombatLockdown and InCombatLockdown() then
    self._pendingOpenStandalone = true
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r configuration queued until combat ends.")
    end
    return
  end
  local frame = createMainFrame()
  rebuildSidebar()
  frame:Show()
  frame:Raise()
end

function UI:RefreshModuleOptions(modName)
  refreshModuleButton(modName)
  local frame = self.mainFrame
  if frame and frame:IsShown() and self.selectedModule == modName then
    buildModuleOptionsOnCanvas(frame.contentHost, modName, Kaldo.modules[modName])
  end
end

local function RegisterSettingsPanels()
  if not Settings then return end
  applyClassTheme()

  local rootFrame = CreateFrame("Frame")
  local title = createFont(rootFrame, "GameFontNormalHuge", "Kaldo Tweaks", C.text)
  title:SetPoint("TOPLEFT", 24, -24)
  local desc = createFont(rootFrame, "GameFontHighlight", "La configuration complete s'ouvre dans une fenetre dediee plus lisible.", C.muted)
  desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
  local btn = makeButton(rootFrame, "Ouvrir Kaldo Tweaks", 220, 32)
  btn:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -24)
  btn:SetScript("OnClick", function() UI:Open() end)

  local rootCategory = Settings.RegisterCanvasLayoutCategory(rootFrame, "Kaldo Tweaks", "Kaldo tweaks")
  Settings.RegisterAddOnCategory(rootCategory)
  KALDO_CATEGORY_ID = rootCategory.ID
end

SLASH_KALDO1 = "/kaldo"
SLASH_KALDO2 = "/kaldotv"
SlashCmdList["KALDO"] = function()
  UI:Open()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    RegisterSettingsPanels()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and UI._pendingOpenStandalone then
    UI._pendingOpenStandalone = nil
    C_Timer.After(0, function() UI:Open() end)
  end
end)
