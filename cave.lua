local cave = {}

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

  for i = 0, self.count - 1, 65535 do
    self.feeler:send('offset', i)
    lovr.graphics.compute(self.feeler, math.min(self.count - i, 65535))
  end

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
    if lovr.headset.isDown(hand, 'a') then
      self.startexit = true
    end
  end
end

function cave:draw()
  if not self.active then return end

  lovr.graphics.setShader(self.shader)
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

return cave
