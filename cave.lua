local cave = {}

cave.scale = .6

function cave:init()
  local points = {}
  local data = lovr.filesystem.read('assets/cave.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(points, { x, y, z })
  end

  self.mesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, points, 'points', 'static')
end

function cave:draw()
  self.mesh:draw(0, 0, 0, self.scale)
end

return cave
