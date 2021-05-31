local gui = require("__flib__.gui-beta")

local constants = require("constants")

local formatter = require("scripts.formatter")
local shared = require("scripts.shared")
local util = require("scripts.util")

local search_gui = {}

function search_gui.build(player, player_table)
  local refs = gui.build(player.gui.screen, {
    {type = "frame", direction = "vertical", ref = {"window"},
      {type = "flow", style = "flib_titlebar_flow", ref = {"titlebar", "flow"},
        {type = "label", style = "frame_title", caption = "Recipe Book", ignored_by_interaction = true},
        {type = "empty-widget", style = "flib_titlebar_drag_handle", ignored_by_interaction = true},
        util.frame_action_button(
          "rb_settings",
          nil,
          {"titlebar", "settings_button"},
          {gui = "search", action = "toggle_settings"}
        ),
        util.frame_action_button(
          "utility/close",
          {"gui.close"},
          {"titlebar", "close_button"},
          {gui = "search", action = "close"}
        )
      },
      {type = "frame", style = "inside_deep_frame_for_tabs", direction = "vertical",
        {type = "tabbed-pane", style = "tabbed_pane_with_no_side_padding", style_mods = {height = 540},
          {tab = {type = "tab", caption = "Search"}, content = (
            -- TODO: Locale-specific widths
            {type = "frame", style = "rb_inside_deep_frame_under_tabs", style_mods = {width = 276}, direction = "vertical",
              {type = "frame", style = "rb_subheader_frame", direction = "vertical",
                -- {type = "flow", style_mods = {vertical_align = "center"},
                --   {type = "label", style = "subheader_caption_label", caption = "Class:"},
                --   {type = "empty-widget", style = "flib_horizontal_pusher"},
                --   {type = "drop-down", items = {"Crafter", "Fluid", "Group", "Lab", "Mining drill", "Offshore pump", "Item", "Recipe category", "Recipe", "Resource category", "Resource", "Technology"}}
                -- },
                -- {type = "line", style = "rb_dark_line"},
                {
                  type = "textfield",
                  style = "flib_widthless_textfield",
                  style_mods = {horizontally_stretchable = true},
                  ref = {"search_textfield"},
                  actions = {
                    on_text_changed = {gui = "search", action = "update_search_query"}
                  }
                },
              },
              {type = "scroll-pane", style = "rb_search_results_scroll_pane", ref = {"search_results_pane"}}
            }
          )},
          {tab = {type = "tab", caption = "Favorites"}, content = (
            {type = "frame", style = "rb_inside_deep_frame_under_tabs", direction = "vertical",
              {type = "scroll-pane", style = "rb_search_results_scroll_pane"}
            }
          )},
          {tab = {type = "tab", caption = "History"}, content = (
            {type = "frame", style = "rb_inside_deep_frame_under_tabs", direction = "vertical",
              {type = "scroll-pane", style = "rb_search_results_scroll_pane"}
            }
          )}
        },
      }
    }
  })

  refs.titlebar.flow.drag_target = refs.window

  refs.search_textfield.focus()

  player_table.guis.search = {
    state = {
      search_query = ""
    },
    refs = refs
  }
  player.set_shortcut_toggled("rb-search", true)
end

function search_gui.destroy(player, player_table)
  player_table.guis.search.refs.window.destroy()
  player_table.guis.search = nil
  player.set_shortcut_toggled("rb-search", false)
end

function search_gui.toggle(player, player_table)
  if player_table.guis.search then
    search_gui.destroy(player, player_table)
  else
    search_gui.build(player, player_table)
  end
end

function search_gui.handle_action(msg, e)
  local player = game.get_player(e.player_index)
  local player_table = global.players[e.player_index]

  local gui_data = player_table.guis.search
  local state = gui_data.state
  local refs = gui_data.refs

  if msg.action == "close" then
    search_gui.destroy(player, player_table)
  elseif msg.action == "update_search_query" then
    local class_filter
    local query = string.lower(e.element.text)
    if string.find(query, "/") then
      -- NOTE: The `_`s here are technically globals, but whatever
      _, _, class_filter, query = string.find(query, "^/(.-)/(.-)$")
      if not class_filter or not query or not constants.pages[class_filter] then
        class_filter = false
      end
    end
    -- local query_len = query and #query or 0
    if query --[[ and query_len > 1 ]] then
      -- TODO: Timeout
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
    else
      state.search_query = ""
    end

    -- Data
    local player_data = formatter.build_player_data(player, player_table)

    -- Update results based on query
    -- TODO: Separate into its own function
    -- TODO: Spread over multiple ticks
    local i = 0
    local pane = refs.search_results_pane
    local children = pane.children
    local add = pane.add
    local max = constants.search_results_limit
    if class_filter ~= false --[[ and query_len > 1 ]] then
      for class in pairs(constants.pages) do
        if not class_filter or class_filter == class then
          for internal, translation in pairs(player_table.translations[class]) do
            -- Match against search string
            if string.find(string.lower(translation), query) then
              local obj_data = global.recipe_book[class][internal]
              local info = formatter(obj_data, player_data)

              if info then
                i = i + 1
                local style = info.researched and "rb_list_box_item" or "rb_unresearched_list_box_item"
                local item = children[i]
                if item then
                  item.style = style
                  item.caption = info.caption
                  item.tooltip = info.tooltip
                  item.enabled = info.enabled
                  gui.update_tags(item, {context = {class = class, name = internal}})
                else
                  add{
                    type = "button",
                    style = style,
                    caption = info.caption,
                    tooltip = info.tooltip,
                    enabled = info.enabled,
                    mouse_button_filter = {"left", "middle"},
                    tags = {
                      [script.mod_name] = {
                        context = {class = class, name = internal},
                        flib = {
                          on_click = {gui = "search", action = "open_object"}
                        },
                      }
                    }
                  }
                  if i >= max then
                    break
                  end
                end
              end
            end
          end
        end
        if i >= max then
          break
        end
      end
    end
    -- Destroy extraneous items
    for j = i + 1, #children do
      children[j].destroy()
    end
  elseif msg.action == "open_object" then
    local context = util.navigate_to(e)
    if context then
      shared.open_page(player, player_table, context)
    end
  end
end

return search_gui
