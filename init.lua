--[[
    Deveolped by Psy
    - ARROW overlay (save-on-close or /stoparrow only)
    - Draws a directional arrow toward your current target.
    - Shows target distance (centered).
    - Lets you tune arrow scale, color, and window position/size (pos is saved; size is fixed unless you remove NoResize).
    - Persists settings ONLY when you close the window or run /stoparrow.

    Requirements:
      - MacroQuest Lua
      - ImGui (bundled with MQ)
      - LIP (INI parser) available as 'lib.LIP'
]]

local mq = require('mq')
require('ImGui')
local LIP = require('lib.LIP')

local terminate = false
local isOpen, shouldDraw = true, true

---@type string
local config_file = mq.configDir .. '/Arrow.ini'

---@class ArrowConfig
---@field arrow_scale number
---@field arrow_color number[]
---@field window_x number
---@field window_y number
---@field window_w number
---@field window_h number
local config = {
    arrow_scale = 4.0,
    arrow_color = {1.0, 1.0, 0.4, 1.0},
    window_x = -1, window_y = -1,
    window_w = 160, window_h = 220,
}

---@param path string
---@return boolean
local function file_exists(path)
    local f = io.open(path, "r")
    if f then f:close() return true end
    return false
end

local function load_config()
    if not file_exists(config_file) then return end
    local ok, ini = pcall(LIP.load, config_file)
    if ok and ini and ini.Settings then
        config.arrow_scale = tonumber(ini.Settings.arrow_scale) or config.arrow_scale
        config.arrow_color = {
            tonumber(ini.Settings.color_r) or config.arrow_color[1],
            tonumber(ini.Settings.color_g) or config.arrow_color[2],
            tonumber(ini.Settings.color_b) or config.arrow_color[3],
            tonumber(ini.Settings.color_a) or config.arrow_color[4],
        }
        config.window_x = tonumber(ini.Settings.window_x) or config.window_x
        config.window_y = tonumber(ini.Settings.window_y) or config.window_y
        config.window_w = tonumber(ini.Settings.window_w) or config.window_w
        config.window_h = tonumber(ini.Settings.window_h) or config.window_h
    end
end

local function save_config()
    local ini = {Settings = {}}

    ini.Settings.arrow_scale = string.format('%.2f', tonumber(config.arrow_scale) or 4.0)
    ini.Settings.color_r     = string.format('%.2f', tonumber(config.arrow_color[1]) or 1.0)
    ini.Settings.color_g     = string.format('%.2f', tonumber(config.arrow_color[2]) or 1.0)
    ini.Settings.color_b     = string.format('%.2f', tonumber(config.arrow_color[3]) or 0.4)
    ini.Settings.color_a     = string.format('%.2f', tonumber(config.arrow_color[4]) or 1.0)

    ini.Settings.window_x    = tostring(math.floor(tonumber(config.window_x or -1)))
    ini.Settings.window_y    = tostring(math.floor(tonumber(config.window_y or -1)))
    ini.Settings.window_w    = tostring(math.floor(tonumber(config.window_w or 160)))
    ini.Settings.window_h    = tostring(math.floor(tonumber(config.window_h or 220)))

    local ok, err = pcall(LIP.save, config_file, ini)
    if not ok then
        print(('\ar[ARROW save error]\ax %s'):format(tostring(err)))
    end
end

---@param draw_list userdata
---@param heading number
---@param size number
---@param corner ImVec2
---@param color integer
local function DrawArrow(draw_list, heading, size, corner, color)
    local halfsize, quartersize, eigthsize, trunksize =
        0.5 * size, 0.25 * size, 0.125 * size, 0.38655 * size

    local center = { x = corner.x + halfsize, y = corner.y + halfsize }
    local rad = math.rad(heading)
    local trunkoffset = 2.896613991
    local sin, cos = math.sin(rad), math.cos(rad)

    local coords = {
        ImVec2(center.x + halfsize * sin, center.y - halfsize * cos),
        ImVec2(center.x + quartersize * cos, center.y + quartersize * sin),
        ImVec2(center.x + eigthsize *  cos, center.y + eigthsize *  sin),
        ImVec2(center.x + trunksize *  math.sin(rad + trunkoffset),
               center.y - trunksize *  math.cos(rad + trunkoffset)),
        ImVec2(center.x + trunksize *  math.sin(rad - trunkoffset),
               center.y - trunksize *  math.cos(rad - trunkoffset)),
        ImVec2(center.x - eigthsize *  cos, center.y - eigthsize *  sin),
        ImVec2(center.x - quartersize * cos, center.y - quartersize * sin),
    }
    draw_list:AddConvexPolyFilled(coords, color)
end

