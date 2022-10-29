local _G = _G
local tinsert, tablesize, select, strfind, strsplit, tonumber = tinsert, table.getn, select, strfind, strsplit, tonumber
local gsub, strsub, strlen = string.gsub, strsub, strlen
local _, class = UnitClass('player')

-- known issues
-- if target is friendly and turns hostile, the pause doesnt go to false

--------------------
--- Inits
--------------------

XerrUtils = CreateFrame("Frame")
XerrUtils.init = false
XerrUtils.paused = true
XerrUtils.spellBookSpells = {}
XerrUtils.hp_path = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Custom\\';
XerrUtils.hp_path_icon = 'Interface\\AddOns\\HaloPro\\HaloPro_Art\\Shadow_Icon\\';

XerrDots = CreateFrame("Frame")

XerrPrio = CreateFrame("Frame")

XerrDots.spells = {
    swp = {
        frame = nil,
        ord = 1,
        name = '', id = 589, dps = 0,
        color = { r = 255 / 255, g = 65 / 255, b = 9 / 255 }
    },
    vt = {
        frame = nil,
        ord = 2,
        name = '', id = 34914, dps = 0,
        color = { r = 60 / 255, g = 52 / 255, b = 175 / 255
        }
    },
    --dp = {
    --    frame = nil,
    --    ord = 3,
    --    name = '', id = 2944,
    --    color = { r = 113 / 255, g = 32 / 255, b = 97 / 255
    --    }
    --}
}

XerrPrio.spells = {
    swp = { name = '', id = 589, icon = '', spellBookID = 0 },
    vt = { name = '', id = 34914, icon = '', spellBookID = 0 },
    dp = { name = '', id = 2944, icon = '', spellBookID = 0 },
    mf = { name = '', id = 15407, icon = '', spellBookID = 0 },
    mb = { name = '', id = 8092, icon = '', spellBookID = 0 },
    halo = { name = '', id = 120644, icon = '', spellBookID = 0 },
    shadowfiend = { name = '', id = 34433, icon = '', spellBookID = 0 },
    swd = { name = '', id = 32379, icon = '', lastCastTime = 0, spellBookID = 0 },
}

XerrPrio.nextSpell = {
    [1] = XerrPrio.spells.swp,
    [2] = XerrPrio.spells.swp
}

XerrUtils.cols = {
    white = '|cffffffff',

    hi1 = '|cffD69637',
    hi2 = '|cffC8d637',
    hi3 = '|cff37d63e',

    lo1 = '|cff37d63e',
    lo2 = '|cffC8d637',
    lo3 = '|cffD69637'
}


XerrDots.dotStats = {}

--------------------
--- Events
--------------------

-- todo check spec to be shadow

XerrUtils:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED')
XerrUtils:RegisterEvent('ADDON_LOADED')
XerrUtils:RegisterEvent('PLAYER_ENTERING_WORLD')
XerrUtils:RegisterEvent('PLAYER_TARGET_CHANGED')
XerrUtils:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
XerrUtils:RegisterEvent('PLAYER_TALENT_UPDATE')
XerrUtils:SetScript("OnEvent", function(frame, event, arg1, arg2, arg3, arg4, arg5)
    if event then
        if (event == 'ADDON_LOADED' and arg1 == 'xerrprio') or event == 'PLAYER_ENTERING_WORLD' then
            XerrUtils:Init()
            return
        end
        if not XerrUtils.init then
            return false
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
                            tof = false,
                            uvls = false,
                            dps = 0
                        }
                    end

                    XerrDots.dotStats[guid][key].tof = XerrUtils:PlayerHasTwistOfFate()
                    XerrDots.dotStats[guid][key].uvls = XerrUtils:PlayerHasUVLS()

                    XerrDots.dotStats[guid][key].dps = XerrUtils:GetSpellDamage(spell.id)

                end
            end

            if arg5 == XerrPrio.spells.swd.id then
                XerrPrio.spells.swd.lastCastTime = GetTime()
            end

        end
        if event == 'PLAYER_TARGET_CHANGED' then
            if not UnitExists('target') then
                XerrUtils.paused = true
                XERR_PRIO_Prio:Hide()
                return
            else
                if UnitReaction('player', 'target') >= 5 then
                    XerrUtils.paused = true
                    XERR_PRIO_Prio:Hide()
                    return
                else
                    XerrUtils.paused = false
                    XERR_PRIO_Prio:Show()
                end
            end
        end
        if event == 'PLAYER_SPECIALIZATION_CHANGED' then
            XerrUtils:PopulateSpellBookID()
            return
        end
    end
end)

--------------------
---  Init
--------------------

