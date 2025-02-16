local bounding_box = require("__flib__.bounding-box")
local dictionary = require("__flib__.dictionary")
local format = require("__flib__.format")
local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("constants")

local core_util = require("__core__.lualib.util")

local util = {}

--- @return AmountIdent
function util.build_amount_ident(input)
  --- @class AmountIdent
  return {
    amount = input.amount or false,
    amount_min = input.amount_min or false,
    amount_max = input.amount_max or false,
    catalyst_amount = input.catalyst_amount or false,
    probability = input.probability or false,
    format = input.format or "format_amount",
  }
end

-- HACK: Requiring `formatter` in this file causes a dependency loop
local function format_number(value)
  return format.number(math.round(value, 0.01))
end

--- @class TemperatureIdent
--- @field string string
--- @field short_string string
--- @field min double
--- @field max double

--- Builds a `TemperatureIdent` based on the fluid input/output parameters.
function util.build_temperature_ident(fluid)
  -- factorio 1.x uses C's +/- DBL_MAX
  -- factorio 2.0 uses C's +/- FLT_MAX
  -- Here for robustness we clamp everything to the float range
  -- assuming that anything beyond float range is not a real temperature.
  local max_temp =  0X1.FFFFFEP+127  -- (FLT_MAX)
  local min_temp = -0X1.FFFFFEP+127  -- (-FLT_MAX)

  local temperature = fluid.temperature
  local minimum_temperature = fluid.minimum_temperature or min_temp
  local maximum_temperature = fluid.maximum_temperature or max_temp
  local temperature_string
  local short_temperature_string
  local short_top_string

  if temperature then
    temperature_string = format_number(temperature)
    short_temperature_string = core_util.format_number(temperature, true)
    minimum_temperature = temperature
    maximum_temperature = temperature
  elseif not fluid.minimum_temperature and not fluid.maximum_temperature then
    -- no temperature specified
    temperature_string = nil
  elseif minimum_temperature <= min_temp then
    temperature_string = "≤" .. format_number(maximum_temperature)
    short_temperature_string = "≤" .. core_util.format_number(maximum_temperature, true)
  elseif maximum_temperature >= max_temp then
    temperature_string = "≥" .. format_number(minimum_temperature)
    short_temperature_string = "≥" .. core_util.format_number(minimum_temperature, true)
  else
    temperature_string = "" .. format_number(minimum_temperature) .. "-" .. format_number(maximum_temperature)
    short_temperature_string = core_util.format_number(minimum_temperature, true)
    short_top_string = core_util.format_number(maximum_temperature, true)
  end

  if temperature_string then
    return {
      string = temperature_string,
      short_string = short_temperature_string,
      short_top_string = short_top_string,
      min = minimum_temperature,
      max = maximum_temperature,
    }
  end
end

--- Get the "sorting number" of a temperature. Will sort in ascending order, with absolute, then min range, then max range.
--- @param temperature_ident TemperatureIdent
function util.get_sorting_number(temperature_ident)
  -- see build_temperature_ident() for a description of these values
  local max_temp =  0X1.FFFFFEP+127  -- (FLT_MAX)
  local min_temp = -0X1.FFFFFEP+127  -- (-FLT_MAX)
  if temperature_ident.min <= min_temp then
    return temperature_ident.max + 0.001
  elseif temperature_ident.max >= max_temp then
    return temperature_ident.min + 0.003
  elseif temperature_ident.min ~= temperature_ident.max then
    return temperature_ident.min + 0.002
  else
    return temperature_ident.min
  end
end

