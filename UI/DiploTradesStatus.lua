include("IconSupport")
include("SupportFunctions")
include("InstanceManager")
include("InfoTooltipInclude")

local gPlayerIM = InstanceManager:new("TradeStatusInstance", "TradeBox", Controls.PlayerBox)
local gAiIM = InstanceManager:new("TradeStatusInstance", "TradeBox", Controls.AiStack)
local gCsIM = InstanceManager:new("CityStateInstance", "TradeBox", Controls.AiStack)
local gResourceIM = InstanceManager:new("TradeResourcesInstance", "TradeBox", Controls.ResourceBox)

local gSortTable
local iPreviousResourceID = -1
	
-- open window?
function ShowHideHandler(bIsHide, bIsInit)
	if (not bIsInit and not bIsHide) then
		gPlayerIM:ResetInstances()
		gAiIM:ResetInstances()
		gCsIM:ResetInstances()
		gResourceIM:ResetInstances()
	  
		local iPlayer = Game.GetActivePlayer()
		
		InitPlayer(iPlayer)
		InitAiList(iPlayer)
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

-- draw first resource line
function InitPlayer(iPlayer)
	GetCivControl(gPlayerIM, iPlayer, false)
end

-- check if there are AIs
function InitAiList(iPlayer)
	local pPlayer = Players[iPlayer]
	local pTeam = Teams[pPlayer:GetTeam()]
	local iCount = 0

	gSortTable = {}
  
	for playerLoop = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local pOtherPlayer = Players[playerLoop]
		local iOtherTeam = pOtherPlayer:GetTeam()
		
		-- draw new resource lines for each met civ
		if (playerLoop ~= iPlayer and pOtherPlayer:IsAlive()) then
			if (pTeam:IsHasMet(iOtherTeam)) then
				iCount = iCount+1
				GetCivControl(gAiIM, playerLoop, true)
			end
		end
	end
	
	-- draw CSs columns for each resource
	if InitCsList() then
		iCount = iCount+1
	end

	if iCount == 0 then
		Controls.AiNoneMetText:SetHide(false)
		Controls.AiScrollPanel:SetHide(true)
	else
		Controls.AiNoneMetText:SetHide(true)
		Controls.AiScrollPanel:SetHide(false)

		Controls.AiStack:SortChildren(ByScore)
		Controls.AiStack:CalculateSize()
		Controls.AiStack:ReprocessAnchoring()
		Controls.AiScrollPanel:CalculateInternalSize()
	end
end

-- sorting rules
function ByScore(a, b)
	local entryA = gSortTable[tostring(a)]
	local entryB = gSortTable[tostring(b)]

	if entryA == nil or entryB == nil then 
		if entryA ~= nil and entryB == nil then
			return true
		elseif entryA == nil and entryB ~= nil then
			return false
		else
			return (tostring(a) < tostring(b)) -- gotta do something!
		end
	end

	return (Players[entryA.PlayerID]:GetScore() > Players[entryB.PlayerID]:GetScore())
end

