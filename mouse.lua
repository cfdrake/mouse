-- ~ mouse ~
-- an instrument and sequencer inspired by music mouse
-- by: @cfd90
--
-- ENC1 x
-- ENC2 y
-- ENC3 clock division
-- KEY2 hold to mute, tap to retrigger
-- KEY3 toggle clock mod
--
-- KEY1 alt
--
-- ALT + ENC1 scale
-- ALT + ENC2 voice mode
-- ALT + ENC3 pattern index
-- ALT + KEY2 voice enable toggle
-- ALT + KEY3 pattern toggle

-----------------------------------
-- Includes
-----------------------------------

engine.name = "Thebangs"

local MusicUtil = require "musicutil"
local thebangs = include("thebangs/lib/thebangs_engine")
local lfo = include("lib/mouse_hnds")
local hs = include("lib/mouse_halfsecond")

-----------------------------------
-- State
-----------------------------------

-- Scale and params value helpers.
local scale = {}
local scale_names = {}
local note_names = {"c", "c#", "d", "d#", "e", "f", "f#", "g", "g#", "a", "a#", "b"}
local speeds = {1, 2, 4, 8}
local voice_modes = {"melody", "pairs"}
local output_options = {"thebangs", "midi", "thebangs + midi"}

-- Local sequencer state.
local x = 1
local y = 1
local last_x = 1
local last_y = 1
local mute = false
local is_alt_held = false
local input_mode = 1
local input_modes = {"norm", "1hand"}

-- MIDI and clock state.
local midi_x_out = nil
local midi_y_out = nil
local clock_id = nil

-- Grid state.
local g = nil

-- LFO targets.
local lfo_targets = {
  "none",
  "pw",
  "attack",
  "release",
  "cutoff",
  "pan",
  "delay",
  "delay_rate",
  "delay_feedback",
  "delay_pan"
}

-- Drawing vars.
local level_label = 15
local level_value = 3
local label_x = 68

-- Pattern state.
local pattern_counter_x = 1
local pattern_counter_y = 1
local patterns = {
  { x = { 0, 3 }, y = { 7, 3 } },
  { x = { 0, 4, 2 }, y = { 0, 3, 7, 3 } },
  { x = { 0, 0, 1, 1 }, y = { 0, 2, 4, 7 } },
  { x = { 0, 1, 4, 6 }, y = { 0, 5, 3, 4, 2, 1, 8 } },
  { x = { 0, 6, 0, 3, 3, 2, 2, 1 }, y = { 0, 2, 12, 14, 4, 2, 2 } },
}

-----------------------------------
-- Helpers
-----------------------------------

local bool_param_options={"yes", "no"}

local function string_for_bool_param(p)
  local val = params:get(p)
  
  return bool_param_options[val]
end

local function value_for_bool_param(p)
  local val = params:get(p)
  
  return val == 1
end

local function toggle_bool_param(p)
  local val = params:get(p)
  
  params:set(p, val == 2 and 1 or 2)
end

local function set_bool_param(p, val)
  params:set(p, val and 1 or 2)
end

local function scale_name(i, shorten)
  local name = string.lower(MusicUtil.SCALES[i].name)
  
  if shorten then
    name = name:gsub("[aeiou]", "")
  end
  
  return name
end

-----------------------------------
-- Initialization
-----------------------------------

