local cave = {}

cave.scale = .6

function cave:init()
  self.points = {}
  local data = lovr.filesystem.read('assets/cave.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(self.points, tonumber(x))
    table.insert(self.points, tonumber(y))
    table.insert(self.points, tonumber(z))
  end
end

function cave:draw()
  lovr.graphics.push()
  lovr.graphics.scale(self.scale)
  lovr.graphics.points(self.points)
  lovr.graphics.pop()
end

return cave
