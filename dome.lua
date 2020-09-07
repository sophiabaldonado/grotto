local dome = {}

dome.scale = 2

function dome:init()
  local points = {}
  local data = lovr.filesystem.read('assets/stardome.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(points, { x, y, z })
  end

  self.mesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, points, 'points', 'static')

  
  self.treetexture = lovr.graphics.newTexture('assets/forest.png')
  self.treematerial = lovr.graphics.newMaterial(self.treetexture, 0, 0, 0, 1)
  self.fade = 0
end

function dome:update(dt)
  for i, hand in ipairs(lovr.headset.getHands()) do
    if (hand == 'hand/right') then
      if (lovr.headset.isDown(hand, 'trigger')) then
        self.fade = math.min(self.fade + dt, 1)
      else
        self.fade = math.max(self.fade - dt, 0)
      end
    end
  end
end

function dome:draw()
  local a = vec3(0, 0, 0)
  local b = vec3(3 / 255, 3 / 255, 10 / 255)
  local c = a:lerp(b, self.fade)
  lovr.graphics.setBackgroundColor(c:unpack())

  self.mesh:draw(0, 0, 0, self.scale)
  lovr.graphics.circle('fill', 0, 30, -5, 1, math.pi / 2, 1, 0, 0)

  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setWinding('clockwise')
  lovr.graphics.sphere(self.treematerial, 0, 15, 0, 15)
  lovr.graphics.setWinding('counterclockwise')
  lovr.graphics.setCullingEnabled(false)
end

return dome