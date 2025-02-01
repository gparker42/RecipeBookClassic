local data_util = require("__flib__.data-util")

data:extend({
  {
    type = "shortcut",
    name = "rb-search",
    action = "lua",
    icon = "__RecipeBookClassic__/graphics/shortcut.png",
    -- GrP fixme shortcut.png should be split up
    icon_size = 32,
    small_icon_size = 32,
    small_icon = "__RecipeBookClassic__/graphics/shortcut.png",
    disabled_icon = "__RecipeBookClassic__/graphics/shortcut.png",
    disabled_small_icon = "__RecipeBookClassic__/graphics/shortcut.png",
    toggleable = true,
    associated_control_input = "rb-search",
  },
})
