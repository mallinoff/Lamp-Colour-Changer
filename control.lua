local WINDOW = "lcc_window"
local DIRECTIONS = {{"lcc.horizontal"}, {"lcc.vertical"}, {"lcc.diagonal"},
  {"lcc.diagonal-up"}, {"lcc.radial"}}
local function is_lamp(entity)
  return entity.valid and (entity.type == "lamp" or
    (entity.type == "entity-ghost" and entity.ghost_type == "lamp"))
end

local function state(index)
  storage.lcc_players = storage.lcc_players or {}
  storage.lcc_players[index] = storage.lcc_players[index] or {r = 255, g = 255, b = 255}
  return storage.lcc_players[index]
end

local function close(player)
  local window = player.gui.screen[WINDOW]
  if window then window.destroy() end
  local previews = storage.lcc_previews
  local lamp = previews and previews[player.index]
  if lamp and lamp.valid then lamp.destroy() end
  if previews then previews[player.index] = nil end
end

local function update_preview(window, colour)
  if window.lcc_body.lcc_hex then
    window.lcc_body.lcc_hex.text = string.format("#%02X%02X%02X", colour.r, colour.g, colour.b)
  end
  local lamp = window.lcc_body.lcc_preview.entity
  if lamp and lamp.valid then lamp.color = {
    r = colour.r / 255, g = colour.g / 255, b = colour.b / 255
  } end
end

local function parse_hex(text)
  local hex = text:match("^#?(%x%x%x%x%x%x)$")
  if not hex then return end
  return {r = tonumber(hex:sub(1, 2), 16), g = tonumber(hex:sub(3, 4), 16), b = tonumber(hex:sub(5, 6), 16)}
end

local function show_gradient(body, enabled)
  body.lcc_gradient.state = enabled
  body.lcc_gradient_options.visible = enabled
  body.lcc_hex_label.caption = {enabled and "lcc.picker-colour" or "lcc.hex"}
  body.lcc_add_favourite.caption = {enabled and "lcc.save-gradient" or "lcc.add-favourite"}
end

local function undo_stack(index)
  storage.lcc_undo = storage.lcc_undo or {}
  local stack = storage.lcc_undo[index] or {}
  -- Preserve the previous release's single saved selection.
  if stack[1] and stack[1].entity then stack = {stack} end
  storage.lcc_undo[index] = stack
  return stack
end

local function redo_stack(index)
  storage.lcc_redo = storage.lcc_redo or {}
  storage.lcc_redo[index] = storage.lcc_redo[index] or {}
  return storage.lcc_redo[index]
end

local function refresh_undo(player)
  local window = player.gui.screen[WINDOW]
  if window then
    local button = window.lcc_body.lcc_tools.lcc_undo
    local count = #undo_stack(player.index)
    button.caption = {"lcc.undo", count}
    button.enabled = count > 0
    local redo = window.lcc_body.lcc_tools.lcc_redo
    if redo then
      local available = #redo_stack(player.index)
      redo.caption = {"lcc.redo", available}
      redo.enabled = available > 0
    end
  end
end

