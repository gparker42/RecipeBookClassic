local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("constants")

local util = require("scripts.util")

local module_category = {}

function module_category.allowed_module_categories_for_crafter(prototype, metadata)
  -- GrP fixme correct to ignore allowed_effects?
  local allowed = {}
  for module_category_name, _ in pairs(prototype.allowed_module_categories or {}) do
    if metadata.all_module_categories[module_category_name] ~= nil then
      allowed[module_category_name] = true
    end
  end
  return allowed
end

function module_category.allowed_module_categories_for_recipe(prototype, metadata)
  -- GrP fixme is this logic correct?

  -- If allowed_module_categories is set, use it.
  if prototype.allowed_module_categories ~= nil then
    return prototype.allowed_module_categories
  end

  -- Otherwise allow all modules except for those disallowed in allowed_effects.
  local allowlist = table.shallow_copy(metadata.all_module_categories)
  for module_category_name, is_allowed in pairs(prototype.allowed_effects or {}) do
    if not is_allowed then
      allowlist[module_category_name] = nil
    end
  end
  return allowlist
end

function module_category.build(database, metadata)
  metadata.module_category = {}
  metadata.all_module_categories = {}

  for name, prototype in pairs(storage.prototypes.module_category) do
    local data = {
      module_names = {},
    }

    for module_name, module_prototype in pairs(storage.prototypes.item) do
      if module_prototype.type == "module" and module_prototype.category == name then
        data.module_names[#data.module_names + 1] = module_name
      end
    end

    metadata.module_category[name] = data

    -- this table is a substitute for recipe.allowed_module_categories
    -- when it is nil, because the default is all module categories
    metadata.all_module_categories[name] = true
  end

  -- Populate crafter.accepted_modules and metadata.crafter_module_categories.
  -- Character crafters never accept modules so skip them.
  metadata.crafter_module_categories = {}
  for crafter_name, crafter_prototype in pairs(storage.prototypes.crafter) do
    local crafter_data = database.entity[crafter_name]
    local categories = module_category.allowed_module_categories_for_crafter(crafter_prototype, metadata)
    metadata.crafter_module_categories[crafter_name] = categories
    for module_category_name, _ in pairs(categories) do
      for _, module_name in pairs(metadata.module_category[module_category_name].module_names) do
        crafter_data.accepted_modules[#crafter_data.accepted_modules + 1] = { class = "item", name = module_name }
      end
    end
  end
end


-- When calling the module directly, call module_category.build
setmetatable(module_category, {
  __call = function(_, ...)
    return module_category.build(...)
  end,
})

return module_category
