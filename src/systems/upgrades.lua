-- upgrades.lua
-- Tracks Heat accumulation and triggers upgrade picks.
-- On level-up: pauses the game and offers 3 random upgrades.

-- ── Upgrade definitions ───────────────────────────────────────────────────
local UPGRADE_POOL = {
    { id="hotterCore",   label="Hotter Core",   desc="+Max Intensity; catch resistant buildings faster." },
    { id="longJump",     label="Long Jump",      desc="+Hop range at every Fire Level." },
    { id="backdraft",    label="Backdraft",      desc="Finishing a building restores Intensity." },
    { id="softLanding",  label="Soft Landing",   desc="Every other hop doesn't cost a Fire Level." },
    { id="heatHaze",     label="Heat Haze",      desc="Nearby defenders move slower." },
    { id="greedyFlames", label="Greedy Flames",  desc="+Heat earned per building." },
    { id="fireproofCore",label="Fireproof Core", desc="+Douse resistance; less Intensity lost to water." },
    { id="crowdPanic",   label="Crowd Panic",    desc="NPCs flee at a lower Fire Level." },
    { id="smokeScreen",  label="Smoke Screen",   desc="After a hop, nearby NPCs lose their path briefly." },
}

-- Heat required to reach each upgrade level (level^1.4 curve)
local BASE_HEAT_COST = 60
local function heatForLevel(lvl)
    return math.floor(BASE_HEAT_COST * (lvl ^ 1.4))
end

local Upgrades = {}
Upgrades.__index = Upgrades

function Upgrades.new(fire)
    local self = setmetatable({}, Upgrades)
    self.fire          = fire
    self.upgradeLevel  = 0         -- how many upgrades picked so far
    self.heatThreshold = heatForLevel(1)
    self.active        = {}        -- set of active upgrade IDs: { longJump=true, ... }

    -- UI state
    self.picking       = false     -- true while upgrade menu is open
    self.choices       = {}        -- 3 upgrade defs offered right now
    self.selectedIdx   = 1

    return self
end

-- ── Shuffle helper ────────────────────────────────────────────────────────
local function shuffle(t)
    local n = #t
    for i = n, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

-- ── Pick 3 random upgrades not already active ─────────────────────────────
function Upgrades:buildChoices()
    local pool = {}
    for _, u in ipairs(UPGRADE_POOL) do
        if not self.active[u.id] then
            table.insert(pool, u)
        end
    end
    shuffle(pool)
    self.choices = { pool[1], pool[2], pool[3] }
    -- Remove nils if pool is small
    for i = #self.choices, 1, -1 do
        if not self.choices[i] then table.remove(self.choices, i) end
    end
end

-- ── Apply an upgrade to the fire system ──────────────────────────────────
function Upgrades:applyUpgrade(upgrade)
    if not upgrade then return end
    self.active[upgrade.id] = true
    self.fire.upgrades[upgrade.id] = true

    -- Immediate effects
    if upgrade.id == "hotterCore" then
        self.fire.intensityMax = self.fire.intensityMax + 25
        self.fire.intensity    = math.min(self.fire.intensityMax, self.fire.intensity + 25)
    end
    -- Other upgrades are flags read by fire.lua / npc.lua at runtime
end

-- ── Update ────────────────────────────────────────────────────────────────
function Upgrades:update(dt)
    if self.picking then return end   -- paused for pick

    -- Mirror heat from fire system
    local heat = self.fire:getHeat()
    if heat >= self.heatThreshold then
        self.upgradeLevel  = self.upgradeLevel + 1
        self.heatThreshold = self.heatThreshold + heatForLevel(self.upgradeLevel + 1)
        self:buildChoices()
        self.picking     = true
        self.selectedIdx = 1
    end
end

-- ── Input ─────────────────────────────────────────────────────────────────
function Upgrades:keypressed(key)
    if not self.picking then return end

    if key == "left" or key == "a" then
        self.selectedIdx = math.max(1, self.selectedIdx - 1)
    elseif key == "right" or key == "d" then
        self.selectedIdx = math.min(#self.choices, self.selectedIdx + 1)
    elseif key == "return" or key == "space" then
        self:applyUpgrade(self.choices[self.selectedIdx])
        self.picking = false
    end
end

-- ── Rendering ─────────────────────────────────────────────────────────────
-- The upgrade pick screen renders on top of the game (run.lua draws after grid/fire)
function Upgrades:draw()
    if not self.picking then return end

    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.65)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

    love.graphics.setColor(1, 0.8, 0.3, 1)
    love.graphics.print("CHOOSE AN UPGRADE", 530, 200)

    for i, u in ipairs(self.choices) do
        local x = 200 + (i - 1) * 300
        local y = 280
        local selected = (i == self.selectedIdx)

        love.graphics.setColor(selected and {1,0.5,0.1,1} or {0.5,0.3,0.1,1})
        love.graphics.rectangle("fill", x, y, 240, 120, 8, 8)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(u.label, x + 10, y + 12)
        love.graphics.setColor(0.85, 0.85, 0.85, 1)
        -- Wrap description manually (simple)
        love.graphics.printf(u.desc, x + 10, y + 36, 220)
    end

    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("← → to choose   ENTER to confirm", 490, 430)
    love.graphics.setColor(1, 1, 1, 1)
end

-- ── Accessors ─────────────────────────────────────────────────────────────
function Upgrades:getHeatThreshold() return self.heatThreshold end
function Upgrades:isPicking()        return self.picking        end

return Upgrades
