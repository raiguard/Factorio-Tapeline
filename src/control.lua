-- ----------------------------------------------------------------------------------------------------
-- TAPELINE CONTROL SCRIPTING

-- debug adapter
pcall(require,'__debugadapter__/debugadapter.lua')

local event = require('lualib/event')
local draw_gui = require('scripts/gui/draw')
local edit_gui = require('scripts/gui/edit')
local mod_gui = require('mod-gui')
local select_gui = require('scripts/gui/select')
local tilegrid = require('scripts/tilegrid')
local util = require('lualib/util')

-- GLOBAL WIDTH VARIABLE: sets the width for all GUI windows so they're all the same
gui_window_width = 252

-- --------------------------------------------------
-- LOCAL UTILITIES

local abs = math.abs
local floor = math.floor
local TEMP_TILEGRID_CLEAR_DELAY = 60

local function setup_player(index)
  local data = {}
  data.settings = {
    auto_clear = true,
    cardinals_only = true,
    grid_type = 1,
    increment_divisor = 5,
    split_divisor = 4,
    log_to_chat = game.get_player(index).mod_settings['log-selection-area'].value
  }
  data.gui = {}
  data.cur_drawing = false
  data.cur_editing = false
  data.cur_selecting = false
  data.cur_adjusting = false
  data.tutorial_shown = false
  data.last_capsule_tile = nil -- doesn't have an initial value, but here for reference
  data.last_capsule_tick = 0
  global.players[index] = data
end

-- --------------------------------------------------
-- CONDITIONAL HANDLERS

-- finish drawing tilegrids, perish tilegrids
local function draw_on_tick(e)
  local cur_tick = game.tick
  local end_wait = global.end_wait
  local drawing = global.tilegrids.drawing
  local perishing = global.tilegrids.perishing
  for i,t in pairs(drawing) do
    if t.last_capsule_tick + end_wait < cur_tick then
      -- finish up tilegrid
      local player_table = global.players[t.player_index]
      local registry = global.tilegrids.registry[i]
      player_table.cur_drawing = false
      -- if the grid is 1x1, just delete it
      if registry.area.width == 1 and registry.area.height == 1 then
        tilegrid.destroy(i)
      else
        if registry.settings.auto_clear then
          -- add to perishing table
          perishing[i] = cur_tick + TEMP_TILEGRID_CLEAR_DELAY
        else
          -- add to editable table
          global.tilegrids.editable[i] = {area=registry.area, surface_index=t.surface_index}
        end
      end
      drawing[i] = nil
    end
  end
  for i,tick in pairs(perishing) do
    if cur_tick >= tick then
      tilegrid.destroy(i)
      perishing[i] = nil
    end
  end
  if table_size(drawing) == 0 and table_size(perishing) == 0 then
    event.deregister(defines.events.on_tick, draw_on_tick, 'draw_on_tick')
  end
end

-- tapeline draw draws a new tilegrid
local function on_draw_capsule(e)
  if e.item.name ~= 'tapeline-draw' then return end
  local player_table = global.players[e.player_index]
  local cur_tile = {x=floor(e.position.x), y=floor(e.position.y)}
  -- check if currently drawing
  if player_table.cur_drawing then
    local drawing = global.tilegrids.drawing[player_table.cur_drawing]
    local registry = global.tilegrids.registry[player_table.cur_drawing]
    local prev_tile = drawing.last_capsule_pos
    drawing.last_capsule_tick = game.ticks_played
    -- if cardinals only, adjust thrown position
    if registry.settings.cardinals_only then
      local origin = registry.area.origin
      if abs(cur_tile.x - origin.x) >= abs(cur_tile.y - origin.y) then
        cur_tile.y = floor(origin.y)
      else
        cur_tile.x = floor(origin.x)
      end
    end
    -- if the current tile position differs from the last known tile position
    if prev_tile.x ~= cur_tile.x or prev_tile.y ~= cur_tile.y then
      -- update existing tilegrid
      drawing.last_capsule_pos = cur_tile
      tilegrid.update(player_table.cur_drawing, cur_tile, drawing, registry)
    end
  else
    -- create new tilegrid
    player_table.cur_drawing = global.next_tilegrid_index
    global.next_tilegrid_index = global.next_tilegrid_index + 1
    tilegrid.construct(player_table.cur_drawing, cur_tile, e.player_index, game.get_player(e.player_index).surface.index)
    -- register on_tick
    if not event.is_registered('draw_on_tick') then
      event.on_tick(draw_on_tick, 'draw_on_tick')
    end
  end
end

