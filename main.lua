cave = require 'cave'
io.stdout:setvbuf('no')

function lovr.load()
  cave:init()
  models = {}
  world = { x = 0, y = 0, z = 0 }
  last = { x = 0, y = 0, z = 0 }
end

function lovr.update(dt)
  --
end

function lovr.draw()
  lovr.graphics.push()
  lovr.graphics.translate(world.x, world.y, world.z)
  cave:draw()
  lovr.graphics.pop()
    
  for i, hand in ipairs(lovr.headset.getHands()) do
    models[hand] = models[hand] or lovr.headset.newModel(hand)
    
    if models[hand] then
      local x, y, z, angle, ax, ay, az = lovr.headset.getPose(hand)
      lovr.graphics.setColor(0.85, 0.85, 0.85, 0.5)
      lovr.graphics.sphere(x, y, z, .025, angle, ax, ay, az)
      lovr.graphics.setColor(1.0, 1.0, 1.0, 1.0)
    end

    if (lovr.headset.isDown('left', 'x')) then
      if (hand == 'hand/left') then
        move(hand)
      end
    else
      world.x = 0
      world.y = 0
      world.z = 0
    end
  end
end

function move(hand)
  local x, y, z = lovr.headset.getPose(hand)
  world.x = world.x - (last.x - x)
  world.z = world.z - (last.z - z)
  last.x = x
  last.y = y
  last.z = z
end