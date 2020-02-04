print("Loading DiploTradeStatus.lua from TOfVP");
--------------------------------------------------------------
-- New Trade Opportunities panel
-- Dec 13, 2017: Retrofitted for Vox Populi, Infixo
-- Jan 14, 2020: Improved, adan_eslavo
--------------------------------------------------------------
include("IconSupport")
include("SupportFunctions")
include("InstanceManager")
include("InfoTooltipInclude")

local g_PlayerIM = InstanceManager:new("TradeStatusInstance", "TradeBox", Controls.PlayerBox)
local g_AiIM = InstanceManager:new("TradeStatusInstance", "TradeBox", Controls.AiStack)
local g_CsIM = InstanceManager:new("CityStateInstance", "TradeBox", Controls.AiStack)
local g_ResourceIM = InstanceManager:new("TradeResourcesInstance", "TradeBox", Controls.ResourceBox)

local g_SortTable
local g_ePreviousResource = -1

local L = Locale.ConvertTextKey

local g_tValidImprovements = {
	"IMPROVEMENT_CAMP",
	"IMPROVEMENT_MINE",
	"IMPROVEMENT_QUARRY",
	"IMPROVEMENT_PLANTATION",
	"IMPROVEMENT_FISHING_BOATS"
}

local g_sColorBrown = "[COLOR_CITY_GREY]"
local g_sColorDarkGreen = "[COLOR:0:135:0:255]"
local g_sColorLightGreen = "[COLOR:125:255:0:255]"
local g_sColorYellowGreen = "[COLOR:200:180:0:255]"
local g_sColorRed = "[COLOR:255:70:70:255]"
local g_sColorBlue = "[COLOR_CITY_BLUE]"
local g_sColorCyan = "[COLOR_CYAN]"	
local g_sColorOrange = "[COLOR_YIELD_FOOD]"

local g_sColorResourceLuxury = "[COLOR:255:235:30:255]"
local g_sColorResourceStrategic = "[COLOR:210:210:210:255]"
local g_sColorResourceName

local g_sColorWar = "[COLOR_NEGATIVE_TEXT]"
local g_sColorFriendly = "[COLOR_POSITIVE_TEXT]"
local g_sColorGuarded = "[COLOR_YELLOW]"
local g_sColorDenounce = "[COLOR_MAGENTA]"
local g_sColorAfraid = "[COLOR_YIELD_FOOD]"

local g_sColorCSResource
local g_tIsCsHasResourceUnimproved = {}

-- open window?
function ShowHideHandler(bIsHide, bIsInit)
	if not bIsInit and not bIsHide then
		g_ResourceIM:ResetInstances()
		g_PlayerIM:ResetInstances()
		g_AiIM:ResetInstances()
		g_CsIM:ResetInstances()
	  
		local ePlayer = Game.GetActivePlayer()
		
		InitPlayer(ePlayer)
		InitAiList(ePlayer)
	end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

-- draw first player line
function InitPlayer(ePlayer)
	GetCivControl(g_PlayerIM, ePlayer, false)
end

