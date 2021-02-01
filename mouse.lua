-- ~ mouse ~
-- music mouse inspired instrument and sequencer
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
-- ALT + ENC1 voice mode
-- ALT + ENC2 enable voices
-- ALT + ENC3 tranpose amount (?)
-- ALT + KEY2 transpose down (?)
-- ALT + KEY3 transpose up (?)

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

local scale = {}
local scale_names = {}

local x = 1
local y = 1
local last_x = 1
local last_y = 1
local mute = false

local speed = 3
local speeds = {1, 2, 4, 8}
local speed_mod = false

local enables = {true, true, true, true}

local clock_id = nil

local voice_mode = 1
local voice_modes = {"melody", "pairs"}

local lfo_targets = {
  "none",
  "pw",
  "release",
  "cutoff",
  "pan",
  "delay",
  "delay_rate",
  "delay_feedback",
  "delay_pan"
}

local is_alt_held = false

local level_label = 15
local level_value = 3
local label_x = 68

-----------------------------------
-- Initialization
-----------------------------------

local function build_scale()
  scale = MusicUtil.generate_scale_of_length(0, string.lower(MusicUtil.SCALES[params:get("scale_mode")].name), 127)
  
  x = math.floor(#scale/2)
  y = math.floor(#scale/2)
  
  last_x = x
  last_y = y
end

local function scale_name(i, shorten)
  local name = string.lower(MusicUtil.SCALES[i].name)
  
  if shorten then
    name = name:gsub("[aeiou]", "")
  end
  
  return name
end

local function setup_scales()
  for i = 1, #MusicUtil.SCALES do
    table.insert(scale_names, scale_name(i, false))
  end
end

local function setup_params()
  params:add_separator("mouse")
  
  params:add{type="option", id="scale_mode", name="scale mode", options=scale_names, default=11, action=function() build_scale() end}
  
  params:add{type="option", id="voice_mode", name="voice mode", options=voice_modes, default=1, action=function(x) voice_mode = x end}
  
  params:add{type="option", id="enables_1", name="voice 1 enabled", options={"no", "yes"}, default=2, action=function(x) enables[1] = (x == 2) end}
  params:add{type="option", id="enables_2", name="voice 2 enabled", options={"no", "yes"}, default=2, action=function(x) enables[2] = (x == 2) end}
  params:add{type="option", id="enables_3", name="voice 3 enabled", options={"no", "yes"}, default=2, action=function(x) enables[3] = (x == 2) end}
  params:add{type="option", id="enables_4", name="voice 4 enabled", options={"no", "yes"}, default=2, action=function(x) enables[4] = (x == 2) end}
  
  params:add_separator("synth")
  thebangs.add_additional_synth_params()

  local cs_AMP = controlspec.new(0, 1, "lin", 0, 0.5, "")
  params:add{type="control", id="amp", controlspec=cs_AMP, action=function(x) engine.amp(x) end}

  local cs_PW = controlspec.new(0, 100, "lin", 0, 50, "%")
  params:add{type="control", id="pw", controlspec=cs_PW, action=function(x) engine.pw(x/100) end}

  local cs_REL = controlspec.new(0.1, 3.2, "lin", 0, 1.2, "s")
  params:add{type="control", id="release", controlspec=cs_REL, action=function(x) engine.release(x) end}

  local cs_CUT = controlspec.new(50, 5000, "exp", 0, 800, "hz")
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
  
  hs.init()
  lfo.init()
end

local function setup_clock()
  clock_id = clock.run(tick)
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
  setup_clock()
  print_logo()
end

-----------------------------------
-- Playback
-----------------------------------

local function play_note(note)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
end

local function allocate_and_play(tx, ty)
  if voice_mode == 1 then
    -- Chords + melody allocation mode
    if tx then
      -- Play chord
      if enables[1] then
        note = scale[x]
        play_note(note)
      end
      
      if x + 2 <= #scale and enables[2] then
        note = scale[x + 2]
        play_note(note)
      end
      
      if x - 3 >= 1 and enables[3] then
        note = scale[x - 3]
        play_note(note)
      end
    end
    
    if ty then
      -- Play melody
      if enables[4] then
        note = scale[y]
        play_note(note)
      end
    end
  elseif voice_mode == 2 then
    -- Pairs allocation mode
    if tx then
      -- Play voice 1
      if enables[1] then
        note = scale[x]
        play_note(note)
      end
      
      if x + 4 <= #scale and enables[2] then
        note = scale[x + 4]
        play_note(note)
      end
    end
    
    if ty then
      -- Play voice 2
      if x - 3 >= 1 and enables[3] then
        note = scale[y - 3]
        play_note(note)
      end
      
      if enables[4] then
        note = scale[y]
        play_note(note)
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
    if speed_mod then
      -- Keep it musical...
      speed = math.random(2, #speeds - 1)
      redraw()
    end
    
    local rate = speeds[speed]
    clock.sync(1/rate)
    
    play(false)
  end
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
      print("todo")
    end
  else
    if n == 1 then
      -- Set x coordinate
      x = util.clamp(x + d, 1, #scale)
    elseif n == 2 then
      -- Set y coordinate
      y = util.clamp(y + d, 1, #scale)
    elseif n == 3 then
      -- Clock division
      speed = util.clamp(speed + d, 1, #speeds)
    end
  end
  
  redraw()
end

function key(n, z)
  if n == 1 then
    is_alt_held = (z == 1)
  end
  
  if is_alt_held then
    if n == 2 then
      print("todo")
    elseif n == 3 then
      print("todo")
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
      speed_mod = not speed_mod
    end
  end
  
  redraw()
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
  screen.move(label_x, 10)
  screen.level(level_label)
  screen.text("x: ")
  screen.level(level_value)
  screen.text(MusicUtil.note_num_to_name(scale[x]))
  
  screen.move(label_x + 30, 10)
  screen.level(level_label)
  screen.text("y: ")
  screen.level(level_value)
  screen.text(MusicUtil.note_num_to_name(scale[y]))
  
  screen.move(label_x, 20)
  screen.level(level_label)
  screen.text("div: ")
  screen.level(level_value)
  screen.text("1/" .. speeds[speed])
  
  screen.move(label_x, 30)
  screen.level(level_label)
  screen.text("mute: ")
  screen.level(level_value)
  screen.text(mute and "y" or "n")
  
  screen.move(label_x, 40)
  screen.level(level_label)
  screen.text("divmod: ")
  screen.level(level_value)
  screen.text(speed_mod and "y" or "n")
end

function draw_alt_params()
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
  screen.text("voices: ")
  screen.level(level_value)
  screen.text(enables[1] and "1" or "")
  screen.text(enables[2] and "2" or "")
  screen.text(enables[3] and "3" or "")
  screen.text(enables[4] and "4" or "")
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
        params:set("release", lfo.scale(lfo[i].slope, -1, 1, 0.1, 3.2))
      elseif target == 4 then
        params:set("cutoff", lfo.scale(lfo[i].slope, -1, 1, 50, 5000))
      elseif target == 5 then
        params:set("pan", lfo[i].slope)
      elseif target == 6 then
        params:set("delay", lfo.scale(lfo[i].slope, -1, 1, 0, 1))
      elseif target == 7 then
        params:set("delay_rate", lfo.scale(lfo[i].slope, -1, 1, 0.5, 2))
      elseif target == 8 then
        params:set("delay_feedback", lfo.scale(lfo[i].slope, -1, 1, 0, 1))
      elseif target == 9 then
        params:set("delay_pan", lfo[i].slope)
      end
    end
  end
end