-- function drawing resource lines
function GetCivControl(im, iPlayer, bCanTrade)
	local iActivePlayer = Game.GetActivePlayer()
	local pActivePlayer = Players[iActivePlayer]
	local iActiveTeam = pActivePlayer:GetTeam()
	local pActiveTeam = Teams[iActiveTeam]
	local bIsActivePlayer = (iActivePlayer == iPlayer)

	local pPlayer = Players[iPlayer]
	local iTeam = pPlayer:GetTeam()
	local pTeam = Teams[iTeam]
	local eCivilization = GameInfo.Civilizations[pPlayer:GetCivilizationType()]
        
	local pDeal = UI.GetScratchDeal()

	local imControlTable = im:GetInstance()
	local imControlTableHeader = gResourceIM:GetInstance()
	local tSortEntry = {}

	imControlTable.TradeOps:SetHide(false)
	imControlTable.TradeWar:SetHide(pActiveTeam:IsAtWar(iTeam) == false)

	imControlTable.CivName:SetText(Locale.ConvertTextKey(eCivilization.ShortDescription))
	CivIconHookup(iPlayer, 32, imControlTable.CivSymbol, imControlTable.CivIconBG, imControlTable.CivIconShadow, false, true)
	imControlTable.CivIconBG:SetHide(false)

	imControlTable.CivButton:SetToolTipString(Locale.ConvertTextKey("TXT_KEY_DO_CIV_STATUS", GetApproach(pActivePlayer, pPlayer), GameInfo.Eras[pPlayer:GetCurrentEra()].Description, pPlayer:GetScore()))

	if (bCanTrade) then        
		imControlTable.CivButton:SetVoid1(iPlayer)
		imControlTable.CivButton:RegisterCallback(Mouse.eLClick, OnCivSelected)

		gSortTable[tostring(imControlTable.TradeBox)] = tSortEntry
		tSortEntry.PlayerID = iPlayer
	else
		imControlTable.CivButtonHL:SetHide(true)
	end
	
	local sGatheredOtherResources = ""
	local sGatheredOtherTooltips = ""
	local sText, sToolTip, iCount, sDeals
	local controlOther = imControlTable["RESOURCE_OTHER_LUXURIES"]
		controlOther:SetText("")		
		controlOther:SetToolTipString("")
		
	imControlTableHeader.RESOURCE_OTHER_LUXURIES_ICON:SetHide(true)
	imControlTableHeader["Other"]:SetText("")
	
	-- loop through resources
	for resource in GameInfo.Resources() do
		if resource.ResourceUsage > 0 then
			-- header
			local controlHeader = imControlTableHeader[Locale.ConvertTextKey(resource.Description)]
			
			if controlHeader == nil then
				local sResourcePart = Locale.ConvertTextKey(resource.IconString) .. " " .. Locale.ConvertTextKey(resource.Description) .. ":[NEWLINE]" .. Locale.ConvertTextKey(resource.Help)
				
				if sGatheredOtherResources == "" then
					sGatheredOtherResources = sResourcePart
				else
					sGatheredOtherResources = sGatheredOtherResources .. "[NEWLINE][NEWLINE]" .. sResourcePart
				end
				
				local controlHeaderBox = imControlTableHeader.RESOURCE_OTHER_LUXURIES_ICON
				controlHeaderBox:SetHide(false)
				
				controlHeader = imControlTableHeader["Other"]
				controlHeader:SetText("[ICON_RES_HIDDEN_ARTIFACTS]")
				controlHeader:SetToolTipString(sGatheredOtherResources)
			else
				controlHeader:SetText(Locale.ConvertTextKey(resource.IconString))
				controlHeader:SetToolTipString(string.format("%s %s:[NEWLINE]%s", resource.IconString, Locale.ConvertTextKey(resource.Description), Locale.ConvertTextKey(resource.Help)))
			end
			
			-- values
			sText, sToolTip, iCount, sDeals = GetUsefulResourceText(pPlayer, resource, bIsActivePlayer, pActivePlayer)
			local control = imControlTable[resource.Type]
			
			if control == nil then
				if sGatheredOtherTooltips == "" then
					sGatheredOtherTooltips = sToolTip .. ": " .. sText
				else
					sGatheredOtherTooltips = sGatheredOtherTooltips .. "[NEWLINE]" .. sToolTip .. ": ".. sText
				end
			else
				if sDeals ~= "" then
					sToolTip = sToolTip .. "[NEWLINE][NEWLINE]" .. sDeals
				end
				
				control:SetText(sText)
				control:SetToolTipString(sToolTip)
			end
		end
	end 

	if sGatheredOtherTooltips ~= "" then
		if sDeals ~= "" then
			sGatheredOtherTooltips = sGatheredOtherTooltips .."[NEWLINE][NEWLINE]" .. sDeals
		end
		
		controlOther:SetText("[COLOR_YIELD_FOOD]...[ENDCOLOR]")		
		controlOther:SetToolTipString(sGatheredOtherTooltips)
		Controls.BottomTrimNormal:SetHide(true)
		Controls.BottomTrimOther:SetHide(false)
		Controls.OtherHeader:SetHide(false)
	else
		Controls.BottomTrimNormal:SetHide(false)
		Controls.BottomTrimOther:SetHide(true)
		Controls.OtherHeader:SetHide(true)
	end
	
	--draw three additional action buttons
	local sResearchIcon = ""
	local sResearchTip = ""
  
	if bIsActivePlayer then
		sResearchIcon = ""
		sResearchTip = ""
	else
		if pDeal:IsPossibleToTradeItem(iPlayer, iActivePlayer, TradeableItems.TRADE_ITEM_RESEARCH_AGREEMENT, Game.GetDealDuration()) then
			sResearchIcon = "[ICON_RESEARCH]"
			sResearchTip = "TXT_KEY_DO_TRADE_STATUS_RA_YES_TT"
		elseif pTeam:IsHasResearchAgreement(iActiveTeam) then
			sResearchIcon = "[ICON_SWAP]"
			sResearchTip = "TXT_KEY_DO_TRADE_STATUS_RA_NO_TT"
		end
	end
	
	imControlTable.ResearchText:SetText(sResearchIcon)
	imControlTable.ResearchText:SetToolTipString(Locale.ConvertTextKey(sResearchTip))

	local sEmbassyIcon = ""
	local sEmbassyTip = ""
  
	if bIsActivePlayer then
		sEmbassyIcon = ""
		sEmbassyTip = ""
	else
		if pDeal:IsPossibleToTradeItem(iPlayer, iActivePlayer, TradeableItems.TRADE_ITEM_ALLOW_EMBASSY, Game.GetDealDuration()) and
			pDeal:IsPossibleToTradeItem(iActivePlayer, iPlayer, TradeableItems.TRADE_ITEM_ALLOW_EMBASSY, Game.GetDealDuration()) then
			sEmbassyIcon = "[ICON_CITY_STATE]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_YES_TT"
		elseif pTeam:HasEmbassyAtTeam(iActiveTeam) and pActiveTeam:HasEmbassyAtTeam(iTeam) then
			sEmbassyIcon = "[ICON_INFLUENCE]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_NO_TT"
		elseif pActiveTeam:HasEmbassyAtTeam(iTeam) then
			sEmbassyIcon = "[ICON_CAPITAL]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_US_TT"
		elseif pTeam:HasEmbassyAtTeam(iActiveTeam) then
			sEmbassyIcon = "[ICON_CAPITAL]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_THEM_TT"
		end
	end
  
	imControlTable.EmbassyText:SetText(sEmbassyIcon)
	imControlTable.EmbassyText:SetToolTipString(Locale.ConvertTextKey(sEmbassyTip))

	local sBordersIcon = ""
	local sBordersTip = ""
  
	if bIsActivePlayer then
		sBordersIcon = ""
		sBordersTip = ""
	else
		if pDeal:IsPossibleToTradeItem(iPlayer, iActivePlayer, TradeableItems.TRADE_ITEM_OPEN_BORDERS, Game.GetDealDuration()) and
			pDeal:IsPossibleToTradeItem(iActivePlayer, iPlayer, TradeableItems.TRADE_ITEM_OPEN_BORDERS, Game.GetDealDuration()) then
			sBordersIcon = "[ICON_TRADE]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_YES_TT"
		elseif pTeam:IsAllowsOpenBordersToTeam(iActiveTeam) and pActiveTeam:IsAllowsOpenBordersToTeam(iTeam) then
			sBordersIcon = "[ICON_TRADE_WHITE]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_NO_TT"
		elseif pTeam:IsAllowsOpenBordersToTeam(iActiveTeam) then
			sBordersIcon = "[ICON_ARROW_RIGHT]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_US_TT"
		elseif pActiveTeam:IsAllowsOpenBordersToTeam(iTeam) then
			sBordersIcon = "[ICON_ARROW_LEFT]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_THEM_TT"
		end
	end
  
	imControlTable.BordersText:SetText(sBordersIcon)
	imControlTable.BordersText:SetToolTipString(Locale.ConvertTextKey(sBordersTip))

	return imControlTable
