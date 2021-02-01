engine.name = "Thebangs"

MusicUtil = require "musicutil"

thebangs = include("thebangs/lib/thebangs_engine")
lfo = include("lib/mouse_hnds")
hs = include("lib/mouse_halfsecond")

scale = MusicUtil.generate_scale_of_length(0, "Minor Pentatonic", 127)

x = math.floor(#scale/2)
y = math.floor(#scale/2)
last_x = x
last_y = y
mute = false

speed = 3
speeds = {1, 2, 4, 8}
speed_mod = false

enables = {true, true, true, true}

clock_id = nil

lfo_targets = {
  "none",
  "pw",
  "release",
  "cutoff",
  "pan"
}

function init()
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

  params:add_separator()
  thebangs.add_additional_synth_params()
  
  params:add_separator()
  thebangs.add_voicer_params()
  
  for i = 1, 4 do
    lfo[i].lfo_targets = lfo_targets
  end
  
  lfo.init()
  hs.init()
  
  clock_id = clock.run(tick)
end

function tick()
  while true do
    if speed_mod then
      -- Keep it musical...
      speed = math.random(2, #speeds - 1)
      redraw()
    end
    clock.sync(1/speeds[speed])
    play(false)
  end
end

function play(force)
  tx = false
  ty = false
  
  if mute and not force then
    return
  end
  
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

function actual_play(tx, ty)
  if tx then
    
    if enables[1] then
      note = scale[x]
      freq = MusicUtil.note_num_to_freq(note)
      engine.hz(freq)
    end
    
    if x + 2 <= #scale and enables[2] then
      note = scale[x + 2]
      freq = MusicUtil.note_num_to_freq(note)
      engine.hz(freq)
    end
    
    if x - 3 >= 1 and enables[3] then
      note = scale[x - 3]
      freq = MusicUtil.note_num_to_freq(note)
      engine.hz(freq)
    end
    
  end
  
  if ty then
    
    if enables[4] then
      note = scale[y]
      freq = MusicUtil.note_num_to_freq(note)
      engine.hz(freq)
    end
    
  end
end

function enc(n, d)
  if n == 1 then
    speed = util.clamp(speed + d, 1, #speeds)
  elseif n == 2 then
    x = util.clamp(x + d, 1, #scale)
  elseif n == 3 then
    y = util.clamp(y + d, 1, #scale)
  end
  
  redraw()
end

function key(n, z)
  if n == 2 then
    if z == 1 then
      mute = true
    else
      mute = false
      play(true)
    end
  elseif n == 3 and z == 1 then
    speed_mod = not speed_mod
  end
  
  redraw()
end

function redraw()
  screen.clear()
  
  screen.level(1)
  screen.move(1 + (x / #scale) * 63, 1)
  screen.line(1 + (x / #scale) * 63, 63)
  screen.stroke()
  screen.move(1, 1 + 63 - (y / #scale) * 63)
  screen.line(63, 1 + 63 - (y / #scale) * 63)
  screen.stroke()
  screen.level(15)
  screen.stroke()
  screen.rect(-1 + (x / #scale) * 63, -1 + (63 - (y / #scale) * 63), 4, 4)
  screen.stroke()
  
  screen.move(68, 10)
  screen.level(15)
  screen.text("x: ")
  screen.level(3)
  screen.text(x)
  screen.move(98, 10)
  screen.level(15)
  screen.text("y: ")
  screen.level(3)
  screen.text(y)
  screen.move(68, 20)
  screen.level(15)
  screen.text("div: ")
  screen.level(3)
  screen.text("1/" .. speeds[speed])
  screen.move(68, 30)
  screen.level(15)
  screen.text("divmod: ")
  screen.level(3)
  screen.text(speed_mod and "y" or "n")
  screen.move(68, 40)
  screen.level(15)
  screen.text("mute: ")
  screen.level(3)
  screen.text(mute and "y" or "n")
  screen.move(68, 50)
  screen.level(15)
  screen.text("voices: ")
  screen.level(3)
  screen.text(enables[1] and "1" or "")
  screen.text(enables[2] and "2" or "")
  screen.text(enables[3] and "3" or "")
  screen.text(enables[4] and "4" or "")
  screen.update()
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