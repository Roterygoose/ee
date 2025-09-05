--[[

    esp-lib.lua
    A library for creating esp visuals in roblox using drawing.
    Provides functions to add boxes, health bars, names and distances to instances.
    Written by tul (@.lutyeh).

]]

-- // table
local esplib = getgenv().esplib
if not esplib then
    esplib = {
        box = {
            enabled = true,
            type = "normal", -- normal, corner
            padding = 1.15,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
        },
        healthbar = {
            enabled = true,
            fill = Color3.new(0,1,0),
            outline = Color3.new(0,0,0),
        },
        name = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
        },
        distance = {
            enabled = true,
            fill = Color3.new(1,1,1),
            size = 13,
        },
        tracer = {
            enabled = true,
            fill = Color3.new(1,1,1),
            outline = Color3.new(0,0,0),
            from = "mouse", -- mouse, head, top, bottom, center
        },
    }
    getgenv().esplib = esplib
end

local espinstances = {}
local espfunctions = {}

-- // services
local run_service = game:GetService("RunService")
local players = game:GetService("Players")
local user_input_service = game:GetService("UserInputService")
local camera = workspace.CurrentCamera
local localPlayer = players.LocalPlayer

-- // optimization variables
local math_huge = math.huge
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_clamp = math.clamp
local vector2_new = Vector2.new
local vector3_new = Vector3.new
local color3_new = Color3.new

-- // cached viewport size
local viewport_size = camera.ViewportSize
local viewport_center_x = viewport_size.X / 2
local viewport_center_y = viewport_size.Y / 2

-- Update viewport cache when screen size changes
camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    viewport_size = camera.ViewportSize
    viewport_center_x = viewport_size.X / 2
    viewport_center_y = viewport_size.Y / 2
end)

function espfunctions.add_box(instance)
    if not instance or espinstances[instance] and espinstances[instance].box then return end

    local box = {}

    local outline = Drawing.new("Quad")
    outline.Thickness = 3
    outline.Filled = false
    outline.Transparency = 1
    outline.Visible = false

    local fill = Drawing.new("Quad")
    fill.Thickness = 1
    fill.Filled = false
    fill.Transparency = 1
    fill.Visible = false

    box.outline = outline
    box.fill = fill

    box.corner_fill = {}
    box.corner_outline = {}
    for i = 1, 8 do
        local outline = Drawing.new("Line")
        outline.Thickness = 3
        outline.Transparency = 1
        outline.Visible = false

        local fill = Drawing.new("Line")
        fill.Thickness = 1
        fill.Transparency = 1
        fill.Visible = false
        table.insert(box.corner_fill, fill)

        table.insert(box.corner_outline, outline)
    end

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].box = box
end

function espfunctions.add_healthbar(instance)
    if not instance or espinstances[instance] and espinstances[instance].healthbar then return end
    
    local outline = Drawing.new("Quad")
    outline.Thickness = 2
    outline.Filled = false
    outline.Transparency = 1

    local fill = Drawing.new("Quad")
    fill.Filled = true
    fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].healthbar = {
        outline = outline,
        fill = fill,
    }
end

function espfunctions.add_name(instance)
    if not instance or espinstances[instance] and espinstances[instance].name then return end
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Size = 13
    text.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].name = text
end

function espfunctions.add_distance(instance)
    if not instance or espinstances[instance] and espinstances[instance].distance then return end
    local text = Drawing.new("Text")
    text.Center = true
    text.Outline = true
    text.Font = 2
    text.Size = 11
    text.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].distance = text
end

function espfunctions.add_tracer(instance)
    if not instance or espinstances[instance] and espinstances[instance].tracer then return end
    local outline = Drawing.new("Line")
    outline.Thickness = 3
    outline.Transparency = 1

    local fill = Drawing.new("Line")
    fill.Thickness = 1
    fill.Transparency = 1

    espinstances[instance] = espinstances[instance] or {}
    espinstances[instance].tracer = {
        outline = outline,
        fill = fill,
    }
end

-- // optimized cleanup function
local function cleanup_instance(instance, data)
    if data.box then
        data.box.outline:Remove()
        data.box.fill:Remove()
        for _, line in ipairs(data.box.corner_fill) do
            line:Remove()
        end
        for _, line in ipairs(data.box.corner_outline) do
            line:Remove()
        end
    end
    if data.healthbar then
        data.healthbar.outline:Remove()
        data.healthbar.fill:Remove()
    end
    if data.name then
        data.name:Remove()
    end
    if data.distance then
        data.distance:Remove()
    end
    if data.tracer then
        data.tracer.outline:Remove()
        data.tracer.fill:Remove()
    end
    espinstances[instance] = nil
