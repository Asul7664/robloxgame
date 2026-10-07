local ServerStorage = game:GetService("ServerStorage")
local folder = ServerStorage:FindFirstChild("Weapons") or Instance.new("Folder")
folder.Name = "Weapons"
folder.Parent = ServerStorage

local function saber()
	if folder:FindFirstChild("Saber") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Saber"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponType", "Saber")
	tool.Grip = CFrame.new(0, 0, -1.1) * CFrame.Angles(math.rad(-90), 0, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.18, 1.1, 0.18)
	handle.Color = Color3.fromRGB(92, 62, 36)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local blade = Instance.new("Part")
	blade.Name = "Blade"
	blade.Size = Vector3.new(0.08, 3.4, 0.28)
	blade.Color = Color3.fromRGB(214, 214, 208)
	blade.Material = Enum.Material.Metal
	blade.CanCollide = false
	blade.Massless = true
	blade.CFrame = handle.CFrame * CFrame.new(0, 2.2, 0)
	blade.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = blade
	w.Parent = handle
	tool.Parent = folder
end

local function musket()
	if folder:FindFirstChild("Musket") then
		return
	end
	local tool = Instance.new("Tool")
	tool.Name = "Musket"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool:SetAttribute("WeaponType", "Musket")
	tool.Grip = CFrame.new(0.15, -0.2, 0.2) * CFrame.Angles(math.rad(-90), math.rad(8), 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.22, 2.6, 0.22)
	handle.Color = Color3.fromRGB(78, 54, 32)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local barrel = Instance.new("Part")
	barrel.Name = "Barrel"
	barrel.Size = Vector3.new(0.16, 1.8, 0.16)
	barrel.Color = Color3.fromRGB(70, 72, 76)
	barrel.Material = Enum.Material.Metal
	barrel.CanCollide = false
	barrel.Massless = true
	barrel.CFrame = handle.CFrame * CFrame.new(0, 2.05, 0)
	barrel.Parent = tool
	local w = Instance.new("WeldConstraint")
	w.Part0 = handle
	w.Part1 = barrel
	w.Parent = handle
	local muzzle = Instance.new("Attachment")
	muzzle.Name = "Muzzle"
	muzzle.Position = Vector3.new(0, barrel.Size.Y * 0.5, 0)
	muzzle.Parent = barrel
	tool.Parent = folder
end

saber()
musket()
