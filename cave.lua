local cave = {}

cave.scale = .6
cave.active = false

function cave:init()
  local data = lovr.filesystem.newBlob('points.bin')
  self.mesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, data, 'points', 'static')

  self.count = data:getSize() / 12
  self.points = lovr.graphics.newShaderBlock('compute', { points = { 'float', self.count * 3 } }, { usage = 'static' })
  self.points:send('points', data)

  local sizes = {}
  for i = 1, self.count do sizes[i] = 0 end
  self.sizes = lovr.graphics.newShaderBlock('compute', { sizes = { 'float', self.count } })
  self.sizes:send('sizes', sizes)

  self.feeler = lovr.graphics.newComputeShader([[
    layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

    layout(std430) buffer Points {
      float points[ ]] .. self.count * 3 .. [[ ];
    };

    layout(std430) buffer Sizes {
      float sizes[ ]] .. self.count .. [[ ];
    };

    uniform vec3 hands[2];
    uniform float dt;

    void compute() {
      uint id = gl_WorkGroupID.x;
      vec3 point = vec3(points[3 * id + 0], points[3 * id + 1], points[3 * id + 2]);
      float leftDistance = distance(hands[0], point * .6);
      float rightDistance = distance(hands[1], point * .6);
      float d = min(leftDistance, rightDistance);

      if (d < .3) {
        float speed = 1.f - d / .3;
        sizes[id] = clamp(sizes[id] + dt * 8.f * speed, 0.f, 1.f);
      }
    }
  ]])

  self.feeler:sendBlock('Points', self.points)
  self.feeler:sendBlock('Sizes', self.sizes)

  self.shader = lovr.graphics.newShader([[
    layout(std430) buffer Sizes {
      float sizes[ ]] .. self.count .. [[ ];
    };

    out float alpha;

    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      gl_PointSize = sizes[gl_VertexID];
      alpha = sizes[gl_VertexID];
      return projection * transform * vertex;
    }
  ]], [[
  in float alpha;
    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      return vec4(alpha);
    }
  ]])

  self.shader:sendBlock('Sizes', self.sizes)

  self.ambience = lovr.audio.newSource('assets/cave.ogg', 'static')
  self.ambience:setLooping(true)
end

function cave:update(dt)
  if not self.active then return end

  self.ambience:play()

  local hands = {}
  local world = vec3(world.x, world.y, world.z)
  hands[1] = vec3(lovr.headset.getPosition('hand/left')):sub(world)
  hands[2] = vec3(lovr.headset.getPosition('hand/right')):sub(world)
  self.feeler:send('hands', hands)
  self.feeler:send('dt', dt)
  lovr.graphics.compute(self.feeler, self.count)

  -- placeholder for when player escapes the cave
  for i, hand in ipairs(lovr.headset.getHands()) do
      if (lovr.headset.isDown(hand, 'a')) then
        self.startexit = true
      end
  end
end

function cave:draw()
  if not self.active then return end

  lovr.graphics.setShader(self.shader)
  self.mesh:draw(0, 0, 0, self.scale)
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

return cave
