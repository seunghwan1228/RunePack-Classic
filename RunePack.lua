local runePowerStatusBar;
local runePowerStatusBarDark;
local runePowerStatusBarText;
local checked;

-- Initialize global variables
alphaOocParam = 1; -- Default to full opacity (global variable)

local RUNETYPEC_BLOOD  = 1;
local RUNETYPEC_FROST  = 2;
local RUNETYPEC_UNHOLY = 3;

local runeY = {
	[1] = 0,
	[2] = 0,
	[3] = 0,
	[4] = 0,
	[5] = 0,
	[6] = 0
}

local runeX = {
	[1] = 10,
	[2] = 50,
	[3] = 90,
	[4] = 130,
	[5] = 170,
	[6] = 210,
}

local runeDir = {
	[1] = 50,
	[2] = 50,
	[3] = 50,
	[4] = 50,
	[5] = 50,
	[6] = 50
}

local runeTextures = {
    [RUNETYPEC_BLOOD]  = "Interface\\AddOns\\RunePack\\textures\\blood.tga",
    [RUNETYPEC_FROST]  = "Interface\\AddOns\\RunePack\\textures\\frost.tga",
    [RUNETYPEC_UNHOLY] = "Interface\\AddOns\\RunePack\\textures\\unholy.tga"
}


-- Default settings
local defaultSettings = {
    x           = 0,
    y           = 316,
    anchor      = "CENTER",
    parent      = "UIParent",
    rel         = "CENTER",  -- Using CENTER for consistency
    scale       = 4.1,
    Locked      = true,
    HideRp      = false,
    BgOpacity   = 0,
    OocOpacity  = 0,
};

-- Function to apply position to frame from saved settings
function RunePack_SetPosition()
    -- Safety check
    if not RuneFrameC then return end
    
    -- Clear all anchor points first
    RuneFrameC:ClearAllPoints();
    
    -- Use absolute positioning relative to UIParent for maximum reliability
    RuneFrameC:SetPoint(
        "CENTER",         -- We always anchor from center point
        UIParent,        -- Always relative to screen
        "CENTER",        -- Always relative to center of screen
        RunePack_Saved.x, -- X offset from center
        RunePack_Saved.y  -- Y offset from center
    );
    
    -- For debugging
    DEFAULT_CHAT_FRAME:AddMessage(string.format("RunePack: Position applied - CENTER, UIParent, CENTER, %.1f, %.1f", 
        RunePack_Saved.x, RunePack_Saved.y));
end

-- Initialize saved variables with defaults if needed
function InitializeSavedVariables()
    if not RunePack_Saved then
        RunePack_Saved = {};
    end
    
    -- Copy default values for any missing settings
    for k, v in pairs(defaultSettings) do
        if RunePack_Saved[k] == nil then
            RunePack_Saved[k] = v;
        end
    end
end

-- Function to ensure settings are saved and provide feedback
-- silent parameter will suppress feedback messages
function RunePack_SaveSettings(silent)
    -- Ensure RunePack_Saved exists
    if not RunePack_Saved then 
        RunePack_Saved = {};
        InitializeSavedVariables();
    end
    
    -- Force the settings to be saved by adding to the session count
    -- This is a technique to ensure the saved variables system marks the data as "changed"
    if not RunePack_Saved.sessionCount then RunePack_Saved.sessionCount = 0; end
    RunePack_Saved.sessionCount = RunePack_Saved.sessionCount + 1;
    
    -- Add a timestamp to track when settings were last saved
    RunePack_Saved.lastSaved = date("%Y-%m-%d %H:%M:%S");
    
    -- Force save with FlushSavedVariables if available (newer WoW API)
    if FlushSavedVariables then
        FlushSavedVariables();
    end
    
    -- Print message to chat only if feedback is enabled and not silent mode
    if not silent and not RunePack_Saved.quietMode then
        DEFAULT_CHAT_FRAME:AddMessage("RunePack: Settings saved.");
    end
end

-- Create a frame to handle special events
local SaveFrame = CreateFrame("Frame");

