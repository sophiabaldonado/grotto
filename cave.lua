local cave = {}

local rooms = { 'depths', 'twisting-tunnel', 'stalactite-cavern' }

local function clamp(x, min, max)
  return math.max(min, math.min(max, x))
end

local function testSphereBox(aabb, x, y, z, r2)
  local minx, maxx, miny, maxy, minz, maxz = unpack(aabb)
  local bx = clamp(x, minx, maxx)
  local by = clamp(y, miny, maxy)
  local bz = clamp(z, minz, maxz)
  local dx, dy, dz = bx - x, by - y, bz - z
  return dx * dx + dy * dy + dz * dz < r2
end

local function getDetail(aabb, x, y, z)
  local minx, maxx, miny, maxy, minz, maxz = unpack(aabb)
  local bx = clamp(x, minx, maxx)
  local by = clamp(y, miny, maxy)
  local bz = clamp(z, minz, maxz)
  local distance = math.sqrt((bx - x) ^ 2, (by - y) ^ 2, (bz - z) ^ 2)
  local lod = math.max(distance / 2 - 1.25, 0) -- usually it's -1, -1.25 is conservative
  return 1 / (2 ^ lod)
end

local function canSee(frustum, aabb)
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
    frustum:mul(points[i])
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

function cave:init()
  self.active = false
  self.frustum = lovr.math.newMat4()
  self.mesh = lovr.graphics.newMesh({}, 1, 'points', 'static')
  self.rooms = { active = {} }

  for i = 1, #rooms do
    self:load(i)
  end

  self.roomTimer = 3
  self.rooms.active = { [self.rooms[1]] = true }

  self.feeler = lovr.graphics.newComputeShader('assets/feeler.glsl')
  self.shader = lovr.graphics.newShader('assets/point.glsl', 'assets/point.glsl')
  self.occlusion = lovr.graphics.newShader('assets/occlusion.glsl', 'assets/occlusion.glsl')

  self.ambience = lovr.audio.newSource('assets/cave.ogg', 'static')
  self.ambience:setLooping(true)
end

function cave:update(dt)
  if not self.active then return end

  local world = vec3(world.x, world.y, world.z)
  local head = vec3(lovr.headset.getPosition()):sub(world)
  local left = vec3(lovr.headset.getPosition('left')):sub(world)
  local right = vec3(lovr.headset.getPosition('right')):sub(world)

  self.shader:send('head', head)
  self.shader:send('world', world)

  self:checkRooms(dt, head)
  self:feel(dt, head, left, right)
  self:updateFrustum()

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
  local hx, hy, hz = head:unpack()

  lovr.graphics.setColorMask()
  lovr.graphics.setShader(self.occlusion)
  for room in pairs(self.rooms.active) do
    if canSee(self.frustum, room.octree[1].aabb) then
      room.mesh:draw()
    end
  end
  lovr.graphics.setColorMask(true, true, true, true)
  lovr.graphics.setShader(self.shader)

  for room in pairs(self.rooms.active) do
    local function visit(node)
      if not node then return end

      -- Touch culling: don't render nodes that haven't been revealed yet
      -- Frustum culling: don't render nodes outside the view frustum
      if not node.revealed then return end
      if not canSee(self.frustum, node.aabb) then return end

      if node.leaf then
        local detail = getDetail(node.aabb, hx, hy, hz)
        draws[#draws + 1] = { node.start, node.count * detail }
      else
        for child = node.key * 8, node.key * 8 + 7 do
          visit(room.octree.lookup[child])
        end
      end
    end

    visit(room.octree[1])

    if #draws > 0 then
      self.shader:sendBlock('Points', room.points)
      self.shader:sendBlock('Sizes', room.sizes)
      self.mesh:setMultidraws(draws)
      self.mesh:draw()
      lovr.graphics.flush()
    end
  end

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

function cave:load(index)
  local room = {}
  local root = 'assets/' .. rooms[index]
  local blob = lovr.filesystem.newBlob(root .. '.bin')
  local count = blob:getSize() / 16
  local sizeFormat = { sizes = { 'float', count } }
  local pointFormat = { points = { 'vec4', count } }
  local octree = require(root)

  octree.lookup = {}
  for i = 1, #octree do
    octree.lookup[octree[i].key] = octree[i]
    octree[i].revealed = false
  end

  room.octree = octree
  room.count = count
  room.sizes = lovr.graphics.newShaderBlock('compute', sizeFormat, { usage = 'static', zero = true })
  room.points = lovr.graphics.newShaderBlock('compute', pointFormat, { usage = 'static' })
  room.points:send('points', blob)
  room.mesh = lovr.graphics.newModel(root .. '.obj')

  self.rooms[index] = room
end

function cave:checkRooms(dt, head)
  self.roomTimer = self.roomTimer - dt
  if self.roomTimer > 0 then return end

  for room in pairs(self.rooms.active) do
    self.rooms.active[room] = nil
  end

  local hx, hy, hz = head:unpack()
  for i, room in ipairs(self.rooms) do
    local minx, maxx, miny, maxy, minz, maxz = unpack(room.octree[1].aabb)
    if hx > minx and hx < maxx and hy > miny and hy < maxy and hz > minz and hz < maxz then
      local before = self.rooms[i - 1]
      local after = self.rooms[i + 1]
      if before then self.rooms.active[before] = true end
      if after then self.rooms.active[after] = true end
      self.rooms.active[room] = true
      break
    end
  end

  self.roomTimer = lovr.math.random(2, 5)
end

function cave:feel(dt, head, left, right)
  local hx, hy, hz = head:unpack()
  local lx, ly, lz = left:unpack()
  local rx, ry, rz = right:unpack()
  local r2 = .3 * .3

  self.feeler:send('lights', { head, left, right })
  self.feeler:send('dt', dt)

  for room in pairs(self.rooms.active) do
    local function visit(node)
      if not node then return end

      local touched = testSphereBox(node.aabb, hx, hy, hz, r2)
      touched = touched or testSphereBox(node.aabb, lx, ly, lz, r2)
      touched = touched or testSphereBox(node.aabb, rx, ry, rz, r2)
      if not touched then return end

      node.revealed = true

      if node.leaf then
        self.feeler:send('offset', node.start - 1)
        lovr.graphics.compute(self.feeler, node.count)
      else
        for child = node.key * 8, node.key * 8 + 7 do
          visit(room.octree.lookup[child])
        end
      end
    end

    self.feeler:sendBlock('Points', room.points)
    self.feeler:sendBlock('Sizes', room.sizes)
    visit(room.octree[1])
  end
end

function cave:updateFrustum()
  local lleft, lright, ltop, lbottom = lovr.headset.getViewAngles(1)
  local rleft, rright, rtop, rbottom = lovr.headset.getViewAngles(2)

  if not lleft or not rleft then return end

  -- Fix vrapi bug
  lleft, lright, ltop, lbottom = -math.rad(lleft), math.rad(lright), math.rad(ltop), -math.rad(lbottom)
  rleft, rright, rtop, rbottom = -math.rad(rleft), math.rad(rright), math.rad(rtop), -math.rad(rbottom)

  -- More conservative
  lleft = lleft - .05
  rright = rright + .05

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

return cave