end

-- approach types checking
function GetApproach(pActivePlayer, pPlayer)
	local sApproach = ""

	if pActivePlayer:GetID() ~= pPlayer:GetID() then
		if Teams[pActivePlayer:GetTeam()]:IsAtWar(pPlayer:GetTeam()) then
			sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR")
		elseif pPlayer:IsDenouncingPlayer(pActivePlayer:GetID()) then
			sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_DENOUNCING")
		else
			local iApproach = pActivePlayer:GetApproachTowardsUsGuess(pPlayer:GetID())
  
			if iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_WAR then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR")
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_HOSTILE")
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_GUARDED")
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_NEUTRAL then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_NEUTRAL")
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_FRIENDLY")
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_AFRAID then
				sApproach = Locale.ConvertTextKey("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_AFRAID")
			end
		end
	end

	if sApproach ~= "" then
		sApproach = sApproach .. ": "
	end

	return sApproach
end

-- filling the gaps with colourful info
function GetUsefulResourceText(pPlayer, pResource, bIsActivePlayer, pActivePlayer)
	local iResource = pResource.ID
	local bIsPaper = iResource == GameInfoTypes.RESOURCE_PAPER
	
	local sColourStart = "[COLOR_CITY_GREY]"
	local sColourDarkGreen = "[COLOR:0:135:0:255]"
	local sColourLightGreen = "[COLOR:125:255:0:255]"
	local sColourYellowGreen = "[COLOR:200:180:0:255]"
	local sColourRed = "[COLOR:255:70:70:255]"
	local sColourBlue = "[COLOR_CITY_BLUE]"
	local sColourCyan = "[COLOR_CYAN]"
	local sColourOrange = "[COLOR_YIELD_FOOD]"
	
	local sText = ""
	local sToolTip = ""
	local sDeals = ""
	local iTotal = 0
	
	if IsAvailableLuxury(iResource) and IsVisibleUsefulResource(iResource, pActivePlayer) then
		local iMinors  = pPlayer:GetResourceFromMinors(iResource)
		local iImports = pPlayer:GetResourceImport(iResource)
		local iExports = pPlayer:GetResourceExport(iResource)
		local iLocal   = pPlayer:GetNumResourceTotal(iResource, false) + iExports
		local iUsed    = pPlayer:GetNumResourceUsed(iResource)
		
		local iSurplus = iLocal - iExports - iUsed
		
		iTotal = iLocal + iMinors + iImports - iExports - iUsed
		
		if bIsActivePlayer then
			if iTotal == 0 then
				local iCounter = 0
				
				sToolTip, iCounter = GetGoldenAgeCities(pPlayer, pResource)

				if sToolTip ~= "" then
					if iCounter > 1 then
						sColourStart = sColourBlue
					else
						sColourStart = sColourCyan
					end
				else
					sColourStart = sColourOrange
				end
			else
				if iSurplus > 3 then
					sColourStart = sColourDarkGreen
				elseif iSurplus > 1 then
					sColourStart = sColourLightGreen
				elseif iSurplus == 1 then
					sColourStart = sColourYellowGreen
				elseif iSurplus < 0 then
					sColourStart = sColourRed
				end
			end

			if sToolTip == "" then
				sToolTip = string.format("%s %s", pResource.IconString, Locale.ConvertTextKey(pResource.Description))
			end
		else
			local iActiveMinors  = pActivePlayer:GetResourceFromMinors(iResource)
			local iActiveImports = pActivePlayer:GetResourceImport(iResource)
			local iActiveExports = pActivePlayer:GetResourceExport(iResource)
			local iActiveLocal   = pActivePlayer:GetNumResourceTotal(iResource, false) + iActiveExports
			local iActiveUsed = pActivePlayer:GetNumResourceUsed(iResource)
			
			local iActiveSurplus = iActiveLocal - iActiveExports - iActiveUsed
	
			local iActiveTotal   = iActiveLocal + iActiveMinors + iActiveImports - iActiveExports - iActiveUsed
			
			if iSurplus > 3 and iActiveTotal <= 0 then
				sColourStart = sColourDarkGreen
			elseif iSurplus > 1 and iActiveTotal <= 0 then
				sColourStart = sColourLightGreen
			elseif iSurplus < 0 then
				sColourStart = sColourRed
			elseif iTotal == 0 and iActiveSurplus > 0 then
				sColourStart = sColourOrange
			end
			
			-- current deals part copied and modified from EUI
			local table = EUI.table
			local tDealsFinalTurn = {}
			local tDeals = table()
			local iCurrentTurn = Game.GetGameTurn()-1
			local iActivePlayer = pActivePlayer:GetID()
			local iPlayer = pPlayer:GetID()
				
			local tDealItems = {}
			local tFinalTurns = table()
			local pDeal = UI.GetScratchDeal()
			
			EUI.PushScratchDeal()
			
			for i = 0, UI.GetNumCurrentDeals(iActivePlayer) - 1 do
				UI.LoadCurrentDeal(iActivePlayer, i)
				
				local iToPlayer = pDeal:GetOtherPlayer(iActivePlayer)
				
				pDeal:ResetIterator()
				
				repeat
					local iItem, iDuration, iFinalTurn, data1, data2, data3, flag1, iFromPlayer = pDeal:GetNextItem()
					
					if iItem then
						if iToPlayer == iPlayer or iFromPlayer == iPlayer then
							local bIsFromUs = iFromPlayer == iActivePlayer
							local tDealItem = tDealItems[iFinalTurn]
							
							if not tDealItem then
								tDealItem = {}
								tDealItems[iFinalTurn] = tDealItem
								tFinalTurns:insert(iFinalTurn)
							end
							
							if iItem == TradeableItems.TRADE_ITEM_GOLD_PER_TURN then
								tDealItem.GPT = (tDealItem.GPT or 0) + (bIsFromUs and -data1 or data1)
							elseif iItem == TradeableItems.TRADE_ITEM_RESOURCES then
								tDealItem[data1] = (tDealItem[data1] or 0) + (bIsFromUs and -data2 or data2)
							else
								tDealsFinalTurn[iItem + (bIsFromUs and 65536 or 0)] = iFinalTurn
							end
						end
					else
						break
					end
				until false
			end
			
			EUI.PopScratchDeal()
			tFinalTurns:sort()
			
			for i = 1, #tFinalTurns do
				local iFinalTurn = tFinalTurns[i]
				local tDealItem = tDealItems[ iFinalTurn ] or {}
				local tDeal = table()
				local iQuantity = tDealItem.GPT
				
				if iQuantity and iQuantity ~= 0 then
					tDeal:insert(string.format("%+g%s", iQuantity, "[ICON_GOLD]"))
				end
				
				for resource in GameInfo.Resources() do
					local iQuantity = tDealItem[resource.ID]
					
					if iQuantity or 0 ~= 0 then
						tDeal:insert(string.format("%+g%s", iQuantity, tostring(resource.IconString)))
					end
				end
				
				if #tDeal > 0 then
					tDeals:insert(table.concat(tDeal) .. " ("..(iFinalTurn - iCurrentTurn)..")[NEWLINE]")
				end
			end
			
			if #tDeals > 0 then
				for i = 0, #tDeals do
					sDeals = string.format("%s with %s:[NEWLINE]%s", Locale.ConvertTextKey("Current deals"), pPlayer:GetName(), table.concat(tDeals))
				end
			end
			
			sToolTip = string.format("%s %s", pResource.IconString, Locale.ConvertTextKey(pResource.Description))
		end
		
		-- monopolies
		local bIsStrategic = pResource.ResourceUsage == 1
		local fRatio = (pPlayer:GetNumResourceTotal(iResource, false) + pPlayer:GetResourceExport(iResource)) / Map.GetNumResources(iResource)
		local bGlobalMonopoly = fRatio > 0.5
		local bStrategicMonopoly = fRatio > 0.25
			
		sText = string.format("%s%d", sColourStart, iTotal)
		
		if not bIsPaper then
			if bGlobalMonopoly then
				sText = sText .. "''"
			elseif bStrategicMonopoly and bIsStrategic then
				sText = sText .. "'"
			end
		end
		
		sText = sText .. "[ENDCOLOR]"
	else
		sText = string.format("%s-[ENDCOLOR]", sColourStart)
		sToolTip = pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description) .. " - unavailable"
	end

	return sText, sToolTip, iTotal, sDeals
