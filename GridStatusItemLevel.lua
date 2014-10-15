HELM, NECK, SHOULDER, SHIRT, CHEST, WAIST, LEGS, FEET, WRISTS, HANDS, RING1, RING2, TRINK1, TRINK2, BACK, WEP, OFFHAND = 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
lastInspectTime = GetTime()

local_, GridStatusItemLevel = ...

if not GridStatusItemLevel.L then GridStatusItemLevel.L = { } end

local L = setmetatable(GridStatusItemLevel.L, {
	__index = function(t, k)
		t[k] = k
		return k
	end
})

local cache = {}

local ItemUpgradeInfo = LibStub("LibItemUpgradeInfo-1.0")
local GridStatusItemLevel = Grid:GetModule("GridStatus"):NewModule("GridStatusItemLevel", "AceTimer-3.0")
local refreshTimer, clearCacheTimer

GridStatusItemLevel.menuName = L["Item Level"];

GridStatusItemLevel.defaultDB = {
	alert_ilvl = {
		text = L["Item Level"],
		enable = true,
		priority = 99,
		range = false,
		color = {r = 192, g = 192, b = 192, a = 1},
	},
}

hooksecurefunc("NotifyInspect", function() lastInspectTime = GetTime(); end)

function GridStatusItemLevel:OnInitialize()
	self.super.OnInitialize(self)
	self:RegisterStatuses()
end

function GridStatusItemLevel:OnEnable()
	refreshTimer = self:ScheduleRepeatingTimer("UpdateAllUnits", 0)
	clearCacheTimer = self:ScheduleRepeatingTimer("ClearCache", 600) --we purge the cache every 10 minutes, this should keep party fairly up to date 
end

function GridStatusItemLevel:RegisterStatuses()
	self:RegisterStatus("alert_ilvl", L["Item Level"], alert_ilvl)
end

function GridStatusItemLevel:UnregisterStatuses()
	self:UnregisterStatus("alert_ilvl")
end

function GridStatusItemLevel:ClearCache()
	for k,v in pairs(cache) do cache[k]=nil end
end

local GridStatusItemLevel_InspectFrame = CreateFrame("Frame", "GridStatusItemLevel_InspectFrame")
GridStatusItemLevel_InspectFrame:Hide()


function InspectEvent(self, event, guid)
	if(event == "INSPECT_READY") then
		if(not cache[guid]) then
			return
		end

		if(guid == UnitGUID(cache[guid].uid)) then --make sure the event is for the player we expect
			CalculateItemLevel(guid, cache[guid].uid)
		end
	end
	if(event == "PLAYER_EQUIPMENT_CHANGED") then
		guid = UnitGUID("player")
		CalculateItemLevel(guid, "player")
	end
end
GridStatusItemLevel_InspectFrame:SetScript("OnEvent", InspectEvent)
GridStatusItemLevel_InspectFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")

local GridRoster = Grid:GetModule("GridRoster")
function GridStatusItemLevel:UpdateAllUnits()
	for guid, unitid in GridRoster:IterateRoster() do
			GridStatusItemLevel:UpdateUnit(guid, unitid)
	end
end

function GridStatusItemLevel:UpdateUnit(guid, unitid)
	local settings = GridStatusItemLevel.db.profile.alert_ilvl
	local itemLevel = 0

	if(not cache[guid] or (cache[guid].itemLevel == 0)) then 
		if(CheckInteractDistance(unitid, 1) and CanInspect(unitid)) then
			if((GetTime() - lastInspectTime) > 2) then
				cache[guid] = {itemLevel = 0, uid = unitid}
				GridStatusItemLevel_InspectFrame:RegisterEvent("INSPECT_READY")
				if(InspectFrame) then
					if(not InspectFrame:IsVisible()) then
						NotifyInspect(unitid)
					end
				else
					NotifyInspect(unitid)
				end
			end
		end
	else
		itemLevel = cache[guid].itemLevel
		SendUpdate(guid, unitid, itemLevel)
	end
end

function SendUpdate(guid, unitid, itemLevel)
	local settings = GridStatusItemLevel.db.profile.alert_ilvl

	if settings.enable then
		GridStatusItemLevel.core:SendStatusGained(guid, "alert_ilvl", 
			settings.priority, 
			(settings.range and 40),
			settings.color,
			string.format("%d", itemLevel)
		)
	else
		if GridStatusItemLevel.core:GetCachedStatus(guid, "alert_ilvl") then GridStatusItemLevel.core:SendStatusLost(guid, "alert_ilvl") end
	end
end

function CalculateItemLevel(guid, unitid)
	local totalIlvl, avgIlvl = 0
	local iter_min, iter_max = 0
	local itemLevel = 0
	local equipType = 0
	local twoHander = nil

	local count = 0
	for i = 1,17 do
		if(i ~= SHIRT) then
			local item = GetInventoryItemLink(unitid, i)
			if(item) then
				local upgradeID = ItemUpgradeInfo:GetUpgradeID(item)
				local upgrade = ItemUpgradeInfo:GetCurrentUpgrade(upgradeID)
				_,_,_,itemLevel,_,_,_,_,equipType = GetItemInfo(item)

				if(itemLevel) then
					count = count + 1
					if(i == WEP) then
						if(equipType == "INVTYPE_2HWEAPON" or equipType == "INVTYPE_RANGED" or equipType == "INVTYPE_RANGEDRIGHT") then
							twoHander = 1
						end
					end

					if(upgrade == 1) then 
						itemLevel = itemLevel + 4
					elseif(upgrade == 2) then
						itemLevel = itemLevel + 8
					elseif(upgrade == 3) then
						itemLevel = itemLevel + 12
					elseif(upgrade == 4) then
						itemLevel = itemLevel + 16
					end
					totalIlvl = totalIlvl + itemLevel
				end
			end
		end
	end
	if((count == 15) and twoHander) then
		avgIlvl = math.floor(totalIlvl / count)
		cache[guid].itemLevel = avgIlvl
		SendUpdate(guid, unitid, avgIlvl)
	elseif((count == 16) and not twoHander) then
		avgIlvl = math.floor(totalIlvl / count)
		cache[guid].itemLevel = avgIlvl
		SendUpdate(guid, unitid, avgIlvl)
	elseif((count == 16) and twoHander) then
		avgIlvl = math.floor(totalIlvl / 16)
		cache[guid].itemLevel = avgIlvl
		SendUpdate(guid, unitid, avgIlvl)
	else
		avgIlvl = math.floor(totalIlvl / 15)
		cache[guid].itemLevel = 0
		SendUpdate(guid, unitid, avgIlvl)
	end
end