local flags = bit32.bor(
    ImGuiWindowFlags.NoBackground,
    ImGuiWindowFlags.NoTitleBar,
    ImGuiWindowFlags.NoCollapse,
    ImGuiWindowFlags.NoFocusOnAppearing,
    ImGuiWindowFlags.NoDocking,
    ImGuiWindowFlags.NoResize
)

local function updateImGui()
    ImGui.SetNextWindowSize(config.window_w or 160, config.window_h or 220, ImGuiCond.FirstUseEver)
    if (config.window_x or -1) >= 0 and (config.window_y or -1) >= 0 then
        ImGui.SetNextWindowPos(config.window_x, config.window_y, ImGuiCond.FirstUseEver)
    end

    local wasOpen = isOpen
    isOpen, shouldDraw = ImGui.Begin('ARROW', isOpen, flags)

    if wasOpen and not isOpen then
        ImGui.End()
        save_config()
        return
    end

    local ok, err = pcall(function()
        if not shouldDraw then return end

        local scale = math.max(1.0, math.min(10.0, tonumber(config.arrow_scale) or 4.0))
        local arrow_px = ImGui.GetTextLineHeightWithSpacing() * scale
        local colorU32 = ImGui.GetColorU32(ImVec4(
            config.arrow_color[1], config.arrow_color[2],
            config.arrow_color[3], config.arrow_color[4]
        ))

        local arrowCorner = ImGui.GetCursorScreenPosVec()
        ImGui.Dummy(arrow_px, arrow_px)

        local dist = (mq.TLO.Target() and tonumber(mq.TLO.Target.Distance3D())) or 0
        local distStr = string.format('%.2f', dist)
        local w = ImGui.CalcTextSize(distStr)
        ImGui.SetCursorPosX((ImGui.GetWindowWidth() - w) * 0.5)
        ImGui.TextColored(1, 0, 0, 1, distStr)

        ImGui.Separator()

        ImGui.Text("Color"); ImGui.SameLine()
        do
            local colorFlags = ImGuiColorEditFlags.NoInputs
            local c1, c2 = ImGui.ColorEdit4("##ArrowColor", config.arrow_color, colorFlags)
            local newc = (type(c1) == 'table') and c1 or ((type(c2) == 'table') and c2 or nil)
            if newc then
                config.arrow_color = {
                    tonumber(newc[1]) or config.arrow_color[1],
                    tonumber(newc[2]) or config.arrow_color[2],
                    tonumber(newc[3]) or config.arrow_color[3],
                    tonumber(newc[4]) or config.arrow_color[4],
                }
                colorU32 = ImGui.GetColorU32(ImVec4(
                    config.arrow_color[1], config.arrow_color[2],
                    config.arrow_color[3], config.arrow_color[4]
                ))
            end
        end

        do
            local a, b = ImGui.SliderFloat("Scale", scale, 1.0, 10.0, "%.1f")
            local newScale = (type(a) == 'number') and a or ((type(b) == 'number') and b or nil)
            if newScale then
                config.arrow_scale = newScale
                arrow_px = ImGui.GetTextLineHeightWithSpacing() * newScale
            end
        end

        if mq.TLO.Target() then
            local draw_list = ImGui.GetWindowDrawList()
            DrawArrow(
                draw_list,
                mq.TLO.Me.Heading.DegreesCCW() - mq.TLO.Target.HeadingTo.DegreesCCW(),
                arrow_px,
                arrowCorner,
                colorU32
            )
        else
            local hint = "No target"
            local tw = ImGui.CalcTextSize(hint)
            local cx = arrowCorner.x + (arrow_px - tw)/2
            local cy = arrowCorner.y + (arrow_px - ImGui.GetTextLineHeight())/2
            local dl = ImGui.GetWindowDrawList()
            dl:AddText(ImVec2(cx, cy), ImGui.GetColorU32(ImVec4(1,1,1,0.5)), hint)
        end

        do
            local pos = ImGui.GetWindowPosVec()
            local ww  = ImGui.GetWindowWidth()
            local wh  = ImGui.GetWindowHeight()
            config.window_x = math.floor(pos.x + 0.5)
            config.window_y = math.floor(pos.y + 0.5)
            config.window_w = math.floor(ww + 0.5)
            config.window_h = math.floor(wh + 0.5)
        end
    end)

    ImGui.End()

    if not ok then
        print(('\ar[ARROW ImGui error]\ax %s'):format(tostring(err)))
    end
end

function ARROW_Stop()
    if not terminate then
        print('\ao[ARROW]\ax Saving settings and stopping overlay...')
        save_config()
        terminate = true
    end
end

mq.bind('/stoparrow', function() ARROW_Stop() end)

load_config()

mq.imgui.init('ARROW', updateImGui)

while not terminate do
    mq.doevents()
    mq.delay(100)
end
