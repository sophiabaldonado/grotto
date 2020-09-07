local menu = {}

function menu:init()
  self.active = true
  self.dotscale = .2
end

function menu:update(dt)
  if lovr.headset.isDown('hand/right', 'trigger') and
  lovr.headset.isDown('hand/left', 'trigger') then
    self:countdown(dt)
  else
    self.dotscale = math.min(self.dotscale + dt, .2)
  end

  if self.start then
    self.active = false
  end
end

function menu:draw()
  lovr.graphics.circle('fill', 0, 1.5, -2, self.dotscale)--, math.pi / 2, 1, 0, 0)
  lovr.graphics.print('Hold Both Triggers to Start', 0, 2, -2, .1)
end

function menu:countdown(dt)
  self.dotscale = math.max(self.dotscale - dt * .25, 0)
  if self.dotscale == 0 then
    self.start = true
  end
end

return menu