-- tapeline edit lets you edit the tilegrid that was clicked on
local function on_edit_capsule(e)
  if e.item.name ~= 'tapeline-edit' then return end
  local player_table = global.players[e.player_index]
  local cur_tile = {x=floor(e.position.x), y=floor(e.position.y)}
  -- to avoid spamming messages, check against last tile position
  local prev_tile = player_table.last_capsule_tile
  if prev_tile and prev_tile.x == cur_tile.x and prev_tile.y == cur_tile.y then return end
  player_table.last_capsule_tile = cur_tile
  -- loop through the editable table to see if we clicked on a tilegrid
  local player = game.get_player(e.player_index)
  local surface_index = player.surface.index
  local clicked_on = {}
  for i,t in pairs(global.tilegrids.editable) do
    if t.surface_index == surface_index and util.area.contains_point(t.area, e.position) then
      table.insert(clicked_on, i)
    end
  end
  local size = table_size(clicked_on)
  if size == 0 then
    player.surface.create_entity{
      name = 'flying-text',
      position = e.position,
      text = {'tl.click-on-tilegrid'},
      render_player_index = e.player_index
    }
    return
  elseif size == 1 then
    -- skip selection dialog
    local tilegrid_registry = global.tilegrids.registry[clicked_on[1]]
    local elems, last_value = edit_gui.create(mod_gui.get_frame_flow(player), e.player_index, tilegrid_registry.settings, tilegrid_registry.hot_corner)
    player_table.cur_editing = clicked_on[1]
    -- create highlight box
    local area = global.tilegrids.registry[clicked_on[1]].area
    local highlight_box = player.surface.create_entity{
      name = 'highlight-box',
      position = area.left_top,
      bounding_box = util.area.expand(area, 0.25),
      render_player_index = e.player_index,
      player = e.player_index,
      blink_interval = 30
    }
    player_table.gui.edit = {elems=elems, highlight_box=highlight_box, last_divisor_value=last_value}
  else
    -- show selection dialog
    select_gui.populate_listbox(e.player_index, clicked_on)
    player_table.cur_selecting = true
  end
  player.clean_cursor()
end

-- tapeline adjust lets you drag an existing tilegrid around to move it
local function on_adjust_capsule(e)
  if e.item.name ~= 'tapeline-adjust' then return end
  local player_table = global.players[e.player_index]
  local registry = global.tilegrids.registry[player_table.cur_editing]
  local cur_tile = {x=floor(e.position.x), y=floor(e.position.y)}
  if game.tick - player_table.last_capsule_tick > global.end_wait then
    player_table.last_capsule_tile = nil
  end
  local prev_tile = player_table.last_capsule_tile
  if prev_tile == nil then
    -- check if the player is actually on the grid
    if util.area.contains_point(registry.area, cur_tile) then
      player_table.last_capsule_tile = cur_tile
    end
  else
    -- check if grid should be moved
    if not util.position.equals(cur_tile, prev_tile) then
      -- calculate vector
      local vector = util.position.subtract(cur_tile, prev_tile)
      -- apply to area and recreate constants
      local area = util.area.additional_data{
        left_top = util.position.add(registry.area.left_top, vector),
        right_bottom = util.position.add(registry.area.right_bottom, vector),
        origin = util.position.add(registry.area.origin, vector)
      }
      registry.area = area
      tilegrid.refresh(player_table.cur_editing)
      -- move highlight box
      local gui_data = player_table.gui.edit
      local highlight_box = gui_data.highlight_box.surface.create_entity{
        name = 'highlight-box',
        position = area.left_top,
        bounding_box = util.area.expand(area, 0.25),
        render_player_index = e.player_index,
        player = e.player_index,
        blink_interval = 30
      }
      gui_data.highlight_box.destroy()
      gui_data.highlight_box = highlight_box
      -- update capsule tile
      player_table.last_capsule_tile = cur_tile
      -- update area in editable registry
      global.tilegrids.editable[player_table.cur_editing].area = area
    end
  end
  player_table.last_capsule_tick = game.tick
end

-- dismiss the tutorial speech bubble when the player throws one of our capsules
local function on_capsule_after_tutorial(e)
  local name = e.item.name
  if name == 'tapeline-draw' or name == 'tapeline-edit' or name == 'tapeline-adjust' then
    local player_table = global.players[e.player_index]
    local bubble = player_table.bubble
    if bubble and bubble.valid then
      if bubble.valid then
        bubble.start_fading_out()
      end
      player_table.bubble = nil
      event.deregister_conditional(on_capsule_after_tutorial, {name='on_capsule_after_tutorial', player_index=e.player_index})
    end
  end
end

-- --------------------------------------------------
-- STATIC HANDLERS

