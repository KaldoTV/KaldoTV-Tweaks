local ADDON_NAME, NS = ...

local DB = {}
NS.DB = DB

DB.CURRENT_SCHEMA_VERSION = 1

local migrations = {}

local function copyTable(value)
  if type(value) ~= "table" then
    return value
  end

  local out = {}
  for key, inner in pairs(value) do
    out[key] = copyTable(inner)
  end
  return out
end

function DB:ApplyDefaults(target, defaults)
  if type(target) ~= "table" or type(defaults) ~= "table" then
    return target
  end

  for key, value in pairs(defaults) do
    if target[key] == nil then
      target[key] = copyTable(value)
    elseif type(target[key]) == "table" and type(value) == "table" then
      self:ApplyDefaults(target[key], value)
    end
  end

  return target
end

function DB:GetAddonVersion()
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version")
  end
  if GetAddOnMetadata then
    return GetAddOnMetadata(ADDON_NAME, "Version")
  end
  return nil
end

function DB:EnsureRoot()
  KaldoDB = KaldoDB or {}

  if type(KaldoDB) ~= "table" then
    KaldoDB = {}
  end

  if KaldoDB.enabled == nil then
    KaldoDB.enabled = true
  end

  if type(KaldoDB.modules) ~= "table" then
    KaldoDB.modules = {}
  end

  return KaldoDB
end

function DB:EnsureModuleDB(moduleName)
  local root = self:EnsureRoot()
  root.modules[moduleName] = root.modules[moduleName] or {}

  local moduleDB = root.modules[moduleName]
  if moduleDB.enabled == nil then
    moduleDB.enabled = false
  end

  return moduleDB
end

function DB:EnsureModuleState(moduleName, defaults)
  local moduleDB = self:EnsureModuleDB(moduleName)
  if type(defaults) == "table" then
    self:ApplyDefaults(moduleDB, defaults)
  end
  return moduleDB
end

function DB:ResetModuleDB(moduleName, keepEnabled)
  local root = self:EnsureRoot()
  local previous = root.modules[moduleName]

  if keepEnabled == nil and type(previous) == "table" then
    keepEnabled = previous.enabled
  end

  root.modules[moduleName] = {}
  local moduleDB = root.modules[moduleName]
  if keepEnabled ~= nil then
    moduleDB.enabled = keepEnabled
  else
    moduleDB.enabled = false
  end

  return moduleDB, previous
end

function DB:ResetModuleState(moduleName, defaults, keepEnabled)
  local moduleDB = self:ResetModuleDB(moduleName, keepEnabled)
  if type(defaults) == "table" then
    self:ApplyDefaults(moduleDB, defaults)
  end
  return moduleDB
end

migrations[1] = function(db)
  if type(db.enabled) ~= "boolean" then
    db.enabled = true
  end

  if type(db.modules) ~= "table" then
    db.modules = {}
  end

  for moduleName, moduleDB in pairs(db.modules) do
    if type(moduleName) ~= "string" or type(moduleDB) ~= "table" then
      db.modules[moduleName] = nil
    elseif moduleDB.enabled == nil then
      moduleDB.enabled = false
    end
  end
end

function DB:RunMigrations()
  local db = self:EnsureRoot()
  local fromVersion = tonumber(db.schema_version) or 0

  while fromVersion < self.CURRENT_SCHEMA_VERSION do
    local nextVersion = fromVersion + 1
    local migrate = migrations[nextVersion]
    if type(migrate) == "function" then
      migrate(db)
    end
    db.schema_version = nextVersion
    fromVersion = nextVersion
  end

  db.last_seen_addon_version = self:GetAddonVersion()
  return db
end
