InterfaceAutomator = LibStub("AceAddon-3.0"):NewAddon("InterfaceAutomator", "AceEvent-3.0", "AceHook-3.0")

function deepcopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[deepcopy(orig_key, copies)] = deepcopy(orig_value, copies)
            end
            setmetatable(copy, deepcopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-------------------------------------------------------------------------------
-- Objects
-------------------------------------------------------------------------------
Trigger = {
    type = "toggle",
    value = 0
}

function Trigger:New(t)
    t = t or deepcopy(Trigger)
    setmetatable(t, self)
    self.__index = self
    return t
end

Event = {
    subscribed = false,
    type = "toggle",
    value = 0,
    cvar = "",
    Execute = function()
    end,
    -- Optional args
    min = 0, 
    max = 100, 
    step = 5
}

function Event:New(t)
    t = t or deepcopy(Event)
    setmetatable(t, self)
    self.__index = self
    return t
end

Filter = {
    enabled = false,
    priority = 0,
    triggers = {
        ["In World"] = Trigger:New(),
        ["In Instance"]  = Trigger:New(),
        ["In Garrison"]  = Trigger:New(),
        ["In Zone"]  = Trigger:New({type = "input", value = ""})
    },
    events = {
        ["Show Friendly Nameplates"]  = Event:New({subscribed = false, type = "toggle", value = 0, cvar = "nameplateShowFriends"}),
        ["Show Enemy Nameplates"]  = Event:New({subscribed = false, type = "toggle", value = 0, cvar ="nameplateShowEnemies"}),
        ["Nameplate Max Distance"]  = Event:New({subscribed = false, type = "range",  value = 0, min = 0, max = 100, step = 5, cvar = "nameplateMaxDistance"})
    }
}

function Filter:New(t)
    t = t or deepcopy(Filter)
    setmetatable(t, self)
    self.__index = self
    return t
end

-------------------------------------------------------------------------------
-- Local variables
-------------------------------------------------------------------------------
local defaults_settings = {
    profile = {
        printdebug = false,
        filternames = {},
        filters = {},
        selected_filter = nil,
        currentGameState = {
            zone = "",
            subzone = "",
            inInstance = false,
            inGarrison = false;
        }
    }
}

local garrisonBuildings = {
    ["Alchemy Lab"] = true,
    ["Barn"] = true,
    ["Barracks"] = true,
    ["Dwarven Bunker"] = true,
    ["Enchanter's Study"] = true,
    ["Engineering Works"] = true,
    ["Fishing Shack"] = true,
    ["Frostwall Tavern"] = true,
    ["Gem Boutique"] = true,
    ["Gladiator's Sanctum"] = true,
    ["Gnomish Gearworks"] = true,
    ["Goblin Workshop"] = true,
    ["Herb Garden"] = true,
    ["Lumber Mill"] = true,
    ["Lunarfall Excavation"] = true,
    ["Lunarfall Inn"] = true,
    ["Mage Tower"] = true,
    ["Menagerie"] = true,
    ["Salvage Yard"] = true,
    ["Scribe's Quarters"] = true,
    ["Spirit Lodge"] = true,
    ["Stables"] = true,
    ["Storehouse"] = true,
    ["Tailoring Emporium"] = true,
    ["The Forge"] = true,
    ["The Tannery"] = true,
    ["Town Hall"] = true,
    ["Trading Post"] = true,
    ["War Mill"] = true
}

local Addon = nil

-------------------------------------------------------------------------------
-- Local functions.
-------------------------------------------------------------------------------
local function Print(msg, r, g, b)
    if InterfaceAutomator.db.profile.printdebug == true then
	    -- Add the message to the default chat frame.
        DEFAULT_CHAT_FRAME:AddMessage("|cff7649a3Interface Automator: " .. tostring(msg) .. "|r", r, g, b)
    end
end


-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------
function InterfaceAutomator:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("InterfaceAutomatorDB", defaults_settings, true)
	self.settings = self.db.profile

	self:SetupOptions()

   LibStub("AceConfigDialog-3.0"):AddToBlizOptions("InterfaceAutomator", "InterfaceAutomator")

    -- Create a frame to receive events.
    InterfaceAutomator.eventFrame = CreateFrame("Frame", "InterfaceAutomatorEvents", UIParent)
    InterfaceAutomator.eventFrame:SetPoint("BOTTOM")
    InterfaceAutomator.eventFrame:SetWidth(0.0001)
    InterfaceAutomator.eventFrame:SetHeight(0.0001)
    InterfaceAutomator.eventFrame:Hide()
    InterfaceAutomator.eventFrame:SetScript("OnEvent", InterfaceAutomator.OnEvent)

    -- Register events for when the mod is loaded and variables are loaded.
    InterfaceAutomator.eventFrame:RegisterEvent("ADDON_LOADED")
    InterfaceAutomator.eventFrame:RegisterEvent("VARIABLES_LOADED")
    InterfaceAutomator.eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    InterfaceAutomator.eventFrame:RegisterEvent("ZONE_CHANGED")
    InterfaceAutomator.eventFrame:RegisterEvent("ZONE_CHANGED_INDOORS")

    Addon = self
    Print("Addon initialized!")
end

function InterfaceAutomator:SetupOptions()
	self.options = {
		name = "Interface Automator",
		descStyle = "inline",
		type = "group",
		childGroups = "tab",
		args = {
			desc = {
				type = "description",
				name = "An event based automator for CVars and other interface settings.",
				fontSize = "medium",
				order = 1
			},
			author = {
				type = "description",
				name = "\n|cff7649a3Author: |r Ike Johnston",
				order = 2
			},
			version = {
				type = "description",
				name = "|cff7649a3Version: |r" .. GetAddOnMetadata("InterfaceAutomator", "Version") .."\n",
				order = 3
            },
			printdebug = {
                name = "Print Debug Messages",
                desc = "|cffaaaaaaPrint addon debug messages to chat. |r",
                descStyle = "inline",
                width = "full",
                type = "toggle",
                order = 4,
                set = function(info, val)
                    self.settings.printdebug = val
                end,
                get = function(info) return self.settings.printdebug end
            },
            filterselector = {
                name = "Filter",
                type = "select",
				style = "dropdown",
				values = function()
                    return self.settings.filternames
                end,
				order = 5,
				set = function(info, val)
                    self.settings.selected_filter = val
                    Print("Selected filter " .. val)
				end,
				get = function(info)
					return self.settings.selected_filter
                end,
                disabled = function(info)
                    numFilters = 0
                    for key, val in pairs(self.settings.filters) do
                        numFilters = numFilters + 1
                    end
                    if numFilters == 0 then
                        return true
                    end
                    return false
                end
            },
            newfilterinput = {
                order = 6,
                type = "input",
                name = "New Filter",
                desc = "Enter a name for a new filter",
                get = false,
                set = function(info, val)
                    self.settings.selected_filter = val
                    for k, v in pairs(self.settings.filternames) do
                        if k == val then
                            return
                        end
                    end
                    self.settings.filternames[val] = val
                    self.settings.filters[val] = Filter:New()
                end
            },
            deletefilterbutton = {
                order = 7,
                type = "execute",
                name = "Delete Filter",
                desc = "Delete current filter",
                func = function(info)
                    self.settings.filternames[self.settings.selected_filter] = nil
                    self.settings.filters[self.settings.selected_filter] = nil
                    self.settings.selected_filter = nil
                end,
                disabled = function(info)
                        if self.settings.selected_filter == nil then
                            return true
                        end
                        return false
                end
            },
            enabled = {
                order = 8,
                type = "toggle",
                name = "Enabled",
                set = function(info,val)
                    if self.settings.selected_filter == nil then
                        return
                    end
                    self.settings.filters[self.settings.selected_filter].enabled = val
                end,
                get = function(info)
                    if self.settings.selected_filter == nil then
                        return false
                    end
                    return self.settings.filters[self.settings.selected_filter].enabled
                end,
                disabled = function(info)
                    if self.settings.selected_filter == nil then
                        return true
                    end
                    return false
                end
            },
            priority = {
                order = 9,
                type = "range",
                min = 0,
                max = 1000,
                step = 1,
                name = "Priority",
                set = function(info,val)
                    if self.settings.selected_filter == nil then
                        return
                    end
                    self.settings.filters[self.settings.selected_filter].priority = val
                end,
                get = function(info)
                    if self.settings.selected_filter == nil then
                        return false
                    end
                    return self.settings.filters[self.settings.selected_filter].priority
                end,
                disabled = function(info)
                    if self.settings.selected_filter == nil then
                        return true
                    end
                    return false
                end
            },
            triggers = {
                type = "group",
                name = "Triggers",
                order = 10,
                inline = true,
                args = self:GenerateTriggerArgs(),
                disabled = function(info)
                    if self.settings.selected_filter == nil then
                        return true
                    end
                    return false
                end
            },
            events = {
                type = "group",
                name = "Events",
                order = 11,
                inline = true,
                args = self:GenerateEventArgs(),
                disabled = function(info)
                    if self.settings.selected_filter == nil then
                        return true
                    end
                    return false
                end
            }
		}
    }

    LibStub("AceConfig-3.0"):RegisterOptionsTable("InterfaceAutomator", self.options)
end

function InterfaceAutomator:GenerateTriggerArgs()
    local triggerArgs = {}
    local triggerOrder = 1

    for k,v in pairs(Filter.triggers) do
        local NewTriggerArg = {
            name = k,
            type = v.type,
            order = triggerOrder,
            set = function(info,val)
                if self.settings.selected_filter == nil then
                    return
                end
                self.settings.filters[self.settings.selected_filter].triggers[k].value = val
                self:UpdateUI()
            end,
            get = function(info)
                if self.settings.selected_filter == nil then
                    return false
                end
                return self.settings.filters[self.settings.selected_filter].triggers[k].value
            end,
            disabled = function(info)
                if self.settings.selected_filter == nil then
                    return true
                end
                return false
            end
        }

        triggerArgs[k] = NewTriggerArg
        triggerOrder = triggerOrder + 1
    end

    return triggerArgs
end

function InterfaceAutomator:GenerateEventArgs()
    local eventArgs = {}
    local eventOrder = 1

    for k,v in pairs(Filter.events) do
        local NewEventArg = {
            type = "group",
            name =  k,
            order = eventOrder,
            inline = true,
            args = {
                subscribed = {
                    name = "Active",
                    type = "toggle",
                    order = 1,
                    set = function(info,val)
                        if self.settings.selected_filter == nil then
                            return
                        end
                        self.settings.filters[self.settings.selected_filter].events[k].subscribed = val
                        self:UpdateUI()
                    end,
                    get = function(info)
                        if self.settings.selected_filter == nil then
                            return false
                        end
                        return self.settings.filters[self.settings.selected_filter].events[k].subscribed
                    end,
                    disabled = function(info)
                        if self.settings.selected_filter == nil then
                            return true
                        end
                        return false
                    end
                },
                value = {
                    name = "Value",
                    type = v.type,
                    order = 1,
                    set = function(info,val)
                        if self.settings.selected_filter == nil then
                            return
                        end
                        self.settings.filters[self.settings.selected_filter].events[k].value = val
                        self:UpdateUI()
                    end,
                    get = function(info)
                        if self.settings.selected_filter == nil then
                            return false
                        end
                        return self.settings.filters[self.settings.selected_filter].events[k].value
                    end,
                    disabled = function(info)
                        if self.settings.selected_filter == nil then
                            return true
                        end
                        return not self.settings.filters[self.settings.selected_filter].events[k].subscribed
                    end
                }
            }
        }

        if v.type == "range" then
            NewEventArg.args.value["min"] = v.min
            NewEventArg.args.value["max"] = v.max
            NewEventArg.args.value["step"] = v.step
        end

        eventArgs[k] = NewEventArg
        eventOrder = eventOrder + 1
    end

    return eventArgs
end

function InterfaceAutomator:UpdateUI()
    -- First sort all filters in ascending priority
    table.sort(self.settings.filters, function (a, b)
        return a.priority < b.priority
      end)

    -- Then process each filter's events in order
    for k,v in pairs(self.settings.filters) do
        filterTriggered = false

        if v.enabled == true then
            if v.triggers["In World"].value == true and Addon.settings.currentGameState.inInstance == false and Addon.settings.currentGameState.inGarrision == false then
                filterTriggered = true 
            elseif v.triggers["In Instance"].value == true and Addon.settings.currentGameState.inInstance == true then 
                filterTriggered = true 
            elseif v.triggers["In Garrison"].value == true and not Addon.settings.currentGameState.inGarrision == true then
                filterTriggered = true 
            elseif string.lower(v.triggers["In Zone"].value) == string.lower(Addon.settings.currentGameState.zone) then
                filterTriggered = true
            end
        end

        if filterTriggered == true then
            for ek,ev in pairs(v.events) do
                if ev.cvar ~= "" then
                    local cVarValue = ev.value
                    if ev.value == false then
                        cVarValue = 0
                    elseif ev.value == true then
                        cVarValue = 1
                    end
                    Print("Setting CVar " .. ev.cvar .. " to " .. cVarValue)
                    SetCVar(ev.cvar, cVarValue)
                end
                if ev.Execute ~= nil then
                    ev:Execute()
                end
            end
        end
    end

end

-------------------------------------------------------------------------------
-- Event handlers.
-------------------------------------------------------------------------------
function InterfaceAutomator.OnEvent(this, event, arg1)
	-- When an addon is loaded.
	if (event == "ADDON_LOADED") then
		-- Ignore the event if it isn't this addon.
		if (arg1 ~= "InterfaceAutomator") then return end

		-- Don't get notification for other addons being loaded.
		this:UnregisterEvent("ADDON_LOADED")

	-- Variables for all addons loaded.
	elseif (event == "VARIABLES_LOADED") then
		Print("Addon loaded!")
        collectgarbage("collect")

    elseif (event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" or event == "ZONE_CHANGED_INDOORS") then
        Addon.settings.currentGameState.zone = GetZoneText()
        Addon.settings.currentGameState.subZone = GetSubZoneText()
        Addon.settings.currentGameState.inInstance = IsInInstance()

        Addon.settings.currentGameState.inGarrison = false
        if (string.find(Addon.settings.currentGameState.subZone, "Garrison") or garrisonBuildings[zone] == true) then
            Addon.settings.currentGameState.inGarrison = true
        end 

        if(Addon.settings.currentGameState.inInstance == true) then
            Print("Is in instance")
        end
        if(Addon.settings.currentGameState.inInstance == false and Addon.settings.currentGameState.inGarrison == false) then
            Print("Is in world")
        end
        if(Addon.settings.currentGameState.inGarrison == true) then
            Print("Is in garrison")
        end

        Addon:UpdateUI()
    end
end

SLASH_INTERFACEAUTOMATOR1 = "/interfaceautomator"
SLASH_INTERFACEAUTOMATOR2 = "/ia"
SlashCmdList["INTERFACEAUTOMATOR"] = function(msg)
    InterfaceOptionsFrame_OpenToCategory("InterfaceAutomator")
    InterfaceOptionsFrame_OpenToCategory("InterfaceAutomator")
end