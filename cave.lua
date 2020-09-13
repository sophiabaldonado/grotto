local cave = {}

cave.active = false

function cave:init()
  local data = lovr.filesystem.newBlob('points.bin')
  self.mesh = lovr.graphics.newMesh({{ 'point', 'float', 4 }}, data, 'points', 'static')

  self.count = data:getSize() / 16
  self.points = lovr.graphics.newShaderBlock('compute', { points = { 'vec4', self.count } }, { usage = 'static' })
  self.points:send('points', data)

  local sizes = {}
  for i = 1, self.count do sizes[i] = 0 end
  self.sizes = lovr.graphics.newShaderBlock('compute', { sizes = { 'float', self.count } })
  self.sizes:send('sizes', sizes)

  self.feeler = lovr.graphics.newComputeShader([[
    layout(local_size_x = 1, local_size_y = 1, local_size_z = 1) in;

    layout(std430, binding = 0) readonly buffer Points {
      vec4 points[ ]] .. self.count .. [[ ];
    };

    layout(std430, binding = 1) buffer Sizes {
      float sizes[ ]] .. self.count .. [[ ];
    };

    uniform int offset;
    uniform vec3 hands[2];
    uniform float dt;

    void compute() {
      uint id = gl_WorkGroupID.x;
      uint index = uint(offset) + id;

      vec3 point = points[index].xyz;
      float leftDistance = distance(hands[0], point);
      float rightDistance = distance(hands[1], point);
      float d = min(leftDistance, rightDistance);

      if (d < .3) {
        float speed = 1.f - d / .3;
        sizes[index] = clamp(sizes[index] + dt * 8.f * speed, 0.f, 1.f);
      }
    }
  ]])

  self.feeler:sendBlock('Points', self.points)
  self.feeler:sendBlock('Sizes', self.sizes)

  self.shader = lovr.graphics.newShader([[
    out float alpha;
    layout(std430) buffer Sizes {
      float sizes[ ]] .. self.count .. [[ ];
    };

    in vec4 point;
    uniform vec3 head;

    float lod() {
      float d = distance(head, point.xyz);
      float pointFill = pow(1. - clamp(d / 2., 0., 1.), 3.);
      return 1. - smoothstep(pointFill - .05, pointFill, 1. - point.w);
    }

    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      alpha = sizes[gl_VertexID];
      gl_PointSize = sizes[gl_VertexID];
      return projection * transform * vec4(point.xyz, 1.);
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
      if (lovr.headset.isDown(hand, 'a')) then
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

return cave
