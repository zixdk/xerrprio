local _G = _G
local tinsert, tablesize, select, strfind, strsplit, tonumber = tinsert, table.getn, select, strfind, strsplit, tonumber
local gsub, strsub, strlen, sformat = string.gsub, strsub, strlen, string.format
local _, class = UnitClass('player')

-- known issues
-- if target is friendly and turns hostile, the pause doesnt go to false

xerrprio = LibStub("AceAddon-3.0"):NewAddon("xerrprio", "AceConsole-3.0", "AceEvent-3.0")
local xerrprio = xerrprio

--------------------
--- Inits
--------------------

XerrPrio = CreateFrame("Frame")
XerrPrio.Worker = CreateFrame("Frame")

XerrPrio.init = false
XerrPrio.paused = true
XerrPrio.spellBookSpells = {}
XerrPrio.hp_path = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Custom\\';
XerrPrio.hp_path_icon = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Shadow_Icon\\';

XerrPrio.bars = {
    spells = {
        swp = {
            frame = nil,
            ord = 1,
            name = '', id = 589, dps = 0, duration = 0, interval = 0,
            ticks = {}
        },
        vt = {
            frame = nil,
            ord = 2,
            name = '', id = 34914, dps = 0, duration = 0, interval = 0,
            ticks = {}
        }
    }
}
XerrPrio.icons = {
    spells = {
        swp = { name = '', id = 589, icon = '', spellBookID = 0 },
        vt = { name = '', id = 34914, icon = '', spellBookID = 0 },
        dp = { name = '', id = 2944, icon = '', spellBookID = 0 },
        mf = { name = '', id = 15407, icon = '', spellBookID = 0 },
        mb = { name = '', id = 8092, icon = '', spellBookID = 0 },
        halo = { name = '', id = 120644, icon = '', spellBookID = 0 },
        shadowfiend = { name = '', id = 34433, icon = '', spellBookID = 0 },
        swd = { name = '', id = 32379, icon = '', lastCastTime = 0, spellBookID = 0 }
    }
}

XerrPrio.buffs = {
    spells = {
        meta = {
            id = 137590, duration = 0
        },
        lightweave = {
            id = 125487, duration = 0
        },
        jade = {
            id = 104993, duration = 0
        },
        volatile = {
            id = 138703, duration = 0
        },
        hydra = {
            id = 138898, duration = 0
        },
        heroism = {
            id = 32182, duration = 0
        },
        bloodlust = {
            id = 2825, duration = 0,
        },
        timewarp = {
            id = 80353, duration = 0,
        },
        ancienthysteria = {
            id = 90355, duration = 0
        }
    }
}

XerrPrio.nextSpell = {
    [1] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' },
    [2] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' }
}

XerrPrio.lowestProcTime = 0

XerrPrio.colors = {
    whiteHex = '|cffffffff',

    hi1 = '|cffD69637',
    hi2 = '|cffC8d637',
    hi3 = '|cff37d63e',

    lo1 = '|cff37d63e',
    lo2 = '|cffC8d637',
    lo3 = '|cffD69637',

    white = { r = 1, g = 1, b = 1, a = 1 },
    swpDefault = { r = 255 / 255, g = 65 / 255, b = 9 / 255, a = 1 },
    vtDefault = { r = 60 / 255, g = 52 / 255, b = 175 / 255, a = 1 }
}

XerrPrio.dotStats = {}

XerrPrio.twistOfFateId = 123254
XerrPrio.uvlsId = 138963

--------------------
--- Events
--------------------

XerrPrio:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
XerrPrio:RegisterEvent('ADDON_LOADED')
XerrPrio:RegisterEvent('PLAYER_ENTERING_WORLD')
XerrPrio:RegisterEvent('PLAYER_TARGET_CHANGED')
XerrPrio:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
XerrPrio:RegisterEvent('PLAYER_TALENT_UPDATE')
XerrPrio:RegisterEvent('VARIABLES_LOADED')
XerrPrio:SetScript("OnEvent", function(self, event, arg1, arg2, arg3, arg4, arg5)
    if event then
        if (event == 'ADDON_LOADED' and arg1 == 'xerrprio') or event == 'PLAYER_ENTERING_WORLD' or event == 'PLAYER_TALENT_UPDATE' then
            self:Init()
            print('init')
            return
        end
        if event == 'VARIABLES_LOADED' then
            self:VarsLoaded()
        end
        if not self.init then
            return false
        end
        if event == 'UNIT_SPELLCAST_SUCCEEDED' and arg1 == 'player' and UnitGUID('target') then
            self:SpellCast(arg5)
            return
        end
        if event == 'PLAYER_TARGET_CHANGED' then
            if XerrPrioDB.configMode then
                XerrPrioBars:Show()
                XerrPrioIcons:Show()
                self.paused = false
                return
            end
            if not UnitExists('target') then
                self.paused = true
                return
            else
                if UnitReaction('player', 'target') and UnitReaction('player', 'target') >= 5 then
                    self.paused = true
                    return
                else
                    self.paused = false
                    return
                end
            end
            return
        end

    end
end)

--------------------
---  Init
--------------------

