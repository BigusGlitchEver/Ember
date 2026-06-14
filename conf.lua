-- LÖVE2D window and module configuration
function love.conf(t)
    t.title          = "Ember"
    t.version        = "11.4"
    t.window.width   = 1280
    t.window.height  = 720
    t.window.resizable = false
    t.window.vsync   = 1

    -- Disable unused modules for faster startup
    t.modules.joystick = false
    t.modules.physics  = false  -- using tile-coord collision, not Box2D
    t.modules.video    = false
end