-- check if there are AIs and run lines for them
function InitAiList(ePlayer)
	local pPlayer = Players[ePlayer]
	local pTeam = Teams[pPlayer:GetTeam()]
	local iCount = 0

	g_SortTable = {}
  
	for playerLoop = 0, GameDefines.MAX_MAJOR_CIVS-1, 1 do
		local pOtherPlayer = Players[playerLoop]
		local eOtherTeam = pOtherPlayer:GetTeam()
		
		-- draw new resource lines for each met civ
		if playerLoop ~= ePlayer and pOtherPlayer:IsAlive() then
			if pTeam:IsHasMet(eOtherTeam) then
				iCount = iCount + 1
				GetCivControl(g_AiIM, playerLoop, true)
			end
		end
	end
	
	-- draw CSs columns for each resource
	if InitCsList() then
		iCount = iCount + 1
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
	local entryA = g_SortTable[tostring(a)]
	local entryB = g_SortTable[tostring(b)]

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
function GetCivControl(im, ePlayer, bCanTrade)
	local eActivePlayer = Game.GetActivePlayer()
	local pActivePlayer = Players[eActivePlayer]
	local eActiveTeam = pActivePlayer:GetTeam()
	local pActiveTeam = Teams[eActiveTeam]
	local bIsActivePlayer = (eActivePlayer == ePlayer)

	local pPlayer = Players[ePlayer]
	local eTeam = pPlayer:GetTeam()
	local pTeam = Teams[eTeam]
	local eCivilization = GameInfo.Civilizations[pPlayer:GetCivilizationType()]
        
	local pDeal = UI.GetScratchDeal()

	local tSortEntry = {}
	
	local imControlTableHeader = g_ResourceIM:GetInstance()
	local imControlTable = im:GetInstance()
		
	imControlTable.TradeOps:SetHide(false)
	imControlTable.TradeWar:SetHide(pActiveTeam:IsAtWar(eTeam) == false)

	imControlTable.CivName:SetText(L(eCivilization.ShortDescription))
	CivIconHookup(ePlayer, 32, imControlTable.CivSymbol, imControlTable.CivIconBG, imControlTable.CivIconShadow, false, true)
	imControlTable.CivIconBG:SetHide(false)

	--imControlTable.CivButton:SetToolTipString(L("TXT_KEY_DO_CIV_STATUS", GetApproach(pActivePlayer, pPlayer), GameInfo.Eras[pPlayer:GetCurrentEra()].Description, pPlayer:GetScore()))

	if bCanTrade then        
		imControlTable.CivButton:SetVoid1(ePlayer)
		imControlTable.CivButton:RegisterCallback(Mouse.eLClick, OnCivSelected)

		g_SortTable[tostring(imControlTable.TradeBox)] = tSortEntry
		tSortEntry.PlayerID = ePlayer
	else
		imControlTable.CivButtonHL:SetHide(true)
	end
	
	local sGatheredOtherHeaders = ""
	local sGatheredOtherTooltips = ""
	local sText, sToolTip, sDeals = ""
	local sVerifiedDeals = ""
	local sColorOther = g_sColorBrown
	
	local controlOther = imControlTable["RESOURCE_OTHER_LUXURIES"]
	controlOther:SetText("")		
	controlOther:SetToolTipString("")
		
	imControlTableHeader.RESOURCE_OTHER_LUXURIES_ICON:SetHide(true)
	imControlTableHeader["Other"]:SetText("")
	
	-- draw headers and lines
	for resource in GameInfo.Resources() do
		if resource.ResourceUsage > 0 then
			-- header
			local controlHeader = imControlTableHeader[L(resource.Description)]
			
			g_sColorResourceName = g_sColorResourceLuxury
			if resource.ResourceUsage == 1 then
				g_sColorResourceName = g_sColorResourceStrategic
			end
			local sColorResourceImprovement = "[COLOR_CYAN]"
			
			if controlHeader == nil then
				local sOtherHeader = L(resource.IconString) .. " " .. g_sColorResourceName .. L(resource.Description) .. "[ENDCOLOR]"
				
				if resource.OnlyMinorCivs then
					sOtherHeader = sOtherHeader .. sColorResourceImprovement .. " (City-State)[ENDCOLOR]"
				else
					for _, validImprovement in ipairs(g_tValidImprovements) do
						for improvement in GameInfo.Improvement_ResourceTypes() do
							if improvement.ResourceType == resource.Type and improvement.ImprovementType == validImprovement then
								sOtherHeader = sOtherHeader .. sColorResourceImprovement .. " (" .. L("TXT_KEY_" .. improvement.ImprovementType) .. ")[ENDCOLOR]"
							end
						end
					end
				end

				local sHelp = L(resource.Help)
				sHelp = string.gsub(sHelp, "(.-)(Monopoly Bonus)(.-)", "[COLOR_POSITIVE_TEXT]%2[ENDCOLOR]%3")

				sOtherHeader = sOtherHeader .. g_sColorResourceName .. ":[ENDCOLOR] " .. sHelp

				if sGatheredOtherHeaders == "" then
					sGatheredOtherHeaders = sOtherHeader
				else
					sGatheredOtherHeaders = sGatheredOtherHeaders .. "[NEWLINE]" .. sOtherHeader
				end
				
				local controlHeaderBox = imControlTableHeader.RESOURCE_OTHER_LUXURIES_ICON
				controlHeaderBox:SetHide(false)
				
				controlHeader = imControlTableHeader["Other"]
				controlHeader:SetText("[ICON_RES_HIDDEN_ARTIFACTS]")
				controlHeader:SetToolTipString(sGatheredOtherHeaders)
			else
				controlHeader:SetText(L(resource.IconString))
				controlHeader:SetToolTipString(string.format("%s %s%s:[ENDCOLOR] %s", resource.IconString, g_sColorResourceName, L(resource.Description), L(resource.Help)))
			end
			
			-- values
			sText, sToolTip, sDeals = GetUsefulResourceText(pPlayer, resource, bIsActivePlayer, pActivePlayer)
			local control = imControlTable[resource.Type]
			
			if control == nil then
				if sGatheredOtherTooltips == "" then
					sGatheredOtherTooltips = sToolTip
				else
					sGatheredOtherTooltips = sGatheredOtherTooltips .. "[NEWLINE]" .. sToolTip
				end

				local iPosStart, iPosEnd = string.find(sToolTip, "unavailable")
				
				if iPosStart == nil then
					sColorOther = g_sColorOrange
				end
			else
				if sDeals ~= "" then
					sToolTip = sToolTip .. "[NEWLINE][NEWLINE]" .. sDeals
				end
				
				control:SetText(sText)
				control:SetToolTipString(sToolTip)
			end
			
			if sDeals ~= "" then
				sVerifiedDeals = sDeals
			end
		end
	end
	
	if sGatheredOtherTooltips ~= "" then
		if sVerifiedDeals ~= "" then
			sGatheredOtherTooltips = sGatheredOtherTooltips .."[NEWLINE][NEWLINE]" .. sVerifiedDeals
		end

		controlOther:SetText(sColorOther .. "...[ENDCOLOR]")
		controlOther:SetToolTipString(sGatheredOtherTooltips)
		Controls.BottomTrimNormal:SetHide(true)
		Controls.BottomTrimOther:SetHide(false)
		Controls.OtherHeader:SetHide(false)
	else
		Controls.BottomTrimNormal:SetHide(false)
		Controls.BottomTrimOther:SetHide(true)
		Controls.OtherHeader:SetHide(true)
	end

	local sPlayerTooltip = L("TXT_KEY_DO_CIV_STATUS", GetApproach(pActivePlayer, pPlayer), GameInfo.Eras[pPlayer:GetCurrentEra()].Description, pPlayer:GetScore())
	if sVerifiedDeals ~= "" then
		sPlayerTooltip = sPlayerTooltip .. "[NEWLINE][NEWLINE]" .. sVerifiedDeals
	end
	imControlTable.CivButton:SetToolTipString(sPlayerTooltip)

	-- draw three additional action buttons
	local sResearchIcon = ""
	local sResearchTip = ""
  
	if bIsActivePlayer then
		sResearchIcon = ""
		sResearchTip = ""
	else
		if pDeal:IsPossibleToTradeItem(ePlayer, eActivePlayer, TradeableItems.TRADE_ITEM_RESEARCH_AGREEMENT, Game.GetDealDuration()) then
			sResearchIcon = "[ICON_RESEARCH]"
			sResearchTip = "TXT_KEY_DO_TRADE_STATUS_RA_YES_TT"
		elseif pTeam:IsHasResearchAgreement(eActiveTeam) then
			sResearchIcon = "[ICON_SWAP]"
			sResearchTip = "TXT_KEY_DO_TRADE_STATUS_RA_NO_TT"
		end
	end
	
	imControlTable.ResearchText:SetText(sResearchIcon)
	imControlTable.ResearchText:SetToolTipString(L(sResearchTip))

	local sEmbassyIcon = ""
	local sEmbassyTip = ""
  
	if bIsActivePlayer then
		sEmbassyIcon = ""
		sEmbassyTip = ""
	else
		if pDeal:IsPossibleToTradeItem(ePlayer, eActivePlayer, TradeableItems.TRADE_ITEM_ALLOW_EMBASSY, Game.GetDealDuration()) and
			pDeal:IsPossibleToTradeItem(eActivePlayer, ePlayer, TradeableItems.TRADE_ITEM_ALLOW_EMBASSY, Game.GetDealDuration()) then
			sEmbassyIcon = "[ICON_CITY_STATE]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_YES_TT"
		elseif pTeam:HasEmbassyAtTeam(eActiveTeam) and pActiveTeam:HasEmbassyAtTeam(eTeam) then
			sEmbassyIcon = "[ICON_INFLUENCE]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_NO_TT"
		elseif pActiveTeam:HasEmbassyAtTeam(eTeam) then
			sEmbassyIcon = "[ICON_CAPITAL]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_US_TT"
		elseif pTeam:HasEmbassyAtTeam(eActiveTeam) then
			sEmbassyIcon = "[ICON_CAPITAL]"
			sEmbassyTip = "TXT_KEY_DO_TRADE_STATUS_EMBASSY_THEM_TT"
		end
	end
  
	imControlTable.EmbassyText:SetText(sEmbassyIcon)
	imControlTable.EmbassyText:SetToolTipString(L(sEmbassyTip))

	local sBordersIcon = ""
	local sBordersTip = ""
  
	if bIsActivePlayer then
		sBordersIcon = ""
		sBordersTip = ""
	else
		if pDeal:IsPossibleToTradeItem(ePlayer, eActivePlayer, TradeableItems.TRADE_ITEM_OPEN_BORDERS, Game.GetDealDuration()) and
			pDeal:IsPossibleToTradeItem(eActivePlayer, ePlayer, TradeableItems.TRADE_ITEM_OPEN_BORDERS, Game.GetDealDuration()) then
			sBordersIcon = "[ICON_TRADE]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_YES_TT"
		elseif pTeam:IsAllowsOpenBordersToTeam(eActiveTeam) and pActiveTeam:IsAllowsOpenBordersToTeam(eTeam) then
			sBordersIcon = "[ICON_TRADE_WHITE]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_NO_TT"
		elseif pTeam:IsAllowsOpenBordersToTeam(eActiveTeam) then
			sBordersIcon = "[ICON_ARROW_RIGHT]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_US_TT"
		elseif pActiveTeam:IsAllowsOpenBordersToTeam(eTeam) then
			sBordersIcon = "[ICON_ARROW_LEFT]"
			sBordersTip = "TXT_KEY_DO_TRADE_STATUS_BORDERS_THEM_TT"
		end
	end
  
	imControlTable.BordersText:SetText(sBordersIcon)
	imControlTable.BordersText:SetToolTipString(L(sBordersTip))

	return imControlTable
