local _G = _G
local tinsert = tinsert
local _, class = UnitClass('player')

XerrDots = CreateFrame("Frame")
XerrPrio = CreateFrame("Frame")

XerrDots.paused = false

XerrDots.spells = {
    swp = {
        frame = nil,
        ord = 1,
        name = '', id = 589, haste_perc = 0, sp_perc = 0,
        color = { r = 255 / 255, g = 65 / 255, b = 9 / 255 }
    },
    vt = {
        frame = nil,
        ord = 2,
        name = '', id = 34914, haste_perc = 0, sp_perc = 0,
        color = { r = 60 / 255, g = 52 / 255, b = 175 / 255
        }
    },
    dp = {
        frame = nil,
        ord = 3,
        name = '', id = 2944, haste_perc = 0, sp_perc = 0,
        color = { r = 113 / 255, g = 32 / 255, b = 97 / 255
        }
    }
}

XerrPrio.spells = {
    swp = { name = '', id = 589, icon = '' },
    vt = { name = '', id = 34914, icon = '' },
    dp = { name = '', id = 2944, icon = '' },
    mf = { name = '', id = 15407, icon = '' },
    mb = { name = '', id = 8092, icon = '' },
    halo = { name = '', id = 120644, icon = '' },
    shadowfiend = { name = '', id = 34433, icon = '' },
    swd = { name = '', id = 32379, icon = '', lastCastTime = '' },
}

XerrPrio.nextSpell = {
    [1] = XerrPrio.spells.swp,
    [2] = XerrPrio.spells.swp
}

XerrDots.cols = {
    white = '|cffffffff',

    hi1 = '|cffD69637',
    hi2 = '|cffC8d637',
    hi3 = '|cff37d63e',

    lo1 = '|cff37d63e',
    lo2 = '|cffC8d637',
    lo3 = '|cffD69637'
}

XerrDots.texts = {
    haste_hi1 = XerrDots.cols.hi1 .. '>|r',
    haste_hi2 = XerrDots.cols.hi2 .. '>>|r',
    haste_hi3 = XerrDots.cols.hi3 .. '>>>|r',

    haste_lo1 = XerrDots.cols.lo1 .. '<|r',
    haste_lo2 = XerrDots.cols.lo2 .. '<<|r',
    haste_lo3 = XerrDots.cols.lo3 .. '<<<|r'
}

XerrDots.dotStats = {}

function XerrDots:GetSpellInfo(id)
    local name, _, icon = GetSpellInfo(id)
    return name, icon
end

function XerrDots:GetDebuffInfo(id)
    if not UnitExists('target') then
        return 0, 0
    end
    for i = 1, 40 do
        local _, _, _, _, _, duration, expirationTime, unitCaster, _, _, spellId = UnitDebuff('target', i)
        if unitCaster == "player" then
            if spellId == id then
                local tl = expirationTime - GetTime()
                local perc = tl / duration
                return expirationTime - GetTime(), perc
            end
        end
    end
    return 0, 0
end

function XerrDots:PlayerHasTwistOfFate()
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, _, id = UnitBuff('player', i)
        if id == 123254 then
            return true
        end
    end
    return false
end

function XerrDots:PercentRefresh(current, dot)
    local perc = math.floor((current / dot) * 100)

    local color = self.cols.white

    -- [0 - 80] [80-90] [90-100]
    -- [0 - 80] [80-90] [90-100]

    if perc < 79 then
        color = self.cols.lo3
    elseif perc >= 80 and perc < 90 then
        color = self.cols.lo2
    elseif perc >= 90 and perc < 99 then
        color = self.cols.lo1
    elseif perc >= 101 and perc < 110 then
        color = self.cols.hi1
    elseif perc >= 110 and perc < 120 then
        color = self.cols.hi2
    elseif perc >= 120 then
        color = self.cols.hi3
    end

    return color .. perc .. '%', perc
end

function XerrDots:HasteRefreshText(diff)
    if diff > 9 and diff < 20 then
        return self.texts.haste_hi1
    elseif diff >= 20 and diff < 30 then
        return self.texts.haste_hi2
    elseif diff >= 30 then
        return self.texts.haste_hi3
    elseif diff < -9 and diff > -20 then
        return self.texts.haste_lo1
    elseif diff < -20 and diff > -30 then
        return self.texts.haste_lo2
    elseif diff <= -30 then
        return self.texts.haste_lo3
    else
        return '==='
    end
