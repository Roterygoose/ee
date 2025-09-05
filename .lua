local RunService = game:GetService("RunService")
local PlayerService = game:GetService("Players")
local LocalPlayer = PlayerService.LocalPlayer
local Camera = workspace.CurrentCamera

local ESPLibrary = {}
local ESPTable = {}

getgenv().Config = {
    Enabled = true;
    BoxVisible = true;
    TextVisible = true;
}

local function GetDistanceFromClient(Position)
    local character = LocalPlayer.Character
    if character and character.PrimaryPart then
        return (character.PrimaryPart.Position - Position).Magnitude
    end
    return math.huge
end

local function AddDrawing(Type, Properties)
    local Drawing = Drawing.new(Type)
    for Index, Value in pairs(Properties) do
        Drawing[Index] = Value
    end
    return Drawing
end

local function CalculateBox(Model)
    if not Model or not Model:IsA("Model") then return end
    
    local success, cframe, size = pcall(function()
        return Model:GetBoundingBox()
    end)
    
    if not success then return end
    
    local corners = {
        TopLeft = Vector3.new(cframe.X - size.X / 2, cframe.Y + size.Y / 2, cframe.Z - size.Z / 2),
        TopRight = Vector3.new(cframe.X + size.X / 2, cframe.Y + size.Y / 2, cframe.Z - size.Z / 2),
        BottomLeft = Vector3.new(cframe.X - size.X / 2, cframe.Y - size.Y / 2, cframe.Z - size.Z / 2),
        BottomRight = Vector3.new(cframe.X + size.X / 2, cframe.Y - size.Y / 2, cframe.Z - size.Z / 2),
        TopLeftBack = Vector3.new(cframe.X - size.X / 2, cframe.Y + size.Y / 2, cframe.Z + size.Z / 2),
        TopRightBack = Vector3.new(cframe.X + size.X / 2, cframe.Y + size.Y / 2, cframe.Z + size.Z / 2),
        BottomLeftBack = Vector3.new(cframe.X - size.X / 2, cframe.Y - size.Y / 2, cframe.Z + size.Z / 2),
        BottomRightBack = Vector3.new(cframe.X + size.X / 2, cframe.Y - size.Y / 2, cframe.Z + size.Z / 2)
    }
    
    local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
    local anyOnScreen = false
    
    for _, corner in pairs(corners) do
        local screenPoint, onScreen = Camera:WorldToViewportPoint(corner)
        if onScreen then
            anyOnScreen = true
            minX = math.min(minX, screenPoint.X)
            minY = math.min(minY, screenPoint.Y)
            maxX = math.max(maxX, screenPoint.X)
            maxY = math.max(maxY, screenPoint.Y)
        end
    end
    
    if not anyOnScreen then
        return {OnScreen = false}
    end
    
    local screenPosition = Vector2.new(minX, minY)
    local screenSize = Vector2.new(maxX - minX, maxY - minY)
    
    return {
        ScreenPosition = screenPosition,
        ScreenSize = screenSize,
        OnScreen = true
    }
end

function ESPLibrary.Add(Model, Options)
    if not Model or ESPTable[Model] then return end
    
    local ChosenColors = (Options and Options.Colors) or {
        BoxColor = Color3.new(1, 0, 0),
        TextPrimaryColor = Color3.new(1, 1, 1),
        TextSecondaryColor = Color3.new(0, 0, 0),
    }
    
    ESPTable[Model] = {
        Name = Options and Options.Name or Model.Name,
        Model = Model,
        Drawing = {
            Box = {	
                Main = AddDrawing("Square", {
                    Color = ChosenColors.BoxColor,
                    ZIndex = 1,
                    Transparency = 1,
                    Thickness = 1,
                    Filled = false
                }),
                Outline = AddDrawing("Square", {
                    Color = ChosenColors.BoxColor,
                    ZIndex = 0,
                    Transparency = 0,
                    Thickness = 3,
                    Filled = false
                })
            },
            Text = AddDrawing("Text", {
                Color = ChosenColors.TextPrimaryColor,
                ZIndex = 1,
                Transparency = 1,
                Size = 14,
                Center = true,
                Outline = true,
                OutlineColor = ChosenColors.TextSecondaryColor
            })
        }
    }
end

function ESPLibrary.Remove(Model)
    if ESPTable[Model] then
        for _, drawingGroup in pairs(ESPTable[Model].Drawing) do
            if drawingGroup.Remove then
                drawingGroup:Remove()
            else
                for _, drawing in pairs(drawingGroup) do
                    drawing:Remove()
                end
            end
        end
        ESPTable[Model] = nil
    end
end

function ESPLibrary.Clear()
    for model in pairs(ESPTable) do
        ESPLibrary.Remove(model)
    end
end

-- Main update loop
RunService.RenderStepped:Connect(function()
    if not Config.Enabled then
        for _, ESP in pairs(ESPTable) do
            ESP.Drawing.Box.Main.Visible = false
            ESP.Drawing.Box.Outline.Visible = false
            ESP.Drawing.Text.Visible = false
        end
        return
    end
    
    for model, ESP in pairs(ESPTable) do
        if not model or not model.Parent then
            ESPLibrary.Remove(model)
            continue
        end
        
        local humanoidRootPart = model:FindFirstChild("HumanoidRootPart") or model:IsA("BasePart") and model
        if not humanoidRootPart then
            ESP.Drawing.Box.Main.Visible = false
            ESP.Drawing.Box.Outline.Visible = false
            ESP.Drawing.Text.Visible = false
            continue
        end
        
        local boxData = CalculateBox(model)
        if not boxData or not boxData.OnScreen then
            ESP.Drawing.Box.Main.Visible = false
            ESP.Drawing.Box.Outline.Visible = false
            ESP.Drawing.Text.Visible = false
            continue
        end
        
        local distance = GetDistanceFromClient(humanoidRootPart.Position)
        
        -- Update box
        ESP.Drawing.Box.Main.Size = boxData.ScreenSize
        ESP.Drawing.Box.Main.Position = boxData.ScreenPosition
        ESP.Drawing.Box.Main.Visible = Config.BoxVisible
        
        ESP.Drawing.Box.Outline.Size = boxData.ScreenSize
        ESP.Drawing.Box.Outline.Position = boxData.ScreenPosition
        ESP.Drawing.Box.Outline.Visible = Config.BoxVisible
        
        -- Update text
        ESP.Drawing.Text.Text = string.format("%s\n%d studs", ESP.Name, math.floor(distance))
        ESP.Drawing.Text.Position = Vector2.new(
            boxData.ScreenPosition.X + boxData.ScreenSize.X / 2, 
            boxData.ScreenPosition.Y + boxData.ScreenSize.Y
        )
        ESP.Drawing.Text.Visible = Config.TextVisible
    end
end)

return ESPLibrary
