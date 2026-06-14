-- grid.lua
-- Owns the tile map: a 2D array of tile structs.
-- Responsible for rendering tiles and answering spatial queries.

-- ── Tile material definitions ──────────────────────────────────────────────
local MATERIALS = {
    shack   = { flammable=true,  levelCap=1, burnDuration=4,  heat=10,  color={0.76,0.60,0.42} },
    house   = { flammable=true,  levelCap=2, burnDuration=8,  heat=25,  color={0.65,0.50,0.35} },
    mansion = { flammable=true,  levelCap=3, burnDuration=14, heat=50,  color={0.55,0.40,0.28} },
    road    = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.35,0.35,0.35} },
    river   = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.20,0.40,0.80}, isWater=true },
    well    = { flammable=false, levelCap=0, burnDuration=0,  heat=0,   color={0.30,0.55,0.70}, isWater=true },
}

local BURN_STATE = { INTACT="intact", BURNING="burning", ASH="ash" }

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

local TILE_W = 48
local TILE_H = 48

-- Colors for level cap dots
local LEVEL_COLORS = {
    [1] = {1.00, 0.90, 0.20},   -- yellow  (L1)
    [2] = {1.00, 0.55, 0.10},   -- orange  (L2)
    [3] = {0.95, 0.20, 0.20},   -- red     (L3)
}

local Grid = {}
Grid.__index = Grid
Grid.BURN_STATE = BURN_STATE
Grid.MATERIALS  = MATERIALS
Grid.TILE_W     = TILE_W
Grid.TILE_H     = TILE_H

function Grid.new()
    local self = setmetatable({}, Grid)
    self.tiles          = {}
    self.cols           = 0
    self.rows           = 0
    self.flammableCount = 0
    self.ashCount       = 0
    self.burningTiles   = {}   -- all currently burning tiles (maintained by igniteTile/ashTile)
    self.waterSources   = {}   -- cached water tile centers, built once after loadMap
    self.smallFont      = love.graphics.newFont(8)
    self:loadMap()
    self:buildWaterCache()
    return self
end

-- ── Map — 26 cols x 15 rows = 1248x720 at 48px tiles ─────────────────────
-- S=shack(L1)  H=house(L2)  M=mansion(L3)
-- R=road  W=well  ~=river
function Grid:loadMap()
    local R,S,H,M,W = "road","shack","house","mansion","well"
    local rv = "river"

    local layout = {
    --  1   2   3   4   5   6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26
      { R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R }, -- 1
      { R,  S,  S,  H,  R,  S,  H,  S,  H,  R,  H,  H,  R,  M,  M,  R,  S,  H,  R,  H,  S,  H,  R,  S,  S,  R }, -- 2
      { R,  S,  H,  H,  R,  H,  S,  H,  H,  R,  H,  S,  R,  M,  H,  R,  H,  H,  R,  H,  H,  H,  R,  S,  H,  R }, -- 3
      { R,  R,  R,  R,  W,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  W,  R,  R,  R,  R,  R,  R,  R }, -- 4
      { R,  H,  M,  M,  R,  S,  S,  H,  R,  H,  H,  R,  S,  R,  M,  M,  H,  R,  H,  H,  R,  S,  M,  R,  M,  R }, -- 5
      { R,  H,  M,  H,  R,  S,  H,  S,  R,  H,  S,  R,  H,  R,  M,  H,  H,  R,  H,  M,  R,  S,  M,  R,  M,  R }, -- 6
      { R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R }, -- 7
      {rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv, rv  }, -- 8
      { R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R }, -- 9
      { R,  M,  M,  H,  R,  H,  H,  R,  S,  S,  H,  R,  H,  R,  M,  M,  R,  S,  H,  H,  R,  M,  R,  S,  H,  R }, -- 10
      { R,  M,  H,  H,  R,  H,  S,  R,  S,  H,  H,  R,  H,  R,  M,  H,  R,  S,  H,  M,  R,  M,  R,  H,  H,  R }, -- 11
      { R,  R,  R,  W,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  W,  R,  R,  R,  R,  R,  R,  R,  R,  R }, -- 12
      { R,  S,  H,  R,  H,  H,  S,  R,  S,  R,  M,  M,  R,  H,  R,  S,  S,  R,  M,  M,  R,  H,  H,  R,  S,  R }, -- 13
      { R,  H,  H,  R,  H,  M,  H,  R,  H,  R,  M,  H,  R,  M,  R,  S,  H,  R,  M,  H,  R,  H,  S,  R,  H,  R }, -- 14
      { R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R,  R }, -- 15
    }

    self.rows = #layout
    self.cols = #layout[1]

    local occupantsByMaterial = { shack=1, house=2, mansion=3 }

    for r, row in ipairs(layout) do
        self.tiles[r] = {}
        for c, mat in ipairs(row) do
            local tile = newTile(mat, c, r)
            tile.occupants = occupantsByMaterial[mat] or 0
            self.tiles[r][c] = tile
            if tile.mat.flammable then
                self.flammableCount = self.flammableCount + 1
            end
        end
    end
