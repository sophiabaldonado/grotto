menu = require 'menu'
cave = require 'cave'
forest = require 'forest'
hands = require 'hands'
io.stdout:setvbuf('no')

function lovr.load()
  lovr.headset.setClipDistance(0.1, 100)
  lovr.graphics.setCullingEnabled(true)
  menu:init()
  cave:init()
  forest:init()
  currentScene = 'menu'
  hands:init()
  swimspeed = 1.5
  world = { x = 5.66936, z = -23.4027, y = 0.752744 }
end

function lovr.update(dt)
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
  if currentScene == 'cave' then
    lovr.graphics.translate(world.x, world.y, world.z)
  end
  drawCurrentScene()
  lovr.graphics.pop()
  lovr.graphics.setColor(1, 1, 1)
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