end

-- // main thread
run_service.RenderStepped:Connect(function()
    for instance, data in pairs(espinstances) do
        if not instance or not instance.Parent then
            cleanup_instance(instance, data)
            continue
        end

        local character = instance
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")

        -- Basic checks
        if not character or not humanoid or not humanoidRootPart or humanoid.Health <= 0 then
            if data.box then
                data.box.outline.Visible = false
                data.box.fill.Visible = false
                for _, line in ipairs(data.box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(data.box.corner_outline) do
                    line.Visible = false
                end
            end
            if data.healthbar then
                data.healthbar.outline.Visible = false
                data.healthbar.fill.Visible = false
            end
            if data.name then
                data.name.Visible = false
            end
            if data.distance then
                data.distance.Visible = false
            end
            if data.tracer then
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
            continue
        end

        -- Get position on screen
        local position, visible = camera:WorldToViewportPoint(humanoidRootPart.Position)
        if not visible then
            if data.box then
                data.box.outline.Visible = false
                data.box.fill.Visible = false
                for _, line in ipairs(data.box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(data.box.corner_outline) do
                    line.Visible = false
                end
            end
            if data.healthbar then
                data.healthbar.outline.Visible = false
                data.healthbar.fill.Visible = false
            end
            if data.name then
                data.name.Visible = false
            end
            if data.distance then
                data.distance.Visible = false
            end
            if data.tracer then
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
            continue
        end

        -- Calculate box dimensions (static size like normal ESP script)
        local size = vector2_new(2000 / position.Z, 3000 / position.Z)
        local topLeft = vector2_new(position.X - size.X / 2, position.Y - size.Y / 2)
        local topRight = vector2_new(position.X + size.X / 2, position.Y - size.Y / 2)
        local bottomRight = vector2_new(position.X + size.X / 2, position.Y + size.Y / 2)
        local bottomLeft = vector2_new(position.X - size.X / 2, position.Y + size.Y / 2)

        if data.box then
            local box = data.box

            if esplib.box.enabled then
                if esplib.box.type == "normal" then
                    box.outline.PointA = topLeft
                    box.outline.PointB = topRight
                    box.outline.PointC = bottomRight
                    box.outline.PointD = bottomLeft
                    box.outline.Color = esplib.box.outline
                    box.outline.Visible = true

                    box.fill.PointA = topLeft
                    box.fill.PointB = topRight
                    box.fill.PointC = bottomRight
                    box.fill.PointD = bottomLeft
                    box.fill.Color = esplib.box.fill
                    box.fill.Visible = true

                    for _, line in ipairs(box.corner_fill) do
                        line.Visible = false
                    end
                    for _, line in ipairs(box.corner_outline) do
                        line.Visible = false
                    end

                elseif esplib.box.type == "corner" then
                    local x, y = topLeft.X, topLeft.Y
                    local w, h = size.X, size.Y
                    local len = math_min(w, h) * 0.25

                    local fill_lines = box.corner_fill
                    local outline_lines = box.corner_outline
                    local fill_color = esplib.box.fill
                    local outline_color = esplib.box.outline

                    local corners = {
                        { vector2_new(x, y), vector2_new(x + len, y) },
                        { vector2_new(x, y), vector2_new(x, y + len) },

                        { vector2_new(x + w - len, y), vector2_new(x + w, y) },
                        { vector2_new(x + w, y), vector2_new(x + w, y + len) },

                        { vector2_new(x, y + h), vector2_new(x + len, y + h) },
                        { vector2_new(x, y + h - len), vector2_new(x, y + h) },

                        { vector2_new(x + w - len, y + h), vector2_new(x + w, y + h) },
                        { vector2_new(x + w, y + h - len), vector2_new(x + w, y + h) },
                    }

                    for i = 1, 8 do
                        local from, to = corners[i][1], corners[i][2]
                        local dir = (to - from).Unit
                        local oFrom = from - dir * 1
                        local oTo = to + dir * 1

                        local o = outline_lines[i]
                        o.From = oFrom
                        o.To = oTo
                        o.Color = outline_color
                        o.Visible = true

                        local f = fill_lines[i]
                        f.From = from
                        f.To = to
                        f.Color = fill_color
                        f.Visible = true
                    end

                    box.outline.Visible = false
                    box.fill.Visible = false
                end
            else
                box.outline.Visible = false
                box.fill.Visible = false
                for _, line in ipairs(box.corner_fill) do
                    line.Visible = false
                end
                for _, line in ipairs(box.corner_outline) do
                    line.Visible = false
                end
            end
        end

        if data.healthbar then
            if esplib.healthbar.enabled then
                local healthPercent = humanoid.Health / humanoid.MaxHealth
                local barWidth = 4
                local barHeight = size.Y
                local barX = topLeft.X - barWidth - 6
                local barY = topLeft.Y

                local healthBarHeight = barHeight * healthPercent
                local healthBarY = barY + (barHeight - healthBarHeight)

                -- Health bar outline
                data.healthbar.outline.PointA = vector2_new(barX - 1, barY - 1)
                data.healthbar.outline.PointB = vector2_new(barX + barWidth + 1, barY - 1)
                data.healthbar.outline.PointC = vector2_new(barX + barWidth + 1, barY + barHeight + 1)
                data.healthbar.outline.PointD = vector2_new(barX - 1, barY + barHeight + 1)
                data.healthbar.outline.Color = esplib.healthbar.outline
                data.healthbar.outline.Visible = true

                -- Health bar
                data.healthbar.fill.PointA = vector2_new(barX, healthBarY)
                data.healthbar.fill.PointB = vector2_new(barX + barWidth, healthBarY)
                data.healthbar.fill.PointC = vector2_new(barX + barWidth, barY + barHeight)
                data.healthbar.fill.PointD = vector2_new(barX, barY + barHeight)
                data.healthbar.fill.Color = esplib.healthbar.fill
                data.healthbar.fill.Visible = true
            else
                data.healthbar.outline.Visible = false
                data.healthbar.fill.Visible = false
            end
        end

        if data.name then
            if esplib.name.enabled then
                local displayName = character.Name
                local player = players:GetPlayerFromCharacter(character)
                if player then
                    displayName = player.Name
                end

                local namePos = vector2_new(position.X, topLeft.Y - 18)

                data.name.Color = esplib.name.fill
                data.name.Position = namePos
                data.name.Text = displayName
                data.name.Size = esplib.name.size
                data.name.Visible = true
            else
                data.name.Visible = false
            end
        end

        if data.distance then
            if esplib.distance.enabled then
                local distance = (humanoidRootPart.Position - camera.CFrame.Position).Magnitude
                local distanceText = string.format('%.0f studs', distance)
                local distancePos = vector2_new(position.X, bottomRight.Y + 20)

                data.distance.Color = esplib.distance.fill
                data.distance.Position = distancePos
                data.distance.Text = distanceText
                data.distance.Size = esplib.distance.size
                data.distance.Visible = true
            else
                data.distance.Visible = false
            end
        end

        if data.tracer then
            if esplib.tracer.enabled then
                local from_pos = vector2_new()

                if esplib.tracer.from == "mouse" then
                    local mouse_location = user_input_service:GetMouseLocation()
                    from_pos = vector2_new(mouse_location.X, mouse_location.Y)
                elseif esplib.tracer.from == "head" then
                    local head = character:FindFirstChild("Head")
                    if head then
                        local pos, visible = camera:WorldToViewportPoint(head.Position)
                        if visible then
                            from_pos = vector2_new(pos.X, pos.Y)
                        else
                            from_pos = vector2_new(viewport_center_x, viewport_size.Y)
                        end
                    else
                        from_pos = vector2_new(viewport_center_x, viewport_size.Y)
                    end
                elseif esplib.tracer.from == "bottom" then
                    from_pos = vector2_new(viewport_center_x, viewport_size.Y)
                elseif esplib.tracer.from == "center" then
                    from_pos = vector2_new(viewport_center_x, viewport_center_y)
                else
                    from_pos = vector2_new(viewport_center_x, viewport_size.Y)
                end

                local to_pos = vector2_new(position.X, position.Y)

                data.tracer.outline.From = from_pos
                data.tracer.outline.To = to_pos
                data.tracer.outline.Color = esplib.tracer.outline
                data.tracer.outline.Visible = true

                data.tracer.fill.From = from_pos
                data.tracer.fill.To = to_pos
                data.tracer.fill.Color = esplib.tracer.fill
                data.tracer.fill.Visible = true
            else
                data.tracer.outline.Visible = false
                data.tracer.fill.Visible = false
            end
        end
    end
end)

-- // return
for k, v in pairs(espfunctions) do
    esplib[k] = v
end

return esplib
