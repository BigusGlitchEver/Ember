-- hud.lua
-- Heads-up display. Primary element: Power Bar with 3 flame icons.

local W_DEFAULT = 1280
local H_DEFAULT = 720

-- Power bar dimensions
local BAR_W = 300
local BAR_H = 20

local COL = {
    barBg       = {0.12, 0.08, 0.06, 0.90},
    fill        = {
        [1] = {0.90, 0.38, 0.05, 1},   -- level 1: deep orange
        [2] = {1.00, 0.60, 0.08, 1},   -- level 2: bright orange
        [3] = {1.00, 0.92, 0.28, 1},   -- level 3: yellow-white
    },
    barBorder   = {0.70, 0.45, 0.15, 1},
    flameOff    = {0.28, 0.18, 0.12, 1},
    flameOn1    = {0.95, 0.50, 0.10, 1},
    flameOn2    = {1.00, 0.70, 0.15, 1},
    flameOn3    = {1.00, 0.95, 0.40, 1},
    flameGlow   = {1.00, 0.80, 0.20, 0.28},
    intBg       = {0.10, 0.10, 0.10, 0.80},
    intFg       = {0.25, 0.65, 1.00, 1},
    intLow      = {1.00, 0.18, 0.08, 1},
    heatBg      = {0.10, 0.10, 0.10, 0.80},
    heatFg      = {0.85, 0.72, 0.18, 1},
    textDim     = {0.70, 0.70, 0.70, 1},
}

local FLAME_COLORS_ON = { COL.flameOn1, COL.flameOn2, COL.flameOn3 }

local HUD = {}
HUD.__index = HUD

function HUD.new(fire, upgrades)
    return setmetatable({ fire=fire, upgrades=upgrades }, HUD)
end

function HUD:update(dt) end

-- ── Helpers ───────────────────────────────────────────────────────────────

local function bar(x, y, w, h, frac, bgCol, fillCol, borderCol)
    love.graphics.setColor(bgCol)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    if frac > 0 then
        love.graphics.setColor(fillCol)
        love.graphics.rectangle("fill", x, y, w * math.min(1, frac), h, 3, 3)
    end
    love.graphics.setColor(borderCol)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
end

-- Simple flame shape: two overlapping ellipses
local function drawFlame(cx, cy, r, lit, level)
    if lit then
        -- Glow
        love.graphics.setColor(COL.flameGlow)
        love.graphics.ellipse("fill", cx, cy, r * 1.3, r * 1.6)

        local col = FLAME_COLORS_ON[level] or COL.flameOn1
        love.graphics.setColor(col)
    else
        love.graphics.setColor(COL.flameOff)
    end
    -- Body
    love.graphics.ellipse("fill", cx, cy + r * 0.1, r * 0.55, r * 0.65)
    -- Tip
    love.graphics.ellipse("fill", cx, cy - r * 0.3, r * 0.32, r * 0.55)
end

-- ── Draw ──────────────────────────────────────────────────────────────────
function HUD:draw()
    local W, H      = love.graphics.getDimensions()
    local fireLevel = self.fire:getLevel()
    local intensity = self.fire:getIntensity()
    local intMax    = self.fire.intensityMax
    local heat      = self.fire:getHeat()
    local heatNext  = self.upgrades:getHeatThreshold()
    local fill      = self.fire:getPowerFill()

    -- ── Power Bar (bottom-center) ─────────────────────────────────────────
    local bx = math.floor((W - BAR_W) / 2)
    local by = H - 44

    bar(bx, by, BAR_W, BAR_H, fill,
        COL.barBg,
        COL.fill[fireLevel] or COL.fill[1],
        COL.barBorder)

    -- Level 3 outer glow
    if fireLevel == 3 then
        love.graphics.setColor(1, 0.9, 0.3, 0.22)
        love.graphics.rectangle("line", bx-3, by-3, BAR_W+6, BAR_H+6, 5, 5)
    end

    -- Flame icons above bar, evenly spaced
    local iconR   = 10
    local spacing = BAR_W / 4
    for i = 1, 3 do
        local ix = bx + spacing * i
        local iy = by - 22
        drawFlame(ix, iy, iconR, fireLevel >= i, i)
    end

    -- Level text
    love.graphics.setColor(1, 1, 1, 0.85)
    love.graphics.print("LVL " .. fireLevel, bx + BAR_W + 8, by + 2)

    -- ── Intensity bar (top-left) ──────────────────────────────────────────
    local iFrac  = intensity / intMax
    local iColor = iFrac < 0.25 and COL.intLow or COL.intFg
    if iFrac < 0.25 then
        -- Pulse red
        local t = love.timer.getTime()
        local p = (math.sin(t * 6) + 1) * 0.5
        iColor  = { iColor[1], iColor[2] * p, iColor[3] * p, 1 }
    end
    bar(20, 18, 160, 14, iFrac, COL.intBg, iColor, {0.4,0.4,0.4,1})
    love.graphics.setColor(COL.textDim)
    love.graphics.print("Intensity  " .. math.floor(intensity), 20, 34)

    -- ── Heat bar (top-right) ──────────────────────────────────────────────
    local hFrac = math.min(1, heat / math.max(1, heatNext))
    bar(W - 180, 18, 160, 14, hFrac, COL.heatBg, COL.heatFg, {0.4,0.4,0.4,1})
    love.graphics.setColor(COL.textDim)
    love.graphics.print("Heat  " .. heat .. " / " .. heatNext, W - 180, 34)

    -- ── Timer (top-center) ────────────────────────────────────────────────
    -- (drawn by run.lua if needed; HUD can expose a timer hook later)

    love.graphics.setColor(1, 1, 1, 1)
end

return HUD