local function build_scale()
  -- Lua indices start from 1, but root note transposition starts from zero.
  -- i.e. "c" is at index 1, but transposition amount should be 0.
  local scale_mode = params:get("scale_mode")
  local root_note = params:get("root_note") - 1
  
  scale = MusicUtil.generate_scale_of_length(root_note, string.lower(MusicUtil.SCALES[scale_mode].name), 127)
  
  x = math.floor(#scale/2)
  y = math.floor(#scale/2)
  
  last_x = x
  last_y = y
end

local function setup_scales()
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, scale_name(i, false))
  end
end

local function setup_midi()
  midi_x_out = midi.connect(params:get("midi_port_x"))
  midi_y_out = midi.connect(params:get("midi_port_y"))
end

local function setup_params()
  params:add_separator()
  params:add_group("MOUSE", 26)
  
  params:add_separator("scale")
  params:add{type="option", id="scale_mode", name="scale mode", options=scale_names, default=11, action=function() build_scale() end}
  params:add{type="option", id="root_note", name="root note", options=note_names, default=1, action=function() build_scale() end}
  params:add{type="number", id="transpose_interval", name="transposition interval", min=1, max=12, default=3}
  
  params:add_separator("clock")
  params:add{type="option", id="speed", name="clock division", options=speeds, default=3}
  params:add{type="option", id="speed_mod", name="modulate clock division", options=bool_param_options, default=2}
  
  params:add_separator("voices")
  params:add{type="option", id="voice_mode", name="voice mode", options=voice_modes, default=1}
  params:add{type="option", id="enables_1", name="voice 1 enabled", options=bool_param_options, default=1}
  params:add{type="option", id="enables_2", name="voice 2 enabled", options=bool_param_options, default=1}
  params:add{type="option", id="enables_3", name="voice 3 enabled", options=bool_param_options, default=1}
  params:add{type="option", id="enables_4", name="voice 4 enabled", options=bool_param_options, default=1}
  
  params:add_separator("patterns")
  params:add{type="option", id="running_pattern", name="pattern enabled", options=bool_param_options, default=2}
  params:add{type="number", id="pattern_index", name="selected pattern", min=1, max=#patterns, default=1}
  
  params:add_separator("output")
  params:add{type="option", id="output_mode", name="output mode", options=output_options, default=1}
  params:add{type="number", id="midi_port_x", name="midi port (x)", default=1, min=1, max=16, action=function(x) setup_midi() end}
  params:add{type="number", id="midi_channel_x", name="midi channel (x)", default=1, min=1, max=16}
  params:add{type="number", id="midi_note_length_x", name="midi note length (x)", default=100, min=1, max=1000}
  params:add{type="number", id="midi_note_probability_x", name="midi note probability (x)", default=100, min=1, max=100}
  params:add{type="number", id="midi_port_y", name="midi port (y)", default=1, min=1, max=16, action=function(x) setup_midi() end}
  params:add{type="number", id="midi_channel_y", name="midi channel (y)", default=1, min=1, max=16}
  params:add{type="number", id="midi_note_length_y", name="midi note length (y)", default=100, min=1, max=1000}
  params:add{type="number", id="midi_note_probability_y", name="midi note probability (y)", default=100, min=1, max=100}
  
  params:add_group("SYNTH", 14)
  
  params:add_separator("synth")
  thebangs.add_additional_synth_params()

  local cs_AMP = controlspec.new(0, 1, "lin", 0, 0.5, "")
  params:add{type="control", id="amp", controlspec=cs_AMP, action=function(x) engine.amp(x) end}

  local cs_PW = controlspec.new(0, 100, "lin", 0, 50, "%")
  params:add{type="control", id="pw", controlspec=cs_PW, action=function(x) engine.pw(x/100) end}

  local cs_REL = controlspec.new(0.1, 3.2, "lin", 0, 1.2, "s")
  params:add{type="control", id="release", controlspec=cs_REL, action=function(x) engine.release(x) end}

  local cs_CUT = controlspec.new(50, 12000, "exp", 0, 12000, "hz")
  params:add{type="control", id="cutoff", controlspec=cs_CUT, action=function(x) engine.cutoff(x) end}

  local cs_GAIN = controlspec.new(0, 4, "lin", 0, 1, "")
  params:add{type="control", id="gain", controlspec=cs_GAIN, action=function(x) engine.gain(x) end}
  
  local cs_PAN = controlspec.new(-1, 1, "lin", 0, 0, "")
  params:add{type="control", id="pan", controlspec=cs_PAN, action=function(x) engine.pan(x) end}

  params:add_separator("voice allocation")
  thebangs.add_voicer_params()
  
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  
  params:add_group("DELAY", 5)
  hs.init()
  
  params:add_group("LFOs", 28)
  lfo.init()
  
  params:bang()
end

local function setup_clock()
  clock_id = clock.run(tick)
end

local function setup_mouse()
  mouse = hid.connect()
  mouse.event = mouse_event
end

local function setup_grid()
  g = grid.connect()
  g.key = grid_key
  grid_redraw()
end

local function print_logo()
  msgs = {"cheese, please!", "meep", "have fun!"}
  
  print("  __QQ")
  print(" (_)_\"> ... welcome to mouse ...")
  print("_)            " ..  msgs[math.random(1, #msgs)])
end

function init()
  setup_scales()
  setup_params()
  build_scale()
  setup_midi()
  setup_clock()
  setup_grid()
  setup_mouse()  -- Revist this, a bit experimental and crazy at the moment.
  print_logo()
end

-----------------------------------
-- Playback
-----------------------------------

local function stop_note(note, mdev, ch, note_len)
  clock.sleep(note_len)
  mdev:note_off(note, nil, ch)
end

local function play_engine_note(note)
  local freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
end

local function play_midi_note(note, axis)
  local mdev = axis == "x" and midi_x_out or midi_y_out
  local ch = params:get("midi_channel_" .. axis)

  local user_note_len = params:get("midi_note_length_" .. axis) / 1000.0  -- ms to s
  local clock_pulse_len = (60.0 / params:get("clock_tempo")) - (1/10.0)  -- give some space
  local note_len = math.min(user_note_len, clock_pulse_len)

  local rand = math.random(1, 100)
  local prob = params:get("midi_note_probability_" .. axis)
  local should_trigger = rand <= prob

  if should_trigger then
    mdev:note_on(note, 100, ch)
    clock.run(stop_note, note, mdev, ch, note_len)
  end
end

local function play_note(note, axis)
  local output_mode = params:get("output_mode")
  
  if output_mode == 1 then
    play_engine_note(note)
  elseif output_mode == 2 then
    play_midi_note(note, axis)
  elseif output_mode == 3 then
    play_engine_note(note)
    play_midi_note(note, axis)
  end
end

local function allocate_and_play(tx, ty)
  local x = x
  local y = y
  
  local running_pattern = value_for_bool_param("running_pattern")
  local pattern_index = params:get("pattern_index")
  
  if running_pattern then
    local pattern = patterns[pattern_index]
  
    pattern_counter_x = pattern_counter_x + 1
    pattern_counter_y = pattern_counter_y + 1
    
    if pattern_counter_x > #pattern["x"] then
      pattern_counter_x = 1
    end
    
    if pattern_counter_y > #pattern["y"] then
      pattern_counter_y = 1
    end
  
    x = x + pattern["x"][pattern_counter_x]
    y = y + pattern["y"][pattern_counter_y]
    
    -- It seems like there could be a better place to put this.
    -- We just want to redraw here because there is a pattern advance.
    redraw()
  end
  
  local voice_mode = params:get("voice_mode")
  
  if voice_mode == 1 then
    -- Chords + melody allocation mode
    if tx then
      -- Play chord
      if value_for_bool_param("enables_1") then
        note = scale[x]
        play_note(note, "x")
      end
      
      if x + 2 <= #scale and value_for_bool_param("enables_2") then
        note = scale[x + 2]
        play_note(note, "x")
      end
      
      if x - 3 >= 1 and value_for_bool_param("enables_3") then
        note = scale[x - 3]
        play_note(note, "x")
      end
    end
    
    if ty then
      -- Play melody
      if value_for_bool_param("enables_4") then
        note = scale[y]
        play_note(note, "y")
      end
    end
  elseif voice_mode == 2 then
    -- Pairs allocation mode
    if tx then
      -- Play voice 1
      if value_for_bool_param("enables_1") then
        note = scale[x]
        play_note(note, "x")
      end
      
      if x + 4 <= #scale and value_for_bool_param("enables_2") then
        note = scale[x + 4]
        play_note(note, "x")
      end
    end
    
    if ty then
      -- Play voice 2
      if x - 3 >= 1 and value_for_bool_param("enables_3") then
        note = scale[y - 3]
        play_note(note, "y")
      end
      
      if value_for_bool_param("enables_4") then
        note = scale[y]
        play_note(note, "y")
      end
    end
  end
end

local function play(force)
  local tx = false
  local ty = false
  
  -- Skip play event if user has mute held
  if mute and not force then
    return
  end

  -- Determine if we need to trigger x and/or y
  if last_x ~= x or force then
    tx = true
    last_x = x
  end
  
  if last_y ~= y or force then
    ty = true
    last_y = y
  end
  
  allocate_and_play(tx, ty)
end

function tick()
  while true do
    if params:get("speed_mod") == 1 then
      -- Keep it musical...
      params:set("speed", math.random(2, #speeds - 1))
      redraw()
      grid_redraw()
    end
    
    local speed = params:get("speed")
    local rate = speeds[speed]
    clock.sync(1/rate)
    
    -- Is there a better place to put this logic?
    local force = value_for_bool_param("running_pattern") and not mute
    
    play(force)
  end
end

-----------------------------------
-- HID Input
-----------------------------------

function mouse_event(typ, code, val)
  val = util.clamp(val, -1, 1)

  if code == 0 then
    x = util.clamp(x + val, 1, #scale)
  elseif code == 1 then
    y = util.clamp(y - val, 1, #scale)
  elseif code == 272 then
    mute = not mute
  end
  
  redraw()
end

-----------------------------------
-- Grid Input
-----------------------------------

function grid_key(_x, _y, z)
  -- Momentary, does not require keypress.
  -- This allows for single-hand Grid and single-hand Norns use.
  if _y == 7 then
    if _x == 1 then
      input_mode = (z == 1 and 2 or 1)
    elseif _x == 2 then
      mute = (z == 1)
      
      if z == 1 then
        play(true)
      end
    end
  end

  if z == 1 then
    if _y == 1 then
      if _x >= 1 and _x <= 4 then
        toggle_bool_param("enables_" .. _x)
      elseif _x == 7 then
        params:set("voice_mode", 1)
      elseif _x == 8 then
        params:set("voice_mode", 2)
      end
    elseif _y == 2 then
      if _x == 1 then
        x = util.clamp(x - params:get("transpose_interval"), 1, #scale)
      elseif _x == 2 then
        y = util.clamp(y - params:get("transpose_interval"), 1, #scale)
      elseif _x == 7 then
        y = util.clamp(y + params:get("transpose_interval"), 1, #scale)
      elseif _x == 8 then
        x = util.clamp(x + params:get("transpose_interval"), 1, #scale)
      end
    elseif _y == 5 then
      if _x >= 1 and _x <= #speeds then
        params:set("speed", _x)
      elseif _x == 8 then
        toggle_bool_param("speed_mod")
      end
    elseif _y == 8 then
      if _x >= 1 and _x <= #patterns then
        params:set("pattern_index", _x)
        
        -- Reset pattern indices.
        pattern_counter_x = 1
        pattern_counter_y = 1
      elseif _x == 8 then
        toggle_bool_param("running_pattern")
      end
    end
  end
  
  redraw()
  grid_redraw()
end

function grid_redraw()
  g:all(0)
  
  g:led(1, 1, value_for_bool_param("enables_1") and 15 or 0)
  g:led(2, 1, value_for_bool_param("enables_2") and 15 or 0)
  g:led(3, 1, value_for_bool_param("enables_3") and 15 or 0)
  g:led(4, 1, value_for_bool_param("enables_4") and 15 or 0)
  g:led(7, 1, params:get("voice_mode") == 1 and 15 or 0)
  g:led(8, 1, params:get("voice_mode") == 2 and 15 or 0)
  
  g:led(1, 2, 15)
  g:led(2, 2, 15)
  g:led(7, 2, 15)
  g:led(8, 2, 15)
  
  g:led(1, 7, input_mode == 2 and 15 or 0)
  g:led(2, 7, mute and 15 or 0)
  
  g:led(params:get("speed"), 5, 15)
  g:led(8, 5, value_for_bool_param("speed_mod") and 15 or 0)
  
  g:led(params:get("pattern_index"), 8, 15)
  g:led(8, 8, value_for_bool_param("running_pattern") and 15 or 0)
  
  g:refresh()
end

-----------------------------------
-- Encoder / Button Input
-----------------------------------

function enc(n, d)
  if is_alt_held then
    if n == 1 then
      params:delta("scale_mode", d)
    elseif n == 2 then
      params:delta("voice_mode", d)
    elseif n == 3 then
      params:delta("pattern_index", d)
    end
  else
    if n == 1 then
      if input_mode == 1 then
        -- Set x coordinate
        x = util.clamp(x + d, 1, #scale)
      else
        -- Set y coordinate
        y = util.clamp(y + d, 1, #scale)
      end
    elseif n == 2 then
      if input_mode == 1 then
        -- Set y coordinate
        y = util.clamp(y + d, 1, #scale)
      end
    elseif n == 3 then
      -- Clock division
      params:delta("speed", d)
    end
  end
  
  redraw()
  grid_redraw()
end

function key(n, z)
  if n == 1 then
    is_alt_held = (z == 1)
  end
  
  if is_alt_held then
    if n == 2 and z == 1 then
      -- If all enabled, switch to one melody one chord.
      -- If one melody one chord, switch to all enabled.
      -- If user-customized state, switch to all enabled.
      local enables_1 = value_for_bool_param("enables_1")
      local enables_2 = value_for_bool_param("enables_2")
      local enables_3 = value_for_bool_param("enables_3")
      local enables_4 = value_for_bool_param("enables_4")
      
      if enables_1 and enables_2 and enables_3 and enables_4 then
        set_bool_param("enables_1", true)
        set_bool_param("enables_2", false)
        set_bool_param("enables_3", false)
        set_bool_param("enables_4", true)
      else
        set_bool_param("enables_1", true)
        set_bool_param("enables_2", true)
        set_bool_param("enables_3", true)
        set_bool_param("enables_4", true)
      end
    elseif n == 3 and z == 1 then
      toggle_bool_param("running_pattern")
    end
  else
    if n == 2 then
      if z == 1 then
        -- Enable mute
        mute = true
      else
        -- Disable mute, trigger note
        mute = false
        play(true)
      end
    elseif n == 3 and z == 1 then
      -- Toggle clock mod
      toggle_bool_param("speed_mod")
    end
  end
  
  redraw()
  grid_redraw()
end

-----------------------------------
-- Drawing
-----------------------------------

local function draw_cursor()
  local cursor_size = 63
  local cursor_box_size = 4
  local cursor_x = 1 + (x/#scale) * cursor_size
  local cursor_y = 1 + cursor_size - (y/#scale) * cursor_size
  
  -- Draw vertical line
  screen.level(1)
  screen.move(cursor_x, 1)
  screen.line(cursor_x, cursor_size)
  screen.stroke()
  
  -- Draw horizontal line
  screen.move(1, cursor_y)
  screen.line(cursor_size, cursor_y)
  screen.stroke()
  
  -- Draw cursor
  if not mute then
    screen.level(15)
    screen.stroke()
    screen.rect(cursor_x - cursor_box_size/2, cursor_y - cursor_box_size/2, cursor_box_size, cursor_box_size)
    screen.stroke()
  end
end

local function draw_default_params()
  local running_pattern = value_for_bool_param("running_pattern")
  local pattern_index = params:get("pattern_index")
  local speed = params:get("speed")
  
  screen.move(label_x, 10)
  screen.level(level_label)
  screen.text("x: ")
  screen.level(level_value)
  screen.text(MusicUtil.note_num_to_name(scale[x]))
  
  if running_pattern then
    screen.text(patterns[pattern_index]["x"][pattern_counter_x])
  end
  
  screen.move(label_x + 34, 10)
  screen.level(level_label)
  screen.text("y: ")
  screen.level(level_value)
  screen.text(MusicUtil.note_num_to_name(scale[y]))
  
  if running_pattern then
    screen.text(patterns[pattern_index]["y"][pattern_counter_y])
  end
  
  screen.move(label_x, 20)
  screen.level(level_label)
  screen.text("div: ")
  screen.level(level_value)
  screen.text("x" .. speeds[speed])
  
  screen.move(label_x, 30)
  screen.level(level_label)
  screen.text("mute: ")
  screen.level(level_value)
  screen.text(mute and "y" or "n")
  
  screen.move(label_x, 40)
  screen.level(level_label)
  screen.text("divmod: ")
  screen.level(level_value)
  screen.text(string_for_bool_param("speed_mod"))
  
  screen.move(label_x, 50)
  screen.level(level_label)
  screen.text("input:")
  
  screen.move(label_x, 60)
  screen.level(level_value)
  screen.text(input_modes[input_mode])
end

function draw_alt_params()
  local voice_mode = params:get("voice_mode")
  local pattern_index = params:get("pattern_index")
  
  screen.move(label_x, 10)
  screen.level(level_label)
  screen.text("scale: ")
  screen.level(level_value)
  screen.text(scale_name(params:get("scale_mode"), true))
  
  screen.move(label_x, 20)
  screen.level(level_label)
  screen.text("mode: ")
  screen.level(level_value)
  screen.text(voice_modes[voice_mode])
  
  screen.move(label_x, 30)
  screen.level(level_label)
  screen.text("ptn #: ")
  screen.level(level_value)
  screen.text(pattern_index)
  
  screen.move(label_x, 40)
  screen.level(level_label)
  screen.text("voices: ")
  screen.level(level_value)
  screen.text(value_for_bool_param("enables_1") and "1" or "")
  screen.text(value_for_bool_param("enables_2") and "2" or "")
  screen.text(value_for_bool_param("enables_3") and "3" or "")
  screen.text(value_for_bool_param("enables_4") and "4" or "")
  
  screen.move(label_x, 50)
  screen.level(level_label)
  screen.text("ptn running: ")
  screen.level(level_value)
  screen.text(string_for_bool_param("running_pattern"))
end

function draw_params()
  if is_alt_held then
    draw_alt_params()
  else
    draw_default_params()
  end
end

function draw_mouse_or_alt()
  if is_alt_held then
    screen.level(1)
    screen.move(112, 64)
    screen.text("[alt]")
  else
    screen.level(15)
    screen.move(97, 51)
    screen.text("  __QQ")
    screen.move(96, 58)
    screen.text("  (_)_\">")
    screen.move(96, 64)
    screen.text(" _)")
  end
end

function redraw()
  screen.clear()
  draw_mouse_or_alt()
  draw_cursor()
  draw_params()
  screen.update()
end

-----------------------------------
-- LFO Management
-----------------------------------

function lfo.process()
  for i=1,4 do
    local target = params:get(i .. "lfo_target")

    if params:get(i .. "lfo") == 2 then
      -- LFOs run from -1 to 1. Params which do not take this range
      -- (i.e. not pan) need to be scaled to their respective ranges.
      
      if target == 2 then
        params:set("pw", lfo.scale(lfo[i].slope, -1, 1, 0, 100))
      elseif target == 3 then
        params:set("attack", lfo.scale(lfo[i].slope, -1, 1, 0.0001, 1))
      elseif target == 4 then
        params:set("release", lfo.scale(lfo[i].slope, -1, 1, 0.1, 3.2))
      elseif target == 5 then
        params:set("cutoff", lfo.scale(lfo[i].slope, -1, 1, 50, 5000))
      elseif target == 6 then
        params:set("pan", lfo[i].slope)
      elseif target == 7 then
        params:set("delay", lfo.scale(lfo[i].slope, -1, 1, 0, 1))
      elseif target == 8 then
        params:set("delay_rate", lfo.scale(lfo[i].slope, -1, 1, 0.5, 2))
      elseif target == 9 then
        params:set("delay_feedback", lfo.scale(lfo[i].slope, -1, 1, 0, 1))
      elseif target == 10 then
        params:set("delay_pan", lfo[i].slope)
      end
    end
  end
end