-- Register important events
SaveFrame:RegisterEvent("PLAYER_LOGOUT");
SaveFrame:RegisterEvent("ADDON_LOADED");
SaveFrame:RegisterEvent("PLAYER_LEAVING_WORLD");
SaveFrame:RegisterEvent("PLAYER_ENTERING_WORLD");

-- Create a backup save timer to ensure settings are saved periodically
local saveTimer = 0;
SaveFrame:SetScript("OnUpdate", function(self, elapsed)
    saveTimer = saveTimer + elapsed;
    -- Save every 30 seconds as a backup measure
    if saveTimer > 30 then
        saveTimer = 0;
        RunePack_SaveSettings(true); -- Silent save
    end
end);

-- Initialize variables immediately
RunePack_Saved = RunePack_Saved or {};

-- Handle events
SaveFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGOUT" then
        -- Save settings when player logs out
        RunePack_SaveSettings();
    elseif event == "PLAYER_LEAVING_WORLD" then
        -- Save settings when changing zones or logging out
        RunePack_SaveSettings(true); -- Silent save
    elseif event == "ADDON_LOADED" and arg1 == "RunePack" then
        -- Initialize saved variables once our addon is loaded
        InitializeSavedVariables();
        DEFAULT_CHAT_FRAME:AddMessage("RunePack: Settings loaded.");
    end
end);

function RuneButtonC_OnLoad (self)
    RuneFrameC_AddRune(RuneFrameC, self);

    self.rune   = _G[self:GetName().."Rune"];
    self.border = _G[self:GetName().."Border"];
    self.bg     = _G[self:GetName().."BG"];

    RuneButtonC_Update(self);

    self:SetScript("OnUpdate", RuneButtonC_OnUpdate);

    self:SetFrameLevel(self:GetFrameLevel() + 2 * self:GetID());
    self.border:SetFrameLevel(self:GetFrameLevel() + 1);
end


function RuneButtonC_OnUpdate (self, elapsed)
    -- In modern WoW, we need to use the C_Rune API functions
    local runeId = self:GetID();
    
    -- Make sure each rune has its own position horizontally
    self:Show();
    
    -- Check if the rune is ready using C_Rune API
    local isRuneReady = false;
    if C_Rune and C_Rune.IsRuneReady then
        isRuneReady = C_Rune.IsRuneReady(runeId);
    end
    
    if (isRuneReady) then
        -- Rune is ready
        self:SetAlpha(1);
        self:SetPoint("TOPLEFT", RuneFrameC, "TOPLEFT", runeX[runeId], runeY[runeId]);
    else
        -- Rune is on cooldown
        local start, duration;
        
        -- First try the C_Rune API
        if C_Rune and C_Rune.GetRuneCooldown then
            start, duration = C_Rune.GetRuneCooldown(runeId);
        else
            -- Fallback to GetRuneCooldown if C_Rune API is not available
            start, duration = GetRuneCooldown(runeId);
        end
        
        -- Add debug info to chat
        -- DEFAULT_CHAT_FRAME:AddMessage("Rune " .. runeId .. " cooldown: start=" .. (start or "nil") .. ", duration=" .. (duration or "nil"));
        
        if not start or not duration or duration <= 0 then
            -- Handle edge case where cooldown data isn't available
            self:SetAlpha(1);
            self:SetPoint("TOPLEFT", RuneFrameC, "TOPLEFT", runeX[runeId], runeY[runeId]);
        else
            -- Calculate how much of the cooldown is remaining
            -- Time since start of cooldown: GetTime() - start
            -- Percentage complete: (GetTime() - start) / duration
            -- Percentage remaining: 1 - ((GetTime() - start) / duration)
            local timeElapsed = GetTime() - start;
            local remain = 1 - (timeElapsed / duration);
            
            -- Make sure remain is between 0 and 1
            remain = math.max(0, math.min(1, remain));
            
            if (remain <= 0) then
                -- Cooldown complete
                self:SetAlpha(1); 
                self:SetPoint("TOPLEFT", RuneFrameC, "TOPLEFT", runeX[runeId], runeY[runeId]);
            else
                -- Cooldown in progress - show partial alpha and animate position
                self:SetAlpha(0.5);
                -- Calculate movement based on remain percentage
                local yOffset = remain * (runeDir[runeId]);
                self:SetPoint("TOPLEFT", RuneFrameC, "TOPLEFT", runeX[runeId], runeY[runeId] + yOffset);
            end
        end
    end
