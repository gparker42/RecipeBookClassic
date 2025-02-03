local bounding_box = require("__flib__.bounding-box")
local gui = require("old-flib-gui")
local math = require("__flib__.math")
local table = require("__flib__.table")

local constants = require("constants")

local formatter = require("scripts.formatter")

local gui_util = {}

-- Perform a pipette-style operation specified in a gui element's tags.
-- Return true if successful.
-- GrP use pipette_entity() instead of poking cursor and clipboard directly?
function gui_util.perform_pipette(player, tags)
  if not tags then
    return false
  end

  local blueprint_result = tags.blueprint_result

  if blueprint_result then
    local cursor_stack = player.cursor_stack
    player.clear_cursor()
    if not cursor_stack or not cursor_stack.valid then
      return false
    end

    local collision_box = prototypes.entity[blueprint_result.name].collision_box
    local height = bounding_box.height(collision_box)
    local width = bounding_box.width(collision_box)
    if blueprint_result.recipe then
      -- Result includes a recipe. Use a blueprint.
      cursor_stack.set_stack({ name = "blueprint", count = 1 })
      cursor_stack.set_blueprint_entities({
        {
          entity_number = 1,
          name = blueprint_result.name,
          position = {
            -- Entities with an even number of tiles to a side need to be set at -0.5 instead of 0
            math.ceil(width) % 2 == 0 and -0.5 or 0,
            math.ceil(height) % 2 == 0 and -0.5 or 0,
          },
          recipe = blueprint_result.recipe,
        },
      })
      player.add_to_clipboard(cursor_stack)
      player.activate_paste()
      player.play_sound({ path = "utility/smart_pipette" })
    elseif prototypes.entity[blueprint_result.name] then
      -- Result is an entity with no recipe. Use the pipette_entity() function.
      local ok = player.pipette_entity(blueprint_result.name, true)
      if not ok then
        return false
      end
    else
      -- Result is not an entity.
      -- GrP fixme implement pipette of items too
      return false
    end
    return true
  end

  return false
end

-- The calling GUI will navigate to the context that is returned, if any
-- Actions that do not open a page will not return a context
function gui_util.navigate_to(e)
  local tags = gui.get_tags(e.element)
  local context = tags.context

  local modifiers = {}
  for name, modifier in pairs({ control = e.control, shift = e.shift, alt = e.alt }) do
    if modifier then
      modifiers[#modifiers + 1] = name
    end
  end

  for _, interaction in pairs(constants.interactions[context.class]) do
    if table.deep_compare(interaction.modifiers, modifiers) then
      local action = interaction.action
      local context_data = storage.database[context.class][context.name]
      local player = game.get_player(e.player_index) --[[@as LuaPlayer]]

      if action == "view_details" then
        return context
      elseif action == "view_product_details" and #context_data.products == 1 then
        return context_data.products[1]
      elseif action == "get_blueprint" then
        gui_util.perform_pipette(player, tags)
--          player.create_local_flying_text({
--            text = { "message.rb-cannot-create-blueprint" },
--            create_at_cursor = true,
--          })
--          player.play_sound({ path = "utility/cannot_build" })
      elseif action == "open_in_technology_window" then
        local player_table = storage.players[e.player_index]
        player_table.flags.technology_gui_open = true
        player.open_technology_gui(context.name)
      elseif action == "view_source" then
        local source = context_data[interaction.source]
        if source then
          return source
        end
      end
    end
  end
end

function gui_util.update_list_box(pane, source_tbl, player_data, iterator, options)
  local i = 0
  local children = pane.children
  local add = pane.add
  for _, obj_ident in iterator(source_tbl) do
    local obj_data = storage.database[obj_ident.class][obj_ident.name]
    local info = formatter(obj_data, player_data, options)
    if info then
      i = i + 1
      local blueprint_result = obj_data.blueprint_result
      local style = info.researched and "rb_list_box_item" or "rb_unresearched_list_box_item"
      local item = children[i]
      if item then
        item.style = style
        item.caption = info.caption
        item.tooltip = info.tooltip
        item.enabled = info.num_interactions > 0
        gui.update_tags(item, {
          blueprint_result = blueprint_result,
          context = { class = obj_ident.class, name = obj_ident.name }
        })
      else
        item = add({
          type = "button",
          style = style,
          caption = info.caption,
          tooltip = info.tooltip,
          enabled = info.num_interactions > 0,
          mouse_button_filter = { "left", "middle" },
          tags = {
            [script.mod_name] = {
              blueprint_result = blueprint_result,
              context = { class = obj_ident.class, name = obj_ident.name },
              old_flib = {
                on_click = { gui = "search", action = "open_object" },
              },
            },
          },
        })
      end
      -- If the element has a blueprint, send hover events so it can be pipetted.
      item.raise_hover_events = (blueprint_result ~= nil)
    end
  end
  -- Destroy extraneous items
  for j = i + 1, #children do
    children[j].destroy()
  end
end

return gui_util
