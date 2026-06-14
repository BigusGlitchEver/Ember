-- statemanager.lua
-- Simple stack-based state machine.
-- Push a state by name; the top of the stack is active.
-- States are lazy-loaded on first push.

local StateManager = {}
StateManager.__index = StateManager

-- Registry: add new states here
local STATE_MODULES = {
    menu    = "src.states.menu",
    run     = "src.states.run",
    results = "src.states.results",
}

local loaded = {}  -- cache of required modules

local function getModule(name)
    if not loaded[name] then
        assert(STATE_MODULES[name], "Unknown state: " .. tostring(name))
        loaded[name] = require(STATE_MODULES[name])
    end
    return loaded[name]
end

function StateManager.new()
    return setmetatable({ stack = {} }, StateManager)
end

-- Push a new state on top. params table is passed to state:enter().
function StateManager:push(name, params)
    local mod   = getModule(name)
    local state = mod.new(self)   -- pass sm so states can push/pop
    state.name  = name
    table.insert(self.stack, state)
    if state.enter then state:enter(params) end
end

-- Pop the top state.
function StateManager:pop()
    local state = self.stack[#self.stack]
    if not state then return end
    if state.exit then state:exit() end
    table.remove(self.stack)
end

-- Replace top state with a new one.
function StateManager:replace(name, params)
    self:pop()
    self:push(name, params)
end

function StateManager:current()
    return self.stack[#self.stack]
end

function StateManager:update(dt)
    local s = self:current()
    if s and s.update then s:update(dt) end
end

function StateManager:draw()
    -- Draw bottom-up so overlaid states (e.g. pause) render on top
    for _, s in ipairs(self.stack) do
        if s.draw then s:draw() end
    end
end

function StateManager:keypressed(key, scancode, isrepeat)
    local s = self:current()
    if s and s.keypressed then s:keypressed(key, scancode, isrepeat) end
end

function StateManager:mousepressed(x, y, button)
    local s = self:current()
    if s and s.mousepressed then s:mousepressed(x, y, button) end
end

function StateManager:mousereleased(x, y, button)
    local s = self:current()
    if s and s.mousereleased then s:mousereleased(x, y, button) end
end

return StateManager
