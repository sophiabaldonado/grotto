local menu = {}

function menu:init()
  self.active = true
end

function menu:update(dt)
  if lovr.headset.isDown('hand/right', 'trigger') and
  lovr.headset.isDown('hand/left', 'trigger') then
    self:countdown()
  end

  if self.start then
    self.active = false
  end
end

function menu:draw()
  lovr.graphics.print('Hold Both Triggers to Start', 0, 2, -2, .1)
end

function menu:countdown()
  -- todo: show bar or circle as they hold triggers
  -- start after 2-3 seconds
  self.start = true
end

return menu