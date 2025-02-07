local table = require("__flib__.table")

local util = require("scripts.util")

local fluid_proc = require("scripts.database.fluid")

return function(database, metadata)
  metadata.gathered_from = {}

  --- @type table<string, LuaEntityPrototype>
  local prototypes = storage.prototypes.entity
  for name, prototype in pairs(prototypes) do
    local equipment_categories = util.unique_obj_array()
    local equipment = util.unique_obj_array()
    local equipment_grid = prototype.grid_prototype
    if equipment_grid then
      for _, equipment_category in pairs(equipment_grid.equipment_categories) do
        table.insert(equipment_categories, { class = "equipment_category", name = equipment_category })
        local category_data = database.equipment_category[equipment_category]
        if category_data then
          for _, equipment_name in pairs(category_data.equipment) do
            table.insert(equipment, equipment_name)
          end
        end
      end
    end

    local fuel_categories, fuel_filter = util.process_energy_source(prototype)

    local expected_resources
    local mineable = prototype.mineable_properties
    if
      mineable
      and mineable.minable
      and mineable.products
      and #mineable.products > 0
      and mineable.products[1].name ~= name
    then
      expected_resources = table.map(mineable.products, function(product)
        if not metadata.gathered_from[product.name] then
          metadata.gathered_from[product.name] = {}
        end
        table.insert(metadata.gathered_from[product.name], { class = "entity", name = name })
        return { class = product.type, name = product.name, amount_ident = util.build_amount_ident(product) }
      end)
    end

    -- Boilers don't have recipes.
    -- Do recipe-like things with them here.
    -- * boiler entity gets ingredients / products
    -- * fluids get ingredient_in / product of
    -- * fluid temperatures
    -- * boiler entity gets input_fluid / output_fluid
    local input_fluid, output_fluid
    local ingredients, products
    if prototype.type == "boiler" then
      local input_fluidbox, output_fluidbox

      -- input and output identity depends on boiler mode
      for _, fluidbox in ipairs(prototype.fluidbox_prototypes) do
        if fluidbox.production_type == "input-output" then
          input_fluidbox = fluidbox
          if prototype.boiler_mode == "heat-fluid-inside" then
            output_fluidbox = fluidbox
            break
          end
        elseif fluidbox.production_type == "input" then
          input_fluidbox = fluidbox
        elseif fluidbox.production_type == "output" then
          if prototype.boiler_mode == "output-to-separate-pipe" then
            output_fluidbox = fluidbox
          end
        end
      end

      if input_fluidbox and output_fluidbox then
        -- add output fluid at boiler's target temperature
        -- and input fluid at boiler's input temperature range

        local input_temp_ident = util.build_temperature_ident({ minimum_temperature = input_fluidbox.minimum_temperature, maximum_temperature = input_fluidbox.maximum_temperature })
        local output_temp_ident = util.build_temperature_ident({ temperature = prototype.target_temperature })

        -- input fluid may or may not have temperature
        local input_base_fluid_name = input_fluidbox.filter.name
        local input_fluid_name = input_base_fluid_name
        if input_fluid_ident then
          fluid_proc.add_temperature(database.fluid[input_base_fluid_name], input_temp_ident)
          input_fluid_name = input_base_fluid_name .. "." .. input_temp_ident.string
        end

        -- output fluid always has a temperature
        local output_base_fluid_name = output_fluidbox.filter.name
        local output_fluid_name = output_base_fluid_name .. "." .. output_temp_ident.string
        fluid_proc.add_temperature(database.fluid[output_base_fluid_name], output_temp_ident)

        input_fluid  = {
          class = "fluid",
          name = input_fluid_name,
        }
        output_fluid = {
          class = "fluid",
          name = output_fluid_name,
        }
        ingredients = {{
          class = "fluid",
          name = input_base_fluid_name,
          temperature_ident = input_temp_ident,
        }}
        products = {{
          class = "fluid",
          name = output_base_fluid_name,
          temperature_ident = output_temp_ident,
        }}

        -- input fluid is an ingredient_in boiler
        -- output fluid is a product_of boiler
        local ingredient_in = database.fluid[input_base_fluid_name].ingredient_in
        ingredient_in[#ingredient_in + 1] = { class = "entity", name = name }
        local product_of = database.fluid[output_base_fluid_name].product_of
        product_of[#product_of + 1] = { class = "entity", name = name }
      end
    end

    database.entity[name] = {
      accepted_equipment = equipment,
      blueprint_result = util.build_blueprint_result(prototype),
      can_burn = {},
      class = "entity",
      enabled_at_start = expected_resources and true or false, -- FIXME: This is inaccurate
      entity_type = { class = "entity_type", name = prototype.type },
      equipment_categories = equipment_categories,
      expected_resources = expected_resources,
      fuel_categories = fuel_categories,
      fuel_filter = fuel_filter,
      input_fluid = input_fluid,
      ingredients = ingredients,
      output_fluid = output_fluid,
      products = products,
      module_slots = prototype.module_inventory_size
          and prototype.module_inventory_size > 0
          and prototype.module_inventory_size
        or nil,
      placed_by = util.process_placed_by(prototype),
      prototype_name = name,
      science_packs = {},
      unlocked_by = {},
    }

    util.add_to_dictionary("entity", name, prototype.localised_name)
    util.add_to_dictionary("entity_description", name, prototype.localised_description)
  end
end
