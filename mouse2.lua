-- ~ mouse ~
-- cartesian gesture sequencer
-- by: @cfd90
--
-- ENC1 x
-- ENC2 y
-- ENC3 clock division
-- KEY2 hold to mute, tap to retrigger
-- KEY3 toggle clock mod

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

local scale = MusicUtil.generate_scale_of_length(0, "Minor Pentatonic", 127)

local x = math.floor(#scale/2)
local y = math.floor(#scale/2)
local last_x = x
local last_y = y
local mute = false

local speed = 3
local speeds = {1, 2, 4, 8}
local speed_mod = false

local enables = {true, true, true, true}

local clock_id = nil

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

-----------------------------------
-- Initialization
-----------------------------------

local function setup_params()
  params:add_separator()
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

  params:add_separator()
  thebangs.add_voicer_params()
  
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  
  lfo.init()
  hs.init()
end

local function setup_clock()
  clock_id = clock.run(tick)
end

function init()
  setup_params()
  setup_clock()
end

-----------------------------------
-- Playback
-----------------------------------

local function play_note(note)
  -- TODO: Add other outputs (MIDI, Crow)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
end

local function actual_play(tx, ty)
  -- TODO: Add "two pairs" voice allocation algorithms
  -- TODO: Add patterns capability
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
  
  actual_play(tx, ty)
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
  
  redraw()
end

function key(n, z)
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
  screen.level(15)
  screen.stroke()
  screen.rect(cursor_x - cursor_box_size/2, cursor_y - cursor_box_size/2, cursor_box_size, cursor_box_size)
  screen.stroke()
end

local function draw_params()
  local level_label = 15
  local level_value = 3
  local label_x = 68
  
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
  screen.text("divmod: ")
  screen.level(level_value)
  screen.text(speed_mod and "y" or "n")
  
  screen.move(label_x, 40)
  screen.level(level_label)
  screen.text("mute: ")
  screen.level(level_value)
  screen.text(mute and "y" or "n")
  
  screen.move(label_x, 50)
  screen.level(level_label)
  screen.text("voices: ")
  screen.level(level_value)
  screen.text(enables[1] and "1" or "")
  screen.text(enables[2] and "2" or "")
  screen.text(enables[3] and "3" or "")
  screen.text(enables[4] and "4" or "")
end

function redraw()
  screen.clear()
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