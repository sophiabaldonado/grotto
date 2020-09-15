local cave = {}

local rooms = { 'depths', 'twisting-tunnel', 'stalactite-cavern', 'tunnel-of-trials', 'the-bridge', 'winding-road' }

local function lerp(x, y, t)
  return x + (y - x) * t
end

local function flerp(x, y, t, dt)
  return lerp(y, x, math.exp(-t * dt))
end

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
  local lod = math.max(distance / 4 - 1.25, 0) -- usually it's -1, -1.25 is conservative
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
  self.emitters = require('tools/breadcrumb-data').drips

  for i = 1, #rooms do
    self:load(i)
  end

  self.roomTimer = 3
  self.rooms.active = { [self.rooms[1]] = true }

  self.feeler = lovr.graphics.newComputeShader('assets/feeler.glsl')
  self.shader = lovr.graphics.newShader('assets/point.glsl', 'assets/point.glsl')
  self.occlusion = lovr.graphics.newShader('assets/occlusion.glsl', 'assets/occlusion.glsl')

  self.blinker = {
    active = false,
    hand = nil,
    prev = lovr.math.newVec3(),
    source = lovr.math.newVec3(),
    target = lovr.math.newVec3(),
    cursor = lovr.math.newVec3(),
    fadeOut = 0,
    fadeIn = 0,
    alpha = 0
  }

  self.intro = lovr.audio.newSource('assets/intro.ogg', 'static')
  self.ambience = lovr.audio.newSource('assets/cave.ogg', 'stream')
  self.ambience:setLooping(true)
  self.drips = {
    lovr.audio.newSource('assets/drip1.ogg', 'static'),
    lovr.audio.newSource('assets/drip2.ogg', 'static'),
    lovr.audio.newSource('assets/drip3.ogg', 'static'),
    lovr.audio.newSource('assets/drip4.ogg', 'static'),
    lovr.audio.newSource('assets/drip5.ogg', 'static'),
    lovr.audio.newSource('assets/drip6.ogg', 'static')
  }

  self.lights = {}
  local crystals = require('tools/breadcrumb-data').crystals
  local mushrooms = require('tools/breadcrumb-data').mushrooms
  for i = 1, #crystals do
    local light = { health = .5, position = crystals[i], crystal = true }
    light.position[2], light.position[3] = light.position[3], -light.position[2]
    table.insert(self.lights, light)
  end
  for i = 1, #mushrooms do
    local light = { health = .5, position = mushrooms[i], mushroom = true }
    light.position[2], light.position[3] = light.position[3], -light.position[2]
    table.insert(self.lights, light)
  end
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

  if not self.intro:isPlaying() and not self.ambience:isPlaying() then
    self.ambience:play()
  end

  local hx, hy, hz = head:unpack()
  local incavern = testSphereBox(self.rooms[3].octree[1].aabb, hx, hy, hz, .1)
  self:playCavernSounds(incavern, dt)

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
    if lovr.headset.isDown(hand, 'a') then
      self.startexit = true
    end
  end

  local v1, v2, v3 = vec3(), vec3(), vec3()
  local e1, e2 = vec3(), vec3()
  local s = vec3()
  local function raycast(origin, direction, triangle)
    local epsilon = 1e-6
    local x1, y1, z1, x2, y2, z2, x3, y3, z3 = unpack(triangle)
    v1:set(x1, y1, z1)
    v2:set(x2, y2, z2)
    v3:set(x3, y3, z3)
    e1:set(v2):sub(v1)
    e2:set(v3):sub(v1)
    local h = vec3(direction):cross(e2)
    local a = e1:dot(h)
    if a > -epsilon and a < epsilon then
      return nil
    end
    local f = 1 / a
    s:set(origin):sub(v1)
    local u = f * s:dot(h)
    if u < 0 or u > 1 then
      return nil
    end
    local q = s:cross(e1)
    local v = f * direction:dot(q)
    if v < 0 or u + v > 1 then
      return nil
    end
    local t = f * e2:dot(q)
    if t > epsilon then
      return vec3(direction):mul(t):add(origin), t
    end
  end

  for i, hand in ipairs({ 'left', 'right' }) do
    if lovr.headset.wasPressed(hand, 'trigger') then
      self.blinker.hand = hand
      self.blinker.active = true
      self.blinker.source:set(lovr.headset.getPosition(hand)):sub(world)
      self.blinker.prev:set(self.blinker.source)
    end
  end

  if self.blinker.active and lovr.headset.isDown(self.blinker.hand, 'trigger') then
    local position = vec3(lovr.headset.getPosition(self.blinker.hand)):sub(world)
    local delta = position - self.blinker.prev

    local d = math.huge
    local target = vec3()
    local origin = self.blinker.source + delta * 2
    local direction = vec3(0, -1, 0)
    local ox, _, oz = origin:unpack()
    for room in pairs(self.rooms.active) do
      local function visit(node)
        if not node then return end

        -- XZ aabb test
        if ox < node.aabb[1] or ox > node.aabb[2] or oz < node.aabb[5] or oz > node.aabb[6] then
          return
        end

        if node.leaf then
          for i = 1, #node.nav do
            local triangle = room.navmesh[node.nav[i] + 1]
            local hit, t = raycast(origin, direction, triangle)
            if hit and t < d then
              target:set(hit)
              d = t
            end
          end
        else
          for child = node.key * 8, node.key * 8 + 7 do
            visit(room.octree.lookup[child])
          end
        end
      end

      visit(room.octree[1])
    end

    if d ~= math.huge and d < 3 then
      self.blinker.target:set(target)
      self.blinker.source:set(origin)
    end

    if lovr.headset.wasPressed(self.blinker.hand, 'trigger') then
      self.blinker.cursor:set(self.blinker.target)
    else
      local cx, cy, cz = self.blinker.cursor:unpack()
      local tx, ty, tz = self.blinker.target:unpack()
      cx = flerp(cx, tx, 15, dt)
      cy = flerp(cy, ty, 15, dt)
      cz = flerp(cz, tz, 15, dt)
      self.blinker.cursor:set(cx, cy, cz)
    end

    self.blinker.prev:set(position)
  else
    if self.blinker.active and self.blinker.fadeOut == 0 then
      self.blinker.alpha = 1
      self.blinker.fadeOut = .1
    end
  end

  if self.blinker.fadeOut > 0 then
    self.blinker.fadeOut = math.max(self.blinker.fadeOut - dt, 0)
    self.blinker.alpha = 1 - self.blinker.fadeOut / .1
    if self.blinker.fadeOut == 0 then
      local delta = vec3(lovr.headset.getPosition())
      local dx, _, dz = delta:unpack()
      local tx, ty, tz = self.blinker.target:unpack()
      local w = _G.world
      w.x, w.y, w.z = -tx + dx, -ty, -tz + dz
      self.blinker.active = false
      self.blinker.fadeIn = .1
    end
  elseif self.blinker.fadeIn > 0 then
    self.blinker.fadeIn = math.max(self.blinker.fadeIn - dt, 0)
    self.blinker.alpha = self.blinker.fadeIn / .1
  end
