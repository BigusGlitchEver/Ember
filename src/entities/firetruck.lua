-- firetruck.lua
-- Fire truck entity. Spawns at a road tile on the map edge, BFS-paths to the
-- nearest road tile adjacent to the fire, then sprays until the fire moves.
--
-- Responsibilities: pathfinding, movement, spraying.
-- Does NOT own its own spawn logic — Defenders calls FireTruck.new().

local TRUCK_SPEED   = 55    -- px/s along road path
local SPRAY_RANGE   = 90    -- px: distance at which truck starts spraying
local SPRAY_RATE    = 28    -- intensity drained per second (very high)
local REPATH_SECS   = 3.0   -- seconds between path recalculations once moving

local FireTruck = {}
FireTruck.__index = FireTruck

-- grid : Grid system
-- fire : Fire system
function FireTruck.new(grid, fire)
    local self      = setmetatable({}, FireTruck)
    self.grid       = grid
    self.fire       = fire
    self.done       = false

    -- Pixel position — start at spawn tile center
    local sc, sr    = FireTruck.findSpawnTile(grid, fire)
    self.x, self.y  = grid:tileCenter(sc, sr)
    self.col        = sc
    self.row        = sr

    -- Path: list of {col, row} waypoints from current pos → target
    self.path       = {}
    self.pathIdx    = 1
    self.repathTimer = 0

    -- Siren flash timer for visuals
    self.sirenTimer = 0

    self:repath()
    return self
end

-- ── Spawn tile: nearest edge road tile to the fire ────────────────────────

function FireTruck.findSpawnTile(grid, fire)
    local fc, fr = fire:getPosition()
    local bestDist = math.huge
    local bc, br   = 1, 1

    local function tryEdge(col, row)
        local tile = grid:getTile(col, row)
        if tile and tile.material == "road" then
            local d = grid:tileDistance(col, row, fc, fr)
            if d < bestDist then
                bestDist = d
                bc, br   = col, row
            end
        end
    end

    -- Check all four edges
    for col = 1, grid.cols do
        tryEdge(col, 1)
        tryEdge(col, grid.rows)
    end
    for row = 1, grid.rows do
        tryEdge(1, row)
        tryEdge(grid.cols, row)
    end

    return bc, br
end

-- ── BFS road pathfinding ──────────────────────────────────────────────────
-- Finds the shortest road-only path from (sc, sr) to any road tile adjacent
-- to the fire's current tile. Returns list of {col, row} or {}.

function FireTruck:bfsToFire()
    local g      = self.grid
    local fc, fr = self.fire:getPosition()

    -- Target set: road tiles adjacent (4-dir) to the fire tile
    local targets = {}
    for _, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
        local nc, nr = fc + d[1], fr + d[2]
        local tile   = g:getTile(nc, nr)
        if tile and tile.material == "road" then
            targets[nc .. "," .. nr] = true
        end
    end

    local startC = math.floor((self.x - g.TILE_W * 0.5) / g.TILE_W) + 1
    local startR = math.floor((self.y - g.TILE_H * 0.5) / g.TILE_H) + 1
    startC = math.max(1, math.min(g.cols, startC))
    startR = math.max(1, math.min(g.rows, startR))

    -- BFS
    local queue   = {{ col=startC, row=startR, path={} }}
    local visited = {}

    while #queue > 0 do
        local node = table.remove(queue, 1)
        local key  = node.col .. "," .. node.row

        if not visited[key] then
            visited[key] = true
            local newPath = {}
            for _, p in ipairs(node.path) do table.insert(newPath, p) end
            table.insert(newPath, { col=node.col, row=node.row })

            if targets[key] then
                return newPath
            end

            for _, d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
                local nc, nr = node.col + d[1], node.row + d[2]
                local nkey   = nc .. "," .. nr
                if not visited[nkey] then
                    local tile = g:getTile(nc, nr)
                    if tile and tile.material == "road" then
                        table.insert(queue, { col=nc, row=nr, path=newPath })
                    end
                end
            end
        end
    end

    return {}   -- no road path found (shouldn't happen on this map)
end

function FireTruck:repath()
    local newPath = self:bfsToFire()
    if #newPath > 0 then
        self.path    = newPath
        self.pathIdx = 1
    end
    self.repathTimer = REPATH_SECS
end

-- ── Spray check ───────────────────────────────────────────────────────────

function FireTruck:distToFire()
    local fc, fr = self.fire:getPosition()
    local fx, fy = self.grid:tileCenter(fc, fr)
    local dx, dy = fx - self.x, fy - self.y
    return math.sqrt(dx * dx + dy * dy)
end

function FireTruck:isSpraying()
    return self:distToFire() <= SPRAY_RANGE
end

-- ── Update ────────────────────────────────────────────────────────────────

function FireTruck:update(dt)
    if self.done then return end

    self.sirenTimer = self.sirenTimer + dt

    if self:isSpraying() then
        -- Spray the fire
        self.fire:douse(SPRAY_RATE * dt)
    else
        -- Drive along path
        self.repathTimer = self.repathTimer - dt
        if self.repathTimer <= 0 then
            self:repath()
        end

        if self.pathIdx <= #self.path then
            local wp      = self.path[self.pathIdx]
            local tx, ty  = self.grid:tileCenter(wp.col, wp.row)
            local dx, dy  = tx - self.x, ty - self.y
            local dist    = math.sqrt(dx * dx + dy * dy)

            if dist <= 3 then
                self.pathIdx = self.pathIdx + 1
            else
                local step = math.min(TRUCK_SPEED * dt, dist)
                self.x = self.x + dx / dist * step
                self.y = self.y + dy / dist * step
            end
        else
            -- Reached end of path without being in spray range — repath
            self:repath()
        end
    end
end

-- ── Rendering ─────────────────────────────────────────────────────────────

function FireTruck:draw()
    local W2, H2 = 18, 11

    -- Body
    love.graphics.setColor(0.85, 0.15, 0.10, 1)
    love.graphics.rectangle("fill", self.x - W2, self.y - H2, W2*2, H2*2, 3, 3)

    -- White stripe
    love.graphics.setColor(1, 1, 1, 0.9)
    love.graphics.rectangle("fill", self.x - W2, self.y - 3, W2*2, 6)

    -- Siren light (alternating blue/red flash)
    local flash = math.floor(self.sirenTimer * 6) % 2 == 0
    love.graphics.setColor(flash and {0.2,0.4,1,1} or {1,0.2,0.1,1})
    love.graphics.rectangle("fill", self.x - 6, self.y - H2 - 5, 12, 5, 2, 2)

    -- Spray cone when active
    if self:isSpraying() then
        local fc, fr = self.fire:getPosition()
        local fx, fy = self.grid:tileCenter(fc, fr)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.25)
        love.graphics.line(self.x, self.y, fx, fy)
        love.graphics.circle("fill", fx, fy, 20)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

return FireTruck