end

-- ── Spatial helpers ────────────────────────────────────────────────────────

function Grid:getTile(col, row)
    local r = self.tiles[row]
    return r and r[col]
end

function Grid:pixelToTile(px, py)
    local col = math.floor(px / TILE_W) + 1
    local row = math.floor(py / TILE_H) + 1
    return col, row
end

function Grid:tileToPixel(col, row)
    return (col - 1) * TILE_W, (row - 1) * TILE_H
end

function Grid:tileCenter(col, row)
    return (col - 1) * TILE_W + TILE_W * 0.5,
           (row - 1) * TILE_H + TILE_H * 0.5
end

function Grid:tileDistance(c1, r1, c2, r2)
    return math.max(math.abs(c2 - c1), math.abs(r2 - r1))
end

-- ── Water source cache ─────────────────────────────────────────────────────
-- Built once after loadMap; O(1) lookup for NPCs.

function Grid:buildWaterCache()
    self.waterSources = {}
    for row = 1, self.rows do
        for col = 1, self.cols do
            local tile = self.tiles[row][col]
            if tile and tile.mat.isWater then
                local cx, cy = self:tileCenter(col, row)
                table.insert(self.waterSources, { x = cx, y = cy, col = col, row = row })
            end
        end
    end
end

-- Returns the pixel center of the water source nearest to (x, y).
function Grid:nearestWater(x, y)
    local bestDist2 = math.huge
    local bx, by   = x, y
    for _, ws in ipairs(self.waterSources) do
        local d2 = (ws.x - x)^2 + (ws.y - y)^2
        if d2 < bestDist2 then
            bestDist2 = d2
            bx, by   = ws.x, ws.y
        end
    end
    return bx, by
end

-- ── Burn state management ──────────────────────────────────────────────────

function Grid:igniteTile(tile)
    if tile.burnState == BURN_STATE.INTACT and tile.mat.flammable then
        tile.burnState = BURN_STATE.BURNING
        tile.burnTimer = 0
        table.insert(self.burningTiles, tile)
    end
end

function Grid:ashTile(tile)
    if tile.burnState == BURN_STATE.BURNING then
        tile.burnState = BURN_STATE.ASH
        self.ashCount  = self.ashCount + 1
        -- Remove from burningTiles list
        for i = #self.burningTiles, 1, -1 do
            if self.burningTiles[i] == tile then
                table.remove(self.burningTiles, i)
                break
            end
        end
    end
end

function Grid:allBurned()
    return self.ashCount >= self.flammableCount
end

function Grid:percentBurned()
    if self.flammableCount == 0 then return 100 end
    return (self.ashCount / self.flammableCount) * 100
end

function Grid:update(dt) end

-- ── Rendering ─────────────────────────────────────────────────────────────
local BURN_TINT = {0.90, 0.40, 0.10}
local ASH_COLOR = {0.20, 0.18, 0.16}

function Grid:draw()
    local prevFont = love.graphics.getFont()
    love.graphics.setFont(self.smallFont)

    for row = 1, self.rows do
        for col = 1, self.cols do
            local tile = self.tiles[row][col]
            local px, py = self:tileToPixel(col, row)

            -- Base tile color
            if tile.burnState == BURN_STATE.ASH then
                love.graphics.setColor(ASH_COLOR)
            elseif tile.burnState == BURN_STATE.BURNING then
                local c = tile.mat.color
                love.graphics.setColor(
                    (c[1] + BURN_TINT[1]) * 0.5,
                    (c[2] + BURN_TINT[2]) * 0.5,
                    (c[3] + BURN_TINT[3]) * 0.5
                )
            else
                love.graphics.setColor(tile.mat.color)
            end
            love.graphics.rectangle("fill", px, py, TILE_W - 1, TILE_H - 1)

            -- Per-tile info: level cap dots + heat reward (intact flammable only)
            if tile.burnState == BURN_STATE.INTACT and tile.mat.flammable
               and tile.mat.levelCap and tile.mat.levelCap > 0 then

                local cap  = tile.mat.levelCap
                local lcol = LEVEL_COLORS[cap] or {1,1,1}
                local dotS = 5
                local dotG = 2

                -- Level cap dots 