local util = require("scripts.util")

local actions = require("scripts.gui.settings.actions")
local root = require("scripts.gui.settings.root")

local function handle_action(msg, e)
  local data = util.get_action_data(msg, e)

  if type(msg) == "string" then
    actions[msg](data)
  else
    actions[msg.action](data)
  end
end

return {
  actions = actions,
  handle_action = handle_action,
  root = root,
}
