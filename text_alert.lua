local _, NS = ...

local TextAlert = {}
NS.TextAlert = TextAlert

local function playSoundSafe(soundKitID)
  local sid = tonumber(soundKitID)
  if not sid or sid <= 0 then
    return
  end

  pcall(PlaySound, sid, "Master")
end

function TextAlert:Create(frameStrata)
  local frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(1, 1)
  frame:SetFrameStrata(frameStrata or "HIGH")
  frame:Hide()

  local fontString = frame:CreateFontString(nil, "OVERLAY")
  fontString:SetPoint("CENTER", UIParent, "CENTER")

  return {
    frame = frame,
    fontString = fontString,
    hideToken = 0,
  }
end

function TextAlert:Apply(controller, config)
  if not controller or not controller.frame or not controller.fontString or type(config) ~= "table" then
    return
  end

  local flags = config.outline
  if flags == "NONE" then
    flags = nil
  end

  controller.frame:ClearAllPoints()
  controller.frame:SetPoint("CENTER", UIParent, "CENTER", config.x or 0, config.y or 170)

  controller.fontString:SetFont(config.font or "Fonts\\FRIZQT__.TTF", config.fontSize or 72, flags)

  local color = config.color or { 1, 1, 1, 1 }
  controller.fontString:SetTextColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
  controller.fontString:SetText(config.text or "")

  if config.shadow then
    local shadowColor = config.shadowColor or { 0, 0, 0, 1 }
    controller.fontString:SetShadowColor(
      shadowColor[1] or 0,
      shadowColor[2] or 0,
      shadowColor[3] or 0,
      shadowColor[4] or 1
    )
    controller.fontString:SetShadowOffset(config.shadowX or 1, config.shadowY or -1)
  else
    controller.fontString:SetShadowColor(0, 0, 0, 0)
    controller.fontString:SetShadowOffset(0, 0)
  end
end

function TextAlert:Hide(controller)
  if not controller or not controller.frame then
    return
  end

  controller.hideToken = (controller.hideToken or 0) + 1
  controller.frame:Hide()
end

function TextAlert:Show(controller, config)
  if not controller or not controller.frame then
    return
  end

  self:Apply(controller, config)
  controller.frame:Show()

  if config and config.playSound then
    playSoundSafe(config.soundKit)
  end

  local duration = tonumber(config and config.duration) or 0
  if duration > 0 then
    controller.hideToken = (controller.hideToken or 0) + 1
    local token = controller.hideToken
    C_Timer.After(duration, function()
      if controller.hideToken == token and controller.frame then
        controller.frame:Hide()
      end
    end)
  end
end
