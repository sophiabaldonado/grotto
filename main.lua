cave = require 'cave'

function lovr.load()
  cave:init()
  models = {}
end

function lovr.update(dt)
  --
end

function lovr.draw()
  cave:draw()
    -- lovr.graphics.box('line', 0, 0, 0, .1, .1, .1)
    
  for i, hand in ipairs(lovr.headset.getHands()) do
    models[hand] = models[hand] or lovr.headset.newModel(hand)
    
    if models[hand] then
      local x, y, z, angle, ax, ay, az = lovr.headset.getPose(hand)
      -- models[hand]:draw(x, y, z, 1, angle, ax, ay, az)
      lovr.graphics.box('line', x, y, z, .1, .1, .1, angle, ax, ay, az)
    end
  end
end
