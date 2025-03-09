local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("constants")

local util = require("scripts.util")

return function(database, metadata)
  for name, prototype in pairs(storage.prototypes.technology) do
    local unlocks_equipment = util.unique_obj_array()
    local unlocks_fluids = util.unique_obj_array()
    local unlocks_items = util.unique_obj_array()
    local unlocks_entities = util.unique_obj_array()
    local unlocks_recipes = util.unique_obj_array()
    local research_ingredients_per_unit = {}

    -- Research units and ingredients per unit
    for _, ingredient in ipairs(prototype.research_unit_ingredients) do
      research_ingredients_per_unit[#research_ingredients_per_unit + 1] = {
        class = "item",  -- GrP fixme 2.x doesn't have item/fluid in the prototype?
        name = ingredient.name,
        amount_ident = util.build_amount_ident({ amount = ingredient.amount }),
      }
    end

    local research_unit_count
    local formula = prototype.research_unit_count_formula
    if not formula then
      research_unit_count = prototype.research_unit_count
    end

    -- Collect the list of science packs required by this technology's research.
    local science_packs = table.map(prototype.research_unit_ingredients, function(pack)
      return { class = "science_pack", name = pack.name }
    end)

    -- Collect the list of non-science-pack triggers required by this research.
    -- These objects might need to be crafted, mined, built, launched.
    -- GrP fixme quality, some of these have quality requirements
    local trigger_objects = table.map({ prototype.research_trigger }, function (trigger)
      local object
      if trigger.type == "craft-item"             then object = { class = "item",        name = trigger.item.name }
      elseif trigger.type == "mine-entity"        then object = { class = "entity_type", name = trigger.entity }
      elseif trigger.type == "craft-fluid"        then object = { class = "fluid",       name = trigger.fluid }
      elseif trigger.type == "build-entity"       then object = { class = "entity_type", name = trigger.entity.name }
      elseif trigger.type == "capture-spawner"    then object = { class = "entity_type", name = trigger.entity and trigger.entity.name or "unit-spawner" }
      elseif trigger.type == "send-item-to-orbit" then object = { class = "item",        name = trigger.item.name }
      -- GrP fixme create-space-platform
      end
      return object
    end)

    -- This technology unlocks recipes, materials, entities.
    -- Set their respective science pack requirements.

    -- GrP fixme need to include prerequisite technology costs to solve
    -- ## the "uranium problem" ##
    -- Unmodded uranium 235 is unlocked by Uranium Processing. Uranium Processing
    -- unlocks after mining some ore, which counts as 1 research ingredient.
    -- Thus it appears to be available soon based on a simple count of
    -- unresearched research ingredients. In reality Uranium Processing also
    -- requires Uranium Mining, and that requires three more science packs.
    -- Including prerequisite costs means that U-235 does not appear
    -- to be available soon at the start of the game.
    for _, modifier in ipairs(prototype.effects) do
      if modifier.type == "unlock-recipe" then
        local recipe_data = database.recipe[modifier.recipe]

        -- Check if the category should be ignored for recipe availability
        local disabled = constants.disabled_categories.recipe_category[recipe_data.recipe_category.name]
        if not disabled or disabled ~= 0 then
          -- Recipe
          recipe_data.researched_forces = recipe_data.researched_forces or {}
          recipe_data.unlocked_by[#recipe_data.unlocked_by + 1] = { class = "technology", name = name }
          unlocks_recipes[#unlocks_recipes + 1] = { class = "recipe", name = modifier.recipe }
          for _, product in pairs(recipe_data.products) do
            local product_name = product.name
            local product_data = database[product.class][product_name]
            local product_ident = { class = product_data.class, name = product_data.prototype_name }

            -- For "empty X barrel" recipes, do not unlock the fluid with the barreling recipe
            -- This is to avoid fluids getting "unlocked" when they are in reality still 100 hours away
            local is_empty_barrel_recipe = util.is_empty_barrel_recipe_name(modifier.recipe)
            if product_data.class ~= "fluid" or not is_empty_barrel_recipe then
              product_data.researched_forces = product_data.researched_forces or {}
              product_data.unlocked_by[#product_data.unlocked_by + 1] = { class = "technology", name = name }
            end

            -- Materials (products of the unlocked recipe)
            if product_data.class == "item" then
              unlocks_items[#unlocks_items + 1] = product_ident
            elseif product_data.class == "fluid" and not is_empty_barrel_recipe then
              unlocks_fluids[#unlocks_fluids + 1] = product_ident
            end

            -- Items (spoilage of the unlocked recipe's products)
            local spoil_result = product_data.spoil_result
            if spoil_result then
              local item_data = database.item[spoil_result.name]
              if item_data then
                item_data.researched_forces = item_data.researched_forces or {}
                item_data.unlocked_by[#item_data.unlocked_by + 1] = { class = "technology", name = name }
                unlocks_items[#unlocks_items + 1] = spoil_result
              end
            end

            -- Entities (products of the unlocked recipe that can be placed)
            local place_result = metadata.place_results[product_name]
            if place_result then
              local entity_data = database.entity[place_result.name]
              if entity_data then
                entity_data.researched_forces = entity_data.researched_forces or {}
                entity_data.unlocked_by[#entity_data.unlocked_by + 1] = { class = "technology", name = name }
                unlocks_entities[#unlocks_entities + 1] = place_result
              end
            end

            -- Equipment (products of the unlocked recipe that can be equipped)
            local place_as_equipment_result = metadata.place_as_equipment_results[product_name]
            if place_as_equipment_result then
              local equipment_data = database.equipment[place_as_equipment_result.name]
              if equipment_data then
                equipment_data.researched_forces = equipment_data.researched_forces or {}
                equipment_data.unlocked_by[#equipment_data.unlocked_by + 1] = { class = "technology", name = name }
                unlocks_equipment[#unlocks_equipment + 1] = place_as_equipment_result
              end
            end
          end
        end
      end
    end

    local level = prototype.level
    local max_level = prototype.max_level

    database.technology[name] = {
      class = "technology",
      contributes_research_ingredients_to = util.unique_obj_array(),
      hidden = prototype.hidden,
      max_level = max_level,
      min_level = level,
      prerequisite_of = {},
      prerequisites = {},
      prototype_name = name,
      researched_forces = {},
      research_ingredients_per_unit = research_ingredients_per_unit,
      research_unit_count_formula = formula,
      research_unit_count = research_unit_count,
      research_unit_energy = prototype.research_unit_energy / 60,
      unlocks_entities = unlocks_entities,
      unlocks_equipment = unlocks_equipment,
      unlocks_fluids = unlocks_fluids,
      unlocks_items = unlocks_items,
      unlocks_recipes = unlocks_recipes,
      upgrade = prototype.upgrade,
    }

    -- Assemble name
    local localised_name
    if level ~= max_level then
      localised_name = {
        "",
        prototype.localised_name,
        " (" .. level .. "-" .. (max_level == math.max_uint and "∞" or max_level) .. ")",
      }
    else
      localised_name = prototype.localised_name
    end

    util.add_to_dictionary("technology", prototype.name, localised_name)
    util.add_to_dictionary("technology_description", name, prototype.localised_description)
  end

  -- Generate prerequisites and prerequisite_of and contributes_research_ingredients_to
  for name, technology in pairs(database.technology) do
    local prototype = storage.prototypes.technology[name]

    if prototype.prerequisites then
      for prerequisite_name in pairs(prototype.prerequisites) do
        technology.prerequisites[#technology.prerequisites + 1] = { class = "technology", name = prerequisite_name }
        local prerequisite_data = database.technology[prerequisite_name]
        prerequisite_data.prerequisite_of[#prerequisite_data.prerequisite_of + 1] = {
          class = "technology",
          name = name,
        }
      end
    end

    -- other_tech in tech.contributes_research_ingredients_to[]
    -- means one of tech's unlocks is a research ingredient of other_tech
    for _, ingredient in ipairs(prototype.research_unit_ingredients) do
      local ingredient_data = database.item[ingredient.name]
      for _, contributor_ident in pairs(ingredient_data.unlocked_by) do
        local contributor_data = database.technology[contributor_ident.name]
        contributor_data.contributes_research_ingredients_to[#contributor_data.contributes_research_ingredients_to + 1] = { class = "technology", name = name }
      end
    end
  end
end
