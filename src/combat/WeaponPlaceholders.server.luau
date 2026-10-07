-- Hydrate real Tools from the same visible models used by the weapon stall.
-- Existing legacy two-part placeholders are replaced, never kept by name alone.
local ServerStorage = game:GetService("ServerStorage")
local server = game:GetService("ServerScriptService"):WaitForChild("QuietCove")
local Models = require(server:WaitForChild("WeaponModels"))
local displays = workspace:WaitForChild("WeaponStall"):WaitForChild("Displays")
local bank = ServerStorage:FindFirstChild("Weapons")
if not bank then bank=Instance.new("Folder");bank.Name="Weapons";bank.Parent=ServerStorage end
Models.Sync(bank,displays)