end

-- check for discovered resources (no spoilers addon)
function IsVisibleUsefulResource(eResource, pPlayer)
	local iPlayer = pPlayer:GetID()
	local pTeam = Teams[pPlayer:GetTeam()]
	
	for playerLoop = 0, GameDefines.MAX_CIV_PLAYERS-1, 1 do
		local pOtherPlayer = Players[playerLoop]
		local iOtherTeam = pOtherPlayer:GetTeam()
    
		if playerLoop == iPlayer then
			if IsPlayerHasResource(pPlayer, eResource) or IsPlayerNearResource(pPlayer, eResource) then
				return true
			end
		elseif playerLoop ~= iPlayer and pOtherPlayer:IsAlive() then
			if pTeam:IsHasMet(iOtherTeam) then
				if IsPlayerHasResource(pOtherPlayer, eResource) or IsPlayerNearResource(pOtherPlayer, eResource) then
					return true
				end
			end
		end
	end

	return false
end

-- check for active player resources
function IsPlayerHasResource(pPlayer, eResource)
	return pPlayer:GetNumResourceTotal(eResource, false) + pPlayer:GetResourceExport(eResource) > 0
end

-- check for nearby resources
function IsPlayerNearResource(pPlayer, eResource)
	local iPlayer = pPlayer:GetID()
	
	for city in pPlayer:Cities() do
		if (city ~= nil) then
			local iThisX = city:GetX()
			local iThisY = city:GetY()
			
			local iRange = 5
			local iCloseRange = 2
			
			for iDX = -iRange, iRange, 1 do
				for iDY = -iRange, iRange, 1 do
					local pTargetPlot = Map.GetPlotXY(iThisX, iThisY, iDX, iDY)
			
					if pTargetPlot ~= nil then
						local iOwner = pTargetPlot:GetOwner()
			  
						if iOwner == iPlayer or iOwner == -1 then
							local plotDistance = Map.PlotDistance(iThisX, iThisY, pTargetPlot:GetX(), pTargetPlot:GetY())
				
							if plotDistance <= iRange and (plotDistance <= iCloseRange or iOwner == iPlayer) then
								if pTargetPlot:GetResourceType(Game.GetActiveTeam()) == eResource then
									return true
								end
							end
						end
					end
				end
			end
		end
	end

	return false