function XerrPrio:Init()

    self.init = false

    if class ~= 'PRIEST' or GetSpecialization() ~= 3 then
        XerrPrioBars:Hide()
        XerrPrioIcons:Hide()
        return false
    end

    self:PopulateSpellBookID()

    for key, spell in next, self.bars.spells do
        if spell.name == '' then
            spell.name, spell.icon = self:GetSpellInfo(spell.id)
            local frameName = 'XerrPrioBar_' .. key

            if not spell.frame then
                spell.frame = CreateFrame('Frame', frameName, XerrPrioBars, 'XerrPrioBarFrameTemplate')
            end

            _G[frameName]:SetPoint("TOPLEFT", XerrPrioBars, "TOPLEFT", 0, -50 + spell.ord * 25)
            _G[frameName .. 'Name']:SetText(spell.name)
            _G[frameName .. 'Icon']:SetTexture(spell.icon)
        end
    end

    for _, spell in next, self.icons.spells do
        if spell.name == '' then
            spell.name, spell.icon = self:GetSpellInfo(spell.id)
        end
    end

    self.icons.spells.swd.lastCastTime = GetTime()

    XerrPrioDB = {
        configMode = false,
        bars = true,
        icons = true,
        swp = {
            enabled = true,
            barColor = self.colors.swpDefault,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            showIcon = true,
            showTicks = true,
            showOnlyLastTick = true,
            tickWidth = 1,
            tickColor = { r = 0, g = 0, b = 0, a = 1 },
            refreshTextColor = { r = 1, g = 1, b = 1, a = 1 },
            refreshBarColor = { r = 0, g = 1, b = 0, a = 1 }
        },
        vt = {
            enabled = true,
            barColor = self.colors.vtDefault,
            textColor = { r = 1, g = 1, b = 1, a = 1 },
            showIcon = true,
            showTicks = true,
            showOnlyLastTick = true,
            tickWidth = 1,
            tickColor = { r = 0, g = 0, b = 0, a = 1 },
            refreshTextColor = { r = 1, g = 1, b = 1, a = 1 },
            refreshBarColor = { r = 0, g = 1, b = 0, a = 1 }
        },
        barWidth = 280,
        refreshMinDuration = 5,
        minDotDpsIncrease = 1
    }

    self:UpdateConfig()

    self.init = true

    XerrPrio.Worker:Show()

end

function XerrPrio:VarsLoaded()
    LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("xerrprio", self:CreateOptions())
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("xerrprio", "xerrprio")
end

--------------------
---  Timers
--------------------

--------------------
--- Worker
--------------------

XerrPrio.Worker:Hide()
XerrPrio.Worker.start = GetTime()
XerrPrio.Worker.dotScanner = {
    spellId = 0,
    enabled = false
}
XerrPrio.Worker.bars = {
    enabled = true,
    show = false
}
XerrPrio.Worker.icons = {
    enabled = true
}

XerrPrio.Worker:SetScript("OnShow", function(self)
    self.start = GetTime()
    self.timeSinceLastUpdate = 0;
end)

