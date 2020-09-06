cave = require 'cave'
dome = require 'dome'
io.stdout:setvbuf('no')

function lovr.load()
  lovr.headset.setClipDistance(0.1, 100)
  cave:init()
  dome:init()
  swimspeed = 1.5
  world = { x = 0, y = 0, z = 0 }
  last = { x = 0, z = 0 }
end

function lovr.update(dt)
  for i, hand in ipairs(lovr.headset.getHands()) do
    if (hand == 'hand/left') then
      local x, y, z = lovr.headset.getPose(hand)
      if (lovr.headset.isDown(hand, 'trigger')) then
        move(x, z)
      end
      last.x = x
      last.z = z
    end
  end

  cave:update(dt)
  dome:update(dt)
end

function lovr.draw()
  lovr.graphics.push()
  lovr.graphics.translate(world.x, world.y, world.z)
  -- cave:draw()
  dome:draw()
  lovr.graphics.pop()

  for i, hand in ipairs(lovr.headset.getHands()) do
    local x, y, z, angle, ax, ay, az = lovr.headset.getPose(hand)
    lovr.graphics.setColor(0.85, 0.85, 0.85, 0.5)
    lovr.graphics.sphere(x, y, z, .025, angle, ax, ay, az)
    lovr.graphics.setColor(1.0, 1.0, 1.0, 1.0)
  end
end

function move(x, z)
  world.x = world.x - (last.x - x) * swimspeed
  world.z = world.z - (last.z - z) * swimspeed
end