end

-- creating list of cities demanding some resource to get WLKTD
function GetGoldenAgeCities(pPlayer,pResource)
	local sCityList = ""
	local iCounter = 0
	local sColourBlue = "[COLOR_CITY_BLUE]"
	local sColourCyan = "[COLOR_CYAN]"
	local sColour = sColourCyan

	for city in pPlayer:Cities() do
		if city:GetWeLoveTheKingDayCounter() == 0 and city:GetResourceDemanded(true) == pResource.ID then
     		if sCityList ~= "" then
				sCityList = sCityList .. ", "
			end
			
			if city:IsCapital() then
				sCityList = sCityList .. "[ICON_CAPITAL] "
			end
			
			sCityList = sCityList .. city:GetName()
			iCounter = iCounter+1
			
			if iCounter > 1 then
				sColour = sColourBlue
			end
		end
	end
	
	if sCityList ~= "" then
		local sHeader = pResource.IconString .. " " .. Locale.ConvertTextKey(pResource.Description) .. ": following cities demand this resource: "
	
		sCityList = sHeader .. sColour .. sCityList .. "[ENDCOLOR]"
	end
	
	return sCityList, iCounter
end

-- function drawing cs buttons
function InitCsList()
	local bCsMet = false

	local iActivePlayer = Game.GetActivePlayer()
	local pActivePlayer = Players[iActivePlayer]
	local pActiveTeam = Teams[pActivePlayer:GetTeam()]

	local imControlTable = gCsIM:GetInstance()
	local iMaxY = imControlTable.TradeBox:GetSizeY()
			
	for resource in GameInfo.Resources() do
		if resource.ResourceUsage > 0 then
			local sLuxControl = resource.Type
			local im = imControlTable[sLuxControl]
			local imPlusBox = imControlTable[sLuxControl .. "_BOX"]
			
			if im ~= nil then
				im:DestroyAllChildren()
			else
				im = imControlTable["RESOURCE_OTHER_LUXURIES"]
				imPlusBox = imControlTable["RESOURCE_OTHER_LUXURIES_BOX"]
				local iResourceID = resource.ID
				
				if iResourceID > iPreviousResourceID then
					iPreviousResourceID = iResourceID
				else
					iPreviousResourceID = -1
					im:DestroyAllChildren()
				end
			end
			
			for csloop = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1, 1 do
				local pCs = Players[csloop]
		
				if pCs:IsAlive() and pActiveTeam:IsHasMet(pCs:GetTeam()) then
					if IsCsHasResource(pCs, resource) or IsCsNearResource(pCs, resource.ID) then
						local tCSTextControlTable = {}
						
						ContextPtr:BuildInstanceForControl("CityStateButtonInstance", tCSTextControlTable, im)

						tCSTextControlTable.CsLuxuryIcon:SetHide(true)
						tCSTextControlTable.CsTraitIcon:SetOffsetVal(-3,0)
						tCSTextControlTable.CsTraitIcon:SetSizeVal(31,24)

						local sTrait = GameInfo.MinorCivilizations[pCs:GetMinorCivType()].MinorCivTrait
						tCSTextControlTable.CsTraitIcon:SetTexture(GameInfo.MinorCivTraits[sTrait].TraitIcon)
						local primaryColor, secondaryColor = pCs:GetPlayerColors()
						tCSTextControlTable.CsTraitIcon:SetColor({x = secondaryColor.x, y = secondaryColor.y, z = secondaryColor.z, w = 1})

						local sCsAlly = "TXT_KEY_CITY_STATE_NOBODY"

						local iCsAlly = pCs:GetAlly()
						
						if iCsAlly ~= nil and iCsAlly ~= -1 then
							if iCsAlly ~= iActivePlayer then
								if pActiveTeam:IsHasMet(Players[iCsAlly]:GetTeam()) then
									sCsAlly = Players[iCsAlly]:GetCivilizationShortDescriptionKey()
								else
									sCsAlly = "TXT_KEY_MISC_UNKNOWN"
								end
							else
								sCsAlly = "TXT_KEY_YOU"
							end
						end

						local sToolTip = Locale.ConvertTextKey(pCs:GetCivilizationShortDescriptionKey()) .. " (" .. Locale.ConvertTextKey(sCsAlly) .. ") " .. GetCsStrategicsOrLuxuries(pCs)
						
						tCSTextControlTable.CsButton:SetToolTipString(sToolTip)
						tCSTextControlTable.CsButton:SetVoid1(csloop)
						tCSTextControlTable.CsButton:RegisterCallback(Mouse.eLClick, OnCsSelected)
					end

					bCsMet = true
				end
			end

			im:CalculateSize()
			im:ReprocessAnchoring()

			imPlusBox:SetSizeY(math.max(30, im:GetSizeY() + 3))

			iMaxY = math.max(iMaxY, im:GetSizeY())
		end
	end 

	if not bCsMet then
		imControlTable.TradeBox:SetHide(true)
	else
		imControlTable.TradeBox:SetHide(false)
		imControlTable.TradeBox:SetSizeY(iMaxY+5)
	end

	return bCsMet
