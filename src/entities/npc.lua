-- npc.lua
-- A single NPC entity (occupant or neighbor).
-- State machine: idle → alarmed → moving-to-water → dousing → moving-to-fire → dousing → flee
-- Reads fire level to decide whether to fight or flee.

local Class = require("src.lib.middleclass")

-- ── Constants ─────────────────────────────────────────────────────────────
local NPC_SPEED        = 80   -- pixels per second
local DOUSE_RANGE      = 40   -- pixels: how close to fire before dousing starts
local DOUSE_RATE       = 8    -- intensity drained per second while dousing
local REFILL_TIME      = 1.5  -- seconds to refill at a water source
local FLEE_SPEED       = 120  -- pixels per second when fleeing
local FLEE_LEVEL       = 3    -- Fire Level at which NPCs give up and flee

-- Visual colors per NPC type
local NPC_COLORS = {
    occupant = {1.0, 0.85, 0.55},
    neighbor = {0.70, 0.80, 1.00},
}

-- ── NPC states ────────────────────────────────────────────────────────────
local STATE = {
    IDLE       = "idle",
    ALARMED    = "alarmed",
    TO_WATER   = "to_water",
    REFILLING  = "refilling",
    TO_FIRE    = "to_fire",
    DOUSING    = "dousing",
    FLEE       = "flee",
    DONE       = "done",
}

-- ── NPC class ─────────────────────────────────────────────────────────────
local NPC = Class("NPC")

function NPC:initialize(npcType, x, y, grid, fire)
    self.npcType   = npcType   -- "occupant" or "neighbor"
    self.x         = x
    self.y         = y
    self.grid      = grid
    self.fire      = fire
    self.state     = STATE.ALARMED
    self.done      = false

    self.bucketFull = true    -- occupants start with a bucket; neighbors fetch first
    if npcType == "neighbor" then self.bucketFull = false end

    self.refillTimer = 0
    self.targetX     = x
    self.targetY     = y

    -- Bucket chain membership
    self.inChain     = false

    -- Find initial water target
    self.waterX, self.waterY = self:findNearestWater()
end

-- ── Pathfinding helpers ───────────────────────────────────────────────────

function NPC:findNearestWater()
    -- Find closest well or river tile center
    local bestDist = math.huge
    local bx, by   = self.x, self.y
    local g = self.grid
    for row = 1, g.rows do
        for col = 1, g.cols do
            local tile = g:getTile(col, row)
            if tile and tile.mat.isWater then
                local cx, cy = g:tileCenter(col, row)
                local d = math.sqrt((cx - self.x)^2 + (cy - self.y)^2)
                if d < bestDist then
                    bestDist = d
                    bx, by   = cx, cy
                end
            end
        end
    end
    return bx, by
end

function NPC:getFireCenter()
    local col, row = self.fire:getPosition()
    return self.grid:tileCenter(col, row)
end

function NPC:moveToward(tx, ty, speed, dt)
    local dx = tx - self.x
    local dy = ty - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    if dist < 2 then return true end  -- arrived
    local step = speed * dt
    self.x = self.x + (dx / dist) * math.min(step, dist)
    self.y = self.y + (dy / dist) * math.min(step, dist)
    return false
end

-- ── Should flee? ──────────────────────────────────────────────────────────
function NPC:shouldFlee()
    local fireLevel = self.fire:getLevel()
    local fleeLvl   = FLEE_LEVEL
    -- Crowd Panic upgrade makes NPCs flee sooner (at level 2)
    if self.fire.upgrades and self.fire.upgrades.crowdPanic then
        fleeLvl = fleeLvl - 1
    end
    return fireLevel >= fleeLvl
end

-- ── Update ────────────────────────────────────────────────────────────────
function NPC:update(dt)
    if self.done then return end

    -- Always check flee condition
    if self:shouldFlee() and self.state ~= STATE.FLEE and self.state ~= STATE.DONE then
        self.state = STATE.FLEE
    end

    if self.state == STATE.ALARMED then
        -- Immediately decide: bucket full → go douse; empty → fetch water
        if self.bucketFull then
            self.state = STATE.TO_FIRE
        else
            self.state = STATE.TO_WATER
        end

    elseif self.state == STATE.TO_WATER then
        local arrived = self:moveToward(self.waterX, self.waterY, NPC_SPEED, dt)
        if arrived then
            self.state       = STATE.REFILLING
            self.refillTimer = REFILL_TIME
        end

    elseif self.state == STATE.REFILLING then
        self.refillTimer = self.refillTimer - dt
        if self.refillTimer <= 0 then
            self.bucketFull = true
            self.state      = STATE.TO_FIRE
        end

    elseif self.state == STATE.TO_FIRE then
        local fx, fy  = self:getFireCenter()
        local arrived = self:moveToward(fx, fy, NPC_SPEED, dt)
        local dx = fx - self.x
        local dy = fy - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist <= DOUSE_RANGE then
            self.state = STATE.DOUSING
        end

    elseif self.state == STATE.DOUSING then
        if not self.bucketFull then
            -- Bucket empty; go refill
            self.waterX, self.waterY = self:findNearestWater()
            self.state = STATE.TO_WATER
        else
            -- Throw water at fire
            self.fire:douse(DOUSE_RATE * dt)
            -- Deplete bucket over time (simplification: 3 seconds of dousing)
            self.douseTimer = (self.douseTimer or 3.0) - dt
            if self.douseTimer <= 0 then
                self.bucketFull = false
                self.douseTimer = nil
            end
        end

    elseif self.state == STATE.FLEE then
        -- Run away from fire in opposite direction
        local fx, fy = self:getFireCenter()
        local dx = self.x - fx
        local dy = self.y - fy
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist > 0 then
            self.x = self.x + (dx / dist) * FLEE_SPEED * dt
            self.y = self.y + (dy / dist) * FLEE_SPEED * dt
        end
        -- Done when off-screen
        local W, H = love.graphics.getDimensions()
        if self.x < -50 or self.x > W + 50 or self.y < -50 or self.y > H + 50 then
            self.done = true
        end
    end
end

-- ── Rendering ─────────────────────────────────────────────────────────────
function NPC:draw()
    local color = NPC_COLORS[self.npcType] or {1, 1, 1}
    love.graphics.setColor(color)
    love.graphics.circle("fill", self.x, self.y, 5)

    -- Draw bucket arc toward fire when dousing
    if self.state == STATE.DOUSING and self.bucketFull then
        local fx, fy = self:getFireCenter()
        love.graphics.setColor(0.4, 0.7, 1.0, 0.6)
        love.graphics.line(self.x, self.y, (self.x + fx)*0.5, (self.y + fy)*0.5 - 10, fx, fy)
    end
end

return NPC
