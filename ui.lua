-- ui.lua (Retail 12.0.1) - Blizzard Settings panels, rebuild à chaque affichage
local ADDON_NAME, NS = ...
local Kaldo = NS.Kaldo

local L = NS.L

local KALDO_CATEGORY_ID
local UI = { _sid = 0, _did = 0 }
UI._modulePanels = {}
NS.UI = UI

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
  local out = {
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 0, "IG_MAINMENU_OPEN" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE or 0, "IG_MAINMENU_CLOSE" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 0, "CHECKBOX_ON" },
    { SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF or 0, "CHECKBOX_OFF" },
  }
  if C_Sound and C_Sound.GetSoundKitName then
    for _, id in ipairs({ 0 }) do end -- placeholder, on garde un set safe par défaut
  end
  return out
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

  return nil -- important: ne cache pas nil
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
  for part in key:gmatch("[^%.]+") do
    parts[#parts + 1] = part
  end
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

-- ---- UI builders
local function addHeader(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  fs:SetPoint("TOPLEFT", x, -y)
  fs:SetText(text or "")
  return fs, y + 32
end

local function addLabel(parent, text, x, y)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, -y)
  fs:SetText(text or "")
  return fs
end

local function addToggle(parent, label, value, onChanged, x, y)
  local b = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  b:SetPoint("TOPLEFT", x, -y)
  b.Text:SetText(label or "")
  b:SetChecked(not not value)
  b:SetScript("OnClick", function(self) onChanged(self:GetChecked()) end)
  return b, y + 26
end

local function addEdit(parent, label, value, onChanged, x, y, w)
  addLabel(parent, label or "", x, y)
  local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  eb:SetSize(w or 280, 20)
  eb:SetPoint("TOPLEFT", x + 220, -y - 4)
  eb:SetAutoFocus(false)
  eb:SetText(value or "")
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus(); onChanged(self:GetText()) end)
  eb:SetScript("OnEditFocusLost", function(self) onChanged(self:GetText()) end)
  return eb, y + 30
end

local function addSlider(parent, label, value, minv, maxv, step, onChanged, x, y, w)
  addLabel(parent, label or "", x, y)
  UI._sid = UI._sid + 1
  local s = CreateFrame("Slider", "KaldoUISlider"..UI._sid, parent, "OptionsSliderTemplate")
  s:SetWidth(w or 280)
  s:SetPoint("TOPLEFT", x + 220, -y - 10)
  s:SetMinMaxValues(minv or 0, maxv or 100)
  s:SetValueStep(step or 1)
  s:SetObeyStepOnDrag(true)
  s.Low:SetText(tostring(minv or 0))
  s.High:SetText(tostring(maxv or 100))
  local initial = value
  if initial == nil then initial = minv or 0 end
  s:SetValue(initial)
  s.Text:SetText(tostring(initial))
  s:SetScript("OnValueChanged", function(self, v)
    local st = step or 1
    v = math.floor((v / st) + 0.5) * st
    self.Text:SetText(tostring(v))
    onChanged(v)
  end)
  return s, y + 44
end


local function addButton(parent, label, onClick, x, y, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 180, 22)
    b:SetPoint("TOPLEFT", x + 220, -y)
    b:SetText(label or "Button")
    b:SetScript("OnClick", onClick)
    return b, y + 30
end