event.on_init(function()
  -- setup global
  global.tilegrids = {
    drawing = {},
    editable = {},
    perishing = {},
    registry = {}
  }
  global.players = {}
  global.next_tilegrid_index = 1
  -- set end_wait for a singleplayer game
  global.end_wait = 3
  -- create player data for any existing players
  for i,player in pairs(game.players) do
    setup_player(i)
  end
end)

event.on_load(function()
  -- re-register conditional handlers if needed
  event.load_conditional_handlers{
    draw_on_tick = draw_on_tick,
    on_draw_capsule = on_draw_capsule,
    on_edit_capsule = on_edit_capsule,
    on_adjust_capsule = on_adjust_capsule
  }
end)

-- when a player's cursor stack changes
event.on_player_cursor_stack_changed(function(e)
  local player_table = global.players[e.player_index]
  local player = game.get_player(e.player_index)
  local stack = player.cursor_stack
  local player_gui = player_table.gui
  -- draw capsule
  if stack and stack.valid_for_read and stack.name == 'tapeline-draw' then
    -- because sometimes it doesn't work properly?
    if player_gui.draw then return end
    -- if the player is currently selecting, don't let them hold a capsule
    if player_table.cur_selecting then
      player.clean_cursor()
      player.print{'chat-message.finish-selection-first'}
      return
    end
    if player_table.tutorial_shown == false then
      -- show tutorial window
      player_table.tutorial_shown = true
      player_table.bubble = player.surface.create_entity{
        name = 'compi-speech-bubble',
        position = player.position,
        text = {'tl.tutorial-text'},
        source = player.character
      }
      event.on_player_used_capsule(on_capsule_after_tutorial, {name='on_capsule_after_tutorial', player_index=e.player_index})
    end
    local elems, last_value = draw_gui.create(mod_gui.get_frame_flow(player), player.index, player_table.settings)
    player_gui.draw = {elems=elems, last_divisor_value=last_value}
    event.on_player_used_capsule(on_draw_capsule, 'on_draw_capsule', e.player_index)
  elseif player_gui.draw then
    draw_gui.destroy(player_table.gui.draw.elems.window, player.index)
    player_gui.draw = nil
    event.deregister(defines.events.on_player_used_capsule, on_draw_capsule, 'on_draw_capsule', e.player_index)
  end
  -- edit capsule
  if stack and stack.valid_for_read and stack.name == 'tapeline-edit' then
    -- because sometimes it doesn't work properly?
    if player_gui.select then return end
    local elems = select_gui.create(mod_gui.get_frame_flow(player), player.index)
    player_gui.select = {elems=elems}
    event.on_player_used_capsule(on_edit_capsule, 'on_edit_capsule', e.player_index)
  elseif player_gui.select and not player_table.cur_selecting then
    select_gui.destroy(player_gui.select.elems.window, player.index)
    player_gui.select = nil
    player_table.last_capsule_tile = nil
    event.deregister(defines.events.on_player_used_capsule, on_edit_capsule, 'on_edit_capsule', e.player_index)
  end
  -- adjust capsule
  if stack and stack.valid_for_read and stack.name == 'tapeline-adjust' then
    player_table.cur_adjusting = true
    event.on_player_used_capsule(on_adjust_capsule, 'on_adjust_capsule', e.player_index)
  elseif player_table.cur_adjusting == true then
    player_table.cur_adjusting = false
    player_table.last_capsule_tile = nil
    event.deregister(defines.events.on_player_used_capsule, on_adjust_capsule, 'on_adjust_capsule', e.player_index)
  end
end)

event.on_player_created(function(e)
  setup_player(e.player_index)
end)

event.on_player_joined_game(function(e)
  -- check if game is multiplayer
  if game.is_multiplayer() then
    -- check if end_wait has already been adjusted
    if global.end_wait == 3 then
      global.end_wait = 60
      game.print{'chat-message.mp-latency-message'}
    end
  end
end)

-- scroll between the items when the player shift+scrolls
event.register({'tapeline-cycle-forwards', 'tapeline-cycle-backwards'}, function(e)
  local player = game.get_player(e.player_index)
  local stack = player.cursor_stack
  if stack and stack.valid_for_read then
    if stack.name == 'tapeline-draw' then
      player.cursor_stack.set_stack{name='tapeline-edit', count=1}
    elseif stack.name == 'tapeline-edit' then
      player.cursor_stack.set_stack{name='tapeline-draw', count=1}
    end
  end
end)

-- DEBUGGING
if __DebugAdapter then
  event.register('DEBUG-INSPECT-GLOBAL', function(e)
    local breakpoint -- put breakpoint here to inspect global at any time
  end)
end