end

-- checking nearby resources
function IsCsNearResource(pCs, iResource)
	local iCs = pCs:GetID()
	local pCapital = pCs:GetCapitalCity()
	
	if pCapital ~= nil then
		local iThisX = pCapital:GetX()
		local iThisY = pCapital:GetY()
		
		local iRange = 5
		local iCloseRange = 2
		
		for iDX = -iRange, iRange, 1 do
			for iDY = -iRange, iRange, 1 do
				local pTargetPlot = Map.GetPlotXY(iThisX, iThisY, iDX, iDY)
        
				if pTargetPlot ~= nil then
					local iOwner = pTargetPlot:GetOwner()
          
					if iOwner == iCs or iOwner == -1 then
						local plotDistance = Map.PlotDistance(iThisX, iThisY, pTargetPlot:GetX(), pTargetPlot:GetY())
            
						if plotDistance <= iRange and (plotDistance <= iCloseRange or iOwner == iCs) then
							if pTargetPlot:GetResourceType(Game.GetActiveTeam()) == iResource then
								return true
							end
						end
					end
				end
			end
		end
	end

	return false
end

-- checks for CS resources
function IsCsHasResource(pCs, pResource)
	return (GetCsResourceCount(pCs, pResource) > 0)
end

-- checks for available resource list
function GetCsStrategicsOrLuxuries(pCs)
	local sStrategicsOrLuxuries = ""
	
	for resource in GameInfo.Resources() do
		local iResource = resource.ID

		if Game.GetResourceUsageType(iResource) > 0  then
			iAmount = GetCsResourceCount(pCs, resource)

			if iAmount > 0 then
				if sStrategicsOrLuxuries ~= "" then
					sStrategicsOrLuxuries = sStrategicsOrLuxuries .. ", "
				end

				sStrategicsOrLuxuries = sStrategicsOrLuxuries .. resource.IconString .. " [COLOR_POSITIVE_TEXT]" .. iAmount .. "[ENDCOLOR]"
			end
		end
	end

	return sStrategicsOrLuxuries
