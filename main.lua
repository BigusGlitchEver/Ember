-- main.lua — thin entry point. All logic lives in modules.
local StateManager = require("src.states.statemanager")

local sm

function love.load()
    love.graphics.setDefaultFilter("nearest", "nearest")
    math.randomseed(os.time())   -- shuffle varies each run

    sm = StateManager.new()
    sm:push("run")   -- push "menu" when menu is ready
end

function love.update(dt)
    sm:update(dt)
end

function love.draw()
    sm:draw()
end

function love.keypressed(key, scancode, isrepeat)
    if key == "escape" then love.event.quit() end
    sm:keypressed(key, scancode, isrepeat)
end

function love.mousepressed(x, y, button, istouch, presses)
    sm:mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    sm:mousereleased(x, y, button)
end
