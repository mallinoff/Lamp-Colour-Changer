local function selection()
  return {
    border_color = {r = 0.3, g = 0.8, b = 1},
    cursor_box_type = "entity",
    mode = {"any-entity", "entity-ghost", "same-force"},
    entity_type_filters = {"lamp", "entity-ghost"}
  }
end

local shortcut = table.deepcopy(data.raw.shortcut["toggle-alt-mode"])
shortcut.name = "lcc-picker"
shortcut.action = "lua"
shortcut.toggleable = false
shortcut.associated_control_input = "lcc-picker"
shortcut.order = "z[lamp-colour-changer]"
shortcut.localised_name = {"shortcut-name.lcc-picker"}
-- Shortcut icon formats differ between Factorio releases; use the base game's format.
if type(shortcut.icon) == "table" then
  shortcut.icon = {filename = "__base__/graphics/icons/small-lamp.png", size = 64}
  shortcut.small_icon = {filename = "__base__/graphics/icons/small-lamp.png", size = 64}
else
  shortcut.icon = "__base__/graphics/icons/small-lamp.png"
  shortcut.icon_size = 64
  shortcut.small_icon = shortcut.icon
  shortcut.small_icon_size = 64
end
shortcut.disabled_icon = nil
shortcut.disabled_small_icon = nil

-- A powered, always-on lamp used only by the GUI's native entity preview.
local preview_lamp = table.deepcopy(data.raw.lamp["small-lamp"])
preview_lamp.name = "lcc-preview-lamp"
preview_lamp.localised_name = {"lcc.title"}
preview_lamp.hidden = true
preview_lamp.hidden_in_factoriopedia = true
preview_lamp.minable = nil
preview_lamp.next_upgrade = nil
preview_lamp.energy_source = {type = "void"}
preview_lamp.always_on = true
preview_lamp.collision_mask = {layers = {}}
data:extend({preview_lamp})
data:extend({{
  type = "selection-tool", name = "lcc-eyedropper",
  icon = "__base__/graphics/icons/small-lamp.png", icon_size = 64,
  flags = {"only-in-cursor", "not-stackable", "spawnable"},
  subgroup = "tool", stack_size = 1, select = selection(), alt_select = selection()
}})

data:extend({
  {
    type = "selection-tool",
    name = "lcc-tool",
    icon = "__base__/graphics/icons/small-lamp.png",
    icon_size = 64,
    flags = {"only-in-cursor", "not-stackable", "spawnable"},
    subgroup = "tool",
    order = "z[lamp-colour-changer]",
    stack_size = 1,
    select = selection(),
    alt_select = selection()
  },
  shortcut,
  {type = "custom-input", name = "lcc-picker", key_sequence = "CONTROL + SHIFT + L", consuming = "none"},
  {type = "custom-input", name = "lcc-undo", key_sequence = "CONTROL + ALT + Z", consuming = "none"},
  {type = "custom-input", name = "lcc-redo", key_sequence = "CONTROL + ALT + Y", consuming = "none"}
})
