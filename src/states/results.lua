-- results.lua — shown after a run ends (win or loss)
local Results = {}
Results.__index = Results

function Results.new(sm)
    return setmetatable({ sm = sm }, Results)
end

function Results:enter(params)
    -- params: { outcome="win"|"loss", heat=N, time=N, percentBurned=N }
    self.outcome      = params and params.outcome      or "loss"
    self.heat         = params and params.heat         or 0
    self.time         = params and params.time         or 0
    self.percentBurned = params and params.percentBurned or 0
end

function Results:exit() end
function Results:update(dt) end

function Results:draw()
    love.graphics.setColor(1, 1, 1, 1)
    local msg = self.outcome == "win"
        and string.format("TOWN DESTROYED\nHeat: %d   Time: %.1fs", self.heat, self.time)
        or  string.format("FIRE EXTINGUISHED\n%.0f%% burned   Heat: %d", self.percentBurned, self.heat)
    love.graphics.print(msg, 480, 320)
    love.graphics.print("Press R to restart", 560, 420)
end

function Results:keypressed(key)
    if key == "r" then self.sm:replace("run") end
end

function Results:mousepressed(x, y, button) end

return Results
