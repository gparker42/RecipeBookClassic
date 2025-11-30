local table = require("__flib__.table")

local util = require("scripts.util")

local item_proc = {}

function item_proc.build(database, metadata)
  local place_as_equipment_results = {}
  local place_results = {}
  local rocket_launch_payloads = {}

  for name, prototype in pairs(storage.prototypes.item) do
    -- Group
    local group = prototype.group
    local group_data = database.group[group.name]
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
    local default_categories =
      util.unique_string_array(#launch_products > 0 and table.shallow_copy(metadata.rocket_silo_categories) or {})

    local place_as_equipment_result = prototype.place_as_equipment_result
    if place_as_equipment_result then
      place_as_equipment_result = { class = "equipment", name = place_as_equipment_result.name }
      place_as_equipment_results[name] = place_as_equipment_result
    end

    -- Not all placement result entities are represented in database.entity[].
    -- place_result is a valid ident in the database, or nil
    -- blueprint_result may be missing from the database
    local blueprint_result = util.build_blueprint_result(prototype.place_result)
    local place_result = prototype.place_result
    if place_result and database.entity[place_result.name] then
      place_result = { class = "entity", name = place_result.name }
      place_results[name] = place_result
    else
      place_result = nil  -- not represented in the database
    end

    local burnt_result = prototype.burnt_result
    if burnt_result then
      burnt_result = { class = "item", name = burnt_result.name }
    end

    local spoil_result = prototype.spoil_result
    local spoil_time = nil
    if spoil_result then
      -- GrP fixme quality
      spoil_time = prototype.get_spoil_ticks()
      spoil_result = { class = "item", name = spoil_result.name }
    end

    -- GrP fixme plant result (spaceage gleba?)
    -- local plant_result = prototype.plant_result
    -- if plant_result then
    --   plant_result = { class = "item", name = plant_result.name }
    -- end

    local equipment_categories = util.unique_obj_array()
    local equipment = util.unique_obj_array()
    local equipment_grid = prototype.equipment_grid
    if equipment_grid then
      for _, equipment_category in pairs(equipment_grid.equipment_categories) do
        table.insert(equipment_categories, { class = "equipment_category", name = equipment_category })
        local category_data = database.equipment_category[equipment_category]
        if category_data then
          for _, equipment_ident in pairs(category_data.equipment) do
            table.insert(equipment, equipment_ident)
            local equipment_data = database.equipment[equipment_ident.name]
            if equipment_data then
              equipment_data.placed_in[#equipment_data.placed_in + 1] = { class = "item", name = name }
            end
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
      -- Process effects
      for effect_name, effect in pairs(prototype.module_effects or {}) do
        module_effects[#module_effects + 1] = {
          type = "plain",
          label = effect_name .. "_bonus",
          value = effect,
          formatter = "percent",
        }
      end
      -- Process which beacons this module is compatible with
      for beacon_name in pairs(storage.prototypes.beacon) do
        local beacon_data = database.entity[beacon_name]
        local allowed_effects = metadata.beacon_allowed_effects[beacon_name]
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
          beacon_data.accepted_modules[#beacon_data.accepted_modules + 1] = { class = "item", name = name }
        end
      end
      -- Process which crafters this module is compatible with
      -- GrP allowed_effects (beacons) and allowed_modules_categories (inserted modules) now differ
      -- for crafter_name in pairs(storage.prototypes.crafter) do
      --   local crafter_data = database.entity[crafter_name]
      --   local allowed_effects = metadata.allowed_effects[crafter_name]
      --   local compatible = true
      --   if allowed_effects then
      --     for effect_name in pairs(prototype.module_effects or {}) do
      --       if not allowed_effects[effect_name] then
      --         compatible = false
      --         break
      --       end
      --     end
      --   end
      --   if compatible then
      --     crafter_data.accepted_modules[#crafter_data.accepted_modules + 1] = { class = "item", name = name }
      --   end
      -- end
    end

    local fuel_category = util.convert_to_ident("fuel_category", prototype.fuel_category)
    if fuel_category then
      local items = database.fuel_category[fuel_category.name].items
      items[#items + 1] = { class = "item", name = name }
    end

    --- @class ItemData
    database.item[name] = {
      accepted_equipment = equipment,
      affects_recipes = {},
      blueprint_result = blueprint_result,
      burned_in = {},
      burnt_result = burnt_result,
      burnt_result_of = {},
      class = "item",
      enabled_at_start = metadata.gathered_from[name] and true or false,
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
      gathered_from = metadata.gathered_from[name],
      group = { class = "group", name = group.name },
      hidden = prototype.hidden,
      ingredient_in = {},
      item_type = { class = "item_type", name = prototype.type },
      mined_from = {},
      module_category = util.convert_to_ident("module_category", prototype.category),
      module_effects = module_effects,
      place_as_equipment_result = place_as_equipment_result,
      place_result = place_result,
      product_of = {},
      prototype_name = name,
      recipe_categories = default_categories,
      researched_in = {},
      rocket_launch_product_of = {},
      rocket_launch_products = launch_products,
      spoil_result = spoil_result,
      spoil_time = spoil_time,
      spoil_result_of = {},
      stack_size = prototype.stack_size,
      subgroup = { class = "group", name = prototype.subgroup.name },
      unlocked_by = util.unique_obj_array(),
    }
    util.add_to_dictionary("item", name, prototype.localised_name)
    util.add_to_dictionary("item_description", name, prototype.localised_description)
  end

  -- Add rocket launch payloads to their material tables
  for product, payloads in pairs(rocket_launch_payloads) do
    local product_data = database.item[product]
    product_data.rocket_launch_product_of = table.array_copy(payloads)
    for i = 1, #payloads do
      local payload = payloads[i]
      local payload_data = database.item[payload.name]
      local payload_unlocked_by = payload_data.unlocked_by
      for j = 1, #payload_unlocked_by do
        product_data.unlocked_by[#product_data.unlocked_by + 1] = payload_unlocked_by[j]
      end
    end
  end

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