end

-- approach types checking
function GetApproach(pActivePlayer, pPlayer)
	local sApproach = ""

	if pActivePlayer:GetID() ~= pPlayer:GetID() then
		if Teams[pActivePlayer:GetTeam()]:IsAtWar(pPlayer:GetTeam()) then
			sApproach = g_sColorWar .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR") .. "[ENDCOLOR]"
		elseif pPlayer:IsDenouncingPlayer(pActivePlayer:GetID()) then
			sApproach = g_sColorDenounce .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_DENOUNCING") .. "[ENDCOLOR]"
		else
			local iApproach = pActivePlayer:GetApproachTowardsUsGuess(pPlayer:GetID())
  
			if iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_WAR then
				sApproach = g_sColorWar .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_WAR") .. "[ENDCOLOR]"
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_HOSTILE then
				sApproach = g_sColorWar .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_HOSTILE") .. "[ENDCOLOR]"
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_GUARDED then
				sApproach = g_sColorGuarded .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_GUARDED") .. "[ENDCOLOR]"
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_NEUTRAL then
				sApproach = L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_NEUTRAL") .. "[ENDCOLOR]"
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_FRIENDLY then
				sApproach = g_sColorFriendly .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_FRIENDLY") .. "[ENDCOLOR]"
			elseif iApproach == MajorCivApproachTypes.MAJOR_CIV_APPROACH_AFRAID then
				sApproach = g_sColorAfraid .. L("TXT_KEY_DIPLO_MAJOR_CIV_DIPLO_STATE_AFRAID") .. "[ENDCOLOR]"
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
	local eResource = pResource.ID
	local bIsPaper = eResource == GameInfoTypes.RESOURCE_PAPER
	
	local sText = ""
	local sToolTip = ""
	local sDeals = ""
	local sCityList = ""
	local iTotal = 0
	local sValueColor = g_sColorBrown

	if IsAvailableLuxury(eResource) and IsVisibleUsefulResource(eResource, pActivePlayer) then
		local iMinors  = pPlayer:GetResourceFromMinors(eResource)
		local iImports = pPlayer:GetResourceImport(eResource)
		local iExports = pPlayer:GetResourceExport(eResource)
		local iLocal   = pPlayer:GetNumResourceTotal(eResource, false) + iExports
		local iUsed    = pPlayer:GetNumResourceUsed(eResource)
		
		local iSurplus = iLocal - iExports - iUsed
		
		iTotal = iLocal + iMinors + iImports - iExports - iUsed
		
		if bIsActivePlayer then
			if iTotal == 0 then
				local iCounter = 0
				
				sCityList, iCounter = GetGoldenAgeCities(pPlayer, pResource)

				if sCityList ~= "" then
					if iCounter > 1 then
						sValueColor = g_sColorBlue
					else
						sValueColor = g_sColorCyan
					end
				else
					sValueColor = g_sColorOrange
				end
			else
				if iSurplus > 3 then
					sValueColor = g_sColorDarkGreen
				elseif iSurplus > 1 then
					sValueColor = g_sColorLightGreen
				elseif iSurplus == 1 then
					sValueColor = g_sColorYellowGreen
				elseif iSurplus < 0 then
					sValueColor = g_sColorRed
				end
			end
		else
			local iActiveMinors  = pActivePlayer:GetResourceFromMinors(eResource)
			local iActiveImports = pActivePlayer:GetResourceImport(eResource)
			local iActiveExports = pActivePlayer:GetResourceExport(eResource)
			local iActiveLocal   = pActivePlayer:GetNumResourceTotal(eResource, false) + iActiveExports
			local iActiveUsed	 = pActivePlayer:GetNumResourceUsed(eResource)
			
			local iActiveSurplus = iActiveLocal - iActiveExports - iActiveUsed
			local iActiveTotal   = iActiveLocal + iActiveMinors + iActiveImports - iActiveExports - iActiveUsed
			
			if iSurplus > 3 and iActiveTotal <= 0 then
				sValueColor = g_sColorDarkGreen
			elseif iSurplus > 1 and iActiveTotal <= 0 then
				sValueColor = g_sColorLightGreen
			elseif iSurplus < 0 then
				sValueColor = g_sColorRed
			elseif iTotal == 0 and iActiveSurplus > 0 then
				sValueColor = g_sColorOrange
			end
			
			-- current deals part copied and modified from EUI
			local table = EUI.table
			local tDealsFinalTurn = {}
			local tDeals = table()
			local iCurrentTurn = Game.GetGameTurn()-1
			local eActivePlayer = pActivePlayer:GetID()
			local ePlayer = pPlayer:GetID()
				
			local tDealItems = {}
			local tFinalTurns = table()
			local pDeal = UI.GetScratchDeal()
			
			EUI.PushScratchDeal()
			
			for i = 0, UI.GetNumCurrentDeals(eActivePlayer) - 1 do
				UI.LoadCurrentDeal(eActivePlayer, i)
				
				local iToPlayer = pDeal:GetOtherPlayer(eActivePlayer)
				
				pDeal:ResetIterator()
				
				repeat
					local iItem, iDuration, iFinalTurn, data1, data2, data3, flag1, iFromPlayer = pDeal:GetNextItem()
					
					if iItem then
						if iToPlayer == ePlayer or iFromPlayer == ePlayer then
							local bIsFromUs = iFromPlayer == eActivePlayer
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
				local tDealItem = tDealItems[iFinalTurn] or {}
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
					sDeals = string.format("%s with %s:[NEWLINE]%s", L("Current deals"), pPlayer:GetName(), table.concat(tDeals))
				end
			end
		end
		
		-- monopolies
		local bIsStrategic = pResource.ResourceUsage == 1
		local fRatio = (pPlayer:GetNumResourceTotal(eResource, false) + pPlayer:GetResourceExport(eResource)) / Map.GetNumResources(eResource)
		local bGlobalMonopoly = fRatio > 0.5
		local bStrategicMonopoly = fRatio > 0.25
			
		sText = string.format("%s%d", sValueColor, iTotal)
		
		if not bIsPaper then
			if bGlobalMonopoly then
				sText = sText .. "''"
			elseif bStrategicMonopoly and bIsStrategic then
				sText = sText .. "'"
			end
		end
		
		sText = sText .. "[ENDCOLOR]"
		sToolTip = string.format("%s %s%s:[ENDCOLOR] %s", pResource.IconString, g_sColorResourceName, L(pResource.Description), sText)

		if sCityList ~= "" then
			sToolTip = sToolTip .. sCityList
		end
	else
		sText = string.format("%s-[ENDCOLOR]", g_sColorBrown)
		sToolTip = string.format("%s %s%s:[ENDCOLOR] %s%s[ENDCOLOR]", pResource.IconString, g_sColorResourceName, L(pResource.Description), g_sColorBrown, "unavailable")
	end

	return sText, sToolTip, sDeals