XerrPrio.Worker:SetScript("OnUpdate", function(self, elapsed)

    self.timeSinceLastUpdate = self.timeSinceLastUpdate + elapsed;

    if self.timeSinceLastUpdate >= 0.05 then
        self.timeSinceLastUpdate = 0;

        self.dotScanner.enabled = not XerrPrio.paused and not XerrPrioDB.configMode and (XerrPrioDB.bars or XerrPrioDB.icons)
        self.bars.enabled = not XerrPrio.paused and XerrPrioDB.bars and not XerrPrioDB.configMode
        self.icons.enabled = not XerrPrio.paused and XerrPrioDB.icons and not XerrPrioDB.configMode

        if XerrPrioDB.configMode or XerrPrio.paused then
            XerrPrio.nextSpell = {
                [1] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' },
                [2] = { id = 0, icon = 'Interface\\Icons\\INV_Misc_QuestionMark' }
            }
            XerrPrioIconsIcon:SetTexture(XerrPrio.nextSpell[1].icon)
            XerrPrioIconsIcon2:SetTexture(XerrPrio.nextSpell[2].icon)

            if XerrPrio.paused then
                XerrPrioBars:Hide()
                XerrPrioIcons:Hide()
            end

            return
        end

        -- Dots Scanner
        -- Scans debuffs for dot duration and interval

        if self.dotScanner.enabled then
            for i = 1, 40 do
                local _, _, _, _, _, duration, _, unitCaster, _, _, spellId = UnitDebuff('target', i)
                if spellId == self.dotScanner.spellId and unitCaster == "player" then
                    XerrPrioTooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
                    XerrPrioTooltipFrame:SetUnitDebuff("target", i)

                    local tooltipDescription = XerrPrioTooltipFrameTextLeft2:GetText()

                    local _, _, interval = strfind(tooltipDescription, "every (%S+) sec")

                    if spellId == XerrPrio.icons.spells.swp.id then
                        XerrPrio.bars.spells.swp.duration = duration
                        XerrPrio.bars.spells.swp.interval = interval
                        self.dotScanner.enabled = false
                    end
                    if spellId == XerrPrio.icons.spells.vt.id then
                        XerrPrio.bars.spells.vt.duration = duration
                        XerrPrio.bars.spells.vt.interval = interval
                        self.dotScanner.enabled = false
                    end

                    break
                end
            end
        end

        -- Bars
        if self.bars.enabled then

            for key, spell in next, XerrPrio.bars.spells do
                local tl, perc, duration = XerrPrio:GetDebuffInfo(spell.id)
                local frame = spell.frame:GetName()
                if tl > 0 then

                    self.show = true

                    local tof, uvls = XerrPrio:PlayerHasProc(XerrPrio.twistOfFateId), XerrPrio:PlayerHasProc(XerrPrio.uvlsId)
                    local guid = UnitGUID('target')

                    if XerrPrio.dotStats[guid] and XerrPrio.dotStats[guid][key] then

                        local current_dps, current_damage = XerrPrio:GetSpellDamage(spell.id)

                        XerrPrio.lowestProcTime = XerrPrio:GetLowestProcTime()

                        if current_dps >= XerrPrio.dotStats[guid][key].dps * (1 + XerrPrioDB.minDotDpsIncrease / 100) then
                            _G[frame .. 'Refresh']:SetText('Refresh ' .. string.format("%.2f", current_dps / XerrPrio.dotStats[guid][key].dps) .. 'x')

                            if XerrPrio.lowestProcTime ~= 0 then

                                local color = XerrPrioDB[key].refreshBarColor
                                if XerrPrio.lowestProcTime > XerrPrioDB.refreshMinDuration then
                                    _G[frame .. 'RefreshDuration']:SetVertexColor(1, 1, 1, 0.2)
                                else
                                    _G[frame .. 'RefreshDuration']:SetVertexColor(color.r, color.g, color.b, color.a)
                                end

                                _G[frame .. 'RefreshDuration']:SetWidth(XerrPrioDB.barWidth * (XerrPrio.lowestProcTime / duration))
                                _G[frame .. 'RefreshDurationSpark']:SetPoint('LEFT', _G[frame], 'LEFT', _G[frame .. 'RefreshDuration']:GetWidth() - 8, 0)
                                _G[frame .. 'RefreshDurationSpark']:Show()
                                _G[frame .. 'RefreshDuration']:Show()

                            end

                        else
                            _G[frame .. 'Refresh']:SetText(sformat('%.1f', tl))
                            _G[frame .. 'RefreshDurationSpark']:Hide()
                            _G[frame .. 'RefreshDuration']:Hide()
                        end

                        if tof then
                            _G[frame .. 'ToF']:SetText('ToF')
                            _G[frame .. 'ToF']:SetTextColor(XerrPrio.dotStats[guid][key].tof and 0 or 1, XerrPrio.dotStats[guid][key].tof and 1 or 0, 0)
                        else
                            if XerrPrio.dotStats[guid][key].tof then
                                _G[frame .. 'ToF']:SetText('ToF')
                                _G[frame .. 'ToF']:SetTextColor(0, 1, 0)
                            else
                                _G[frame .. 'ToF']:SetText('')
                            end
                        end

                        if uvls then
                            _G[frame .. 'UVLS']:SetText('UVLS')
                            _G[frame .. 'UVLS']:SetTextColor(XerrPrio.dotStats[guid][key].uvls and 0 or 1, XerrPrio.dotStats[guid][key].uvls and 1 or 0, 0)
                        else
                            if XerrPrio.dotStats[guid][key].uvls then
                                _G[frame .. 'UVLS']:SetText('UVLS')
                                _G[frame .. 'UVLS']:SetTextColor(0, 1, 0)
                            else
                                _G[frame .. 'UVLS']:SetText('')
                            end
                        end

                    end

                    _G[frame .. 'Duration']:SetWidth(XerrPrioDB.barWidth * perc)
                    _G[frame .. 'Background']:SetWidth(XerrPrioDB.barWidth * perc)
                    _G[frame .. 'Spark']:SetPoint('LEFT', _G[frame], 'LEFT', _G[frame .. 'Duration']:GetWidth() - 8, 0)
                    _G[frame .. 'TimeLeft']:SetText(math.floor(tl))

                    for i = 1, #spell.ticks do
                        spell.ticks[i]:Hide()
                    end
                    if XerrPrioDB[key].showTicks then
                        local ticks = math.floor(spell.duration / spell.interval)
                        local numTicks = XerrPrioDB[key].showOnlyLastTick and 1 or ticks
                        if ticks > 0 then
                            for i = 1, numTicks do
                                if not spell.ticks[i] then
                                    spell.ticks[i] = CreateFrame("Frame", "XerrPrio_" .. key .. "_BarTicks_" .. i, _G[frame], "XerrPrioBarTickTemplate")
                                end
                                spell.ticks[i]:SetPoint("TOPLEFT", _G[frame], "TOPLEFT", XerrPrioDB.barWidth * i * spell.interval / spell.duration, 0)
                                _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetVertexColor(0, 0, 0, 1)
                                local tickColor = XerrPrioDB[key].tickColor
                                _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetVertexColor(tickColor.r, tickColor.g, tickColor.b, tickColor.a)
                                _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetWidth(XerrPrioDB[key].tickWidth)
                                spell.ticks[i]:Show()
                            end
                        end
                    end

                    _G[frame]:Show()
                else
                    _G[frame]:Hide()
                end
            end

            if self.show then
                XerrPrioBars:Show()
            else
                XerrPrioBars:Hide()
            end
        end

        -- Icons
        XerrPrio.nextSpell = XerrPrio:GetNextSpell()
        if self.icons.enabled then
            XerrPrioIconsIcon:SetTexture(XerrPrio.nextSpell[1].icon)
            XerrPrioIconsIcon2:SetTexture(XerrPrio.nextSpell[2].icon)
            XerrPrioIcons:Show()
        end
    end

end)

--------------------
--- Helpers
--------------------

