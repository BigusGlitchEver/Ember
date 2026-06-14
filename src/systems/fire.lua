-- fire.lua
-- The ember: the player-controlled fire.
-- No auto-spread — every building that burns is one the player hopped to.

local FIRE_LEVEL_MAX = 3

-- Chebyshev hop range per Fire Level
local HOP_RANGE = { [1]=2, [2]=3, [3]=5 }

-- Burn speed multiplier per Fire Level (higher = faster burn)
local BURN_SPEED = { [1]=1.0, [2]=1.5, [3]=2.2 }

-- Intensity drain/restore rates (per second)
local AMBIENT_DRAIN = 2.0   -- fire always hungers; drains while idle (between burns)
local BURN_RESTORE  = 6.0   -- restored while actively burning a building

local INTENSITY_MAX = 100.0

-- Starting tile
local START_COL = 2
local START_ROW = 2

local Fire = {}
Fire.__index = Fire

function Fire.new(grid)
    local self = setmetatable({}, Fire)
    self.grid         = grid
    self.level        = 1
    self.entryLevel   = 1   -- Fire Level at the moment of the last hop
    self.intensity    = INTENSITY_MAX
    self.intensityMax = INTENSITY_MAX
    self.heat         = 0

    self.col          = START_COL
    self.row          = START_ROW
    self.hopping      = false
    self.hopTimer     = 0

    self.burnTimer    = 0
    self.burnDurCached = 0   -- computed once per building at hop time
    self.burning      = false
    self.currentTile  = nil

    self.upgrades     = {}
    self.hopTargets   = {}

    -- Ignite starting tile
    local startTile = grid:getTile(START_COL, START_ROW)
    if startTile then
        grid:igniteTile(startTile)
        self.burning       = true
        self.currentTile   = startTile
        self.entryLevel    = 1
        self.burnDurCached = self:_calcBurnDuration(startTile, 1)
    end

    return self
end

-- ── Internal helpers ──────────────────────────────────────────────────────

-- Burn duration for a tile given a specific entry level (cached at hop time)
function Fire:_calcBurnDuration(tile, lvl)
    return tile.mat.burnDuration / BURN_SPEED[lvl]
end

function Fire:hopRange()
    return HOP_RANGE[self.level] + (self.upgrades.longJump and 1 or 0)
end

-- ── Hop target computation ────────────────────────────────────────────────
function Fire:computeHopTargets()
    self.hopTargets = {}
    local range = self:hopRange()
    local g = self.grid
    for row = 1, g.rows do
        for col = 1, g.cols do
            if not (col == self.col and row == self.row) then
                local tile = g:getTile(col, row)
                if tile
                   and tile.mat.flammable
                   and tile.burnState == g.BURN_STATE.INTACT
                   and g:tileDistance(self.col, self.row, col, row) <= range
                then
                    table.insert(self.hopTargets, tile)
                end
            end
        end
    end
end

function Fire:isValidTarget(col, row)
    for _, t in ipairs(self.hopTargets) do
        if t.col == col and t.row == row then return true end
    end
    return false
end

-- ── Hopping ───────────────────────────────────────────────────────────────
function Fire:tryHop(px, py)
    if self.hopping then return end
    local col, row = self.grid:pixelToTile(px, py)
    if not self:isValidTarget(col, row) then return end
    self:doHop(col, row)
end

function Fire:doHop(col, row)
    -- Level cost (floor 1)
    local newLevel  = math.max(1, self.level - 1)
    self.level      = newLevel
    self.entryLevel = newLevel

    -- Leave old tile burning visually (it will ash when finished via burnTimer in future)
    -- For Phase 1: old tile just keeps its burn state; only one active ember

    -- Move
    self.col  = col
    self.row  = row
    self.currentTile   = self.grid:getTile(col, row)
    self.burnTimer     = 0
    self.burnDurCached = self:_calcBurnDuration(self.currentTile, self.entryLevel)
    self.burning       = true

    self.grid:igniteTile(self.currentTile)

    -- Hop animation
    self.hopping  = true
    self.hopTimer = 0.12
end

