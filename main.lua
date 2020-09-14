menu = require 'menu'
cave = require 'cave'
forest = require 'forest'
hands = require 'hands'
io.stdout:setvbuf('no')

function lovr.load()
  lovr.headset.setClipDistance(0.1, 100)
  menu:init()
  cave:init()
  forest:init()
  currentScene = 'menu'
  hands:init()
  swimspeed = 1.5
  world = { x = 0, y = 0, z = 0 }
  last = { x = 0, z = 0 }
end

function lovr.update(dt)
  for i, hand in ipairs(lovr.headset.getHands()) do
    -- todo: make work for both hands
    if (hand == 'hand/left') then
      local x, y, z = lovr.headset.getPose(hand)
      if (lovr.headset.isDown(hand, 'trigger')) then
        move(x, z)
      end
      last.x = x
      last.z = z
    end
  end

  hands:update(dt)

  if currentScene == 'menu' then
    menu:update(dt)
    if not menu.active then
      currentScene = 'cave'
      cave:start()
    end
  elseif currentScene == 'cave' then
    cave:update(dt)
    if not cave.active then
      currentScene = 'forest'
      forest:start()
    end
  elseif currentScene == 'forest' then
    forest:update(dt)
  end
end

function lovr.draw()
  hands:draw()

  lovr.graphics.push()
  lovr.graphics.translate(world.x, world.y, world.z)
  drawCurrentScene()
  lovr.graphics.pop()
end

function move(x, z)
  world.x = world.x - (last.x - x) * swimspeed
  world.z = world.z - (last.z - z) * swimspeed
end

function drawCurrentScene()
  if currentScene == 'menu' then
    menu:draw()
  elseif currentScene == 'cave' then
    cave:draw()
  elseif currentScene == 'forest' then
    forest:draw()
  end
end