function XerrPrio:SpellCast(id)

    local guid = UnitGUID('target')

    for key, spell in next, self.bars.spells do
        if id == spell.id then

            if not self.dotStats[guid] then
                self.dotStats[guid] = {}
            end

            if not self.dotStats[guid][key] then
                self.dotStats[guid][key] = {
                    tof = false,
                    uvls = false,
                    dps = 0,
                    damage = 0
                }
            end

            self.dotStats[guid][key].tof = self:PlayerHasProc(self.twistOfFateId)
            self.dotStats[guid][key].uvls = self:PlayerHasProc(self.uvlsId)

            self.dotStats[guid][key].dps, XerrPrio.dotStats[guid][key].damage = self:GetSpellDamage(spell.id)

            XerrPrio.Worker.dotScanner.spellId = id
            XerrPrio.Worker.dotScanner.enabled = true

            return
        end
    end

    if id == self.icons.spells.swd.id then
        self.icons.spells.swd.lastCastTime = GetTime()
    end
end

function XerrPrio:GetSpellInfo(id)
    local name, _, icon, _, _, _, castTime = GetSpellInfo(id)
    return name, icon, castTime / 1000
end

function XerrPrio:GetLowestProcTime()

    local lowestTime = 100

    for i = 1, 40 do
        for _, spell in next, self.buffs.spells do
            local name, _, _, _, _, _, expirationTime, _, _, _, spellId = UnitBuff("player", i)
            if name then
                if spellId == spell.id then
                    if expirationTime - GetTime() < lowestTime then
                        lowestTime = expirationTime - GetTime()
                    end
                end
            end
        end
    end

    if lowestTime > 0 and lowestTime ~= 100 then
        return lowestTime
    end
    return 0
end

function XerrPrio:GetDebuffInfo(id)
    if not UnitExists('target') then
        return 0, 0, 0
    end
    for i = 1, 40 do
        local _, _, _, _, _, duration, expirationTime, unitCaster, _, _, spellId = UnitDebuff('target', i)
        if unitCaster == "player" then
            if spellId == id then
                local tl = expirationTime - GetTime()
                local perc = tl / duration
                return expirationTime - GetTime(), perc, duration
            end
        end
    end
    return 0, 0, 0
end

function XerrPrio:PlayerHasProc(procId)
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, _, id = UnitBuff('player', i)
        if id == procId then
            return true
        end
    end
    return false
end

function XerrPrio:GetWAIconColor(spell)

    if not UnitExists('target') or self.paused then
        return 1, 1, 1, 1, false, false, false, self.hp_path_icon .. 'offcd'
    end

    local inRange = false
    local isNext = self.nextSpell[1].id == spell.id
    local isNext2 = self.nextSpell[2].id == spell.id
    local icon = 'center'

    if spell.id == self.icons.spells.halo.id then
        inRange = false
        if HaloPro_MainFrame and HaloPro_MainFrame.texture:GetTexture() then
            local hpt = HaloPro_MainFrame.texture:GetTexture()
            if hpt == self.hp_path .. 'left' then
                icon = 'left'
            elseif hpt == self.hp_path .. 'mid_left' then
                icon = 'mid_left'
            elseif hpt == self.hp_path .. 'center' then
                inRange = true
                icon = 'center'
            elseif hpt == self.hp_path .. 'mid_right' then
                icon = 'mid_right'
            elseif hpt == self.hp_path .. 'right' then
                icon = 'right'
            end
        end
    else
        inRange = IsSpellInRange(spell.spellBookID, "target") == 1
    end

    icon = self.hp_path_icon .. icon

    if inRange then
        if isNext then
            return 1, 1, 1, 1, isNext, isNext2, inRange, icon
        elseif isNext2 then
            return 1, 1, 1, 1, isNext, isNext2, inRange, icon
        else
            return 0.7, 0.7, 0.7, 1, isNext, isNext2, inRange, icon
        end
    end

    -- out of range
    return 1, 0.2, 0.2, 1, isNext, isNext2, inRange, icon
end

function XerrPrio:PopulateSpellBookID()
    self.spellBookSpells = {}

    local i = 1
    while true do
        local spellName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not spellName then
            do
                break
            end
        end
        self.spellBookSpells[spellName] = i
        i = i + 1
    end

    for _, spell in next, self.icons.spells do
        spell.spellBookID = self.spellBookSpells[spell.name] or false
    end
end

