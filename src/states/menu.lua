-- menu.lua — stub for MVP; wire up when needed
local Menu = {}
Menu.__index = Menu

function Menu.new(sm)
    return setmetatable({ sm = sm }, Menu)
end

function Menu:enter() end
function Menu:exit()  end

function Menu:update(dt) end

function Menu:draw()
    love.graphics.setColor(1, 0.4, 0.1, 1)
    love.graphics.print("EMBER\n\nPress ENTER to start", 560, 320)
end

function Menu:keypressed(key)
    if key == "return" or key == "space" then
        self.sm:replace("run")
    end
end

function Menu:mousepressed(x, y, button) end

return Menu
