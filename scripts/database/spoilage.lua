local table = require("__flib__.table")

local constants = require("constants")

return function(database)
  -- Item :: Decay from
  for item_name, item_data in pairs(database.item) do
    local spoil_result = item_data.spoil_result
    if spoil_result then
      local result_data = database.item[spoil_result.name]
      result_data.spoil_result_of[#result_data.spoil_result_of + 1] = { class = "item", name = item_name }
    end
  end
end