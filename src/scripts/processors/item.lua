local table = require("__flib__.table")

local constants = require("constants")

local util = require("scripts.util")

local item_proc = {}

function item_proc.build(recipe_book, dictionaries, metadata)
  local modules = {}
  local place_as_equipment_results = {}
  local place_results = {}
  local rocket_launch_payloads = {}

  for name, prototype in pairs(global.prototypes.item) do
    -- Group
    local group = prototype.group
    local group_data = recipe_book.group[group.name]
    group_data.items[#group_data.items + 1] = { class = "item", name = name }
    -- Rocket launch products
    local launch_products = {}
    for i, product in ipairs(prototype.rocket_launch_products or {}) do
      -- Add to products table w/ amount string
      local amount_ident = util.build_amount_ident(product)
      launch_products[i] = {
        class = product.type,
        name = product.name,
        amount_ident = amount_ident,
      }
      -- Add to payloads table
      local product_payloads = rocket_launch_payloads[product.name]
      local ident = { class = "item", name = name }
      if product_payloads then
        product_payloads[#product_payloads + 1] = ident
      else
        rocket_launch_payloads[product.name] = { ident }
      end
    end
    local default_categories = util.unique_string_array(
      #launch_products > 0 and table.shallow_copy(metadata.rocket_silo_categories) or {}
    )

    local place_as_equipment_result = prototype.place_as_equipment_result
    if place_as_equipment_result then
      place_as_equipment_result = { class = "equipment", name = place_as_equipment_result.name }
      place_as_equipment_results[name] = place_as_equipment_result
    end

    local place_result = prototype.place_result
    if place_result then
      local class = constants.derived_type_to_class[place_result.type]
      if class and recipe_book[class][place_result.name] then
        place_result = { class = class, name = place_result.name }
        place_results[name] = place_result
      else
        place_result = nil
      end
    end

    local burnt_result = prototype.burnt_result
    if burnt_result then
      burnt_result = { class = "item", name = burnt_result.name }
    end

    local equipment_categories = util.unique_obj_array()
    local equipment = util.unique_obj_array()
    local equipment_grid = prototype.equipment_grid
    if equipment_grid then
      for _, equipment_category in pairs(equipment_grid.equipment_categories) do
        table.insert(equipment_categories, { class = "equipment_category", name = equipment_category })
        local category_data = recipe_book.equipment_category[equipment_category]
        if category_data then
          for _, equipment_name in pairs(category_data.equipment) do
            table.insert(equipment, equipment_name)
          end
        end
      end
    end

    local fuel_value = prototype.fuel_value
    local has_fuel_value = prototype.fuel_value > 0
    local fuel_acceleration_multiplier = prototype.fuel_acceleration_multiplier
    local fuel_emissions_multiplier = prototype.fuel_emissions_multiplier
    local fuel_top_speed_multiplier = prototype.fuel_top_speed_multiplier

    local module_effects = {}
    if prototype.type == "module" then
      -- Add to internal list of modules
      modules[name] = table.invert(prototype.limitations)
      -- Process effects
      for effect_name, effect in pairs(prototype.module_effects or {}) do
        module_effects[#module_effects + 1] = {
          type = "plain",
          label = effect_name .. "_bonus",
          value = effect.bonus,
          formatter = "percent",
        }
      end
      -- Process which crafters this module is compatible with
      for crafter_name, crafter_data in pairs(recipe_book.crafter) do
        local allowed_effects = metadata.allowed_effects[crafter_name]
        local compatible = true
        if allowed_effects then
          for effect_name in pairs(prototype.module_effects or {}) do
            if not allowed_effects[effect_name] then
              compatible = false
              break
            end
          end
        end
        if compatible then
          crafter_data.compatible_modules[#crafter_data.compatible_modules + 1] = { class = "item", name = name }
        end
      end
    end

    local fuel_category = util.convert_to_ident("fuel_category", prototype.fuel_category)
    if fuel_category then
      local items = recipe_book.fuel_category[fuel_category.name].items
      items[#items + 1] = { class = "item", name = name }
    end

    recipe_book.item[name] = {
      burned_in = {},
      burnt_result = burnt_result,
      burnt_result_of = {},
      class = "item",
      compatible_equipment = equipment,
      equipment_categories = equipment_categories,
      fuel_acceleration_multiplier = has_fuel_value
          and fuel_acceleration_multiplier ~= 1
          and fuel_acceleration_multiplier
        or nil,
      fuel_category = fuel_category,
      fuel_emissions_multiplier = has_fuel_value and fuel_emissions_multiplier ~= 1 and fuel_emissions_multiplier
        or nil,
      fuel_top_speed_multiplier = has_fuel_value and fuel_top_speed_multiplier ~= 1 and fuel_top_speed_multiplier
        or nil,
      fuel_value = has_fuel_value and fuel_value or nil,
      group = { class = "group", name = group.name },
      hidden = prototype.has_flag("hidden"),
      ingredient_in = {},
      mined_from = {},
      module_category = util.convert_to_ident("module_category", prototype.category),
      module_effects = module_effects,
      place_as_equipment_result = place_as_equipment_result,
      place_result = place_result,
      product_of = {},
      prototype_name = name,
      recipe_categories = default_categories,
      rocket_launch_product_of = {},
      rocket_launch_products = launch_products,
      researched_in = {},
      stack_size = prototype.stack_size,
      unlocked_by = util.unique_obj_array(),
    }
    dictionaries.item:add(name, prototype.localised_name)
    dictionaries.item_description:add(name, prototype.localised_description)
  end

  -- Add rocket launch payloads to their material tables
  for product, payloads in pairs(rocket_launch_payloads) do
    local product_data = recipe_book.item[product]
    product_data.rocket_launch_product_of = table.array_copy(payloads)
    for i = 1, #payloads do
      local payload = payloads[i]
      local payload_data = recipe_book.item[payload.name]
      local payload_unlocked_by = payload_data.unlocked_by
      for j = 1, #payload_unlocked_by do
        product_data.unlocked_by[#product_data.unlocked_by + 1] = payload_unlocked_by[j]
      end
    end
  end

  metadata.modules = modules
  metadata.place_as_equipment_results = place_as_equipment_results
  metadata.place_results = place_results
end

-- When calling the module directly, call fluid_proc.build
setmetatable(item_proc, {
  __call = function(_, ...)
    return item_proc.build(...)
  end,
})

return item_proc
