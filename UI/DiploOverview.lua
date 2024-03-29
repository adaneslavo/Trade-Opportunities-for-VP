print("This is the modded DiploOverview from 'UI - Trade Opportunities'")

include( "IconSupport" )
-------------------------------------------------
-- Diplomatic
-------------------------------------------------
local m_CurrentPanel = Controls.GraphPanel
local m_PopupInfo = nil

-------------------------------------------------
-- On Popup
-------------------------------------------------
function OnPopup(popupInfo)
	if popupInfo.Type == ButtonPopupTypes.BUTTONPOPUP_DIPLOMATIC_OVERVIEW then
		m_PopupInfo = popupInfo
		
		if m_PopupInfo.Data1 == 1 then
        	if ContextPtr:IsHidden() == false then
        	    OnClose()
            else
            	UIManager:QueuePopup(ContextPtr, PopupPriority.InGameUtmost)
        	end
    	else
        	UIManager:QueuePopup(ContextPtr, PopupPriority.DiploOverview)
    	end
	end
end
Events.SerialEventGameMessagePopup.Add(OnPopup)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnGraph()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(false)
	Controls.RelationsSelectHighlight:SetHide(true)
	Controls.GlobalSelectHighlight:SetHide(true)
	Controls.TradesSelectHighlight:SetHide(true)
	Controls.CityStatesSelectHighlight:SetHide(true)
	Controls.DealsSelectHighlight:SetHide(true)
	
	-- Set Panels
    Controls.GraphPanel:SetHide(false)
    Controls.RelationsPanel:SetHide(true)
    Controls.GlobalPanel:SetHide(true)
    Controls.TradesPanel:SetHide(true)
    Controls.CityStatesPanel:SetHide(true)
    Controls.DealsPanel:SetHide(true)
    
	m_CurrentPanel = Controls.GraphPanel
end
Controls.GraphButton:RegisterCallback(Mouse.eLClick, OnGraph)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnRelations()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(true)
	Controls.RelationsSelectHighlight:SetHide(false)
	Controls.GlobalSelectHighlight:SetHide(true)
	Controls.TradesSelectHighlight:SetHide(true)
	Controls.CityStatesSelectHighlight:SetHide(true)
	Controls.DealsSelectHighlight:SetHide(true)
	
	-- Set Panels
    Controls.GraphPanel:SetHide(true)
    Controls.RelationsPanel:SetHide(false)
    Controls.GlobalPanel:SetHide(true)
    Controls.TradesPanel:SetHide(true)
    Controls.CityStatesPanel:SetHide(true)
    Controls.DealsPanel:SetHide(true)
    
	m_CurrentPanel = Controls.RelationsPanel
end
Controls.RelationsButton:RegisterCallback(Mouse.eLClick, OnRelations)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnGlobal()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(true)
	Controls.RelationsSelectHighlight:SetHide(true)
	Controls.GlobalSelectHighlight:SetHide(false)
	Controls.TradesSelectHighlight:SetHide(true)
	Controls.CityStatesSelectHighlight:SetHide(true)
	Controls.DealsSelectHighlight:SetHide(true)
	
	-- Set Panels
    Controls.GraphPanel:SetHide(true)
    Controls.RelationsPanel:SetHide(true)
    Controls.GlobalPanel:SetHide(false)
    Controls.TradesPanel:SetHide(true)
    Controls.CityStatesPanel:SetHide(true)
    Controls.DealsPanel:SetHide(true)
    
	m_CurrentPanel = Controls.GlobalPanel
end
Controls.GlobalPoliticsButton:RegisterCallback(Mouse.eLClick, OnGlobal)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnTrades()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(true)
	Controls.RelationsSelectHighlight:SetHide(true)
	Controls.GlobalSelectHighlight:SetHide(true)
	Controls.TradesSelectHighlight:SetHide(false)
	Controls.CityStatesSelectHighlight:SetHide(true)
	Controls.DealsSelectHighlight:SetHide(true)
	
	-- Set Panels
    Controls.GraphPanel:SetHide(true)
    Controls.RelationsPanel:SetHide(true)
    Controls.GlobalPanel:SetHide(true)
    Controls.TradesPanel:SetHide(false)
    Controls.CityStatesPanel:SetHide(true)
    Controls.DealsPanel:SetHide(true)
    
	m_CurrentPanel = Controls.TradesPanel