end

-- check for discovered resources (no spoilers addon)
function IsVisibleUsefulResource(eResource, pPlayer)
	local ePlayer = pPlayer:GetID()
	local pTeam = Teams[pPlayer:GetTeam()]
	
	for playerLoop = 0, GameDefines.MAX_CIV_PLAYERS-1, 1 do
		local pOtherPlayer = Players[playerLoop]
		local eOtherTeam = pOtherPlayer:GetTeam()
    
		if playerLoop == ePlayer then
			if IsPlayerHasResource(pPlayer, eResource) or IsPlayerNearResource(pPlayer, eResource) then
				return true
			end
		elseif playerLoop ~= ePlayer and pOtherPlayer:IsAlive() then
			if pTeam:IsHasMet(eOtherTeam) then
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
	local ePlayer = pPlayer:GetID()
	
	for city in pPlayer:Cities() do
		if city ~= nil then
			local iThisX = city:GetX()
			local iThisY = city:GetY()
			
			local iRange = 5
			local iCloseRange = 2
			
			for iDX = -iRange, iRange, 1 do
				for iDY = -iRange, iRange, 1 do
					local pTargetPlot = Map.GetPlotXY(iThisX, iThisY, iDX, iDY)
			
					if pTargetPlot ~= nil then
						local eOwner = pTargetPlot:GetOwner()
			  
						if eOwner == ePlayer or eOwner == -1 then
							local plotDistance = Map.PlotDistance(iThisX, iThisY, pTargetPlot:GetX(), pTargetPlot:GetY())
				
							if plotDistance <= iRange and (plotDistance <= iCloseRange or eOwner == ePlayer) then
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
	local sColor = g_sColorCyan

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
				sColor = g_sColorBlue
			end
		end
	end
	
	if sCityList ~= "" then
		sCityList = " (following cities demand this resource: " .. sColor .. sCityList .. "[ENDCOLOR])"
	end
	
	return sCityList, iCounter