function XerrPrio:GetNextSpell()

    local prio = {}

    local guid = UnitGUID('target')
    -- refresh dots if uvls procd
    if self:PlayerHasProc(self.uvlsId) and self.dotStats[guid] then
        if self.dotStats[guid].swp and not self.dotStats[guid].swp.uvls then
            tinsert(prio, self.icons.spells.swp)
        end
        if self.dotStats[guid].vt and not self.dotStats[guid].vt.uvls then
            tinsert(prio, self.icons.spells.vt)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- refresh swp or vt, only if mindblast is on cd and we dont have dp up
    if self:GetSpellCooldown(self.icons.spells.mb.id) > 1.5 and self:GetDebuffInfo(self.icons.spells.dp.id) == 0 then

        if self.dotStats[guid] then
            if self.dotStats[guid].swp then
                if self:GetSpellDamage(self.icons.spells.swp.id) >= self.dotStats[guid].swp.dps * (1 + XerrPrioDB.minDotDpsIncrease / 100) then
                    if self.lowestProcTime > 0 and self.lowestProcTime <= XerrPrioDB.refreshMinDuration then
                        tinsert(prio, self.icons.spells.swp)
                    end
                end
            end
            if self.dotStats[guid].vt then
                if self:GetSpellDamage(self.icons.spells.vt.id) >= self.dotStats[guid].vt.dps * (1 + XerrPrioDB.minDotDpsIncrease / 100) then
                    if self.lowestProcTime > 0 and self.lowestProcTime <= XerrPrioDB.refreshMinDuration then
                        tinsert(prio, self.icons.spells.vt)
                    end
                end
            end
        end

    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- halo when offcooldown and no dp
    if self.icons.spells.halo.spellBookID and self:GetSpellCooldown(self.icons.spells.halo.id) == 0 then
        if self:GetDebuffInfo(self.icons.spells.dp.id) == 0 then
            tinsert(prio, self.icons.spells.halo)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- devouring plague if 3 orbs
    if self:GetShadowOrbs() == 3 then
        tinsert(prio, self.icons.spells.dp)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- mindblast and dp after if we'll have 3 orbs after mindblast
    if self:GetSpellCooldown(self.icons.spells.mb.id) <= self:GetGCD() then
        tinsert(prio, self.icons.spells.mb)
        if self:GetShadowOrbs() == 2 then
            tinsert(prio, self.icons.spells.dp)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- shadow word: death
    if self:ExecutePhase() and self:GetSpellCooldown(self.icons.spells.swd.id) == 0 then
        if self:GetDebuffInfo(self.icons.spells.dp.id) >= 0.2 then
            if GetTime() - self.icons.spells.swd.lastCastTime >= 8 then
                tinsert(prio, self.icons.spells.swd)
            elseif self:GetSpellCooldown(self.icons.spells.mb.id) == 0 then
                tinsert(prio, self.icons.spells.mb)
                if self:GetShadowOrbs() == 2 then
                    tinsert(prio, self.icons.spells.dp)
                end
            else
                tinsert(prio, self.icons.spells.mf)
            end
        else
            tinsert(prio, self.icons.spells.swd)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- insanity
    if self:GetDebuffInfo(self.icons.spells.dp.id) > 0 then
        tinsert(prio, self.icons.spells.mf)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- shadowfiend
    if self:GetSpellCooldown(self.icons.spells.shadowfiend.id) == 0 then
        tinsert(prio, self.icons.spells.shadowfiend)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- swp
    if self:GetDebuffInfo(self.icons.spells.swp.id) < 0.5 then
        tinsert(prio, self.icons.spells.swp)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- vt
    if self:GetDebuffInfo(self.icons.spells.vt.id) >= 0 then
        if self:GetDebuffInfo(self.icons.spells.vt.id) < select(3, self:GetSpellInfo(self.icons.spells.vt.id)) then
            tinsert(prio, self.icons.spells.vt)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind flay if nothing else is available
    tinsert(prio, self.icons.spells.mf)

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind blast 2nd if cd <= 1s
    if prio[1] and prio[1].id ~= self.icons.spells.mb.id and self:GetSpellCooldown(self.icons.spells.mb.id) <= 1 then
        if prio[2] and prio[2].id ~= self.icons.spells.dp.id then
            prio[2] = self.icons.spells.mb
        end
    end

    -- if we dont have a 2nd spell by now add mb if cooldown shorter than halo cd
    -- else add mf
    if tablesize(prio) == 1 then
        if self:GetSpellCooldown(self.icons.spells.mb.id) < self:GetSpellCooldown(self.icons.spells.halo.id) then
            tinsert(prio, self.icons.spells.mb)
        end
        tinsert(prio, self.icons.spells.mf)
    end

    return prio
end

function XerrPrio:TimeSinceLastSWD()
    local t = GetTime() - self.icons.spells.swd.lastCastTime
    local icd = 8 - t
    if icd > 0 and self:GetSpellCooldown(self.icons.spells.swd.id) == 0 then
        return 'i' .. sformat(icd > 2 and "%d" or "%.1f", icd)
    else
        local cd = self:GetSpellCooldown(self.icons.spells.swd.id)
        if cd == 0 then
            return ''
        end
        return sformat(icd > 2 and "%d" or "%.1f", cd)
    end
end

function XerrPrio:GetSpellCooldown(id)
    local start, duration, enabled = GetSpellCooldown(id);
    if enabled == 0 then
        return 0 --active, like pom
    elseif start > 0 and duration > 0 then
        if start + duration - GetTime() <= self:GetGCD() + 0.1 then
            return 0
        end
        return start + duration - GetTime()
    end
    return 0
end

function XerrPrio:GetGCD()
    local start, duration = GetSpellCooldown(61304);
    if start > 0 and duration > 0 then
        return start + duration - GetTime()
    end
    return 0
end

function XerrPrio:GetShadowOrbs()
    return UnitPower("player", SPELL_POWER_SHADOW_ORBS)
end

function XerrPrio:ExecutePhase()
    if not UnitExists('target') then
        return false
    end
    return (UnitHealth('target') * 100) / UnitHealthMax('target') <= 20
end

function XerrPrio:replace(text, search, replace)
    if search == replace then
        return text
    end
    local searchedtext = ""
    local textleft = text
    while (strfind(textleft, search, 1, true)) do
        searchedtext = searchedtext .. strsub(textleft, 1, strfind(textleft, search, 1, true) - 1) .. replace
        textleft = strsub(textleft, strfind(textleft, search, 1, true) + strlen(search))
    end
    if (strlen(textleft) > 0) then
        searchedtext = searchedtext .. textleft
    end
    return searchedtext
end

