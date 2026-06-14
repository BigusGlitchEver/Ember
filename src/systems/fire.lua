-- fire.lua
-- The ember: the player-controlled fire.
-- Owns: current tile, Fire Level, Intensity, Heat, hopping logic.
-- No auto-spread — every burning tile is one the player hopped to.

local FIRE_LEVEL_MAX = 3

-- How far (Chebyshev tiles) the ember can hop at each level
local HOP_RANGE = { [1]=2, [2]=3, [3]=5 }

-- Burn speed multiplier per Fire Level (higher = burns through faster)
local BURN_SPEED = { [1]=1.5, [2]=2.5, [3]=4.0 }

-- Intensity drain/restore rates
local AMBIENT_DRAIN = 3.0   -- lost per second always
local BURN_RESTORE  = 9.0   -- gained per second while burning a building

local INTENSITY_MAX = 100.0

-- Starting position — a house so level can immediately begin climbing
local START_COL = 2
local START_ROW = 2

-- Directional hop: map key → (dx, dy) in tile space
local DIR = {
    right = { 1,  0},
    d     = { 1,  0},
    left  = {-1,  0},
    a     = {-1,  0},
    up    = { 0, -1},
    w     = { 0, -1},
    down  = { 0,  1},
    s     = { 0,  1},
}

local Fire = {}
Fire.__index = Fire

function Fire.new(grid)
    local self = setmetatable({}, Fire)
    self.grid         = grid
    self.level        = 1
    self.intensity    = INTENSITY_MAX
    self.intensityMax = INTENSITY_MAX
    self.heat         = 0

    self.col          = START_COL
    self.row          = START_ROW
    self.hopping      = false
    self.hopTimer     = 0

    self.burnTimer    = 0
    self.burning      = false

    self.hopTargets   = {}
    self.hoveredCol   = nil
    self.hoveredRow   = nil

    local startTile = grid:getTile(START_COL, START_ROW)
    if startTile then
        grid:igniteTile(startTile)
        self.burning     = true
        self.currentTile = startTile
    end

    return self
end

-- ── Hop range ─────────────────────────────────────────────────────────────

function Fire:hopRange()
    return HOP_RANGE[self.level]
end

-- ── Valid hop targets ──────────────────────────────────────────────────────

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

-- Directional hop: find the valid target best aligned with (dx, dy)
function Fire:tryHopDirection(dx, dy)
    if self.hopping then return end
    if #self.hopTargets == 0 then return end

    local best      = nil
    local bestScore = -math.huge

    for _, tile in ipairs(self.hopTargets) do
        local tc  = tile.col - self.col
        local tr  = tile.row - self.row
        local len = math.sqrt(tc * tc + tr * tr)
        if len > 0 then
            -- dot product with direction (cosine similarity)
            local dot   = (tc * dx + tr * dy) / len
            -- penalise distant tiles slightly so nearby wins ties
            local score = dot - len * 0.05
            if score > bestScore then
                bestScore = score
                best      = tile
            end
        end
    end

    -- Only hop if the best target is roughly in the right direction (dot > 0.3)
    if best and bestScore > 0.3 then
        self:doHop(best.col, best.row)
    end
end

function Fire:doHop(col, row)
    -- Ash the tile we're leaving (ember IS the fire; without it the building is done)
    if self.currentTile and self.currentTile.burnState == self.grid.BURN_STATE.BURNING then
        self.grid:ashTile(self.currentTile)
    end

    -- Level drops by 1 on every hop (floor 1)
    self.level = math.max(1, self.level - 1)

    self.col         = col
    self.row         = row
    self.currentTile = self.grid:getTile(col, row)
    self.burnTimer   = 0
    self.burning     = true

    self.grid:igniteTile(self.currentTile)

    self.hopping  = true
    self.hopTimer = 0.12
end

-- ── Burn progress ──────────────────────────────────────────────────────────

function Fire:burnDuration(tile)
    return tile.mat.burnDuration / BURN_SPEED[self.level]
end

function Fire:onBuildingFinished()
    local tile = self.currentTile
    if not tile then return end

    self.heat = self.heat + tile.mat.heat
    self.grid:ashTile(tile)
    self.burning = false
end

-- Level climbs toward building's cap using a sqrt curve for fast early gain
function Fire:updateLevelFromBurn()
    if not self.currentTile then return end
    local cap = self.currentTile.mat.levelCap
    if cap <= self.level then return end

    local duration = self:burnDuration(self.currentTile)
    if duration <= 0 then return end

    -- sqrt makes level climb fast early in the burn
    local progress = math.sqrt(math.min(1.0, self.burnTimer / duration))
    local target   = self.level + math.floor(progress * (cap - self.level) + 0.5)
    target = math.min(cap, math.max(self.level, target))
    self.level = math.min(FIRE_LEVEL_MAX, target)
end

-- ── Intensity ─────────────────────────────────────────────────────────────

function Fire:drainIntensity(dt)
    self.intensity = self.intensity - AMBIENT_DRAIN * dt
    if self.burning then
        self.intensity = self.intensity + BURN_RESTORE * dt
    end
    self.intensity = math.max(0, math.min(self.intensityMax, self.intensity))
end

function Fire:douse(amount)
    local resistance = 0.25 * (self.level - 1)
    self.intensity = math.max(0, self.intensity - amount * (1 - resistance))
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

        if self.burnTimer >= self:burnDuration(self.currentTile) then
            self:onBuildingFinished()
        end
    end

    self:drainIntensity(dt)
    self:computeHopTargets()
end

-- ── Input ─────────────────────────────────────────────────────────────────

function Fire:keypressed(key)
    local dir = DIR[key]
    if dir then
        self:tryHopDirection(dir[1], dir[2])
    end
end

-- ── Rendering ─────────────────────────────────────────────────────────────

function Fire:draw()
    -- Hop target highlights
    for _, tile in ipairs(self.hopTargets) do
        local px, py = self.grid:tileToPixel(tile.col, tile.row)
        love.graphics.setColor(1, 0.7, 0.2, 0.30)
        love.graphics.rectangle("fill", px, py, self.grid.TILE_W - 1, self.grid.TILE_H - 1)
        love.graphics.setColor(1, 0.5, 0.1, 0.75)
        love.graphics.rectangle("line", px, py, self.grid.TILE_W - 1, self.grid.TILE_H - 1)
    end

    -- Ember on current tile
    if self.currentTile then
        local cx, cy = self.grid:tileCenter(self.col, self.row)
        local radius = 8 + self.level * 4
        love.graphics.setColor(1.0, 0.9, 0.3, 1)
        love.graphics.circle("fill", cx, cy, radius)
        love.graphics.setColor(1.0, 0.4, 0.0, 0.7)
        love.graphics.circle("fill", cx, cy, radius * 0.6)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Accessors ─────────────────────────────────────────────────────────────

function Fire:getLevel()      return self.level       end
function Fire:getIntensity()  return self.intensity   end
function Fire:getHeat()       return self.heat        end
function Fire:getPosition()   return self.col, self.row end

function Fire:getPowerFill()
    if not self.currentTile or not self.burning then return 0 end
    local duration = self:burnDuration(self.currentTile)
    if duration <= 0 then return 1 end
    return math.min(1.0, self.burnTimer / duration)
end

return Fire
