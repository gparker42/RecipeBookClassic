local on_tick_n = require("__flib__.on-tick-n")

local constants = require("constants")
local shared = require("scripts.shared")

local root = require("scripts.gui.settings.root")

local actions = {}

function actions.close(data)
  -- TODO: This won't need to be shared anymore!
  shared.deselect_settings_button(data.player, data.player_table)
  root.destroy(data.player_table)
end

function actions.toggle_search(data)
  local state = data.state
  local refs = data.refs

  local opened = state.search_opened
  state.search_opened = not opened

  local search_button = refs.toolbar.search_button
  local search_textfield = refs.toolbar.search_textfield
  if opened then
    search_button.style = "tool_button"
    search_textfield.visible = false

    if state.search_query ~= "" then
      -- Reset query
      search_textfield.text = ""
      state.search_query = ""
      -- TODO: Refresh page
    end
  else
    -- Show search textfield
    search_button.style = "flib_selected_tool_button"
    search_textfield.visible = true
    search_textfield.focus()
  end
end

function actions.update_search_query(data)
  local player_table = data.player_table
  local state = data.state

  local query = string.lower(data.e.element.text)
  -- Fuzzy search
  if player_table.settings.use_fuzzy_search then
    query = string.gsub(query, ".", "%1.*")
  end
  -- Input sanitization
  for pattern, replacement in pairs(constants.input_sanitizers) do
    query = string.gsub(query, pattern, replacement)
  end
  -- Save query
  state.search_query = query

  -- Remove scheduled update if one exists
  if state.update_results_ident then
    on_tick_n.remove(state.update_results_ident)
    state.update_results_ident = nil
  end

  if query == "" then
    -- Update now
    -- TODO:
    -- info_gui.update_contents(player, player_table, msg.id, {refresh = true})
  else
    -- Update in a while
    state.update_results_ident = on_tick_n.add(
      game.tick + constants.search_timeout,
      {gui = "settings", action = "update_search_results", player_index = data.e.player_index}
    )
  end
end

function actions.update_search_results(data)
  -- TODO:
end

return actions
