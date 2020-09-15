local hands = {}

function hands:init()
  self.models = {}
  self.shader = lovr.graphics.newShader([[
    vec4 position(mat4 projection, mat4 transform, vec4 vertex) {
      return projection * transform * vertex;
    }
  ]], [[
    vec4 color(vec4 graphicsColor, sampler2D image, vec2 uv) {
      if (int(gl_FragCoord.x) % 10 != 7 || int(gl_FragCoord.y) % 10 != 3) discard;
      return vec4(vec3(.08), .5);
    }
  ]], { flags = { animated = true } })
end

function hands:update(dt)
  for i, hand in ipairs({ 'left', 'right' }) do
    if lovr.headset.isTracked(hand) and not self.models[hand] then
      self.models[hand] = lovr.headset.newModel(hand, { animated = true })
    end
  end
end

function hands:draw()
  lovr.graphics.setShader()
  for i, hand in ipairs({ 'left', 'right' }) do
    if lovr.headset.isTracked(hand) then
      if lovr.headset.getDriver() == 'vrapi' and self.models[hand] and lovr.headset.animate(hand, self.models[hand]) then
        lovr.graphics.setShader(self.shader)
        self.models[hand]:draw(mat4(lovr.headset.getPose(hand)))
      else
        lovr.graphics.sphere(mat4(lovr.headset.getPose(hand)):scale(.01))
      end
    end
  end
  lovr.graphics.setShader()
end

return hands
