local util = require("scripts.util")

return function(database)
  for name, prototype in pairs(storage.prototypes.generator) do
    local fluid_box = prototype.fluidbox_prototypes[1]
    local can_burn = {}
    local fuel_categories = {}
    if fluid_box.filter then
      can_burn = { { class = "fluid", name = fluid_box.filter.name } }
    else
      fuel_categories = { { class = "fuel_category", name = "burnable-fluid" } }
    end

    -- GrP fixme multiple pollution types
    local pollution = nil
    if prototype.emissions_per_second and prototype.emissions_per_second["pollution"] and prototype.emissions_per_second["pollution"] > 0 then
      pollution = prototype.emissions_per_second["pollution"]
    end
    database.entity[name] = {
      base_pollution = pollution, -- prototype.emissions_per_second > 0 and prototype.emissions_per_second or nil,
      blueprint_result = util.build_blueprint_result(prototype),
      can_burn = can_burn,
      class = "entity",
      entity_type = { class = "entity_type", name = prototype.type },
      fluid_consumption = prototype.fluid_usage_per_tick * 60,
      fuel_categories = fuel_categories,
      -- GrP fixme quality
      max_energy_production = prototype.get_max_energy_production(),
      maximum_temperature = prototype.maximum_temperature,
      minimum_temperature = fluid_box.minimum_temperature,
      placed_by = util.process_placed_by(prototype),
      prototype_name = name,
      unlocked_by = {},
    }

    util.add_to_dictionary("entity", name, prototype.localised_name)
    util.add_to_dictionary("entity_description", name, prototype.localised_description)
  end
end