local function undo(player, redo)
  local stack = undo_stack(player.index)
  local destination = redo_stack(player.index)
  if redo then stack, destination = destination, stack end
  local history = table.remove(stack)
  if not history then player.print({redo and "lcc.no-redo" or "lcc.no-undo"}); return end
  local reverse = {}
  for _, entry in ipairs(history) do
    local entity = entry.entity
    if entity.valid and entity.force == player.force then
      local snapshot = {entity = entity}
      if entry.colour then
        local control = entity.get_or_create_control_behavior()
        snapshot.colour = entity.color or {r = 1, g = 1, b = 1, a = 1}
        snapshot.use_colors = control and control.use_colors or false
        entity.color = entry.colour
        if control then control.use_colors = entry.use_colors end
      end
      if entry.always_on ~= nil then
        snapshot.always_on = entity.always_on
        entity.always_on = entry.always_on
      end
      reverse[#reverse + 1] = snapshot
    end
  end
  if #reverse > 0 then destination[#destination + 1] = reverse end
  refresh_undo(player)
  player.print({redo and "lcc.redone" or "lcc.undone", #reverse, #stack})
end

local function create_preview(player)
  local surface = game.surfaces["lcc-preview"] or game.create_surface("lcc-preview", {width = 1, height = 1})
  surface.freeze_daytime = true
  surface.daytime = 0.5
  storage.lcc_previews = storage.lcc_previews or {}
  local previous = storage.lcc_previews[player.index]
  if previous and previous.valid then previous.destroy() end
  local lamp = surface.create_entity{name = "lcc-preview-lamp", position = {0, 0},
    force = player.force, create_build_effect_smoke = false}
  if lamp then
    lamp.destructible = false
    storage.lcc_previews[player.index] = lamp
  end
  return lamp
end

local function favourites(index)
  storage.lcc_favourites = storage.lcc_favourites or {}
  storage.lcc_favourites[index] = storage.lcc_favourites[index] or {next_id = 1, colours = {}}
  return storage.lcc_favourites[index]
end

local function refresh_favourites(window, player)
  local list = window.lcc_body.lcc_favourites
  list.clear()
  local saved = favourites(player.index)
  if #saved.colours == 0 then list.add{type = "label", caption = {"lcc.no-favourites"}} end
  for _, favourite in ipairs(saved.colours) do
    local row = list.add{type = "flow", name = "lcc_favourite_" .. favourite.id, direction = "horizontal"}
    row.style.vertical_align = "center"
    row.style.horizontal_spacing = 8
    row.style.bottom_margin = 4
    local swatch = row.add{type = "label", caption = "■",
      tooltip = string.format("R %d  G %d  B %d", favourite.r, favourite.g, favourite.b)}
    swatch.style.font_color = {favourite.r / 255, favourite.g / 255, favourite.b / 255}
    swatch.style.width = 18
    swatch.style.horizontal_align = "center"
    if favourite.gradient_end then
      local endpoint = favourite.gradient_end
      local end_swatch = row.add{type = "label", caption = "■"}
      end_swatch.style.font_color = {endpoint.r / 255, endpoint.g / 255, endpoint.b / 255}
      end_swatch.style.width = 18
      end_swatch.style.horizontal_align = "center"
      swatch.tooltip = {"lcc.gradient-tooltip",
        string.format("#%02X%02X%02X", favourite.r, favourite.g, favourite.b),
        string.format("#%02X%02X%02X", endpoint.r, endpoint.g, endpoint.b),
        DIRECTIONS[favourite.gradient_direction or 1]}
      end_swatch.tooltip = swatch.tooltip
    else
      local spacer = row.add{type = "empty-widget"}
      spacer.style.width = 18
    end
    local name = row.add{type = "textfield", name = "lcc_favourite_name", text = favourite.name, tags = {lcc_favourite_id = favourite.id}}
    name.style.width = 140
    for _, action in ipairs({"select", "delete", "up", "down"}) do
      local button = row.add{type = "button", name = "lcc_favourite_" .. action,
        caption = {"lcc.favourite-" .. action},
        tags = {lcc_favourite_id = favourite.id, lcc_favourite_action = action}}
      if action == "up" or action == "down" then
        button.style.width = 36
        button.style.left_padding = 0
        button.style.right_padding = 0
        button.style.horizontal_align = "center"
      end
    end
  end
end

local function open(player)
  if player.gui.screen[WINDOW] then close(player); return end
  local colour = state(player.index)
  local window = player.gui.screen.add{type = "frame", name = WINDOW,
    caption = {"lcc.title"}, direction = "vertical"}
  window.auto_center = true
  local body = window.add{type = "flow", name = "lcc_body", direction = "vertical"}
  local tools = body.add{type = "flow", name = "lcc_tools", direction = "horizontal"}
  tools.add{type = "button", name = "lcc_eyedropper", caption = {"lcc.eyedropper"}}
  tools.add{type = "button", name = "lcc_undo", caption = {"lcc.undo"}}
  tools.add{type = "button", name = "lcc_redo", caption = {"lcc.redo"}}
  refresh_undo(player)
  local rgb = body.add{type = "table", name = "lcc_rgb", column_count = 4}
  local slider_styles = {r = "red_slider", g = "green_slider", b = "blue_slider"}
  for _, channel in ipairs({"r", "g", "b"}) do
    rgb.add{type = "label", caption = string.upper(channel)}
    local slider = rgb.add{type = "slider", name = "lcc_slider_" .. channel,
      minimum_value = 0, maximum_value = 255, value = colour[channel],
      value_step = 1, discrete_slider = true, discrete_values = true,
      style = slider_styles[channel]}
    slider.style.width = 180
    local field = rgb.add{type = "textfield", name = "lcc_" .. channel,
      text = tostring(colour[channel]), numeric = true, allow_decimal = false,
      allow_negative = false}
    field.style.width = 52
    if channel == "r" then
      rgb.add{type = "checkbox", name = "lcc_always_on", caption = {"lcc.always-on"},
        tooltip = {"lcc.always-on-tooltip"}, state = colour.always_on == true}
    elseif channel == "g" then
      rgb.add{type = "checkbox", name = "lcc_change_colour", caption = {"lcc.change-colour"}, state = colour.change_colour ~= false}
    else
      rgb.add{type = "checkbox", name = "lcc_change_always_on", caption = {"lcc.change-always-on"}, state = colour.change_always_on ~= false}
    end
  end
  for _ = 1, 3 do rgb.add{type = "empty-widget"} end
  rgb.add{type = "checkbox", name = "lcc_skip_circuit", caption = {"lcc.skip-circuit"},
    tooltip = {"lcc.skip-circuit-tooltip"}, state = colour.skip_circuit == true}
  body.add{type = "label", name = "lcc_hex_label", caption = {"lcc.hex"}}
  local hex = body.add{type = "textfield", name = "lcc_hex", text = "", tooltip = {"lcc.hex-help"}}
  hex.style.width = 120
  body.add{type = "checkbox", name = "lcc_gradient", caption = {"lcc.gradient"}, state = colour.gradient == true}
  local gradient = body.add{type = "table", name = "lcc_gradient_options", column_count = 3}
  gradient.visible = colour.gradient == true
  gradient.add{type = "label", caption = {"lcc.gradient-start"}}
  local start = colour.gradient_start
  local start_hex = gradient.add{type = "textfield", name = "lcc_start_hex",
    tooltip = {"lcc.gradient-start-help"},
    text = start and string.format("#%02X%02X%02X", start.r, start.g, start.b) or ""}
  start_hex.style.width = 100
  gradient.add{type = "button", name = "lcc_capture_start", caption = {"lcc.capture-start"}}
  gradient.add{type = "label", caption = {"lcc.gradient-end"}}
  local endpoint = colour.gradient_end or {r = 255, g = 255, b = 255}
  local end_hex = gradient.add{type = "textfield", name = "lcc_end_hex",
    text = string.format("#%02X%02X%02X", endpoint.r, endpoint.g, endpoint.b)}
  end_hex.style.width = 100
  gradient.add{type = "button", name = "lcc_capture_end", caption = {"lcc.capture-end"}}
  gradient.add{type = "drop-down", name = "lcc_direction",
    items = DIRECTIONS, selected_index = colour.gradient_direction or 1}
  local preview = body.add{type = "entity-preview", name = "lcc_preview"}
  preview.style.width = 398
  preview.style.height = 140
  preview.entity = create_preview(player)
  update_preview(window, colour)
  body.add{type = "button", name = "lcc_add_favourite", caption = {"lcc.add-favourite"}}
  show_gradient(body, colour.gradient == true)
  body.add{type = "label", caption = {"lcc.favourites"}}
  local list = body.add{type = "scroll-pane", name = "lcc_favourites",
    direction = "vertical", horizontal_scroll_policy = "never"}
  list.style.maximal_height = 200
  list.style.top_margin = 4
  list.style.bottom_margin = 10
  refresh_favourites(window, player)
  local actions = body.add{type = "flow", direction = "horizontal"}
  actions.style.horizontal_spacing = 8
  actions.add{type = "button", name = "lcc_close", caption = {"lcc.close"}}
  actions.add{type = "button", name = "lcc_select", caption = {"lcc.select"}, style = "confirm_button"}
  player.opened = window
end

script.on_event(defines.events.on_lua_shortcut, function(event)
  if event.prototype_name == "lcc-picker" then open(game.get_player(event.player_index)) end
end)
script.on_event("lcc-picker", function(event) open(game.get_player(event.player_index)) end)
script.on_event("lcc-undo", function(event) undo(game.get_player(event.player_index)) end)
script.on_event("lcc-redo", function(event) undo(game.get_player(event.player_index), true) end)

script.on_event(defines.events.on_gui_click, function(event)
  local element = event.element
  if not element.valid then return end
  local player = game.get_player(event.player_index)
  local window = player.gui.screen[WINDOW]
  if not window then return end
  if element.name == "lcc_close" then close(player)
  elseif element.name == "lcc_undo" then undo(player)
  elseif element.name == "lcc_redo" then undo(player, true)
  elseif element.name == "lcc_capture_start" or element.name == "lcc_capture_end" then
    local current = parse_hex(window.lcc_body.lcc_hex.text)
    if not current then player.print({"lcc.invalid-hex"}); return end
    local field = element.name == "lcc_capture_start" and "lcc_start_hex" or "lcc_end_hex"
    window.lcc_body.lcc_gradient_options[field].text = string.format("#%02X%02X%02X", current.r, current.g, current.b)
  elseif element.name == "lcc_eyedropper" then
    if not player.clear_cursor() then player.print({"lcc.cursor-full"}); return end
    if player.cursor_stack and player.cursor_stack.set_stack{name = "lcc-eyedropper", count = 1} then
      close(player)
      player.print({"lcc.eyedropper-help"})
    end
  elseif element.name == "lcc_add_favourite" then
    if not parse_hex(window.lcc_body.lcc_hex.text) then player.print({"lcc.invalid-hex"}); return end
    local colour = {}
    for _, channel in ipairs({"r", "g", "b"}) do
      local value = tonumber(window.lcc_body.lcc_rgb["lcc_" .. channel].text)
      if not value or value < 0 or value > 255 or value % 1 ~= 0 then
        player.print({"lcc.invalid-rgb"}); return
      end
      colour[channel] = value
    end
    local body = window.lcc_body
    if body.lcc_gradient.state then
      local gradient = body.lcc_gradient_options
      local start_hex = gradient.lcc_start_hex.text
      if start_hex ~= "" then
        local start = parse_hex(start_hex)
        if not start then player.print({"lcc.invalid-hex"}); return end
        colour = start
      end
      colour.gradient_end = parse_hex(gradient.lcc_end_hex.text)
      if not colour.gradient_end then player.print({"lcc.invalid-hex"}); return end
      colour.gradient_direction = gradient.lcc_direction.selected_index
    end
    local saved = favourites(player.index)
    colour.id = saved.next_id
    colour.name = (colour.gradient_end and "Gradient " or "Colour ") .. saved.next_id
    saved.next_id = saved.next_id + 1
    saved.colours[#saved.colours + 1] = colour
    refresh_favourites(window, player)
  elseif element.tags.lcc_favourite_id then
    local saved = favourites(player.index)
    for i, favourite in ipairs(saved.colours) do
      if favourite.id == element.tags.lcc_favourite_id then
        local action = element.tags.lcc_favourite_action
        if action == "select" then
          local colour = state(player.index)
          for _, channel in ipairs({"r", "g", "b"}) do
            colour[channel] = favourite[channel]
            window.lcc_body.lcc_rgb["lcc_" .. channel].text = tostring(colour[channel])
            window.lcc_body.lcc_rgb["lcc_slider_" .. channel].slider_value = colour[channel]
          end
          update_preview(window, colour)
          local body = window.lcc_body
          local gradient = body.lcc_gradient_options
          colour.gradient = favourite.gradient_end ~= nil
          show_gradient(body, colour.gradient)
          if favourite.gradient_end then
            colour.gradient_start = {r = favourite.r, g = favourite.g, b = favourite.b}
            gradient.lcc_start_hex.text = window.lcc_body.lcc_hex.text
            local endpoint = favourite.gradient_end
            colour.gradient_end = {r = endpoint.r, g = endpoint.g, b = endpoint.b}
            colour.gradient_direction = favourite.gradient_direction or 1
            gradient.lcc_end_hex.text = string.format("#%02X%02X%02X", endpoint.r, endpoint.g, endpoint.b)
            gradient.lcc_direction.selected_index = colour.gradient_direction
          end
        elseif action == "delete" then
          table.remove(saved.colours, i)
          refresh_favourites(window, player)
        elseif action == "up" or action == "down" then
          local target = i + (action == "up" and -1 or 1)
          if saved.colours[target] then
            saved.colours[i], saved.colours[target] = saved.colours[target], saved.colours[i]
            refresh_favourites(window, player)
          end
        end
        break
      end
    end
  elseif element.name == "lcc_select" then
    if not parse_hex(window.lcc_body.lcc_hex.text) then player.print({"lcc.invalid-hex"}); return end
    local colour = {}
    for _, channel in ipairs({"r", "g", "b"}) do
      local value = tonumber(window.lcc_body.lcc_rgb["lcc_" .. channel].text)
      if not value or value < 0 or value > 255 or value % 1 ~= 0 then
        player.print({"lcc.invalid-rgb"})
        return
      end
      colour[channel] = value
    end
    colour.always_on = window.lcc_body.lcc_rgb.lcc_always_on.state
    colour.change_colour = window.lcc_body.lcc_rgb.lcc_change_colour.state
    colour.change_always_on = window.lcc_body.lcc_rgb.lcc_change_always_on.state
    colour.gradient = window.lcc_body.lcc_gradient.state
    local skip_circuit = window.lcc_body.lcc_rgb.lcc_skip_circuit or window.lcc_body.lcc_skip_circuit
    colour.skip_circuit = skip_circuit and skip_circuit.state or false
    local gradient = window.lcc_body.lcc_gradient_options
    local start_hex = gradient.lcc_start_hex.text
    colour.gradient_start = parse_hex(start_hex)
    colour.gradient_end = parse_hex(gradient.lcc_end_hex.text)
    colour.gradient_direction = gradient.lcc_direction.selected_index
    if colour.gradient and colour.change_colour and
      (not colour.gradient_end or (start_hex ~= "" and not colour.gradient_start)) then
      player.print({"lcc.invalid-hex"}); return
    end
    if not colour.change_colour and not colour.change_always_on then player.print({"lcc.no-changes"}); return end
    storage.lcc_players[player.index] = colour
    if not player.clear_cursor() then player.print({"lcc.cursor-full"}); return end
    if player.cursor_stack and player.cursor_stack.set_stack{name = "lcc-tool", count = 1} then
      close(player)
    end
  end
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
  local player = game.get_player(event.player_index)
  local window = player.gui.screen[WINDOW]
  local element = event.element
  if not window or not element.valid then return end
  if element.name == "lcc_gradient" and element == window.lcc_body.lcc_gradient then
    show_gradient(window.lcc_body, element.state)
    state(player.index).gradient = element.state
  end
  if element.name == "lcc_always_on" and element == window.lcc_body.lcc_rgb.lcc_always_on then
    state(player.index).always_on = element.state
  end
  for _, key in ipairs({"change_colour", "change_always_on"}) do
    if element.name == "lcc_" .. key and element == window.lcc_body.lcc_rgb["lcc_" .. key] then
      state(player.index)[key] = element.state
    end
  end
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
  local player = game.get_player(event.player_index)
  local window = player.gui.screen[WINDOW]
  if not window or not event.element.valid then return end
  if event.element.name == "lcc_hex" then
    local colour = parse_hex(event.element.text)
    if not colour then return end
    for _, channel in ipairs({"r", "g", "b"}) do
      window.lcc_body.lcc_rgb["lcc_" .. channel].text = tostring(colour[channel])
      window.lcc_body.lcc_rgb["lcc_slider_" .. channel].slider_value = colour[channel]
    end
    update_preview(window, colour)
    return
  end
  if event.element.name == "lcc_favourite_name" then
    local id = event.element.tags.lcc_favourite_id
    for _, favourite in ipairs(favourites(player.index).colours) do
      if favourite.id == id then
        local name = event.element.text:match("^%s*(.-)%s*$")
        if name ~= "" then favourite.name = name end
        break
      end
    end
    return
  end
  if not ({lcc_r = true, lcc_g = true, lcc_b = true})[event.element.name] then return end
  local colour = {}
  for _, channel in ipairs({"r", "g", "b"}) do
    local value = tonumber(window.lcc_body.lcc_rgb["lcc_" .. channel].text)
    if not value or value < 0 or value > 255 or value % 1 ~= 0 then return end
    colour[channel] = value
  end
  for _, channel in ipairs({"r", "g", "b"}) do
    window.lcc_body.lcc_rgb["lcc_slider_" .. channel].slider_value = colour[channel]
  end
  update_preview(window, colour)
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
  local player = game.get_player(event.player_index)
  local window = player.gui.screen[WINDOW]
  local element = event.element
  if not window or not element.valid then return end
  local channel = ({lcc_slider_r = "r", lcc_slider_g = "g", lcc_slider_b = "b"})[element.name]
  if not channel or element ~= window.lcc_body.lcc_rgb["lcc_slider_" .. channel] then return end
  local rgb = window.lcc_body.lcc_rgb
  rgb["lcc_" .. channel].text = tostring(math.floor(element.slider_value + 0.5))
  local colour = {}
  for _, key in ipairs({"r", "g", "b"}) do
    colour[key] = rgb["lcc_slider_" .. key].slider_value
    rgb["lcc_" .. key].text = tostring(math.floor(colour[key] + 0.5))
  end
  update_preview(window, colour)
end)

script.on_event(defines.events.on_gui_closed, function(event)
  if event.element and event.element.valid and event.element.name == WINDOW then
    close(game.get_player(event.player_index))
  end
end)

local function paint(event)
  if event.item == "lcc-eyedropper" then
    local player = game.get_player(event.player_index)
    if #event.entities ~= 1 then player.print({"lcc.pick-one"}); return end
    local entity = event.entities[1]
    if not is_lamp(entity) or entity.force ~= player.force then return end
    local control = entity.get_control_behavior()
    local sampled = (control and control.use_colors and control.color) or entity.color
    if not sampled then player.print({"lcc.no-sample"}); return end
    local colour = state(player.index)
    for _, channel in ipairs({"r", "g", "b"}) do
      colour[channel] = math.max(0, math.min(255, math.floor(sampled[channel] * 255 + 0.5)))
    end
    player.clear_cursor()
    open(player)
    return
  end
  if event.item ~= "lcc-tool" then return end
  local player = game.get_player(event.player_index)
  if not player or not player.valid or player.controller_type == defines.controllers.spectator then return end
  local colour = state(player.index)
  local count = 0
  local history = {}
  local lamps, ghosts = 0, 0
  local skipped = 0
  local targets = {}
  if colour.change_colour == false and colour.change_always_on == false then player.print({"lcc.no-changes"}); return end
  for _, entity in ipairs(event.entities) do
    if is_lamp(entity) and entity.force == player.force then
      local control = colour.skip_circuit and entity.get_control_behavior()
      if control and (control.use_colors or control.circuit_enable_disable) then
        skipped = skipped + 1
      else
        targets[#targets + 1] = entity
      end
    end
  end
  local direction = colour.gradient_direction or 1
  local centre
  local function coordinate(position)
    if direction == 2 then return position.y end
    if direction == 3 then return position.x + position.y end
    if direction == 4 then return position.x - position.y end
    if direction == 5 then
      local dx, dy = position.x - centre.x, position.y - centre.y
      return math.sqrt(dx * dx + dy * dy)
    end
    return position.x
  end
  local low, high
  if colour.gradient and colour.change_colour ~= false then
    if direction == 5 and #targets > 0 then
      local first = targets[1].position
      local min_x, max_x, min_y, max_y = first.x, first.x, first.y, first.y
      for _, entity in ipairs(targets) do
        local position = entity.position
        min_x, max_x = math.min(min_x, position.x), math.max(max_x, position.x)
        min_y, max_y = math.min(min_y, position.y), math.max(max_y, position.y)
      end
      centre = {x = (min_x + max_x) / 2, y = (min_y + max_y) / 2}
    end
    for _, entity in ipairs(targets) do
      local position = coordinate(entity.position)
      low = direction == 5 and 0 or (low and math.min(low, position) or position)
      high = high and math.max(high, position) or position
    end
  end
  for _, entity in ipairs(targets) do
    local entry = {entity = entity}
    if colour.change_colour ~= false then
      local control = entity.get_or_create_control_behavior()
      local old = entity.color or {r = 1, g = 1, b = 1, a = 1}
      entry.colour = {r = old.r, g = old.g, b = old.b, a = old.a}
      entry.use_colors = control and control.use_colors or false
      if control then control.use_colors = false end
      local result = {a = 1}
      local ratio = low and high > low and (coordinate(entity.position) - low) / (high - low) or 0
      local start = colour.gradient and colour.gradient_start or colour
      local endpoint = colour.gradient and colour.gradient_end or start
      endpoint = endpoint or colour
      for _, channel in ipairs({"r", "g", "b"}) do
        result[channel] = (start[channel] + (endpoint[channel] - start[channel]) * ratio) / 255
      end
      entity.color = result
    end
    if colour.change_always_on ~= false then
      entry.always_on = entity.always_on
      entity.always_on = colour.always_on == true
    end
    history[#history + 1] = entry
    count = count + 1
    if entity.type == "entity-ghost" then ghosts = ghosts + 1 else lamps = lamps + 1 end
  end
  if count > 0 then
    local stack = undo_stack(player.index)
    stack[#stack + 1] = history
    if #stack > 20 then table.remove(stack, 1) end
    if storage.lcc_redo then storage.lcc_redo[player.index] = nil end
    refresh_undo(player)
  end
  local colour_summary = colour.change_colour == false and {"lcc.unchanged"} or
    (colour.gradient and {"lcc.gradient"} or {"lcc.solid-colour"})
  local on_summary = colour.change_always_on == false and {"lcc.unchanged"} or
    (colour.always_on and {"lcc.on"} or {"lcc.day-night"})
  player.print({"lcc.selection-summary", count, lamps, ghosts, colour_summary, on_summary, skipped})
end
script.on_event(defines.events.on_player_selected_area, paint)
script.on_event(defines.events.on_player_alt_selected_area, paint)
script.on_event(defines.events.on_player_removed, function(event)
  local lamp = storage.lcc_previews and storage.lcc_previews[event.player_index]
  if lamp and lamp.valid then lamp.destroy() end
  if storage.lcc_previews then storage.lcc_previews[event.player_index] = nil end
  if storage.lcc_players then storage.lcc_players[event.player_index] = nil end
  if storage.lcc_favourites then storage.lcc_favourites[event.player_index] = nil end
  if storage.lcc_undo then storage.lcc_undo[event.player_index] = nil end
  if storage.lcc_redo then storage.lcc_redo[event.player_index] = nil end
end)