end

-- subfunction
function GetCsResourceCount(pCs, pResource)
	local iResource = pResource.ID
	
	return pCs:GetNumResourceTotal(iResource, false) + pCs:GetResourceExport(iResource)
end

-- it's a City State being founded, so we may now have Mercantile luxuries
function OnCityCreated(hexPos, iPlayer)
	if (iPlayer >= GameDefines.MAX_MAJOR_CIVS) then
		GetCsLuxuriesAndStrategics()
	end
end
Events.SerialEventCityCreated.Add(OnCityCreated)

---------------
-- callbacks --
---------------
function OnCivSelected(iPlayer)
	if (Players[iPlayer]:IsHuman()) then
		Events.OpenPlayerDealScreenEvent(iPlayer)
	else
		UI.SetRepeatActionPlayer(iPlayer)
		UI.ChangeStartDiploRepeatCount(1)
		Players[iPlayer]:DoBeginDiploWithHuman()
	end
end

function OnCsSelected(iCs)
	local popupInfo = {
		Type = ButtonPopupTypes.BUTTONPOPUP_CITY_STATE_DIPLO,
		Data1 = iCs
	}
    
	Events.SerialEventGameMessagePopup(popupInfo)
end

---------------------------
-- resource list creator --
---------------------------
local gAvailableUsefulResources = nil

