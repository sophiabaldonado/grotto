local forest = {}

forest.scale = 2
forest.active = false

function forest:init()
  local points = {}
  local data = lovr.filesystem.read('assets/stardome.obj')
  for x, y, z in data:gmatch('(-?%d*%.%d+) (-?%d*%.%d+) (-?%d*%.%d+)') do
    table.insert(points, { x, y, z })
  end

  self.domemesh = lovr.graphics.newMesh({{ 'lovrPosition', 'float', 3 }}, points, 'points', 'static')
  self.treetexture = lovr.graphics.newTexture('assets/forest.png')
  self.treematerial = lovr.graphics.newMaterial(self.treetexture, 0, 0, 0, 1)

  self.ambience = lovr.audio.newSource('assets/forest.ogg', 'static')
  self.ambience:setLooping(true)
  self.ambiencevolume = 0
  self.ambience:setVolume(self.ambiencevolume)

  self.treefade = 0
  self.conclude = false
  self.concluded = false
  self.moonopacity = 0
end

function forest:update(dt)
  if not self.active then return end

  -- placeholder for transitioning the trees in
  for i, hand in ipairs(lovr.headset.getHands()) do
    if (hand == 'hand/right') then
      if (lovr.headset.isDown(hand, 'trigger')) then
        self.conclude = true
      end
    end
  end

  if self.conclude then
    self.ambience:play()
    self.moonopacity = math.min(self.moonopacity + dt * .1, 1)
    self.ambiencevolume = math.min(self.ambiencevolume + dt * .3, 5)
    if self.moonopacity > .25 then
      self.moon = true
    end
  end

  if self.moon then
    if not self.concluded then
      self.concluded = true
    end
    self.treefade = math.min(self.treefade + dt * .5, 1)
  end
  self.ambience:setVolume(self.ambiencevolume)
end

function forest:draw()
  if not self.active then return end

  local a = vec3(0, 0, 0)
  local b = vec3(3 / 255, 3 / 255, 10 / 255)
  local c = a:lerp(b, self.treefade)
  lovr.graphics.setBackgroundColor(c:unpack())

  self.domemesh:draw(0, 0, 0, self.scale)

  lovr.graphics.setColor(1.0, 1.0, 1.0, self.moonopacity)
  lovr.graphics.circle('fill', 5, 25, -18, 1, math.pi / 3, 1, 0, 0)
  lovr.graphics.setColor(1.0, 1.0, 1.0, 1.0)

  lovr.graphics.setWinding('clockwise')
  lovr.graphics.sphere(self.treematerial, 0, 15, 0, 15)
  lovr.graphics.setWinding('counterclockwise')
end

function forest:start()
  self.active = true
end

return forest
