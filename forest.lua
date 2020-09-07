local forest = {}

forest.scale = 2
forest.active = false

function forest:init()
  local points = {}
  local data = lovr.filesystem.read('assets/stardome.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(points, { x, y, z })
  end

  self.domemesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, points, 'points', 'static')
  self.treetexture = lovr.graphics.newTexture('assets/forest.png')
  self.treematerial = lovr.graphics.newMaterial(self.treetexture, 0, 0, 0, 1)

  self.ambience = lovr.audio.newSource('assets/forest.ogg', 'static')
  self.fade = 0
  self.conclude = false
end

function forest:update(dt)
  if not self.active then return end

  -- placeholder for transitioning the trees in
  for i, hand in ipairs(lovr.headset.getHands()) do
    if (hand == 'hand/right') then
      if (lovr.headset.isDown(hand, 'trigger')) then
        self.conclude = true
        lovr.audio.setVolume(3)
      end
    end
  end

  if self.conclude then
    self.ambience:play()
    self.fade = math.min(self.fade + dt * 1.5, 1)
  end
end

function forest:draw()
  if not self.active then return end

  local a = vec3(0, 0, 0)
  local b = vec3(3 / 255, 3 / 255, 10 / 255)
  local c = a:lerp(b, self.fade)
  lovr.graphics.setBackgroundColor(c:unpack())

  self.domemesh:draw(0, 0, 0, self.scale)
  lovr.graphics.circle('fill', 0, 30, -5, 1, math.pi / 2, 1, 0, 0)

  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setWinding('clockwise')
  lovr.graphics.sphere(self.treematerial, 0, 15, 0, 15)
  lovr.graphics.setWinding('counterclockwise')
  lovr.graphics.setCullingEnabled(false)
end

return forest