end

function XerrDots:SpellPowerRefreshText(diff)
    if diff > 1550 and diff < 3700 then
        return self.cols.hi1 .. '+' .. math.floor(diff / 1000) .. 'k|r'
    elseif diff >= 3700 and diff < 7000 then
        return self.cols.hi2 .. '+' .. math.floor(diff / 1000) .. 'k|r'
    elseif diff >= 7000 then
        return self.cols.hi3 .. '+' .. math.floor(diff / 1000) .. 'k|r'
    elseif diff < -1550 and diff > -3700 then
        return self.cols.lo2 .. math.floor(diff / 1000) .. 'k|r'
    elseif diff < -3700 and diff > -7000 then
        return self.cols.lo2 .. math.floor(diff / 1000) .. 'k|r'
    elseif diff <= -7000 then
        return self.cols.lo2 .. math.floor(diff / 1000) .. 'k|r'
    else
        return '==='
    end
end

XerrDots:Hide()
XerrDots.start = GetTime()

XerrDots:SetScript("OnShow", function()
    XERR_PRIO_Dots:Show()
    XerrDots.start = GetTime()
end)
XerrDots:SetScript("OnHide", function()
    XERR_PRIO_Dots:Hide()
    XerrDots.start = GetTime()
end)

XerrDots:SetScript("OnUpdate", function()
    local plus = 0.05
    local gt = GetTime() * 1000
    local st = (XerrDots.start + plus) * 1000
    if gt >= st then

        XerrDots.start = GetTime()

        if XerrDots.paused or not XerrPrioDB.dots then
            return
        end

        XERR_PRIO_Dots:Hide()

        local oneDot = false

        for key, spell in next, XerrDots.spells do
            local tl, perc = XerrDots:GetDebuffInfo(spell.id)
            local frame = spell.frame:GetName()
            if tl > 0 then

                oneDot = true

                local haste, sp, tof = UnitSpellHaste("player"), GetSpellBonusDamage(6), XerrDots:PlayerHasTwistOfFate()
                local guid = UnitGUID('target')

                if XerrDots.dotStats[guid] and XerrDots.dotStats[guid][key] then

                    if XerrDots.dotStats[guid][key].haste > 0 then
                        local text, p = XerrDots:PercentRefresh(haste, XerrDots.dotStats[guid][key].haste)
                        spell.haste_perc = p
                        _G[frame .. 'Haste']:SetText(text)
                    else
                        _G[frame .. 'Haste']:SetText(' - ')
                    end

                    if XerrDots.dotStats[guid][key].sp > 0 then

                        local text, p = XerrDots:PercentRefresh(sp, XerrDots.dotStats[guid][key].sp)
                        spell.sp_perc = p
                        _G[frame .. 'SP']:SetText(text)

                    else
                        _G[frame .. 'SP']:SetText(' - ')
                    end
                end

                if XerrDots.dotStats[guid] and XerrDots.dotStats[guid][key] then

                    if tof then
                        _G[frame .. 'ToF']:SetText('ToF')
                        if XerrDots.dotStats[guid][key].tof then
                            _G[frame .. 'ToF']:SetTextColor(0, 1, 0)
                        else
                            _G[frame .. 'ToF']:SetTextColor(1, 0, 0)
                        end
                    else
                        _G[frame .. 'ToF']:SetText('')
                    end

                end

                _G[frame .. 'Duration']:SetWidth(280 * perc)
                _G[frame .. 'Spark']:SetPoint('LEFT', _G[frame], 'LEFT', _G[frame .. 'Duration']:GetWidth() - 8, 0)
                _G[frame .. 'TimeLeft']:SetText(math.floor(tl))
                _G[frame .. 'TimeLeft']:SetTextColor(1, 1, 1)

                _G[frame]:Show()
            else
                _G[frame]:Hide()
            end
        end

        if oneDot then
            XERR_PRIO_Dots:Show()
        end
    end
end)



XerrPrio:Hide()
XerrPrio.start = GetTime()

XerrPrio:SetScript("OnShow", function()
    XERR_PRIO_Prio:Show()
    XerrPrio.start = GetTime()
end)
XerrPrio:SetScript("OnHide", function()
    XERR_PRIO_Prio:Hide()
    XerrPrio.start = GetTime()
end)