function XerrUtils:Init()

    if class ~= 'PRIEST' then
        XERR_PRIO_Dots:Hide()
        XERR_PRIO_Prio:Hide()
        return false
    end

    self:PopulateSpellBookID()

    for key, spell in next, XerrDots.spells do
        spell.name, spell.icon = XerrUtils:GetSpellInfo(spell.id)

        local frameName = 'XERRPRIODots_' .. key

        spell.frame = CreateFrame('Frame', frameName, XERR_PRIO_Dots, 'XerrPrioFrameTemplate')

        _G[frameName]:SetPoint("TOPLEFT", XERR_PRIO_Dots, "TOPLEFT", 0, -50 + spell.ord * 25)

        _G[frameName .. 'Icon']:SetTexture(spell.icon)
        _G[frameName .. 'Duration']:SetVertexColor(spell.color.r, spell.color.g, spell.color.b)
        _G[frameName .. 'Name']:SetText(spell.name)
        _G[frameName .. 'Name']:SetTextColor(1, 1, 1)

    end

    for _, spell in next, XerrPrio.spells do
        spell.name, spell.icon = XerrUtils:GetSpellInfo(spell.id)
    end
    XerrPrio.spells.swd.lastCastTime = GetTime()

    if not XerrPrioDB then
        XerrPrioDB = {
            bars = false,
            prio = false,
            configMode = false
        }
    end

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
    else

        for _, spell in next, XerrDots.spells do
            spell.frame:Hide()
        end

        XerrPrioDB.configMode = false
        XERR_PRIO_Dots:Hide()
    end

    XERR_PRIO_Prio:Hide()
    self.init = true
end

function XerrUtils:PopulateSpellBookID()
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

    for _, spell in next, XerrPrio.spells do
        spell.spellBookID = self.spellBookSpells[spell.name] or false
    end
end

--------------------
---  Timers
--------------------

--------------------
--- Dots
--------------------

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

        XERR_PRIO_Dots:Hide()

        if XerrUtils.paused or not XerrPrioDB.dots or XerrPrioDB.configMode then
            return
        end

        local oneDot = false

        for key, spell in next, XerrDots.spells do
            local tl, perc = XerrUtils:GetDebuffInfo(spell.id)
            local frame = spell.frame:GetName()
            if tl > 0 then

                oneDot = true

                local tof, uvls = XerrUtils:PlayerHasTwistOfFate(), XerrUtils:PlayerHasUVLS()
                local guid = UnitGUID('target')

                if XerrDots.dotStats[guid] and XerrDots.dotStats[guid][key] then

                    local current_dps = XerrUtils:GetSpellDamage(spell.id)

                    if current_dps > XerrDots.dotStats[guid][key].dps then
                        _G[frame .. 'Refresh']:SetText('Refresh ' .. string.format("%.2f", current_dps / XerrDots.dotStats[guid][key].dps) .. 'x')
                    else
                        _G[frame .. 'Refresh']:SetText('=')
                    end

                    if tof then
                        _G[frame .. 'ToF']:SetText('ToF')
                        _G[frame .. 'ToF']:SetTextColor(XerrDots.dotStats[guid][key].tof and 0 or 1, XerrDots.dotStats[guid][key].tof and 1 or 0, 0)
                    else
                        if XerrDots.dotStats[guid][key].tof then
                            _G[frame .. 'ToF']:SetText('ToF')
                            _G[frame .. 'ToF']:SetTextColor(0, 1, 0)
                        else
                            _G[frame .. 'ToF']:SetText('')
                        end
                    end

                    if uvls then
                        _G[frame .. 'UVLS']:SetText('UVLS')
                        _G[frame .. 'UVLS']:SetTextColor(XerrDots.dotStats[guid][key].uvls and 0 or 1, XerrDots.dotStats[guid][key].uvls and 1 or 0, 0)
                    else
                        if XerrDots.dotStats[guid][key].uvls then
                            _G[frame .. 'UVLS']:SetText('UVLS')
                            _G[frame .. 'UVLS']:SetTextColor(0, 1, 0)
                        else
                            _G[frame .. 'UVLS']:SetText('')
                        end
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

--------------------
--- Prio
--------------------

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

        if XerrUtils.paused or not XerrPrioDB.prio or XerrPrioDB.configMode then
            XerrPrio.nextSpell = {
                [1] = { id = 0, name = '' },
                [2] = { id = 0, name = '' }
            }
            return
        end
        XerrPrio.nextSpell = XerrPrio:GetNextSpell()

        if XerrPrio.nextSpell[1] then
            XERR_PRIO_PrioIcon:SetTexture(XerrPrio.nextSpell[1].icon)
        else
            XERR_PRIO_PrioIcon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
        if XerrPrio.nextSpell[2] then
            XERR_PRIO_PrioIcon2:SetTexture(XerrPrio.nextSpell[2].icon)
        else
            XERR_PRIO_PrioIcon2:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        end
    end