end

-- function drawing cs buttons
function InitCsList()
	local bCsMet = false

	local eActivePlayer = Game.GetActivePlayer()
	local pActivePlayer = Players[eActivePlayer]
	local pActiveTeam = Teams[pActivePlayer:GetTeam()]

	local imControlTable = g_CsIM:GetInstance()
	local iMaxY = imControlTable.TradeBox:GetSizeY()
			
	for resource in GameInfo.Resources() do
		if resource.ResourceUsage > 0 then
			local sLuxControl = resource.Type
			local im = imControlTable[sLuxControl]
			local imPlusBox = imControlTable[sLuxControl .. "_BOX"]
			local eResource = resource.ID

			if im ~= nil then
				im:DestroyAllChildren()
			else
				im = imControlTable["RESOURCE_OTHER_LUXURIES"]
				imPlusBox = imControlTable["RESOURCE_OTHER_LUXURIES_BOX"]
				
				
				if eResource > g_ePreviousResource then
					g_ePreviousResource = eResource
				else
					g_ePreviousResource = -1
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
						
						if g_tIsCsHasResourceUnimproved[eResource] then
							tCSTextControlTable.CsTraitIcon:SetColor({x = 0.8, y = 0.8, z = 0.8, w = 1})
							g_sColorCSResource = "[COLOR_NEGATIVE_TEXT]"
						else
							local primaryColor, secondaryColor = pCs:GetPlayerColors()
							tCSTextControlTable.CsTraitIcon:SetColor({x = secondaryColor.x, y = secondaryColor.y, z = secondaryColor.z, w = 1})
							g_sColorCSResource = "[COLOR_POSITIVE_TEXT]"
						end

						local sCsAlly = "TXT_KEY_CITY_STATE_NOBODY"
						local iCsAlly = pCs:GetAlly()
						
						if iCsAlly ~= nil and iCsAlly ~= -1 then
							if iCsAlly ~= eActivePlayer then
								if pActiveTeam:IsHasMet(Players[iCsAlly]:GetTeam()) then
									sCsAlly = Players[iCsAlly]:GetCivilizationShortDescriptionKey()
								else
									sCsAlly = "TXT_KEY_MISC_UNKNOWN"
								end
							else
								sCsAlly = "TXT_KEY_YOU"
							end
						end

						local sToolTip = resource.IconString .. " " .. L(pCs:GetCivilizationShortDescriptionKey()) .. " (" .. L(sCsAlly) .. ") " .. GetCsStrategicsOrLuxuries(pCs)
						
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
function IsCsNearResource(pCs, eResource)
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
					local eOwner = pTargetPlot:GetOwner()
          
					if eOwner == iCs or eOwner == -1 then
						local plotDistance = Map.PlotDistance(iThisX, iThisY, pTargetPlot:GetX(), pTargetPlot:GetY())
            
						if plotDistance <= iRange and (plotDistance <= iCloseRange or eOwner == iCs) then
							if pTargetPlot:GetResourceType(Game.GetActiveTeam()) == eResource then
								print(eResource)
								for resource in GameInfo.Resources{ID=eResource} do
									print(eResource, "found")
									if not IsCsHasResource(pCs, resource) then
										print(eResource, "true")
										g_tIsCsHasResourceUnimproved[eResource] = true
									else
										print(eResource, "false_1")
										g_tIsCsHasResourceUnimproved[eResource] = false
									end

									break
								end

								return true
							end
						end
					end
				end
			end
		end
	end

	print(eResource, "false_2")
	g_tIsCsHasResourceUnimproved[eResource] = false
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
		local eResource = resource.ID

		if Game.GetResourceUsageType(eResource) > 0  then
			iAmount = GetCsResourceCount(pCs, resource)

			if iAmount > 0 then
				if sStrategicsOrLuxuries ~= "" then
					sStrategicsOrLuxuries = sStrategicsOrLuxuries .. ", "
				end

				sStrategicsOrLuxuries = sStrategicsOrLuxuries .. resource.IconString .. " " .. g_sColorCSResource .. iAmount .. "[ENDCOLOR]"
			elseif g_tIsCsHasResourceUnimproved[eResource] then
				if sStrategicsOrLuxuries ~= "" then
					sStrategicsOrLuxuries = sStrategicsOrLuxuries .. ", "
				end

				sStrategicsOrLuxuries = sStrategicsOrLuxuries .. resource.IconString .. " " .. g_sColorCSResource .. "?[ENDCOLOR]"
			end
		end
	end

	return sStrategicsOrLuxuries
end

-- subfunction
function GetCsResourceCount(pCs, pResource)
	local eResource = pResource.ID
	
	return pCs:GetNumResourceTotal(eResource, false) + pCs:GetResourceExport(eResource)
end

-- it's a City State being founded, so we may now have Mercantile luxuries
function OnCityCreated(hexPos, ePlayer)
	if (ePlayer >= GameDefines.MAX_MAJOR_CIVS) then
		GetCsLuxuriesAndStrategics()
	end
end
Events.SerialEventCityCreated.Add(OnCityCreated)

---------------
-- callbacks --
---------------
function OnCivSelected(ePlayer)
	if (Players[ePlayer]:IsHuman()) then
		Events.OpenPlayerDealScreenEvent(ePlayer)
	else
		UI.SetRepeatActionPlayer(ePlayer)
		UI.ChangeStartDiploRepeatCount(1)
		Players[ePlayer]:DoBeginDiploWithHuman()
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
--------------------------------------------------------------
--------------------------------------------------------------
print("Loaded DiploTradeStatus.lua from TOfVP");
--------------------------------------------------------------
--------------------------------------------------------------