XerrPrio:SetScript("OnUpdate", function()
    local plus = 0.05
    local gt = GetTime() * 1000
    local st = (XerrPrio.start + plus) * 1000
    if gt >= st then

        XerrPrio.start = GetTime()

        if XerrDots.paused or not XerrPrioDB.prio then
            return
        end
        XerrPrio.nextSpell = XerrPrio:GetNextSpell()

        XERR_PRIO_PrioIcon:SetTexture(XerrPrio.nextSpell[1].icon)
        XERR_PRIO_PrioIcon2:SetTexture(XerrPrio.nextSpell[2].icon)
    end
end)


XerrDots:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
XerrDots:RegisterEvent('ADDON_LOADED')
XerrDots:RegisterEvent('PLAYER_TARGET_CHANGED')
XerrDots:SetScript("OnEvent", function(frame, event, arg1, arg2, arg3, arg4, arg5)
    if event then
        if event == 'ADDON_LOADED' and arg1 == 'xerrprio' then
            print("XerrDots OnLoad")

            for key, spell in next, XerrDots.spells do
                spell.name, spell.icon = XerrDots:GetSpellInfo(spell.id)

                local frameName = 'XERRPRIODots_' .. key

                spell.frame = CreateFrame('Frame', frameName, XERR_PRIO_Dots, 'XerrPrioFrameTemplate')

                _G[frameName]:SetPoint("TOPLEFT", XERR_PRIO_Dots, "TOPLEFT", 0, -50 + spell.ord * 25)

                _G[frameName .. 'Icon']:SetTexture(spell.icon)
                _G[frameName .. 'Duration']:SetVertexColor(spell.color.r, spell.color.g, spell.color.b)
                _G[frameName .. 'Name']:SetText(spell.name)
                _G[frameName .. 'Name']:SetTextColor(1, 1, 1)

            end

            for key, spell in next, XerrPrio.spells do
                spell.name, spell.icon = XerrDots:GetSpellInfo(spell.id)
            end
            XerrPrio.spells.swd.lastCastTime = GetTime()

            if not XerrPrioDB then
                XerrPrioDB = {
                    bars = false,
                    prio = false,
                    configMode = false
                }
            else
                if XerrPrioDB.dots then
                    XerrDots:Show()
                else
                    XerrDots:Hide()
                end

                if XerrPrioDB.prio then
                    XerrPrio:Show()
                else
                    XerrPrio:Hide()
                end

                if XerrPrioDB.configMode then

                    for _, spell in next, XerrDots.spells do
                        spell.frame:Show()
                    end

                    XerrPrioDB.configMode = true
                    XERR_PRIO_Dots:Show()
                    print('XerrPrio Dots Config Mode On')
                else

                    for _, spell in next, XerrDots.spells do
                        spell.frame:Hide()
                    end

                    XerrPrioDB.configMode = false
                    XERR_PRIO_Dots:Hide()
                    print('XerrPrio Dots Config Mode Off')
                end
            end



        end
        if event == 'UNIT_SPELLCAST_SUCCEEDED' and arg1 == 'player' and UnitGUID('target') then

            local guid = UnitGUID('target')

            for key, spell in next, XerrDots.spells do
                if arg5 == spell.id then

                    if not XerrDots.dotStats[guid] then
                        XerrDots.dotStats[guid] = {}
                    end

                    if not XerrDots.dotStats[guid][key] then
                        XerrDots.dotStats[guid][key] = {
                            haste = 0,
                            sp = 0,
                            tof = false
                        }
                    end

                    XerrDots.dotStats[guid][key].haste = UnitSpellHaste("player");
                    XerrDots.dotStats[guid][key].sp = GetSpellBonusDamage(6);
                    XerrDots.dotStats[guid][key].tof = XerrDots:PlayerHasTwistOfFate();

                end
            end

            if arg5 == XerrPrio.spells.swd.id then
                XerrPrio.spells.swd.lastCastTime = GetTime()
            end

        end
        if event == 'PLAYER_TARGET_CHANGED' then
            XerrDots.paused = false
            if not UnitExists('target') then
                XerrDots.paused = true
            else
                if UnitReaction('player', 'target') >= 5 then
                    XerrDots.paused = true
                end
            end
        end
    end
end)