local function addDropdown(parent, label, value, values, onChanged, x, y, w, isTree)
  addLabel(parent, label or "", x, y + 14)
  UI._did = UI._did + 1
  local dd = CreateFrame("Frame", "KaldoUIDropdown"..UI._did, parent, "UIDropDownMenuTemplate")
  dd:SetPoint("TOPLEFT", x + 205, -y - 6)
  UIDropDownMenu_SetWidth(dd, w or 240)

  local function setTextFor(val)
    local txt = tostring(val)
    for _, it in ipairs(values or {}) do
      if it[1] == val then txt = it[2] end
    end
    UIDropDownMenu_SetText(dd, txt)
  end


    UIDropDownMenu_Initialize(dd, function(_, level)
        level = level or 1
        if isTree then
            local tree = Kaldo.Media:GetCDMSoundTree()
            if not tree then return end

            if level == 1 then
            local cats = {}
            for cat,_ in pairs(tree) do cats[#cats+1] = cat end
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
    end
  return dd, y + 44
end

local function rgbaToObj(rgba)
  local r,g,b,a = 1,1,1,1
  if type(rgba) == "table" then
    r,g,b,a = rgba[1] or 1, rgba[2] or 1, rgba[3] or 1, rgba[4]
    if a == nil then a = 1 end
  end
  return r,g,b,a
end

local function applySwatch(tex, rgba)
  local r,g,b,a = rgbaToObj(rgba)
  tex:SetColorTexture(r,g,b,a)
end

local function addColorPicker(parent, label, rgba, onChanged, x, y, w)
  addLabel(parent, label or "", x, y)

  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(w or 180, 22)
  btn:SetPoint("TOPLEFT", x + 220, -y)
  btn:SetText("Choisir")

  local swatch = btn:CreateTexture(nil, "OVERLAY")
  swatch:SetSize(16, 16)
  swatch:SetPoint("LEFT", btn, "RIGHT", 8, 0)
  applySwatch(swatch, rgba)

  btn:SetScript("OnClick", function()
    local r,g,b,a = rgbaToObj(rgba)
    local prev = { r=r, g=g, b=b, a=a }

    local function set(rr, gg, bb, aa)
      rgba = { rr, gg, bb, aa or 1 }
      applySwatch(swatch, rgba)
      onChanged(rgba)
    end

    ColorPickerFrame:SetupColorPickerAndShow({
      r=r, g=g, b=b,
      hasOpacity=true,
      opacity=1-a,
      swatchFunc=function()
        local rr,gg,bb = ColorPickerFrame:GetColorRGB()
        local aa = 1 - (ColorPickerFrame:GetColorAlpha() or 0)
        set(rr,gg,bb,aa)
      end,
      opacityFunc=function()
        local rr,gg,bb = ColorPickerFrame:GetColorRGB()
        local aa = 1 - (ColorPickerFrame:GetColorAlpha() or 0)
        set(rr,gg,bb,aa)
      end,
      cancelFunc=function()
        set(prev.r, prev.g, prev.b, prev.a)
      end,
    })
  end)

  return btn, y + 30
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

local function clearCanvas(frame)
  if frame._children then for _, c in ipairs(frame._children) do c:Hide() end end
  frame._children = {}
  if frame._content then
    for _, r in ipairs({ frame._content:GetRegions() }) do
      if r and r.GetObjectType and r:GetObjectType() == "FontString" then r:Hide() end
    end
  end
end

local function addChild(frame, widget)
  frame._children = frame._children or {}
  table.insert(frame._children, widget)
end

local function attachTooltip(widget, text)
  if not widget or not text or text == "" then return end
  if widget.EnableMouse then
    widget:EnableMouse(true)
  end
  if type(widget.HookScript) ~= "function" then return end
  widget:HookScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    if GameTooltip.ClearLines then GameTooltip:ClearLines() end
    if GameTooltip.AddLine then
      GameTooltip:AddLine(text, 1, 1, 1, true)
    else
      GameTooltip:SetText(text)
    end
    GameTooltip:Show()
  end)
  widget:HookScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
end

local function buildModuleOptionsOnCanvas(canvasFrame, modName, mod)
  clearCanvas(canvasFrame)
  local content = canvasFrame._content or createScrollCanvas(canvasFrame)

  local db = ensureModuleDB(modName, mod)
  local opts = (mod and mod.GetOptions and mod:GetOptions()) or {}

  local title = (mod.GetDisplayName and mod:GetDisplayName())
            or mod.displayName
            or modName

  local injected = {
    { type="header", text=title },
    { type="toggle", key="enabled", label=L.ENABLE_MODULE },
  }
  if mod and mod.ResetDB then
    injected[#injected + 1] = {
      type = "button",
      label = (L and L.RESET_CONFIG) or "Reset config",
      onClick = function()
        mod:ResetDB()
        C_Timer.After(0, function()
          buildModuleOptionsOnCanvas(canvasFrame, modName, mod)
        end)
      end,
    }
  end
  for _, o in ipairs(opts) do injected[#injected+1] = o end
  opts = injected

  local y, x = 10, 16
  local firstHeaderSeen = false
  for _, opt in ipairs(opts) do
    local optValue = getOptionValue(db, opt.key)
    if opt.getValue then
      optValue = opt.getValue(db, mod)
    end

    local function applyOptionValue(v)
      if opt.setValue then
        opt.setValue(v, db, mod)
      else
        setOptionValue(db, opt.key, v)
      end
      if mod and mod.OnOptionChanged then mod:OnOptionChanged(opt.key, v) end
      if opt.key == "enabled" and Kaldo and Kaldo.RefreshEventSubscriptions then
        Kaldo:RefreshEventSubscriptions()
      end
    end

    local tooltip = opt.tooltip
    if type(tooltip) == "function" then
      tooltip = tooltip()
    end

    if opt.type == "header" then
      if firstHeaderSeen then
        y = y + 12
      end
      local _, ny = addHeader(content, opt.text or modName, x, y); y = ny
      firstHeaderSeen = true
    elseif opt.type == "toggle" then
      local w; w, y = addToggle(content, opt.label, optValue, function(v)
        applyOptionValue(v)
      end, x, y)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "input" then
      local w; w, y = addEdit(content, opt.label, optValue, function(v)
        applyOptionValue(v)
      end, x, y, 280)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "number" then
      local minv = opt.min
      local maxv = opt.max
      if type(minv) == "function" then minv = minv() end
      if type(maxv) == "function" then maxv = maxv() end
      local w; w, y = addSlider(content, opt.label, optValue, minv, maxv, opt.step, function(v)
        applyOptionValue(v)
      end, x, y, 280)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "select" then
        local values = opt.values
        if type(values) == "function" then values = values() end
        local isTree = (opt.valuesTree == true)

        local w
        w, y = addDropdown(content, opt.label, optValue, values, function(v)
            applyOptionValue(v)
        end, x, y, 240, isTree)

    attachTooltip(w, tooltip)
    addChild(canvasFrame, w)
    elseif opt.type == "color" then
      local w; w, y = addColorPicker(content, opt.label, getOptionValue(db, opt.key), function(v)
        setOptionValue(db, opt.key, v)
        if mod and mod.OnOptionChanged then mod:OnOptionChanged(opt.key, v) end
      end, x, y, 180)
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "label" then
      local w = addLabel(content, opt.text or "", x, y)
      y = y + 20
      attachTooltip(w, tooltip)
      addChild(canvasFrame, w)
    elseif opt.type == "button" then
    local w; w, y = addButton(content, opt.label, function()
        if opt.onClick then opt.onClick(mod, db) end
    end, x, y, 180)
    attachTooltip(w, tooltip)
    addChild(canvasFrame, w)
    end
    if opt.key == "enabled" then
      y = y + 18
    end
  end

  content:SetHeight(y + 40)
end

local function RegisterSettingsPanels()
  if not Settings then return end

  local rootFrame = CreateFrame("Frame")
  local rootCategory = Settings.RegisterCanvasLayoutCategory(rootFrame, "Kaldo Tweaks", "Kaldo tweaks")
  Settings.RegisterAddOnCategory(rootCategory)
  KALDO_CATEGORY_ID = rootCategory.ID

  for modName, mod in pairs(Kaldo.modules or {}) do
    local name, m = modName, mod
    local subFrame = CreateFrame("Frame")
    createScrollCanvas(subFrame)

    local function BuildWhenReady()
      if not subFrame:IsShown() then return end
      if (subFrame:GetWidth() or 0) < 10 then return end
      local now = GetTime()
      if subFrame.__lastBuild and (now - subFrame.__lastBuild) < 0.2 then return end
      subFrame.__lastBuild = now
      buildModuleOptionsOnCanvas(subFrame, name, m)
    end

    UI._modulePanels[name] = {
      frame = subFrame,
      rebuild = BuildWhenReady,
    }

    subFrame:SetScript("OnShow", function()
      C_Timer.After(0, BuildWhenReady)
    end)
    subFrame:SetScript("OnSizeChanged", function()
      C_Timer.After(0, BuildWhenReady)
    end)

    local title = (m.GetDisplayName and m:GetDisplayName()) or m.displayName or name
    local sub = Settings.RegisterCanvasLayoutSubcategory(rootCategory, subFrame, title, title)
    Settings.RegisterAddOnCategory(sub)
  end
end

function UI:RefreshModuleOptions(modName)
  local entry = self._modulePanels and self._modulePanels[modName]
  if not entry or not entry.frame or not entry.rebuild then return end
  if not entry.frame:IsShown() then return end
  C_Timer.After(0, entry.rebuild)
end

SLASH_KALDO1 = "/kaldo"
SlashCmdList["KALDO"] = function()
  if InCombatLockdown and InCombatLockdown() then
    UI._pendingOpenRootCategory = true
    if DEFAULT_CHAT_FRAME then
      DEFAULT_CHAT_FRAME:AddMessage("|cff7fd1ffKaldo Tweaks:|r settings queued until combat ends.")
    end
    return
  end
  if Settings and Settings.OpenToCategory and KALDO_CATEGORY_ID then
    Settings.OpenToCategory(KALDO_CATEGORY_ID)
  end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    RegisterSettingsPanels()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" and UI._pendingOpenRootCategory then
    UI._pendingOpenRootCategory = nil
    if Settings and Settings.OpenToCategory and KALDO_CATEGORY_ID then
      C_Timer.After(0, function()
        Settings.OpenToCategory(KALDO_CATEGORY_ID)
      end)
    end
  end
end)