end


function RuneButtonC_Update (self, rune)
    -- In modern WoW, Death Knights use a single rune type based on spec
    local currentSpec = GetSpecialization();
    local runeType;
    
    -- Map specialization index to rune type
    if currentSpec == 1 then -- Blood
        runeType = RUNETYPEC_BLOOD;
    elseif currentSpec == 2 then -- Frost
        runeType = RUNETYPEC_FROST;
    elseif currentSpec == 3 then -- Unholy
        runeType = RUNETYPEC_UNHOLY;
    else
        runeType = RUNETYPEC_BLOOD; -- Default fallback
    end
    
    self.rune:SetTexture(runeTextures[runeType]);
    self.rune:SetWidth(50);
    self.rune:SetHeight(50);
end


function RuneFrameC_OnLoad (self)
    -- Disable rune frame if not a death knight.
    local _, class = UnitClass("player");

    if (class ~= "DEATHKNIGHT") then
        self:Hide();
        DEFAULT_CHAT_FRAME:AddMessage("RunePack: Not a Death Knight, addon disabled");
        return;
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD");
    self:RegisterEvent("RUNE_POWER_UPDATE");
    self:RegisterEvent("VARIABLES_LOADED");
    self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED");
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED");
    self:RegisterEvent("PLAYER_LEAVING_WORLD"); -- Register to save settings when leaving world
    -- C_Rune.GetRuneType no longer exists, so we don't need RUNE_TYPE_UPDATE
    -- RUNE_REGEN_UPDATE is also no longer needed as we're using C_Rune API
    
    DEFAULT_CHAT_FRAME:AddMessage("RunePack activated! All options are now in the Interface Addons menu.");
    DEFAULT_CHAT_FRAME:AddMessage("Use /runepack to open the options.");

    self:SetScript("OnEvent",  RuneFrameC_OnEvent);
    self:SetScript("OnUpdate", RuneFrameC_OnUpdate);

    self.runes = {};
    
    -- Explicitly initialize all the rune frames for visibility
    for i = 1, 6 do
        local runeName = "RuneButtonIndividual" .. i .. "C";
        if _G[runeName] then
            _G[runeName]:Show();
            _G[runeName .. "Rune"]:SetTexture(runeTextures[RUNETYPEC_BLOOD]);
        end
    end

    -- just an anchor for the text at this point
    runePowerStatusBar = CreateFrame("Frame", "RpText", RuneFrameC, "BackdropTemplate");

    runePowerStatusBarText = runePowerStatusBar:CreateFontString(nil, 'OVERLAY');
    runePowerStatusBarText:ClearAllPoints();

    -- you can change the first argument to a custom font
    runePowerStatusBarText:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE");

    -- yellow
    runePowerStatusBarText:SetTextColor(1,1,0);

    runePowerStatusBarText:SetWidth(90);
    runePowerStatusBarText:SetHeight(40);
    runePowerStatusBarText:SetJustifyH("CENTER");
    runePowerStatusBarText:SetPoint("LEFT", RuneFrameC, "LEFT", -64, 10);
    
    -- IMPORTANT: Only apply saved settings AFTER they've been loaded
    -- This happens after the VARIABLES_LOADED or ADDON_LOADED event
    if RunePack_Saved and RunePack_Saved.scale then
        RuneFrameC:SetScale(RunePack_Saved.scale / 5);
        
        -- Position the frame using saved coordinates if they exist
        if RunePack_Saved.anchor and RunePack_Saved.x and RunePack_Saved.y then
            RuneFrameC:SetPoint(RunePack_Saved.anchor, RunePack_Saved.parent, RunePack_Saved.rel, RunePack_Saved.x, RunePack_Saved.y);
        end
    end
