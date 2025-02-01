local table = require("__flib__.table")

local constants = require("constants")

local global_data = {}

function global_data.init()
  storage.forces = {}
  storage.players = {}
  storage.prototypes = {}
end

function global_data.build_prototypes()
  storage.forces = table.shallow_copy(game.forces)

  local new_prototypes = {}

  for key, filters in pairs(constants.prototypes.filtered_entities) do
    new_prototypes[key] = table.shallow_copy(prototypes.get_entity_filtered(filters))
  end
  for _, type in pairs(constants.prototypes.straight_conversions) do
    new_prototypes[type] = table.shallow_copy(prototypes[type])
  end

  storage.prototypes = new_prototypes
end

function global_data.update_sync_data()
  storage.sync_data = {
    active_mods = script.active_mods,
    settings = table.map(settings.startup, function(v)
      return v
    end),
  }
end

function global_data.add_force(force)
  table.insert(storage.forces, force)
end

return global_data