end)

--------------------
--- Helpers
--------------------

function XerrUtils:GetSpellInfo(id)
    local name, _, icon, _, _, _, castTime = GetSpellInfo(id)
    return name, icon, castTime / 1000
end

function XerrUtils:GetDebuffInfo(id)
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

function XerrUtils:PlayerHasTwistOfFate()
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, _, id = UnitBuff('player', i)
        if id == 123254 then
            return true
        end
    end
    return false
end

function XerrUtils:PlayerHasUVLS()
    for i = 1, 40 do
        local _, _, _, _, _, _, _, _, _, _, id = UnitBuff('player', i)
        if id == 138963 then
            return true
        end
    end
    return false
end

function XerrUtils:GetWAIconColor(spell)

    if not UnitExists('target') or XerrUtils.paused then
        return 1, 1, 1, 1, false, false, false, self.hp_path_icon .. 'offcd'
    end

    local inRange = false
    local isNext = XerrPrio.nextSpell[1].id == spell.id
    local isNext2 = XerrPrio.nextSpell[2].id == spell.id
    local icon = self.hp_path .. 'center'

    if spell.id == XerrPrio.spells.halo.id then
        inRange = false
        local hp = HaloPro_MainFrame
        if hp.texture:GetTexture() then
            local hpt = hp.texture:GetTexture()
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



--N	13.99	shadow_word_pain,if=ticks_remain<=1
--O	15.98	vampiric_touch,max_cycle_targets=5,if=remains<cast_time+tick_time
--P	0.00	vampiric_embrace,if=shadow_orb=3&health.pct<=40
--Q	16.62	devouring_plague,if=shadow_orb=3
--V	0.64	wait,sec=cooldown.shadow_word_death.remains,if=target.health.pct<20&cooldown.shadow_word_death.remains<0.5
--W	10.73	wait,sec=cooldown.mind_blast.remains,if=cooldown.mind_blast.remains<0.5
--Z	123.92	mind_flay,chain=1,interrupt=1
--a	0.00	shadow_word_death,moving=1
--e	0.00	shadow_word_pain,moving=1


function XerrPrio:GetNextSpell()

    local prio = {}

    local guid = UnitGUID('target')
    -- refresh dots if uvls procd
    if XerrUtils:PlayerHasUVLS() and XerrDots.dotStats[guid] then
        if XerrDots.dotStats[guid].swp and not XerrDots.dotStats[guid].swp.uvls then
            tinsert(prio, self.spells.swp)
        end
        if XerrDots.dotStats[guid].vt and not XerrDots.dotStats[guid].vt.uvls then
            tinsert(prio, self.spells.vt)
        end
    end

    -- refresh swp or vt, only if mindblast is on cd and we dont have dp up
    if XerrUtils:GetSpellCooldown(self.spells.mb.id) > 1.5 and XerrUtils:GetDebuffInfo(self.spells.dp.id) == 0 then

        if XerrDots.dotStats[guid] then
            if XerrDots.dotStats[guid].swp then
                if XerrUtils:GetSpellDamage(self.spells.swp.id) > XerrDots.dotStats[guid].swp.dps then
                    tinsert(prio, self.spells.swp)
                end
            end
            if XerrDots.dotStats[guid].vt then
                if XerrUtils:GetSpellDamage(self.spells.vt.id) > XerrDots.dotStats[guid].vt.dps then
                    tinsert(prio, self.spells.vt)
                end
            end
        end

    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- halo when offcooldown and no dp
    if self.spells.halo.spellBookID and XerrUtils:GetSpellCooldown(self.spells.halo.id) == 0 then
        if XerrUtils:GetDebuffInfo(self.spells.dp.id) == 0 then
            tinsert(prio, self.spells.halo)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    --F	6.82	shadow_word_death,if=buff.shadow_word_death_reset_cooldown.stack=1
    --todo

    -- devouring plague
    if XerrUtils:GetShadowOrbs() == 3 then
        tinsert(prio, self.spells.dp)
    end

    -- mindblast and dp after if we'll have 3 orbs after mindblast
    if XerrUtils:GetSpellCooldown(self.spells.mb.id) == 0 then
        tinsert(prio, self.spells.mb)
        if XerrUtils:GetShadowOrbs() == 2 then
            tinsert(prio, self.spells.dp)
        end
    end

    --I	6.97	shadow_word_death,if=buff.shadow_word_death_reset_cooldown.stack=0
    --todo


    if tablesize(prio) == 2 then
        return prio
    end

    -- shadow word: death
    if XerrUtils:ExecutePhase() and XerrUtils:GetSpellCooldown(self.spells.swd.id) == 0 then
        if XerrUtils:GetDebuffInfo(self.spells.dp.id) >= 0.2 then
            if GetTime() - self.spells.swd.lastCastTime >= 8 then
                tinsert(prio, self.spells.swd)
            elseif XerrUtils:GetSpellCooldown(self.spells.mb.id) == 0 then
                tinsert(prio, self.spells.mb)
                if XerrUtils:GetShadowOrbs() == 2 then
                    tinsert(prio, self.spells.dp)
                end
            else
                tinsert(prio, self.spells.mf)
            end
        else
            tinsert(prio, self.spells.swd)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- insanity
    if XerrUtils:GetDebuffInfo(self.spells.dp.id) > 0 then
        tinsert(prio, self.spells.mf)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- shadowfiend
    if XerrUtils:GetSpellCooldown(self.spells.shadowfiend.id) == 0 then
        tinsert(prio, self.spells.shadowfiend)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- swp
    if XerrUtils:GetDebuffInfo(self.spells.swp.id) < 0.5 then
        tinsert(prio, self.spells.swp)
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- vt
    if XerrUtils:GetDebuffInfo(self.spells.vt.id) >= 0 then
        if XerrUtils:GetDebuffInfo(self.spells.vt.id) < select(3, XerrUtils:GetSpellInfo(self.spells.vt.id)) then
            tinsert(prio, self.spells.vt)
        end
    end

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind flay if nothing else is available
    tinsert(prio, self.spells.mf)

    if tablesize(prio) == 2 then
        return prio
    end

    -- mind blast 2nd if cd <= 1s
    if prio[1] and prio[1].id ~= self.spells.mb.id and XerrUtils:GetSpellCooldown(self.spells.mb.id) <= 1 then
        if prio[2] and prio[2].id ~= self.spells.dp.id then
            prio[2] = self.spells.mb
        end
    end

    -- if we dont have a 2nd spell by now add mb if cooldown shorter than halo cd
    -- else add mf
    if tablesize(prio) == 1 then
        if XerrUtils:GetSpellCooldown(self.spells.mb.id) < XerrUtils:GetSpellCooldown(self.spells.halo.id) then
            tinsert(prio, self.spells.mb)
        end
        tinsert(prio, self.spells.mf)
    end

    return prio
