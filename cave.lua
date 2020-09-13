local cave = {}

local octree = require 'points'
octree.lookup = {}
for i = 1, #octree do
  octree.lookup[i] = octree[octree[i].key]
end

local function clamp(x, min, max)
  return math.max(min, math.min(max, x))
end

local function testSphereBox(aabb, sphere, r2)
  local minx, maxx, miny, maxy, minz, maxz = unpack(node.aabb)
  local x = clamp(sphere.x, minx, maxx)
  local y = clamp(sphere.y, miny, maxy)
  local z = clamp(sphere.z, minz, maxz)
  local dx, dy, dz = x - sphere.x, y - sphere.y, z - sphere.z
  return dx * dx + dy * dy + dz * dz < r2
end

function cave:init()
  cave.active = false

  self:load()

  self.feeler = lovr.graphics.newComputeShader('assets/feeler.glsl')
  self.feeler:sendBlock('Points', self.points)
  self.feeler:sendBlock('Sizes', self.sizes)

  self.shader = lovr.graphics.newShader('assets/point.glsl', 'assets/point.glsl')
  self.shader:sendBlock('Points', self.points)
  self.shader:sendBlock('Sizes', self.sizes)

  self.ambience = lovr.audio.newSource('assets/cave.ogg', 'static')
  self.ambience:setLooping(true)
end

function cave:update(dt)
  if not self.active then return end

  self.ambience:play()

  local world = vec3(world.x, world.y, world.z)

  local hands = {
    vec3(lovr.headset.getPosition('hand/left')):sub(world),
    vec3(lovr.headset.getPosition('hand/right')):sub(world)
  }

  self.feeler:send('hands', hands)
  self.feeler:send('dt', dt)

  local r2 = .3 * .3
  local rooms = { octree }
  for i, room in ipairs(rooms) do
    local function visit(node)
      if not testSphereBox(node.aabb, hands[1], r2) and not testSphereBox(node.aabb, hands[2], r2) then
        return
      end

      local child = key * 8
      local minx, maxx, miny, maxy, minz, maxz = unpack(aabb)
      local cx, cy, cz = (minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2
    end

    visit(room.nodes[1])
  end

  for i = 0, self.count - 1, 65535 do
    self.feeler:send('offset', i)
    lovr.graphics.compute(self.feeler, math.min(self.count - i, 65535))
  end

  self.shader:send('head', vec3(lovr.headset.getPosition()):sub(world))

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
    if lovr.headset.isDown(hand, 'a') then
      self.startexit = true
    end
  end
end

function cave:draw()
  if not self.active then return end

  lovr.graphics.setBlendMode()
  lovr.graphics.setShader(self.shader)
  self.mesh:draw()
  lovr.graphics.setShader()

  --[[local head = vec3(lovr.headset.getPosition()):sub(vec3(world.x, world.y, world.z))
  for i = 1, #octree do
    if octree[i].leaf then
      local minx, maxx, miny, maxy, minz, maxz = unpack(octree[i].aabb)
      local center = vec3((minx + maxx) / 2, (miny + maxy) / 2, (minz + maxz) / 2)
      if head:distance(center) < 4 then
        self.mesh:setDrawRange(octree[i].start, octree[i].count)
        self.mesh:draw()
      end
    end
  end
  lovr.graphics.setShader()]]
end

function cave:start()
  self.active = true
  self.ambience:play()
end

function cave:exit()
  self.active = false
  -- todo: this should fade out but once
  -- active is false we wont get updates
  self.ambience:stop()
end

function cave:load()
  local blob = lovr.filesystem.newBlob('points.bin')
  self.count = blob:getSize() / 16
  local sizeFormat = { sizes = { 'float', self.count } }
  local pointFormat = { points = { 'vec4', self.count } }
  self.mesh = lovr.graphics.newMesh({}, self.count, 'points', 'static')
  self.sizes = lovr.graphics.newShaderBlock('compute', sizeFormat, { zero = true })
  self.points = lovr.graphics.newShaderBlock('compute', pointFormat, { usage = 'static' })
  self.points:send('points', blob)
end

return cave