end


function RuneFrameC_OnUpdate(self)
    -- Use Enum.PowerType.RunicPower (6) for Death Knights
    local power = UnitPower("player", Enum.PowerType.RunicPower);
    if (power > 89) then
        runePowerStatusBarText:SetText(power);
        runePowerStatusBarText:SetTextColor(1,0,0); --red
    -- elseif (power > 59) then --uncomment for color change at feedback requested levels
        -- runePowerStatusBarText:SetText(power);
        -- runePowerStatusBarText:SetTextColor(0,1,1); --cyan
    elseif (power > 39) then
        runePowerStatusBarText:SetText(power);
        runePowerStatusBarText:SetTextColor(0,1,0); --green
    -- elseif (power > 19) then --uncomment for color change at feedback requested levels
        -- runePowerStatusBarText:SetText(power);
        -- runePowerStatusBarText:SetTextColor(1,.55,0); --orange
    elseif (power > 0) then
        runePowerStatusBarText:SetText(power);
        runePowerStatusBarText:SetTextColor(1,1,0); --yellow
    else
        runePowerStatusBarText:SetText(nil);
    end
    RuneFrameC_AlphaOoc_update(self)
end


function RuneFrameC_OnEvent (self, event, ...)
    -- Update all runes when player enters world, changes talents, or changes specialization
    if (event == "PLAYER_ENTERING_WORLD") or 
       (event == "ACTIVE_TALENT_GROUP_CHANGED") or 
       (event == "PLAYER_SPECIALIZATION_CHANGED") then
        for rune in next, self.runes do
            RuneButtonC_Update(self.runes[rune], rune);
        end
    elseif (event == "VARIABLES_LOADED") then
        -- Load saved settings
        InitializeSavedVariables();
        RunePackOptionsPanel_CancelOrLoad();
        
        -- Apply saved settings from saved variables
        if RunePack_Saved then
            -- Apply scale
            if RunePack_Saved.scale then
                RuneFrameC:SetScale(RunePack_Saved.scale / 5);
            end
            
                -- Apply position using our dedicated positioning function
            if RunePack_Saved.x ~= nil and RunePack_Saved.y ~= nil then
                RunePack_SetPosition();
            end
            
            -- Apply transparency settings
            if RuneFrameBack and RunePack_Saved.BgOpacity then
                RuneFrameBack:SetAlpha(RunePack_Saved.BgOpacity / 100);
            end
            
            -- Report settings were loaded
            DEFAULT_CHAT_FRAME:AddMessage("RunePack: Loaded settings from previous session.");
        end
    elseif (event == "PLAYER_LEAVING_WORLD") then
        -- Save settings when player leaves world
        RunePack_SaveSettings();
    end
end


function RuneFrameC_AddRune (runeFrameC, rune)
    tinsert(runeFrameC.runes, rune);
end


function RuneFrameC_OnDragStart()
    RuneFrameC:StartMoving();
end


function RuneFrameC_OnDragStop()
    RunePack_Saved.anchor = "CENTER";
    RunePack_Saved.parent = "UIParent";
    RunePack_Saved.rel = "BOTTOMLEFT";
    RunePack_Saved.x,RunePack_Saved.y = RuneFrameC:GetCenter();
    RuneFrameC:StopMovingOrSizing();
end

--
-- GUI Functions
--