function XerrPrio:GetSpellDamage(id)

    XerrPrioTooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
    XerrPrioTooltipFrame:SetSpellByID(id);
    local tooltipDescription = XerrPrioTooltipFrameTextLeft4:GetText();
    local totalDmg, tickTime, dps = 0, 0, 0

    if strfind(tooltipDescription, "Cooldown remaining") then
        tooltipDescription = XerrPrioTooltipFrameTextLeft5:GetText()
    end

    tooltipDescription = self:replace(tooltipDescription, ',', '')

    if id == XerrPrio.icons.spells.swp.id then
        _, _, totalDmg, tickTime = strfind(tooltipDescription, "(%S+) Shadow damage over (%S+)")
    end
    if id == XerrPrio.icons.spells.vt.id then
        _, _, totalDmg, tickTime = strfind(tooltipDescription, "Causes (%S+) Shadow damage over (%S+)")
    end

    dps = tonumber(totalDmg) / tonumber(tickTime)

    return dps, totalDmg, tickTime

end

--------------------
--- Slashcommands
--------------------

SLASH_XERRPRIO1, SLASH_XERRPRIO2 = "/xerrprio", "/xprio";
function SlashCmdList.XERRPRIO(arg)

    if arg then

        if arg == 'prio' then
            XerrPrio:SetOption(arg, not XerrPrioDB[arg])
            return
        end

        if arg == 'dots' then
            XerrPrio:SetOption(arg, not XerrPrioDB[arg])
            return
        end

        if arg == 'config' then
            XerrPrio:SetOption('configMode', not XerrPrioDB['configMode'])
            return
        end
    end

    print('XerrPrio available options:')
    print('dots: ' .. (XerrPrioDB.dots and 'on' or 'off'))
    print('prio: ' .. (XerrPrioDB.prio and 'on' or 'off'))
    print('config: ' .. (XerrPrioDB.config and 'on' or 'off'))

end


--------------------
--- Options
--------------------

