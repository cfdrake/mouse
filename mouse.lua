-- mouse
-- by @cfd90

MusicUtil = require "musicutil"

hs = include("lib/mouse_halfsecond")
lfo = include("lib/mouse_hnds")

engine.name = "PolyPerc"

x = math.floor(127 / 2)
y = math.floor(127 / 2)
play = true
spread = 3

speed = 2
speeds = {0.5, 1, 2, 4}
rand_speed = false

scale = MusicUtil.generate_scale_of_length(0, "major", 127)
id = nil

lfo_targets = {
  "none",
  "pw",
  "release",
  "cutoff",
  "pan"
}

function init()
  id = clock.run(tick)
  
  params:add_separator()
  
  cs_AMP = controlspec.new(0,1,'lin',0,0.5,'')
  params:add{type="control",id="amp",controlspec=cs_AMP,
    action=function(x) engine.amp(x) end}

  cs_PW = controlspec.new(0,100,'lin',0,50,'%')
  params:add{type="control",id="pw",controlspec=cs_PW,
    action=function(x) engine.pw(x/100) end}

  cs_REL = controlspec.new(0.1,3.2,'lin',0,1.2,'s')
  params:add{type="control",id="release",controlspec=cs_REL,
    action=function(x) engine.release(x) end}

  cs_CUT = controlspec.new(50,5000,'exp',0,800,'hz')
  params:add{type="control",id="cutoff",controlspec=cs_CUT,
    action=function(x) engine.cutoff(x) end}

  cs_GAIN = controlspec.new(0,4,'lin',0,1,'')
  params:add{type="control",id="gain",controlspec=cs_GAIN,
    action=function(x) engine.gain(x) end}
  
  cs_PAN = controlspec.new(-1,1, 'lin',0,0,'')
  params:add{type="control",id="pan",controlspec=cs_PAN,
    action=function(x) engine.pan(x) end}

  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  
  lfo.init()
  
  hs.init()
end

function play_step()
  -- melody
  note = MusicUtil.snap_note_to_array(y, scale)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
  
  -- harmony
  note = MusicUtil.snap_note_to_array(x, scale)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
  
  note = MusicUtil.snap_note_to_array(x - spread, scale)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
  
  note = MusicUtil.snap_note_to_array(x + spread, scale)
  freq = MusicUtil.note_num_to_freq(note)
  engine.hz(freq)
end

function tick()
  while true do
    clock.sync(1/speeds[speed])
    if play then
      play_step()
    end
    
    if rand_speed then
      speed = math.random(1, #speeds)
      redraw()
    end
  end
end

function redraw()
  screen.clear()
  screen.level(1)
  screen.move(1 + (x / 127) * 63, 1)
  screen.line(1 + (x / 127) * 63, 63)
  screen.stroke()
  screen.move(1, 1 + (y / 127) * 63)
  screen.line(63, 1 + (y / 127) * 63)
  screen.stroke()
  screen.level(15)
  screen.stroke()
  screen.rect(-1 + (x / 127) * 63, -1 + (y / 127) * 63, 4, 4)
  screen.stroke()
  screen.move(68, 10)
  screen.text("playing: " .. (play and "true" or "false"))
  screen.move(68, 20)
  screen.text("x: " .. x)
  screen.move(68, 30)
  screen.text("y: " .. y)
  screen.move(68, 40)
  screen.text("speed: " .. speeds[speed])
  screen.move(68, 50)
  screen.text("rand: " .. (rand_speed and "true" or "false"))
  screen.move(68, 60)
  screen.text("spread: " .. spread)
  screen.update()
end

function enc(n, d)
  if n == 1 then
    speed = util.clamp(speed + d, 1, #speeds)
  elseif n == 2 then
    last_x = x
    x = util.clamp(x + d, 1, 127)
  elseif n == 3 then
    last_y = y
    y = util.clamp(y + d, 1, 127)
  end
  
  redraw()
end

function key(n, z)
  if n == 2 then
    play = z == 0
  elseif n == 3 and z == 1 then
    rand_speed = not rand_speed
  end
  
  redraw()
end

function lfo.process()
  for i=1,4 do
    target = params:get(i .. "lfo_target")

    if params:get(i .. "lfo") == 2 then
      if target == 2 then
        params:set("pw", lfo.scale(lfo[i].slope, -4, 3, 0, 100))
      elseif target == 3 then
        params:set("release", lfo.scale(lfo[i].slope, -4, 3, 0.1, 3.2))
      elseif target == 4 then
        params:set("cutoff", lfo.scale(lfo[i].slope, -4, 3, 50, 5000))
      elseif target == 5 then
        params:set("pan", lfo.scale(lfo[i].slope, -4, 3, -1, 1))
      end
    end
  end
end