-- This function is run on pressing the Ok or Close Buttons.
--   Sets the Status of the Saved Variables to the new settings
--
function RunePackOptionsPanel_Close()
    -- Save all settings to RunePack_Saved
    RunePack_Saved.scale      = RunePackOptions_Scale:GetValue();
    RunePack_Saved.BgOpacity  = RunePackOptions_Alpha:GetValue();
    RunePack_Saved.OocOpacity = RunePackOptions_AlphaOoc:GetValue();

    if (RunePackOptions_Locked:GetChecked() == true) then
        RunePack_Saved.Locked = true;
    else
        RunePack_Saved.Locked = false;
    end

    if (RunePackOptions_HideRp:GetChecked() == true) then
        RunePack_Saved.HideRp = true;
    else
        RunePack_Saved.HideRp = false;
    end
    
    -- Apply scale immediately
    RuneFrameC:SetScale(RunePack_Saved.scale / 5);
    RuneFrameC_AlphaOoc_update(RuneFrameC);
    
    -- Force save settings
    RunePack_SaveSettings();
    
    DEFAULT_CHAT_FRAME:AddMessage("RunePack: Settings saved.");
end


-- This function is run on pressing the Cancel Button or from the VARIABLES LOADED event function.
--   Sets the status of the Check Boxes to the Values of the Saved Variables.
--
function RunePackOptionsPanel_CancelOrLoad()
  --GUI
    RunePackOptions_Locked:SetChecked(RunePack_Saved.Locked);
    RunePackOptions_HideRp:SetChecked(RunePack_Saved.HideRp);
    RunePackOptions_Scale:SetValue(RunePack_Saved.scale);
    RunePackOptions_Alpha:SetValue(RunePack_Saved.BgOpacity);
    RunePackOptions_AlphaOoc:SetValue(RunePack_Saved.OocOpacity);

    --Addon Frames
    RuneFrameC:ClearAllPoints();
    RuneFrameC:SetPoint(RunePack_Saved.anchor, RunePack_Saved.parent, RunePack_Saved.rel, RunePack_Saved.x, RunePack_Saved.y);
    RuneFrameC:SetScale(RunePack_Saved.scale / 5);
    RuneFrameC_Locked_OnClick(RunePack_Saved.Locked);
    RuneFrameC_HideRp_OnClick(RunePack_Saved.HideRp);
    RuneFrameBack:SetAlpha(RunePack_Saved.BgOpacity / 100);
    alphaOocParam = RunePack_Saved.OocOpacity / 100;

end


-- The GUI OnLoad function.
--
function RunePackOptionsPanel_OnLoad(panel)
    -- Ensure saved variables exist
    if not RunePack_Saved then
        RunePack_Saved = {};
        InitializeSavedVariables();
    end
    
    -- Set the Text for the Check boxes.
    RunePackOptions_LockedText:SetText("Locked");
    RunePackOptions_HideRpText:SetText("Hide Runic Power");

    -- now done from VARIABLES_LOADED
    -- RunePackOptionsPanel_CancelOrLoad()

    -- Set the name for the Category for the Panel
    panel.name = "RunePack";

    -- When the player clicks okay, set the Saved Variables to the current Check Box setting
    panel.okay = function (self) RunePackOptionsPanel_Close(); end;

    -- When the player clicks cancel, set the Check Box status to the Saved Variables.
    panel.cancel = function (self) RunePackOptionsPanel_CancelOrLoad(); end
    
    -- Modern client uses Settings API
    if Settings then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "RunePack");
        Settings.RegisterAddOnCategory(category);
    else
        -- Fallback for older clients
        InterfaceOptions_AddCategory(panel);
    end
    
    -- Initialize sliders with saved values if available
    if RunePack_Saved then
        if RunePackOptions_Scale and RunePack_Saved.scale then
            RunePackOptions_Scale:SetValue(RunePack_Saved.scale);
        end
        
        if RunePackOptions_Alpha and RunePack_Saved.BgOpacity then
            RunePackOptions_Alpha:SetValue(RunePack_Saved.BgOpacity);
        end
        
        if RunePackOptions_AlphaOoc and RunePack_Saved.OocOpacity then
            RunePackOptions_AlphaOoc:SetValue(RunePack_Saved.OocOpacity);
            alphaOocParam = RunePack_Saved.OocOpacity / 100;
        end
    end
end