function XerrPrio:CreateOptions()

    return {
        type = "group",
        name = "XerrPrio Options",
        args = {
            d = {
                type = "description",
                name = "Shadow priest helper",
                order = 0,
            },
            configMode = {
                order = 1,
                name = "Config mode",
                desc = "Config mode desc",
                type = "toggle",
                width = "full",
                set = function(_, val)
                    XerrPrioDB.configMode = val
                    XerrPrio:UpdateConfig()
                end,
                get = function()
                    return XerrPrioDB.configMode
                end
            },
            general = {
                type = "group",
                name = "General",
                order = 2,
                args = {
                    procTime = {
                        order = 1,
                        type = "range",
                        name = "Dot refresh procs min duration",
                        desc = "Refresh dots based on procs like trinkets, jade spirit.",
                        min = 1,
                        max = 10,
                        step = 0.5,
                        get = function()
                            return XerrPrioDB.refreshMinDuration
                        end,
                        set = function(_, val)
                            XerrPrioDB.refreshMinDuration = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                    minDotDps = {
                        order = 1,
                        type = "range",
                        name = "Minimum dot dps increase (%)",
                        desc = "for refresh",
                        min = 1,
                        max = 100,
                        step = 1,
                        get = function()
                            return XerrPrioDB.minDotDpsIncrease
                        end,
                        set = function(_, val)
                            XerrPrioDB.minDotDpsIncrease = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                },
            },
            dotBars = {
                type = "group",
                name = "Dot Bars",
                order = 3,
                args = {
                    dotBars = {
                        order = 1,
                        name = "Enable",
                        desc = "Bars for SWP and VT",
                        type = "toggle",
                        width = "full",
                        set = function(_, val)
                            XerrPrioDB.bars = val
                            XerrPrio:UpdateConfig()
                        end,
                        get = function()
                            return XerrPrioDB.bars
                        end
                    },
                    barsWidth = {
                        order = 2,
                        type = "range",
                        name = "Bar Width",
                        desc = "Bar Width",
                        min = 260,
                        max = 360,
                        step = 1,
                        get = function()
                            return XerrPrioDB.barWidth
                        end,
                        set = function(_, val)
                            XerrPrioDB.barWidth = val
                            XerrPrio:UpdateConfig()
                        end,

                    },
                    swp = {
                        order = 3,
                        type = "group",
                        name = "Shadow Word: Pain",
                        inline = true,
                        args = {
                            enable = {
                                order = 1,
                                name = "Enable",
                                desc = "Enable SWP Bar",
                                type = "toggle",
                                width = "full",
                                set = function(_, val)
                                    XerrPrioDB.swp.enabled = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.enabled
                                end
                            },
                            icon = {
                                order = 2,
                                name = "Show Icon",
                                desc = "Show SWP Icon",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showIcon = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showIcon
                                end
                            },
                            textColor = {
                                order = 3,
                                name = "Text Color",
                                desc = "Color of the SWP Text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.textColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.textColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            barColor = {
                                order = 4,
                                name = "Bar Color",
                                desc = "Color of the SWP Bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.barColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.barColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetTextColor = {
                                order = 5,
                                name = "Reset Text Color",
                                desc = "Reset Text Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                func = function()
                                    XerrPrioDB.swp.textColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetBarColor = {
                                order = 6,
                                name = "Reset Bar Color",
                                desc = "Reset Bar Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                func = function()
                                    XerrPrioDB.swp.barColor = XerrPrio.colors.swpDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            ticks = {
                                order = 7,
                                name = "Show Ticks",
                                desc = "Show DOT ticks",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showTicks = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showTicks
                                end
                            },
                            ticksOnlyLast = {
                                order = 8,
                                name = "Only last tick",
                                desc = "Show only last tick",
                                type = "toggle",
                                disabled = function()
                                    return (not XerrPrioDB.swp.enabled and not XerrPrioDB.swp.showTicks) or not XerrPrioDB.swp.showTicks
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.showOnlyLastTick = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.swp.showOnlyLastTick
                                end
                            },
                            tickColor = {
                                order = 9,
                                name = "Tick Color",
                                desc = "Color of the SWP tick",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return (not XerrPrioDB.swp.enabled and not XerrPrioDB.swp.showTicks) or not XerrPrioDB.swp.showTicks
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.tickColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.tickColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            tickWidth = {
                                order = 10,
                                type = "range",
                                name = "Tick Width",
                                desc = "Tick Width",
                                min = 1,
                                max = 5,
                                step = 1,
                                disabled = function()
                                    return (not XerrPrioDB.swp.enabled and not XerrPrioDB.swp.showTicks) or not XerrPrioDB.swp.showTicks
                                end,
                                get = function()
                                    return XerrPrioDB.swp.tickWidth
                                end,
                                set = function(_, val)
                                    XerrPrioDB.swp.tickWidth = val
                                    XerrPrio:UpdateConfig()
                                end,

                            },
                            refreshTextColor = {
                                order = 11,
                                name = "Refresh Text Color",
                                desc = "Color of the SWP Refresh Text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.refreshTextColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.refreshTextColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            refreshBarColor = {
                                order = 12,
                                name = "Refresh Bar Color",
                                desc = "Color of the SWP Refresh Bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.swp.refreshBarColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.swp.refreshBarColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshTextColor = {
                                order = 13,
                                name = "Reset Refresh Text Color",
                                desc = "Reset Refresh Text Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                func = function()
                                    XerrPrioDB.swp.refreshTextColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshBarColor = {
                                order = 14,
                                name = "Reset Refresh Bar Color",
                                desc = "Reset Refresh Bar Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.swp.enabled
                                end,
                                func = function()
                                    XerrPrioDB.swp.refreshBarColor = XerrPrio.colors.swpDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                        }
                    },
                    vt = {
                        order = 4,
                        type = "group",
                        name = "Vampiric Embrace",
                        inline = true,
                        args = {
                            enable = {
                                order = 1,
                                name = "Enable",
                                desc = "Enable VT Bar",
                                type = "toggle",
                                width = "full",
                                set = function(_, val)
                                    XerrPrioDB.vt.enabled = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.enabled
                                end
                            },
                            icon = {
                                order = 2,
                                name = "Show Icon",
                                desc = "Show VT Icon",
                                type = "toggle",
                                width = "full",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showIcon = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showIcon
                                end
                            },
                            textColor = {
                                order = 3,
                                name = "Text Color",
                                desc = "Color of the VT Text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.textColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.textColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            barColor = {
                                order = 4,
                                name = "Bar Color",
                                desc = "Color of the VT Bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.barColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.barColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetTextColor = {
                                order = 5,
                                name = "Reset Text Color",
                                desc = "Reset Text Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                func = function()
                                    XerrPrioDB.vt.textColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetBarColor = {
                                order = 6,
                                name = "Reset Bar Color",
                                desc = "Reset Bar Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                func = function()
                                    XerrPrioDB.vt.barColor = XerrPrio.colors.vtDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            ticks = {
                                order = 7,
                                name = "Show Ticks",
                                desc = "Show DOT ticks",
                                type = "toggle",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showTicks = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showTicks
                                end
                            },
                            ticksOnlyLast = {
                                order = 8,
                                name = "Only last tick",
                                desc = "Show only last tick",
                                type = "toggle",
                                disabled = function()
                                    return (not XerrPrioDB.vt.enabled and not XerrPrioDB.vt.showTicks) or not XerrPrioDB.vt.showTicks
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.showOnlyLastTick = val
                                    XerrPrio:UpdateConfig()
                                end,
                                get = function()
                                    return XerrPrioDB.vt.showOnlyLastTick
                                end
                            },
                            tickColor = {
                                order = 9,
                                name = "Tick Color",
                                desc = "Color of the SWP tick",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return (not XerrPrioDB.vt.enabled and not XerrPrioDB.vt.showTicks) or not XerrPrioDB.vt.showTicks
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.tickColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.tickColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            tickWidth = {
                                order = 10,
                                type = "range",
                                name = "Tick Width",
                                desc = "Tick Width",
                                min = 1,
                                max = 5,
                                step = 1,
                                disabled = function()
                                    return (not XerrPrioDB.vt.enabled and not XerrPrioDB.vt.showTicks) or not XerrPrioDB.vt.showTicks
                                end,
                                get = function()
                                    return XerrPrioDB.vt.tickWidth
                                end,
                                set = function(_, val)
                                    XerrPrioDB.vt.tickWidth = val
                                    XerrPrio:UpdateConfig()
                                end,

                            },
                            refreshTextColor = {
                                order = 11,
                                name = "Refresh Text Color",
                                desc = "Color of the VT Refresh Text",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.refreshTextColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.refreshTextColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            refreshBarColor = {
                                order = 12,
                                name = "Refresh Bar Color",
                                desc = "Color of the VT Refresh Bar",
                                type = "color",
                                hasAlpha = true,
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                get = function()
                                    local c = XerrPrioDB.vt.refreshBarColor
                                    return c.r, c.g, c.b, c.a
                                end,
                                set = function(_, r, g, b, a)
                                    XerrPrioDB.vt.refreshBarColor = { r = r, g = g, b = b, a = a }
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshTextColor = {
                                order = 13,
                                name = "Reset Refresh Text Color",
                                desc = "Reset Refresh Text Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                func = function()
                                    XerrPrioDB.vt.refreshTextColor = XerrPrio.colors.white
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                            resetRefreshBarColor = {
                                order = 14,
                                name = "Reset Refresh Bar Color",
                                desc = "Reset Refresh Bar Color to default value",
                                type = "execute",
                                disabled = function()
                                    return not XerrPrioDB.vt.enabled
                                end,
                                func = function()
                                    XerrPrioDB.vt.refreshBarColor = XerrPrio.colors.vtDefault
                                    XerrPrio:UpdateConfig()
                                end,
                            },
                        }
                    }
                },
            },
            prioIcons = {
                type = "group",
                name = "Priority Icons",
                order = 4,
                args = {
                    prioIcons = {
                        order = 1,
                        name = "Enable",
                        desc = "Icons for next spell on priority list",
                        type = "toggle",
                        width = "full",
                        set = function(_, val)
                            XerrPrioDB.icons = val
                            XerrPrio:UpdateConfig()
                        end,
                        get = function()
                            return XerrPrioDB.icons
                        end
                    },
                },
            },
        }
    }

end

function XerrPrio:UpdateConfig()

    XerrPrioBars:Hide()
    if XerrPrioDB.bars then
        XerrPrioBars:Show()
    end

    XerrPrioIcons:Hide()
    if XerrPrioDB.icons then
        XerrPrioIcons:Show()
    end

    self.paused = not XerrPrioDB.configMode

    if XerrPrioDB.configMode then
        XerrPrioBarsBackground:Show()
    else
        for _, spell in next, self.bars.spells do
            spell.frame:Hide()
        end
        XerrPrioBarsBackground:Hide()
    end

    XerrPrioBars:SetWidth(XerrPrioDB.barWidth)
    XerrPrioBars:SetHeight(48)

    for key, spell in next, self.bars.spells do
        local frame = spell.frame:GetName()

        spell.frame:SetWidth(XerrPrioDB.barWidth)

        if XerrPrioDB[key].enabled then
            spell.frame:Show()
        else
            spell.frame:Hide()
        end

        if XerrPrioDB[key].showIcon then
            _G[frame .. 'Icon']:Show()
        else
            _G[frame .. 'Icon']:Hide()
        end

        local barColor = XerrPrioDB[key].barColor
        local textColor = XerrPrioDB[key].textColor
        local refreshTextColor = XerrPrioDB[key].refreshTextColor
        local refreshBarColor = XerrPrioDB[key].refreshBarColor

        _G[frame .. 'RefreshDuration']:SetWidth(XerrPrioDB.barWidth * (XerrPrioDB.refreshMinDuration / 18))
        _G[frame .. 'RefreshDuration']:SetVertexColor(refreshBarColor.r, refreshBarColor.g, refreshBarColor.b, refreshBarColor.a)
        _G[frame .. 'RefreshDuration']:Show()
        _G[frame .. 'RefreshDurationSpark']:SetPoint('LEFT', _G[frame], 'LEFT', _G[frame .. 'RefreshDuration']:GetWidth() - 8, 0)
        _G[frame .. 'RefreshDurationSpark']:Show()
        _G[frame .. 'Refresh']:SetTextColor(refreshTextColor.r, refreshTextColor.g, refreshTextColor.b, refreshTextColor.a)
        _G[frame .. 'Refresh']:SetText(sformat('%.1f', XerrPrioDB.refreshMinDuration))

        _G[frame .. 'Duration']:SetWidth(XerrPrioDB.barWidth * 0.75)
        _G[frame .. 'Duration']:SetVertexColor(barColor.r, barColor.g, barColor.b, barColor.a)
        _G[frame .. 'Spark']:SetPoint('LEFT', _G[frame], 'LEFT', _G[frame .. 'Duration']:GetWidth() - 8, 0)

        _G[frame .. 'Name']:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)

        _G[frame .. 'TimeLeft']:SetText(12)
        _G[frame .. 'TimeLeft']:SetTextColor(textColor.r, textColor.g, textColor.b, textColor.a)
        _G[frame .. 'Background']:SetWidth(XerrPrioDB.barWidth)

        _G[frame .. 'ToF']:SetText('ToF')
        _G[frame .. 'ToF']:SetTextColor(0, 1, 0, 0)
        _G[frame .. 'ToF']:Show()

        _G[frame .. 'UVLS']:SetText('UVLS')
        _G[frame .. 'UVLS']:SetTextColor(0, 1, 0, 0)
        _G[frame .. 'UVLS']:Show()

        for i = 1, #spell.ticks do
            spell.ticks[i]:Hide()
        end
        if XerrPrioDB[key].showTicks then
            local ticks = 6
            local numTicks = XerrPrioDB[key].showOnlyLastTick and 1 or ticks
            if ticks > 0 then
                for i = 1, numTicks do
                    if not spell.ticks[i] then
                        spell.ticks[i] = CreateFrame("Frame", "XerrPrio_" .. key .. "_BarTicks_" .. i, _G[frame], "XerrPrioBarTickTemplate")
                    end
                    spell.ticks[i]:SetPoint("TOPLEFT", _G[frame], "TOPLEFT", XerrPrioDB.barWidth * i * (3 / 18), 0)
                    local tickColor = XerrPrioDB[key].tickColor
                    _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetVertexColor(tickColor.r, tickColor.g, tickColor.b, tickColor.a)
                    _G["XerrPrio_" .. key .. "_BarTicks_" .. i .. "Tick"]:SetWidth(XerrPrioDB[key].tickWidth)
                    spell.ticks[i]:Show()
                end
            end
        end

    end

end