end

function cave:draw()
  if not self.active then return end

  if self.blinker.active then
    lovr.graphics.setColor(.5, .5, .5)
    local tx, ty, tz = self.blinker.target:unpack()
    local cx, cy, cz = self.blinker.cursor:unpack()
    lovr.graphics.circle('line', tx, ty, tz, .015, -math.pi / 2, 1, 0, 0)
    lovr.graphics.circle('fill', cx, cy, cz, .01, -math.pi / 2, 1, 0, 0)
  end

  local draws = {}

  local head = vec3(lovr.headset.getPosition()):sub(vec3(world.x, world.y, world.z))
  local hx, hy, hz = head:unpack()

  lovr.graphics.setColorMask()
  lovr.graphics.setShader(self.occlusion)
  if lovr.graphics.setDepthNudge then lovr.graphics.setDepthNudge(5, 5) end
  for room in pairs(self.rooms.active) do
    if canSee(self.frustum, room.octree[1].aabb) then
      room.mesh:draw()
    end
  end
  lovr.graphics.flush()
  if lovr.graphics.setDepthNudge then lovr.graphics.setDepthNudge(0, 0) end
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

  if self.blinker.alpha > 0 then
    lovr.graphics.setColor(0, 0, 0, self.blinker.alpha)
    lovr.graphics.setBlendMode('alpha')
    lovr.graphics.fill()
    lovr.graphics.setBlendMode()
  end
