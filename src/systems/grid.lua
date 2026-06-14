-- grid.lua
-- The tile map. Owns all tile data and spatial queries.
-- Renders itself centered on the screen.

local MATERIALS = {
    shack   = { flammable=true,  levelCap=1, burnDuration=6,  heat=10,  color={0.76,0.60,0.42} },
    house   = { flammable=true,  levelCap=2, burnDuration=14, heat=25,  color={0.60,0.47,0.32} },
    mansion = { flammable=true,  levelCap=3, burnDuration=26, heat=50,  color={0.48,0.36,0.24} },
    brick   = { flammable=false, levelCap=3, burnDuration=35, heat=80,  color={0.55,0.32,0.22}, slowCatch=true },
    tree    = { flammable=true,  levelCap=1, burnDuration=4,  heat=5,   color={0.25,0.52,0.20} },
    road    = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.32,0.32,0.32} },
    river   = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.18,0.38,0.75}, isWater=true, fastRefill=true },
    well    = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.28,0.52,0.68}, isWater=true, fastRefill=true },
    fuel    = { flammable=true,  levelCap=3, burnDuration=2,  heat=150, color={0.68,0.58,0.18}, explosive=true },
}

local BURN_STATE = { INTACT="intact", BURNING="burning", ASH="ash" }

local TILE_W = 48
local TILE_H = 48

local function newTile(material, col, row)
    local mat = MATERIALS[material]
    assert(mat, "Unknown material: " .. tostring(material))
    return {
        material  = material,
        mat       = mat,
        col       = col,
        row       = row,
        burnState = BURN_STATE.INTACT,
        burnTimer = 0,
        occupants = 0,
    }
end

local Grid = {}
Grid.__index    = Grid
Grid.BURN_STATE = BURN_STATE
Grid.MATERIALS  = MATERIALS
Grid.TILE_W     = TILE_W
Grid.TILE_H     = TILE_H

function Grid.new()
    local self      = setmetatable({}, Grid)
    self.tiles      = {}
    self.cols       = 0
    self.rows       = 0
    self.flammableCount = 0
    self.ashCount       = 0
    self.offsetX    = 0
    self.offsetY    = 0
    self:loadMap()
    self:centerOnScreen()
    return self
end

-- ── Map layout ────────────────────────────────────────────────────────────
function Grid:loadMap()
    local layout = {
        {"road","road","road","road","road","road","road","road","road","road","road","road","road","road","road","road"},
        {"road","shack","shack","house","road","shack","house","road","well","road","house","mansion","road","shack","shack","road"},
        {"road","shack","house","house","road","house","house","road","road","road","house","mansion","road","house","shack","road"},
        {"road","road","road","road","road","road","road","road","road","road","road","road","road","road","road","road"},
        {"road","house","mansion","road","shack","shack","road","well","road","shack","road","house","house","road","house","road"},
        {"road","house","mansion","road","shack","house","road","road","road","house","road","house","mansion","road","house","road"},
        {"road","road","road","road","road","road","road","road","road","road","road","road","road","road","road","road"},
        {"river","river","river","river","river","river","river","river","river","river","river","river","river","river","river","river"},
        {"road","road","road","road","road","road","road","road","road","road","road","road","road","road","road","road"},
        {"road","mansion","mansion","road","house","house","road","well","road","house","road","shack","shack","road","mansion","road"},
        {"road","mansion","house","road","house","shack","road","road","road","house","road","shack","house","road","mansion","road"},
        {"road","road","road","road","road","road","road","road","road","road","road","road","road","road","road","road"},
    }

    local occupantsByMaterial = { shack=1, house=2, mansion=3 }

    self.rows = #layout
    self.cols = #layout[1]

    for r, row in ipairs(layout) do
        self.tiles[r] = {}
        for c, mat in ipairs(row) do
            local tile       = newTile(mat, c, r)
            tile.occupants   = occupantsByMaterial[mat] or 0
            self.tiles[r][c] = tile
            if tile.mat.flammable then
                self.flammableCount = self.flammableCount + 1
            end
        end
    end
end

function Grid:centerOnScreen()
    local W, H     = love.graphics.getDimensions()
    self.offsetX   = math.floor((W - self.cols * TILE_W) / 2)
    self.offsetY   = math.floor((H - self.rows * TILE_H) / 2)
end

-- ── Spatial helpers ───────────────────────────────────────────────────────
function Grid:getTile(col, row)
    local r = self.tiles[row]
    return r and r[col]
end

function Grid:pixelToTile(px, py)
    local col = math.floor((px - self.offsetX) / TILE_W) + 1
    local row = math.floor((py - self.offsetY) / TILE_H) + 1
    return col, row
end

function Grid:tileToPixel(col, row)
    return self.offsetX + (col - 1) * TILE_W,
           self.offsetY + (row - 1) * TILE_H
end

function Grid:tileCenter(col, row)
    return self.offsetX + (col - 1) * TILE_W + TILE_W * 0.5,
           self.offsetY + (row - 1) * TILE_H + TILE_H * 0.5
end

function Grid:tileDistance(c1, r1, c2, r2)
    return math.max(math.abs(c2 - c1), math.abs(r2 - r1))
end

-- ── Burn state management ──────────────────────────────────────────────────
function Grid:igniteTile(tile)
    if tile.burnState == BURN_STATE.INTACT and tile.mat.flammable then
        tile.burnState = BURN_STATE.BURNING
        tile.burnTimer = 0
    end
end

function Grid:ashTile(tile)
    if tile.burnState == BURN_STATE.BURNING then
        tile.burnState  = BURN_STATE.ASH
        self.ashCount   = self.ashCount + 1
    end
end

-- ── Win condition ─────────────────────────────────────────────────────────
function Grid:allBurned()
    return self.ashCount >= self.flammableCount
end

function Grid:percentBurned()
    if self.flammableCount == 0 then return 100 end
    return (self.ashCount / self.flammableCount) * 100
end

-- ── Update ────────────────────────────────────────────────────────────────
function Grid:update(dt)
    -- Grid is passive; fire system drives burn timers.
end

-- ── Rendering ─────────────────────────────────────────────────────────────
local ASH_COLOR  = {0.18, 0.16, 0.14}
local BURN_TINT  = {0.85, 0.38, 0.08}

function Grid:draw()
    for row = 1, self.rows do
        for col = 1, self.cols do
            local tile = self.tiles[row][col]
            local px   = self.offsetX + (col - 1) * TILE_W
            local py   = self.offsetY + (row - 1) * TILE_H

            if tile.burnState == BURN_STATE.ASH then
                love.graphics.setColor(ASH_COLOR)
            elseif tile.burnState == BURN_STATE.BURNING then
                local c = tile.mat.color
                love.graphics.setColor(
                    math.min(1, c[1] * 0.5 + BURN_TINT[1] * 0.5),
                    math.min(1, c[2] * 0.5 + BURN_TINT[2] * 0.5),
                    math.min(1, c[3] * 0.5 + BURN_TINT[3] * 0.5)
                )
            else
                love.graphics.setColor(tile.mat.color)
            end

            love.graphics.rectangle("fill", px+1, py+1, TILE_W-2, TILE_H-2)

            -- Subtle grid lines
            love.graphics.setColor(0, 0, 0, 0.18)
            love.graphics.rectangle("line", px, py, TILE_W, TILE_H)
        end
    end
    love.graphics.setColor(1, 1, 1, 1)
end

return Grid
