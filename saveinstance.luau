--!native
--!optimize 2
--!divine-intellect
-- 0ps V5 - Fixed version with proper Union handling and CollisionFidelity support

local konstantdecompiler = loadstring(game:HttpGet('https://raw.githubusercontent.com/verysigmapro/UniversalSynSaveInstance-With-Save-Terrain/refs/heads/main/konstantdecompiler.lua'))()

local game = game
local pcall = pcall
local workspace = workspace
local setmetatable = setmetatable
local bit32 = bit32
local buffer = buffer
local Instance = Instance
local assert = assert
local table = table
local string = string

local function string_find(s, pattern)
	return string.find(s, pattern, nil, true)
end

local function ArrayToDict(t, hydridMode, valueOverride, typeStrict)
	local tmp = {}

	if hydridMode then
		for some1, some2 in t do
			if type(some1) == "number" then
				tmp[some2] = valueOverride or true
			elseif type(some2) == "table" then
				tmp[some1] = ArrayToDict(some2, hydridMode) -- Some1 is Class, Some2 is Name
			else
				tmp[some1] = some2
			end
		end
	else
		for _, key in t do
			if not typeStrict or typeStrict and type(key) == typeStrict then
				tmp[key] = true
			end
		end
	end

	return tmp
end

-- Load the original saveinstance script without our changes
local original_script = readfile("saveinstance.lua")

-- Now make our modifications to it
original_script = original_script:gsub("-- 0ps V5", "-- 0ps V5 - Fixed version with proper Union handling and CollisionFidelity support")

-- Add FixCollisionFidelity option
original_script = original_script:gsub("TreatUnionsAsParts = EXECUTOR_NAME == \"Solara\", -- TODO Temporary true", 
                                       "TreatUnionsAsParts = EXECUTOR_NAME == \"Solara\", -- TODO Temporary true\n\t\tFixCollisionFidelity = true, -- Fix for collision fidelity in mesh parts and unions")

-- Update the Whitelist to include CollisionFidelity for all mesh types
original_script = original_script:gsub("Whitelist = { TriangleMeshPart = ArrayToDict%({ \"CollisionFidelity\" }) },", 
                                       [[Whitelist = { 
        TriangleMeshPart = ArrayToDict({ "CollisionFidelity" }),
        MeshPart = ArrayToDict({ "CollisionFidelity" }),
        UnionOperation = ArrayToDict({ "CollisionFidelity" }),
        NegateOperation = ArrayToDict({ "CollisionFidelity" }),
        PartOperation = ArrayToDict({ "CollisionFidelity" })
    },]])

-- Update the NotScriptableFixes section to handle CollisionFidelity
original_script = original_script:gsub("TriangleMeshPart = {\n\t\t\tFluidFidelityInternal = \"FluidFidelity\",\n\t\t},", 
                                       [[TriangleMeshPart = {
			FluidFidelityInternal = "FluidFidelity",
            CollisionFidelity = function(instance)
                return instance.CollisionFidelity
            end,
		},]])

original_script = original_script:gsub("MeshPart = { InitialSize = \"MeshSize\" },", 
                                       [[MeshPart = { 
            InitialSize = "MeshSize",
            CollisionFidelity = function(instance)
                return instance.CollisionFidelity
            end,
        },]])

original_script = original_script:gsub("PartOperation = { InitialSize = \"MeshSize\" },", 
                                       [[PartOperation = { 
            InitialSize = "MeshSize",
            CollisionFidelity = function(instance)
                return instance.CollisionFidelity
            end,
        },]])

-- Modify the TreatUnionsAsParts section to save CollisionFidelity
original_script = original_script:gsub("if TreatUnionsAsParts and instance:IsA%(\"PartOperation\"%) then\n\t\t\t\t\t\tClassName, InstanceOverride = \"Part\", replaceClassName%(instance, InstanceName, ClassName%)\n\t\t\t\t\t\tClassNameOverride = \"BasePart\" -- %* Mutual Superclass for PartOperation and Part; For properties only", 
                                       [[if TreatUnionsAsParts and instance:IsA("PartOperation") then
						ClassName, InstanceOverride = "Part", replaceClassName(instance, InstanceName, ClassName)
						ClassNameOverride = "BasePart" -- * Mutual Superclass for PartOperation and Part; For properties only
                        
                        -- Ensure we save CollisionFidelity
                        if not InstanceOverride.Properties then
                            InstanceOverride.Properties = {}
                        end
                        
                        -- Try to get the CollisionFidelity property if it exists
                        local ok, collisionFidelity = pcall(function() return instance.CollisionFidelity end)
                        if ok and collisionFidelity then
                            InstanceOverride.Properties.CollisionFidelity = collisionFidelity
                        end]])

-- Add special handling for mesh parts and unions at the start of save_hierarchy function
original_script = original_script:gsub("local function save_hierarchy%(hierarchy%)\n\t\tfor _, instance in hierarchy do\n\t\t\tif IgnoreNotArchivable and not instance.Archivable then\n\t\t\t\tcontinue", 
                                       [[local function save_hierarchy(hierarchy)
		for _, instance in hierarchy do
			if IgnoreNotArchivable and not instance.Archivable then
				continue
            
            -- Special handling for MeshPart and PartOperation types to ensure CollisionFidelity is correctly set
            if (instance:IsA("MeshPart") or instance:IsA("PartOperation") or instance:IsA("TriangleMeshPart")) and OPTIONS.FixCollisionFidelity ~= false then
                pcall(function()
                    instance.CollisionFidelity = instance.CollisionFidelity or Enum.CollisionFidelity.Default
                end)
            end]])

-- Add collision fidelity initialization code at the end of the file
original_script = original_script:gsub("savebuffer%[savebuffer_size%] =\n\t\t\t\"</roblox><!-- Saved by UniversalSynSaveInstance %(Join to Copy Games%) https://discord.gg/wx4ThpAsmw -->\"", 
                                       [[-- Initialize collision fidelity for all mesh parts before saving
        if OPTIONS.FixCollisionFidelity ~= false then
            local defaultCollisionFidelity = Enum.CollisionFidelity.Default
            
            -- Use coroutine to avoid script timeout for large games
            coroutine.wrap(function()
                if __DEBUG_MODE then
                    __DEBUG_MODE("Fixing collision fidelity for all mesh parts and unions")
                end
                
                for _, instance in game:GetDescendants() do
                    if (instance:IsA("MeshPart") or instance:IsA("PartOperation") or instance:IsA("TriangleMeshPart")) then
                        pcall(function()
                            -- Only set if it's not already set
                            if not instance.CollisionFidelity or instance.CollisionFidelity == Enum.CollisionFidelity.Default then
                                instance.CollisionFidelity = defaultCollisionFidelity
                            end
                        end)
                    end
                    
                    -- Yield occasionally to prevent the script from freezing
                    if _ % 500 == 0 then
                        task.wait()
                    end
                end
                
                if __DEBUG_MODE then
                    __DEBUG_MODE("Finished fixing collision fidelity")
                end
            end)()
        end

		savebuffer[savebuffer_size] =
			"</roblox><!-- Saved by UniversalSynSaveInstance (Join to Copy Games) https://discord.gg/wx4ThpAsmw -->"]])

-- Execute the modified script
return loadstring(original_script)() 
