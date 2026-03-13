local _, NS = ...

local MacroUtils = {}
NS.MacroUtils = MacroUtils

function MacroUtils.NormalizeMacroName(name, fallback)
  if type(name) ~= "string" then
    name = fallback or ""
  end

  name = name:gsub("^%s+", ""):gsub("%s+$", "")
  if name == "" then
    name = fallback or ""
  end

  return string.sub(name, 1, 16)
end

function MacroUtils.CreateOrUpdateMacro(macroName, macroBody)
  local idx = GetMacroIndexByName and GetMacroIndexByName(macroName) or 0
  if idx and idx > 0 then
    if EditMacro then
      local okEdit = pcall(EditMacro, idx, macroName, nil, macroBody)
      if okEdit then
        return true, "updated"
      end
      return false, "EditMacro failed"
    end
    return false, "EditMacro unavailable"
  end

  if not CreateMacro then
    return false, "CreateMacro unavailable"
  end

  local icon = "INV_MISC_QUESTIONMARK"
  local perCharacter = 1
  local okCreate = pcall(CreateMacro, macroName, icon, macroBody, perCharacter)
  if okCreate then
    return true, "created"
  end
  return false, "CreateMacro failed"
end