function RuneFrameC_Locked_OnClick(self)
    if (self == true or self == false) then
        --from saved
        checked = self;
    else
        --from ui
        if (self:GetChecked() == true) then
            checked = true;
        else
            checked = false;
        end
    end

    -- Get the correct drag button reference
    local dragButton = _G["RuneFrameC_Drag"];
    if not dragButton then
        DEFAULT_CHAT_FRAME:AddMessage("RunePack: Can't find drag button!");
        return;
    end

    if (checked) then
        -- Locked state
        RunePack_Saved.Locked = true;
        dragButton:Hide();
        RuneFrameC:EnableMouse(false);
        DEFAULT_CHAT_FRAME:AddMessage("RunePack locked.");
    else
        -- Unlocked state
        RunePack_Saved.Locked = false;
        dragButton:Show();
        RuneFrameC:EnableMouse(true);
        RuneFrameC:RegisterForDrag("LeftButton");
        DEFAULT_CHAT_FRAME:AddMessage("RunePack unlocked. Click and drag anywhere on the frame to move it.");
    end
end

function RuneFrameC_HideRp_OnClick(self)
    if (self == true or self == false) then
        --from saved
        checked = self;
    else
        --from ui
        if (self:GetChecked() == true) then
            checked = true;
        else
            checked = false;
        end
    end

    if (checked) then
        RpText:Hide();
        DEFAULT_CHAT_FRAME:AddMessage("Runic power hidden.");
    else
        RpText:Show();
        DEFAULT_CHAT_FRAME:AddMessage("Runic power shown.");
    end
end

function RuneFrameC_Scale_OnValueChanged(self)
    local scaleParam = self:GetValue() / 5;
    RuneFrameC:SetScale(scaleParam);
    
    -- Save the scale value immediately, with nil check
    if RunePack_Saved then
        RunePack_Saved.scale = self:GetValue();
        -- Force settings to save
        RunePack_SaveSettings();
    end
end

function RuneFrameBack_Alpha_OnValueChanged(self)
    local alphaParam = self:GetValue() / 100;
    RuneFrameBack:SetAlpha(alphaParam);
    
    -- Save the opacity value immediately, with nil check
    if RunePack_Saved then
        RunePack_Saved.BgOpacity = self:GetValue();
        -- Force settings to save
        RunePack_SaveSettings();
    end
end

function RuneFrameC_AlphaOoc_value(self)
    -- Initialize alphaOocParam if this is called during options panel creation
    if not self:GetValue() then return end
    
    -- Set the out-of-combat opacity value
    alphaOocParam = self:GetValue() / 100;
    
    -- Apply to frame immediately if it exists
    if RuneFrameC and not UnitAffectingCombat("player") then
        RuneFrameC:SetAlpha(alphaOocParam);
    end
    
    -- Save the out-of-combat opacity value immediately, with nil check
    if RunePack_Saved then
        RunePack_Saved.OocOpacity = self:GetValue();
        -- Force settings to save
        RunePack_SaveSettings();
    end
end

function RuneFrameC_AlphaOoc_update(frame)
    local inCombat = UnitAffectingCombat("player");
    if (inCombat == true) then
        frame:SetAlpha(1);
    else
        frame:SetAlpha(alphaOocParam);
    end
end

SLASH_RUNEPACK1 = "/RunePack";
SLASH_RUNEPACK2 = "/Runepack";
SLASH_RUNEPACK3 = "/runepack";

SlashCmdList["RUNEPACK"] = RunePack_SlashCommand;

function RunePack_SlashCommand()
    -- In modern WoW, use the Settings API
    if Settings then
        Settings.OpenToCategory(Settings.GetCategory("RunePack"));
    elseif InterfaceOptionsFrame_OpenToCategory then
        -- Fallback for pre-Dragonflight clients
        InterfaceOptionsFrame_OpenToCategory("RunePack");
        InterfaceOptionsFrame_OpenToCategory("RunePack"); -- Call twice for Blizzard's buggy implementation
    else
        -- Fallback message if neither API is available
        DEFAULT_CHAT_FRAME:AddMessage("RunePack: To access options, open Game Menu > Interface > AddOns > RunePack");
    end
end
