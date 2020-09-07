local cave = {}

cave.scale = .6
cave.active = false

function cave:init()
  local points = {}
  local data = lovr.filesystem.read('assets/cave.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(points, { x, y, z })
  end

  self.mesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, points, 'points', 'static')

  self.count = #points
  self.points = lovr.graphics.newShaderBlock('compute', { points = { 'vec4', self.count } }, { usage = 'static' })
  self.points:send('points', points)

  local sizes = {}
  for i = 1, self.count do sizes[i] = 0 end
  self.sizes = lovr.graphics.newShaderBlock('compute', { sizes = { 'float', self.count } })
  self.sizes:send('sizes', sizes)

  self.feeler = lovr.graphics.newComputeShader([[
    layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

    ]] .. self.points:getShaderCode('Points') .. [[
    ]] .. self.sizes:getShaderCode('Sizes') .. [[

    uniform vec3 handPosition;
    uniform float dt;

    void compute() {
      uint id = gl_WorkGroupID.x;
      float dis = distance(handPosition, points[id].xyz * .6);
      if (dis < .3) {
        float speed = 1.f - dis / .3;
        sizes[id] = clamp(sizes[id] + dt * 32.f * speed, 0.f, 8.f);
      }
    }
  ]])

  self.feeler:sendBlock('Points', self.points)
  self.feeler:sendBlock('Sizes', self.sizes)

  self.shader = lovr.graphics.newShader([[
    ]] .. self.sizes:getShaderCode('Sizes') .. [[

    out float alpha;

    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      gl_PointSize = sizes[gl_VertexID];
      alpha = sizes[gl_VertexID] / 4.f;
      return projection * transform * vertex;
    }
  ]], [[
  in float alpha;
    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      vec2 xx = 2. * gl_PointCoord - 1.;
      if (length(xx) > 1.f) discard;
      return vec4(alpha);
    }
  ]])

  self.shader:sendBlock('Sizes', self.sizes)

  self.ambience = lovr.audio.newSource('assets/cave.ogg', 'static')
end

function cave:update(dt)
  if not self.active then return end

  self.ambience:play()
  self.feeler:send('handPosition', { lovr.headset.getPosition('hand/right') })
  self.feeler:send('dt', dt)
  lovr.graphics.compute(self.feeler, self.count)

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
    -- if (hand == 'hand/right') then
      if (lovr.headset.isDown(hand, 'a')) then
        self:exit()
      end
    -- end
  end
end

function cave:draw()
  if not self.active then return end

  lovr.graphics.setShader(self.shader)
  self.mesh:draw(0, 0, 0, self.scale)
  lovr.graphics.setShader()
end

function cave:exit()
  self.active = false
  self.ambience:stop()
end

return cave
