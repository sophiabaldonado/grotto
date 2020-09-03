local cave = {}

function cave:init()
  self.points = {}
  local data = lovr.filesystem.read('assets/cave.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(self.points, tonumber(x) / 10)
    table.insert(self.points, tonumber(y) / 10)
    table.insert(self.points, tonumber(z) / 10)
  end
end

function cave:draw()
  lovr.graphics.points(self.points)
end

return cave
