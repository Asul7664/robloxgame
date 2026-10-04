-- Remove only the retired template when a server starts with the updated catalogue.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("QuietCove")
local Config = require(shared:WaitForChild("Config"))

if not Config.ById.cappuccino then
    local template = shared:WaitForChild("CreatureAssets"):FindFirstChild("cappuccino")
    if template then template:Destroy() end
end
