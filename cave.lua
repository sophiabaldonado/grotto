local cave = {}

local octree = require 'points'
octree.lookup = {}
for i = 1, #octree do
  octree.lookup[octree[i].key] = octree[i]
  octree[i].revealed = false
end

local function clamp(x, min, max)
  return math.max(min, math.min(max, x))
end

local function testSphereBox(aabb, sphere, r2)
  local minx, maxx, miny, maxy, minz, maxz = unpack(aabb)
  local x = clamp(sphere.x, minx, maxx)
  local y = clamp(sphere.y, miny, maxy)
  local z = clamp(sphere.z, minz, maxz)
  local dx, dy, dz = x - sphere.x, y - sphere.y, z - sphere.z
  return dx * dx + dy * dy + dz * dz < r2
end

local function getDetail(aabb, head)
  local minx, maxx, miny, maxy, minz, maxz = unpack(aabb)
  local x = clamp(head.x, minx, maxx)
  local y = clamp(head.y, miny, maxy)
  local z = clamp(head.z, minz, maxz)
  local distance = head:distance(vec3(x, y, z))
  local lod = math.max(distance / 2 - 1.25, 0) -- usually it's -1, -1.25 is conservative
  return 1 / (2 ^ lod)
end

function cave:init()
  self.active = false
  self.frustum = lovr.math.newMat4()

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

  self:updateFrustum()

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
  for _, room in ipairs(rooms) do
    local function visit(node)
      if not node or (not testSphereBox(node.aabb, hands[1], r2) and not testSphereBox(node.aabb, hands[2], r2)) then
        return
      end

      node.revealed = true

      if node.leaf then
        self.feeler:send('offset', node.start - 1)
        lovr.graphics.compute(self.feeler, node.count)
      else
        for child = node.key * 8, node.key * 8 + 7 do
          visit(room.lookup[child])
        end
      end
    end

    visit(room[1])
  end

  --[[
  for i = 0, self.count - 1, 65535 do
    self.feeler:send('offset', i)
    lovr.graphics.compute(self.feeler, math.min(self.count - i, 65535))
  end
  ]]

  self.shader:send('head', vec3(lovr.headset.getPosition()):sub(world))
  self.shader:send('world', world)

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
    if lovr.headset.isDown(hand, 'a') then
      self.startexit = true
    end
  end
end

function cave:draw()
  if not self.active then return end

  local draws = {}

  local head = vec3(lovr.headset.getPosition()):sub(vec3(world.x, world.y, world.z))

  local function visit(node)
    if not node then return end

    -- Touch culling: don't render nodes that haven't been revealed yet
    -- Frustum culling: don't render nodes outside the view frustum
    if not node.revealed then return end
    if not self:canSee(node.aabb) then return end

    if node.leaf then
      local detail = getDetail(node.aabb, head)
      table.insert(draws, { node.start, node.count * detail })
    else
      for child = node.key * 8, node.key * 8 + 7 do
        visit(octree.lookup[child])
      end
    end
  end

  visit(octree[1])

  lovr.graphics.setBlendMode()
  lovr.graphics.setCullingEnabled(true)
  lovr.graphics.setShader(self.shader)
  lovr.graphics.setColor(1, 1, 1)
  self.mesh:setMultidraws(draws)
  self.mesh:draw()
  lovr.graphics.setShader()
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

function cave:updateFrustum()
  local lleft, lright, ltop, lbottom = lovr.headset.getViewAngles(1)
  local rleft, rright, rtop, rbottom = lovr.headset.getViewAngles(2)

  if not lleft or not rleft then return end

  -- Fix vrapi bug
  lleft, lright, ltop, lbottom = -math.rad(lleft), math.rad(lright), math.rad(ltop), -math.rad(lbottom)
  rleft, rright, rtop, rbottom = -math.rad(rleft), math.rad(rright), math.rad(rtop), -math.rad(rbottom)

  local left = vec3(lovr.headset.getViewPose(1))
  local right = vec3(lovr.headset.getViewPose(2))

  local near = .1
  local far = 100
  local ipd = left:distance(right)
  local zoffset = ipd / (rright - lleft)
  local bottom = math.min(lbottom, rbottom)
  local top = math.max(ltop, rtop)
  local n = near + zoffset
  local f = far + zoffset
  local idx = 1 / (rright - lleft)
  local idy = 1 / (top - bottom)
  local idz = 1 / (f - n)
  local sx = rright + lleft
  local sy = top + bottom
  local P = mat4(2 * idx, 0, 0, 0, 0, 2 * idy, 0, 0, sx * idx, sy * idy, -f * idz, -1, 0, 0, -f * n * idz, 0)

  local center = vec3(left):add(right):mul(.5)
  local rotate = quat(lovr.headset.getOrientation())
  local view = mat4(center, rotate)
  local V = mat4(-world.x, -world.y, -world.z):mul(view):translate(0, 0, zoffset):invert()
  self.frustum:set(2 * idx, 0, 0, 0, 0, 2 * idy, 0, 0, sx * idx, sy * idy, -f * idz, -1, 0, 0, -f * n * idz, 0)
  self.frustum:mul(V)
end

function cave:canSee(aabb)
  local points = {
    vec4(aabb[1], aabb[3], aabb[5], 1),
    vec4(aabb[1], aabb[3], aabb[6], 1),
    vec4(aabb[1], aabb[4], aabb[5], 1),
    vec4(aabb[1], aabb[4], aabb[6], 1),
    vec4(aabb[2], aabb[3], aabb[5], 1),
    vec4(aabb[2], aabb[3], aabb[6], 1),
    vec4(aabb[2], aabb[4], aabb[5], 1),
    vec4(aabb[2], aabb[4], aabb[6], 1)
  }

  for i = 1, 8 do
    self.frustum:mul(points[i])
  end

  local inside

  inside = false
  for i = 1, 8 do if points[i].x > -points[i].w then inside = true break end end
  if not inside then return false end

  inside = false
  for i = 1, 8 do if points[i].x < points[i].w then inside = true break end end
  if not inside then return false end

  inside = false
  for i = 1, 8 do if points[i].y > -points[i].w then inside = true break end end
  if not inside then return false end

  inside = false
  for i = 1, 8 do if points[i].y < points[i].w then inside = true break end end
  if not inside then return false end

  inside = false
  for i = 1, 8 do if points[i].z > -points[i].w then inside = true break end end
  if not inside then return false end

  inside = false
  for i = 1, 8 do if points[i].z < points[i].w then inside = true break end end
  if not inside then return false end

  return true
end

return cave