-- ── Level growth during burn ──────────────────────────────────────────────
-- Divide the building's burn time into equal segments per level step.
-- entryLevel + earned steps = current level.
-- Example: mansion (cap=3), entry=1 → 2 steps, each at 50% of burn time.
--   0–49%  → level 1
--   50–99% → level 2
--   100%   → level 3 (set in onBuildingFinished)
function Fire:updateLevelFromBurn()
    if not self.currentTile then return end
    local cap   = self.currentTile.mat.levelCap
    local steps = cap - self.entryLevel
    if steps <= 0 then return end   -- building can't grow us further

    local dur = self.burnDurCached
    if dur <= 0 then return end

    local progress    = math.min(0.999, self.burnTimer / dur)  -- cap just below 1.0; 1.0 handled by finish
    local stepsEarned = math.floor(progress * steps)
    self.level        = math.min(FIRE_LEVEL_MAX, self.entryLevel + stepsEarned)
end

-- ── Building finish ───────────────────────────────────────────────────────
function Fire:onBuildingFinished()
    local tile = self.currentTile
    if not tile then return end

    -- Award Heat
    self.heat = self.heat + tile.mat.heat

    -- Climb to cap on completion
    self.level = math.min(FIRE_LEVEL_MAX, tile.mat.levelCap)

    -- Backdraft upgrade
    if self.upgrades.backdraft then
        self.intensity = math.min(self.intensityMax, self.intensity + 20)
    end

    self.grid:ashTile(tile)
    self.burning     = false
    self.currentTile = nil
end

-- ── Intensity ─────────────────────────────────────────────────────────────
function Fire:drainIntensity(dt)
    if self.burning then
        self.intensity = self.intensity + BURN_RESTORE * dt
    else
        self.intensity = self.intensity - AMBIENT_DRAIN * dt
    end
    self.intensity = math.max(0, math.min(self.intensityMax, self.intensity))
end

function Fire:douse(amount)
    local resistance = 0.25 * (self.level - 1)
    self.intensity   = math.max(0, self.intensity - amount * (1 - resistance))
end

-- ── Update ────────────────────────────────────────────────────────────────
function Fire:update(dt)
    if self.hopping then
        self.hopTimer = self.hopTimer - dt
        if self.hopTimer <= 0 then self.hopping = false end
    end

    if self.burning and self.currentTile then
        self.burnTimer = self.burnTimer + dt
        self:updateLevelFromBurn()
        if self.burnTimer >= self.burnDurCached then
            self:onBuildingFinished()
        end
    end

    self:drainIntensity(dt)
    self:computeHopTargets()
end

function Fire:keypressed(key) end

-- ── Rendering ─────────────────────────────────────────────────────────────
function Fire:draw()
    local g  = self.grid
    local ox = g.offsetX
    local oy = g.offsetY

    -- Hop target highlights
    for _, tile in ipairs(self.hopTargets) do
        local px, py = g:tileToPixel(tile.col, tile.row)
        love.graphics.setColor(1, 0.7, 0.2, 0.30)
        love.graphics.rectangle("fill", px, py, g.TILE_W - 1, g.TILE_H - 1)
        love.graphics.setColor(1, 0.55, 0.05, 0.85)
        love.graphics.rectangle("line", px, py, g.TILE_W - 1, g.TILE_H - 1)
    end

    -- Ember circle (grows with level)
    if self.currentTile or not self.burning then
        local cx, cy = g:tileCenter(self.col, self.row)
        local r = 6 + self.level * 5
        -- Outer glow
        love.graphics.setColor(1.0, 0.6, 0.1, 0.30)
        love.graphics.circle("fill", cx, cy, r * 1.6)
        -- Main body
        love.graphics.setColor(1.0, 0.85, 0.25, 1)
        love.graphics.circle("fill", cx, cy, r)
        -- Hot core
        love.graphics.setColor(1.0, 1.0, 0.8, 0.9)
        love.graphics.circle("fill", cx, cy, r * 0.45)
    end

    -- Burn progress arc on current tile
    if self.burning and self.currentTile and self.burnDurCached > 0 then
        local cx, cy  = g:tileCenter(self.col, self.row)
        local progress = math.min(1.0, self.burnTimer / self.burnDurCached)
        love.graphics.setColor(1, 0.4, 0.0, 0.5)
        love.graphics.arc("fill", cx, cy, g.TILE_W * 0.4,
            -math.pi/2, -math.pi/2 + progress * math.pi * 2)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Accessors ─────────────────────────────────────────────────────────────
function Fire:getLevel()     return self.level      end
function Fire:getIntensity() return self.intensity  end
function Fire:getHeat()      return self.heat       end
function Fire:getPosition()  return self.col, self.row end

function Fire:getPowerFill()
    if not self.burning or self.burnDurCached <= 0 then return 0 end
    return math.min(1.0, self.burnTimer / self.burnDurCached)
end

return Fire