function IsAvailableLuxury(resource)
	if gAvailableUsefulResources == nil then
		GetAvailableUsefulResources()
	end

	return gAvailableUsefulResources[resource]
end

function GetAvailableUsefulResources()
	gAvailableUsefulResources = {}

	GetMapLuxuriesAndStrategics()
	GetBuildingLuxuriesAndStrategics()
	GetCsLuxuriesAndStrategics()
	GetCivLuxuriesAndStrategics()
end

-- any luxuries placed on the map
function GetMapLuxuriesAndStrategics()
	for iPlot = 0, Map.GetNumPlots()-1, 1 do
		local pPlot = Map.GetPlotByIndex(iPlot)

		if pPlot:GetResourceType() ~= -1 then
			local resource = GameInfo.Resources[pPlot:GetResourceType()]

			if resource ~= nil and resource.ResourceUsage > 0 then
				gAvailableUsefulResources[resource.ID] = true
			end
		end
	end
end

-- any luxuries from buildings
function GetBuildingLuxuriesAndStrategics()
	for buildingResource in GameInfo.Building_ResourceQuantity() do
		local resource = GameInfo.Resources[buildingResource.ResourceType]

		if resource ~= nil and resource.ResourceUsage > 0 then
			gAvailableUsefulResources[resource.ID] = true
		end
	end
end

-- any luxuries from City States
function GetCsLuxuriesAndStrategics()
	for iCs = GameDefines.MAX_MAJOR_CIVS, GameDefines.MAX_CIV_PLAYERS-1, 1 do
		local pCs = Players[iCs]
			
		if pCs:IsEverAlive() and pCs:GetMinorCivTrait() == MinorCivTraitTypes.MINOR_CIV_TRAIT_MERCANTILE then
			local pPlot = pCs:GetStartingPlot()
			local resource = pPlot and GameInfo.Resources[pPlot:GetResourceType()]

			if resource ~= nil and resource.ResourceUsage > 0 then
				gAvailableUsefulResources[resource.ID] = true
			end
		end
	end
end

-- any civ specific luxuries and strategics
function GetCivLuxuriesAndStrategics()
	for iCiv = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local pCiv = Players[iCiv]
		
		if pCiv:IsEverAlive() then
			local sCivType = GameInfo.Civilizations[pCiv:GetCivilizationType()].Type

			for resource in GameInfo.Resources() do
				if resource.ResourceUsage > 0 and resource.CivilizationType == sCivType then
					gAvailableUsefulResources[resource.ID] = true
				end
			end
		end
	end
end

GetAvailableUsefulResources()