function XerrPrio:GetNextSpell()

    local prio = {}

    -- shadowfiend
    if self:GetSpellCooldown(self.spells.shadowfiend.id) == 0 then
        tinsert(prio, self.spells.shadowfiend)
    end

    -- refresh swp or vt
    if XerrDots.spells.swp.haste_perc > 110 and XerrDots.spells.swp.sp_perc > 110 then
        tinsert(prio, self.spells.swp)
    end
    if XerrDots.spells.vt.haste_perc > 110 and XerrDots.spells.vt.sp_perc > 110 then
        tinsert(prio, self.spells.vt)
    end

    -- plague
    if self:GetShadowOrbs() == 3 then
        tinsert(prio, self.spells.dp)
        --return self.spells.dp
    end
    -- shadow word: death
    if self:ExecutePhase() and self:GetSpellCooldown(self.spells.swd.id) == 0 then
        if XerrDots:GetDebuffInfo(self.spells.dp.id) >= 0.2 then
            if GetTime() - self.spells.swd.lastCastTime >= 8 then
                tinsert(prio, self.spells.swd)
                --return self.spells.swd
            elseif self:GetSpellCooldown(self.spells.mb.id) == 0 then
                tinsert(prio, self.spells.mb)
                if self:GetShadowOrbs() == 2 then
                    tinsert(prio, self.spells.dp)
                end
                --return self.spells.mb
            else
                tinsert(prio, self.spells.mf)
                --return self.spells.mf
            end
        else
            tinsert(prio, self.spells.swd)
            --return self.spells.swd
        end
    end

    -- mind blast
    if self:GetSpellCooldown(self.spells.mb.id) <= 0.1 then
        tinsert(prio, self.spells.mb)
        if self:GetShadowOrbs() == 2 then
            tinsert(prio, self.spells.dp)
        end
        --return self.spells.mb
    end

    -- mindflay insanity
    if XerrDots:GetDebuffInfo(self.spells.dp.id) >= 0.1 then
        tinsert(prio, self.spells.mf)
        --return self.spells.mf
    end

    -- swp
    if XerrDots:GetDebuffInfo(self.spells.swp.id) == 0 then
        tinsert(prio, self.spells.swp)
        --return self.spells.swp
    end

    -- vt
    if XerrDots:GetDebuffInfo(self.spells.vt.id) <= 1 then
        tinsert(prio, self.spells.vt)
        --return self.spells.vt
    end

    -- halo
    if self:GetSpellCooldown(self.spells.halo.id) == 0 then
        tinsert(prio, self.spells.halo)
        --return self.spells.halo
    end

    -- mind flay if nothing else is available
    tinsert(prio, self.spells.mf)
    --return self.spells.mf

    return prio
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

SLASH_XERRPRIO1, SLASH_XERRPRIO2 = "/xerrprio", "/xprio";
function SlashCmdList.XERRPRIO(arg)

    if arg then

        if arg == 'prio' then
            XerrPrioDB.prio = not XerrPrioDB.prio

            if XerrPrioDB.prio then
                print('XerrPrio Prio Icons ON')
                XerrPrio:Show()
            else
                print('XerrPrio Prio Icons OFF')
                XerrPrio:Hide()
            end
            return
        end

        if arg == 'dots' then
            XerrPrioDB.dots = not XerrPrioDB.dots

            if XerrPrioDB.dots then
                print('XerrPrio Dots ON')
                XerrDots:Show()
            else
                print('XerrPrio Dots OFF')
                XerrDots:Hide()
            end
            return
        end

        if arg == 'config' then
            XerrPrioDB.configMode = not XerrPrioDB.configMode

            if XerrPrioDB.configMode then

                for _, spell in next, XerrDots.spells do
                    spell.frame:Show()
                end

                XerrPrioDB.configMode = true
                XERR_PRIO_Dots:Show()
                print('XerrPrio Dots Config Mode On')
            else

                for _, spell in next, XerrDots.spells do
                    spell.frame:Hide()
                end

                XerrPrioDB.configMode = false
                XERR_PRIO_Dots:Hide()
                print('XerrPrio Dots Config Mode Off')
            end
            return
        end
    end

    print('XerrPrio available options: prio, dots, config.')
    print('Current values:')
    if XerrPrioDB.dots then
        print('Dots: on')
    else
        print('Dots: off')
    end

    if XerrPrioDB.prio then
        print('Prio: on')
    else
        print('Prio: off')
    end

    if XerrPrioDB.config then
        print('Config: on')
    else
        print('Config: off')
    end


end