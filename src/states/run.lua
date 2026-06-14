-- run.lua
-- Main game state for a single run.
-- Phase 1: no defenders — playable loop only.

local Grid     = require("src.systems.grid")
local Fire     = require("src.systems.fire")
local Upgrades = require("src.systems.upgrades")
local HUD      = require("src.ui.hud")

local Run = {}
Run.__index = Run

function Run.new(sm)
    return setmetatable({ sm = sm }, Run)
end

function Run:enter(params)
    self.grid     = Grid.new()
    self.fire     = Fire.new(self.grid)
    self.upgrades = Upgrades.new(self.fire)
    self.hud      = HUD.new(self.fire, self.upgrades)

    self.over     = false
    self.outcome  = nil
    self.timer    = 0
end

function Run:update(dt)
    if self.over then
        -- Press R to restart
        return
    end

    self.timer = self.timer + dt
    self.grid:update(dt)
    self.fire:update(dt)
    self.upgrades:update(dt)
    self.hud:update(dt)

    self:checkEndConditions()
end

function Run:checkEndConditions()
    if self.grid:allBurned() then
        self:endRun("win")
    elseif self.fire.intensity <= 0 then
        self:endRun("loss")
    end
end

function Run:endRun(outcome)
    self.over    = true
    self.outcome = outcome
    self.sm:push("results", {
        outcome      = outcome,
        heat         = self.fire.heat,
        time         = self.timer,
        percentBurned = self.grid:percentBurned(),
    })
end

function Run:draw()
    self.grid:draw()
    self.fire:draw()
    self.hud:draw()
    self.upgrades:draw()   -- upgrade pick screen overlays when active
end

function Run:keypressed(key)
    self.fire:keypressed(key)
    self.upgrades:keypressed(key)
end

function Run:mousepressed(x, y, button)
    if button == 1 and not self.upgrades:isPicking() then
        self.fire:tryHop(x, y)
    end
end

function Run:mousereleased(x, y, button) end
function Run:exit() end

return Run
