-- defenders.lua
-- Spawns and manages NPCs (occupants, neighbors, fire department).
-- Reads fire position/level to make targeting and flee decisions.
-- Delegates per-NPC behavior to the NPC entity class.

local NPC = require("src.entities.npc")

-- ── Escalation timing ─────────────────────────────────────────────────────
local NEIGHBOR_DELAY     = 10.0   -- seconds after ignition before neighbors respond
local FIRETRUCK_DELAY    = 90.0   -- seconds before first truck (reduced at high burn%)
local FIRETRUCK_DELAY_MIN = 30.0  -- minimum truck delay regardless of burn speed
local BUCKET_CHAIN_COUNT = 3      -- NPCs near same water source to auto-chain

-- ── NPC cap ───────────────────────────────────────────────────────────────
local NPC_CAP = 25

-- ── Defenders ─────────────────────────────────────────────────────────────
local Defenders = {}
Defenders.__index = Defenders

function Defenders.new(grid, fire)
    local self = setmetatable({}, Defenders)
    self.grid    = grid
    self.fire    = fire
    self.npcs    = {}       -- active NPC entities
    self.trucks  = {}       -- fire trucks (future entity)

    -- Track which tiles have triggered occupant/neighbor spawns
    self.spawnedOccupants = {}   -- tile key → true
    self.neighborTriggered = {}  -- tile key → true

    self.runTimer         = 0
    self.truckSpawned     = false

    return self
end

-- ── Tile key ──────────────────────────────────────────────────────────────
local function tileKey(col, row) return col .. "," .. row end

-- ── NPC spawning ──────────────────────────────────────────────────────────

function Defenders:spawnOccupants(tile)
    local key = tileKey(tile.col, tile.row)
    if self.spawnedOccupants[key] then return end
    self.spawnedOccupants[key] = true

    local count = tile.occupants or 0
    for i = 1, count do
        if #self.npcs < NPC_CAP then
            local cx, cy = self.grid:tileCenter(tile.col, tile.row)
            local npc = NPC.new("occupant", cx, cy, self.grid, self.fire)
            table.insert(self.npcs, npc)
        end
    end
end

function Defenders:spawnNeighbors(burningTile)
    local key = tileKey(burningTile.col, burningTile.row)
    if self.neighborTriggered[key] then return end
    self.neighborTriggered[key] = true

    local radius = 3  -- neighbor response radius in tiles
    local g = self.grid

    for row = 1, g.rows do
        for col = 1, g.cols do
            if g:tileDistance(burningTile.col, burningTile.row, col, row) <= radius then
                local tile = g:getTile(col, row)
                if tile and tile.mat.flammable
                   and tile.burnState == g.BURN_STATE.INTACT
                   and tile.occupants and tile.occupants > 0
                then
                    local nkey = tileKey(col, row)
                    if not self.spawnedOccupants[nkey] then
                        -- Spawn as neighbor (delayed, calmer)
                        if #self.npcs < NPC_CAP then
                            local cx, cy = g:tileCenter(col, row)
                            local npc = NPC.new("neighbor", cx, cy, g, self.fire)
                            table.insert(self.npcs, npc)
                        end
                    end
                end
            end
        end
    end
end

-- ── Bucket chain self-organization ────────────────────────────────────────
-- When 3+ NPCs are near the same water source, they automatically chain.
-- Called each update; cheap because NPC count is capped.
function Defenders:updateBucketChains()
    -- TODO: group NPCs by nearest water source tile,
    -- if group size >= BUCKET_CHAIN_COUNT, set chain=true on each member.
    -- Chained NPCs get a dousing bonus and don't individually path to fire.
end

-- ── Fire truck ────────────────────────────────────────────────────────────
function Defenders:trySpawnTruck(runTimer)
    if self.truckSpawned then return end

    local burnPct = self.grid:percentBurned()
    -- Delay shortens as more of the town burns
    local delay = FIRETRUCK_DELAY - (burnPct / 100) * (FIRETRUCK_DELAY - FIRETRUCK_DELAY_MIN)
    delay = math.max(FIRETRUCK_DELAY_MIN, delay)

    if runTimer >= delay then
        self.truckSpawned = true
        -- TODO: spawn fire truck entity at map edge, path to fire
        -- self.trucks[#self.trucks+1] = FireTruck.new(...)
    end
end

-- ── Update ────────────────────────────────────────────────────────────────

function Defenders:update(dt, runTimer)
    self.runTimer = runTimer

    -- Check for newly burning tiles to trigger occupant spawns
    local g = self.grid
    local fc, fr = self.fire:getPosition()
    local burningTile = g:getTile(fc, fr)
    if burningTile and burningTile.burnState == g.BURN_STATE.BURNING then
        self:spawnOccupants(burningTile)
    end

    -- Trigger neighbor response after delay
    if runTimer >= NEIGHBOR_DELAY and burningTile
       and burningTile.burnState == g.BURN_STATE.BURNING then
        self:spawnNeighbors(burningTile)
    end

    -- Fire truck escalation
    self:trySpawnTruck(runTimer)

    -- Bucket chain check
    self:updateBucketChains()

    -- Update each NPC; remove dead/fled ones
    local alive = {}
    for _, npc in ipairs(self.npcs) do
        npc:update(dt)
        if not npc.done then
            table.insert(alive, npc)
        end
    end
    self.npcs = alive
end

-- ── Rendering ─────────────────────────────────────────────────────────────

function Defenders:draw()
    for _, npc in ipairs(self.npcs) do
        npc:draw()
    end
    -- TODO: draw fire trucks
end

return Defenders
