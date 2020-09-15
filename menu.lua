local menu = {}

function menu:init()
  self.active = true
  self.dotscale = .2
  self.logoTex = lovr.graphics.newTexture('assets/grotto-logo.png')
  self.logo = lovr.graphics.newMaterial(self.logoTex)

  self.logoFade = 0
  self.locoFade = 0
  self.startFade = 0
end

function menu:update(dt)
  local time = lovr.timer.getTime()

  if time > 5 then self.logoFade = math.min(self.logoFade + dt * .1, 1) end
  if time > 7 then self.locoFade = math.min(self.locoFade + dt * .1, 1) end
  if time > 9 then self.startFade = math.min(self.startFade + dt * .1, 1) end

  if lovr.headset.isDown('hand/right', 'trigger') and
  lovr.headset.isDown('hand/left', 'trigger') then
    self:countdown(dt)
  else
    self.dotscale = math.min(self.dotscale + dt, .2)
  end
end

function menu:draw()
  lovr.graphics.push()
  lovr.graphics.origin()
  lovr.graphics.setColor(1, 1, 1, self.logoFade)
  lovr.graphics.circle('fill', -.065, 1.5, -1.99, self.dotscale)
  lovr.graphics.plane(self.logo, 0, 1.5, -2, self.logoTex:getWidth() * .002, self.logoTex:getHeight() * .002)
  lovr.graphics.setColor(1, 1, 1, self.locoFade)
  lovr.graphics.print('Use Trigger to Move', 0, 1, -2, .05)
  lovr.graphics.setColor(1, 1, 1, self.startFade)
  lovr.graphics.print('Hold Both Triggers to Start', 0, .9, -2, .05)
  lovr.graphics.pop()
end

function menu:countdown(dt)
  self.dotscale = math.max(self.dotscale - dt * .25, 0)
  if self.dotscale == 0 then
    self.active = false
  end
end

return menu