end

function XerrUtils:TimeSinceLastSWD()
    if self:GetDebuffInfo(XerrPrio.spells.dp.id) >= 0.2 then
        local t = math.floor(GetTime() - XerrPrio.spells.swd.lastCastTime)
        local cd = 8 - t
        if cd > 0 then
            return cd
        end
    end
    local cd = self:GetSpellCooldown(XerrPrio.spells.swd.id)
    if cd > 0 then
        return cd
    end
    return ''
end

function XerrUtils:GetSpellCooldown(id)
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

function XerrUtils:GetGCD()
    local start, duration = GetSpellCooldown(61304);
    if start > 0 and duration > 0 then
        return start + duration - GetTime()
    end
    return 0
end

function XerrUtils:GetShadowOrbs()
    return UnitPower("player", SPELL_POWER_SHADOW_ORBS)
end

function XerrUtils:ExecutePhase()
    if not UnitExists('target') then
        return false
    end
    return (UnitHealth('target') * 100) / UnitHealthMax('target') <= 20
end

function XerrUtils:replace(text, search, replace)
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

function XerrUtils:GetSpellDamage(spellId)
    XerrPrioTooltipFrame:SetOwner(UIParent, "ANCHOR_NONE")
    XerrPrioTooltipFrame:SetSpellByID(spellId);
    local tooltipDescription = XerrPrioTooltipFrameTextLeft4:GetText();
    local totalDmg, tickTime, dps = 0, 0, 0

    if string.find(tooltipDescription,"Cooldown remaining") then
        tooltipDescription = XerrPrioTooltipFrameTextLeft5:GetText()
    end

    if spellId == XerrPrio.spells.swp.id then
        tooltipDescription = XerrUtils:replace(tooltipDescription, ',', '')
        _, _, totalDmg, tickTime = string.find(tooltipDescription, "(%S+) Shadow damage over (%S+)")
    end
    if spellId == XerrPrio.spells.vt.id then
        tooltipDescription = XerrUtils:replace(tooltipDescription, ',', '')
        _, _, totalDmg, tickTime = string.find(tooltipDescription, "Causes (%S+) Shadow damage over (%S+)")
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

    print('XerrPrio available options:')
    print('dots: ' .. (XerrPrioDB.bars and 'on' or 'off'))
    print('prio: ' .. (XerrPrioDB.prio and 'on' or 'off'))
    print('config: ' .. (XerrPrioDB.config and 'on' or 'off'))

end