end

function cave:start()
  self.active = true
  self.intro:play()
end

function cave:exit()
  self.active = false
  -- todo: this should fade out but once
  -- active is false we wont get updates
  self.ambience:stop()
end

function cave:load(index)
  do
    local room = {}
    local root = 'assets/' .. rooms[index]
    local blob = lovr.filesystem.newBlob(root .. '.bin')
    local count = blob:getSize() / 16
    local sizeFormat = { sizes = { 'float', count } }
    local pointFormat = { points = { 'vec4', count } }
    local octree = require(root).octree
    local navmesh = require(root).navmesh

    octree.lookup = {}
    for i = 1, #octree do
      octree.lookup[octree[i].key] = octree[i]
      octree[i].revealed = false
    end

    room.count = count
    room.octree = octree
    room.navmesh = navmesh
    room.mesh = lovr.graphics.newModel(root .. '.obj')
    room.sizes = lovr.graphics.newShaderBlock('compute', sizeFormat, { usage = 'static', zero = true })
    room.points = lovr.graphics.newShaderBlock('compute', pointFormat, { usage = 'static' })
    room.points:send('points', blob)
    blob:release()

    self.rooms[index] = room
  end

  collectgarbage()
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
  local cx, cy, cz = self.blinker.cursor:unpack()
  local r2 = .3 * .3

  local lights = { { hx, hy, hz }, { lx, ly, lz }, { rx, ry, rz } }

  if self.blinker.active then
    lights[4] = { cx, cy, cz }
  end

  if self.lights[1] then
    lights[4] = self.lights[1].position
    self.lights[1].health = self.lights[1].health - dt
    if self.lights[1].health <= 0 then
      self.lights[1] = nil
    end
  else
    for i, light in pairs(self.lights) do
      if head:distance(light.position) < .5 then
        lights[4] = light.position
        light.health = light.health - dt
        if light.health <= 0 then
          self.lights[i] = nil
          break
        end
      end
    end
  end

  self.feeler:send('lights', lights)
  self.feeler:send('dt', dt)

  for room in pairs(self.rooms.active) do
    local function visit(node)
      if not node then return end

      local touched = testSphereBox(node.aabb, hx, hy, hz, r2)
      touched = touched or testSphereBox(node.aabb, lx, ly, lz, r2)
      touched = touched or testSphereBox(node.aabb, rx, ry, rz, r2)
      touched = touched or testSphereBox(node.aabb, cx, cy, cz, r2)
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
  if lovr.headset.getDriver() == 'vrapi' then
    lleft, lright, ltop, lbottom = -math.rad(lleft), math.rad(lright), math.rad(ltop), -math.rad(lbottom)
    rleft, rright, rtop, rbottom = -math.rad(rleft), math.rad(rright), math.rad(rtop), -math.rad(rbottom)
  end

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

function cave:playCavernSounds(incavern, dt)
  if incavern then
    for i,e in ipairs(self.emitters) do
      local playchance = lovr.math.random()
      if playchance < (dt / .1) then
        local sound = self.drips[lovr.math.random(1, 6)]
        local pos = { e[1] + world.x, e[2] + world.y, e[3] + world.z }
        if not sound:isPlaying() then
          sound:setPosition(unpack(pos))
          sound:play()
        end
      end
    end
  end
end

return cave