function util.convert_and_sort(tbl)
  for key in pairs(tbl) do
    tbl[#tbl + 1] = key
  end
  table.sort(tbl)
  return tbl
end

function util.unique_string_array(initial_tbl)
  initial_tbl = initial_tbl or {}
  local hash = {}
  for _, value in pairs(initial_tbl) do
    hash[value] = true
  end
  return setmetatable(initial_tbl, {
    __newindex = function(tbl, key, value)
      if not hash[value] then
        hash[value] = true
        rawset(tbl, key, value)
      end
    end,
  })
end

function util.unique_obj_array(initial_tbl)
  local hash = {}
  return setmetatable(initial_tbl or {}, {
    __newindex = function(tbl, key, value)
      if not hash[value.name] then
        hash[value.name] = true
        rawset(tbl, key, value)
      end
    end,
  })
end

function util.frame_action_button(sprite, tooltip, ref, action)
  -- Use "sprite_white" and "sprite_black" if available,
  -- otherwise fall back to just "sprite".
  -- Some builtin sprites in factorio-2.0 like "utility/search"
  -- no longer come in explicit _white and _black forms.
  local white = sprite .. "_white"
  local black = sprite .. "_black"
  local sprite_white = helpers.is_valid_sprite_path(white) and white or sprite
  local sprite_black = helpers.is_valid_sprite_path(black) and black or sprite

  return {
    type = "sprite-button",
    style = "frame_action_button",
    sprite = sprite_white,
    hovered_sprite = sprite_black,
    clicked_sprite = sprite_black,
    tooltip = tooltip,
    mouse_button_filter = { "left" },
    ref = ref,
    actions = {
      on_click = action,
    },
  }
end

function util.process_placed_by(prototype)
  local placed_by = prototype.items_to_place_this
  if placed_by then
    return table.map(placed_by, function(item_stack)
      return {
        class = "item",
        name = item_stack.name,
        amount_ident = util.build_amount_ident({ amount = item_stack.count }),
      }
    end)
  end
end

function util.convert_categories(source_tbl, class)
  local categories = {}
  for category in pairs(source_tbl) do
    categories[#categories + 1] = { class = class, name = category }
  end
  return categories
end

function util.convert_to_ident(class, source)
  if source then
    return { class = class, name = source }
  end
end

--- @param prototype LuaEntityPrototype
--- @return DisplayResolution?
function util.get_size(prototype)
  if prototype.selection_box then
    local box = prototype.selection_box
    return { height = math.ceil(bounding_box.height(box)), width = math.ceil(bounding_box.width(box)) }
  end
end

--- @param prototype LuaEntityPrototype
function util.process_energy_source(prototype)
  local burner = prototype.burner_prototype
  local fluid_energy_source = prototype.fluid_energy_source_prototype
  if burner then
    return util.convert_categories(burner.fuel_categories, "fuel_category")
  elseif fluid_energy_source then
    local filter = fluid_energy_source.fluid_box.filter
    if filter then
      return {}, { class = "fluid", name = filter.name }
    end
    return { { class = "fuel_category", name = "burnable-fluid" } }
  end
  return {}
end

--- Safely retrive the given GUI, checking for validity.
--- @param player_index number
--- @param gui_name string
--- @param gui_key number|string?
function util.get_gui(player_index, gui_name, gui_key)
  local player_table = storage.players[player_index]
  if not player_table then
    return
  end
  local tbl = player_table.guis[gui_name]
  if not tbl then
    return
  end
  if gui_key then
    tbl = tbl[gui_key]
  end
  if tbl and tbl.refs.window and tbl.refs.window.valid then
    return tbl
  end
end

--- Dispatch the given action on all GUIs of the given name.
--- @param player_index number
--- @param gui_name string
--- @param msg string|table
function util.dispatch_all(player_index, gui_name, msg)
  local player_table = storage.players[player_index]
  if not player_table then
    return
  end
  local ignored = gui_name == "info" and constants.ignored_info_ids or {}
  for key, Gui in pairs(player_table.guis[gui_name]) do
    if not ignored[key] then
      Gui:dispatch(msg)
    end
  end
end

--- Determine if the given prototype is blueprintable
--- @param prototype LuaEntityPrototype
--- @return boolean
function util.is_blueprintable(prototype)
  return prototype.has_flag("player-creation")
    and not prototype.has_flag("not-selectable-in-game")
    and not prototype.has_flag("not-blueprintable")
    and not prototype.hidden
end

--- @param prototype LuaEntityPrototype
function util.build_blueprint_result(prototype)
  if (not prototype or
      not prototypes.entity[prototype.name] or
      not util.is_blueprintable(prototype)) then
    return nil
  end
  return { name = prototype.name }
end

--- Create a new dictionary only if not in on_load.
--- @param name string
--- @param initial_contents Dictionary?
function util.new_dictionary(name, initial_contents)
  if game then
    dictionary.new(name, initial_contents)
  end
end

--- Add to the dictionary only if not in on_load.
--- @param dict string
--- @param key string
--- @param localised LocalisedString
function util.add_to_dictionary(dict, key, localised)
  if game then
    -- Fall back to internal key in non-description dictionaries
    if not string.find(dict, "description") then
      localised = { "?", localised, key }
    end
    dictionary.add(dict, key, localised)
  end
end

-- src_array[left_start..left_end] is sorted
-- src_array[left_start + 1, right_end] is sorted
-- right side may be shorter than left side
-- right side may be empty (left_end == right_end)
-- merge left and right sides into dst_array[left_start..right_end]
local function sorted_merge(dst_array, src_array,
                            left_start, left_end, right_end, is_in_order)
  local left = left_start
  local right = left_end + 1

  -- copy until one side runs out
  local dst = left_start
  while left <= left_end and right <= right_end do
    if is_in_order(src_array[left], src_array[right]) then
      dst_array[dst] = src_array[left]
      left = left + 1
    else
      dst_array[dst] = src_array[right]
      right = right + 1
    end
    dst = dst + 1
  end

  -- copy the remainder of any non-empty side
  for i = left, left_end do
    dst_array[dst] = src_array[i]
    dst = dst + 1
  end
  for i = right, right_end do
    dst_array[dst] = src_array[i]
    dst = dst + 1
  end
end

local function merge_from_width(dst_array, src_array, old_width, is_in_order)
  -- handle
  local last = table.size(src_array)
  local next_unsorted = 1
  while next_unsorted < last do
    local left_start = next_unsorted
    local left_end = left_start + old_width - 1
    local right_end = left_end + old_width
    if left_end > last then
      left_end = last
    end
    if right_end > last then
      right_end = last
    end
    sorted_merge(dst_array, src_array, left_start, left_end, right_end, is_in_order)
    next_unsorted = right_end + 1
  end
end

-- stable sort array using merge sort
-- is_in_order(x, y) returns true if x <= y
-- (the = part is important for stability)
function util.stable_sort(array, is_in_order)
  local src = array
  local dst = {}

  local sorted_width = 1
  while sorted_width < table.size(src) do
    -- each sorted_width size run of src is already sorted
    -- sort each sorted_width*2 run by merging two sorted_width runs
    -- output into dst

    merge_from_width(dst, src, sorted_width, is_in_order)
    sorted_width = sorted_width * 2

    -- dst is now sorted into sorted_width size runs
    -- Exchange the arrays in preparation for the next round.
    local temp = dst
    dst = src
    src = temp
    -- src is now the more-sorted array
  end

  -- src is now fully sorted
  -- Copy into the original array if necessary.
  if not (src == array) then
    for i = 1, table.size(src) do
      array[i] = src[i]
    end
  end
end

-- Compare two object ident by researchedness.
-- Researched is before unresearched.
-- Slightly unresearched is before distantly unresearched.
function util.researchedness_comparator(database, player_data, lhs_ident, rhs_ident)
  local force_index = player_data.force.index
  local colorize_unresearched = player_data.settings.general.content.colorize_unresearched
  local lhs_data = database[lhs_ident.class][lhs_ident.name]
  local rhs_data = database[rhs_ident.class][rhs_ident.name]

  -- sort by researchedness
  -- `not not` fixes `false ~= nil` problems
  local lhs_res = not not (lhs_data.enabled_at_start or
                           (lhs_data.researched_forces and
                            lhs_data.researched_forces[force_index]))
  local rhs_res = not not (rhs_data.enabled_at_start or
                           (rhs_data.researched_forces and
                            rhs_data.researched_forces[force_index]))
  if lhs_res ~= rhs_res then
    return lhs_res
  end

  -- sort by missing researches
  if colorize_unresearched then
    local lhs_miss = lhs_data.research_ingredients_missing[force_index]
    local rhs_miss = rhs_data.research_ingredients_missing[force_index]
    if lhs_miss ~= rhs_miss then
      return lhs_miss <= rhs_miss
    end
  end

  -- same researchedness, lhs and rhs are in order
  return true
end

return util