end
Controls.TradesButton:RegisterCallback(Mouse.eLClick, OnTrades)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnCityStates()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(true)
	Controls.RelationsSelectHighlight:SetHide(true)
	Controls.GlobalSelectHighlight:SetHide(true)
	Controls.TradesSelectHighlight:SetHide(true)
	Controls.CityStatesSelectHighlight:SetHide(false)
	Controls.DealsSelectHighlight:SetHide(true)
	
	-- Set Panels
    Controls.GraphPanel:SetHide(true)
    Controls.RelationsPanel:SetHide(true)
    Controls.GlobalPanel:SetHide(true)
    Controls.TradesPanel:SetHide(true)
    Controls.CityStatesPanel:SetHide(false)
    Controls.DealsPanel:SetHide(true)
    
	m_CurrentPanel = Controls.CityStatesPanel
end
Controls.CityStatesButton:RegisterCallback(Mouse.eLClick, OnCityStates)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnDeals()
	-- Set Tabs
	Controls.GraphSelectHighlight:SetHide(true)
	Controls.RelationsSelectHighlight:SetHide(true)
	Controls.GlobalSelectHighlight:SetHide(true)
	Controls.TradesSelectHighlight:SetHide(true)
	Controls.CityStatesSelectHighlight:SetHide(true)
	Controls.DealsSelectHighlight:SetHide(false)
	
	-- Set Panels
	Controls.GraphPanel:SetHide(true)
    Controls.RelationsPanel:SetHide(true)
    Controls.GlobalPanel:SetHide(true)
    Controls.TradesPanel:SetHide(true)
    Controls.CityStatesPanel:SetHide(true)
    Controls.DealsPanel:SetHide(false)
    
	m_CurrentPanel = Controls.DealsPanel
end
Controls.DealsButton:RegisterCallback(Mouse.eLClick, OnDeals)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local m_AllPanels = {OnGraph, OnRelations, OnGlobal, OnTrades, OnCityStates, OnDeals}
function OnDiploCornerOpenPanel(iIndex)
	if ContextPtr:IsHidden() then
		m_AllPanels[iIndex]()
		Events.SerialEventGameMessagePopup({Type=ButtonPopupTypes.BUTTONPOPUP_DIPLOMATIC_OVERVIEW})
	end
end
LuaEvents.DiploCornerOpenPanel.Add(OnDiploCornerOpenPanel)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function OnClose()
    UIManager:DequeuePopup(ContextPtr)
end
Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose)

----------------------------------------------------------------
-- 'Active' (local human) player has changed
----------------------------------------------------------------
Events.GameplaySetActivePlayer.Add(OnClose)

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function InputHandler(uiMsg, wParam, lParam)
    if uiMsg == KeyEvents.KeyDown then
        if wParam == Keys.VK_ESCAPE or wParam == Keys.VK_RETURN then
            OnClose()
            return true
        end
    end
end
ContextPtr:SetInputHandler(InputHandler)


-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
function ShowHideHandler(bIsHide, bInitState)
	-- Set player icon at top of screen
	CivIconHookup(Game.GetActivePlayer(), 64, Controls.Icon, Controls.CivIconBG, Controls.CivIconShadow, false, true)

    if not bInitState then
        if not bIsHide then
        	UI.incTurnTimerSemaphore()
        	-- trigger the show/hide handler to update state
        	m_CurrentPanel:SetHide(false)
        	Events.SerialEventGameMessagePopupShown(m_PopupInfo)
        else
        	UI.decTurnTimerSemaphore()
        	Events.SerialEventGameMessagePopupProcessed.CallImmediate(ButtonPopupTypes.BUTTONPOPUP_DIPLOMATIC_OVERVIEW, 0)
        end
    end
end
ContextPtr:SetShowHideHandler(ShowHideHandler)

OnRelations()
