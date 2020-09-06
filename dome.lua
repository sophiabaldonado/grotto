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
end

function dome:draw()
  lovr.graphics.setBackgroundColor(0x03030a)

  self.mesh:draw(0, 0, 0, self.scale)
  lovr.graphics.circle('fill', 0, 30, -5, 1, math.pi / 2, 1, 0, 0)

  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setWinding('clockwise')
  lovr.graphics.sphere(self.treematerial, 0, 15, 0, 15)
  lovr.graphics.setWinding('counterclockwise')
  lovr.graphics.setCullingEnabled(false)
end

return dome