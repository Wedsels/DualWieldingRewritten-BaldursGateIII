local Common = {}

Common.ActiveDebuff = false
Common.Ranged = false
Common.Melee = false
Common.Debt = -3
Common.Key = "DualWieldingBalance"
Common.Off = "_DualOffhand"

Common.Spells = {}

Common.InitializeSpellLists = function()
    Common.Spells = {}

    for _,name in pairs( Ext.Stats.GetStats( "SpellData" ) ) do
        local spell = Ext.Stats.Get( name )

        if string.find( name, "AttackOfOpportunity" ) or Common.OffHandSpell( name ) or tostring( spell.CastTextEvent ) == "CastOffhand" then
        elseif spell.SpellType == "Projectile" and Common.Contains( spell.WeaponTypes, "Ammunition" ) then
            Common.Spells[ name ] = 0
        elseif spell.SpellType == "Target" and Common.Contains( spell.WeaponTypes, "Melee" ) then
            Common.Spells[ name ] = 1
        end
    end
end

Common.Contains = function( tbl, val )
    for _,v in ipairs( tbl ) do
        if tostring( v ) == tostring( val ) then
            return true
        end
    end
    return false
end

Common.GetDebt = function( p )
    if Osi.HasPassive( p, "FightingStyle_TwoWeaponFighting" ) == 1 then
        return Common.Debt + 3
    end
    return Common.Debt
end

Common.OffHandSpell = function( name )
    return string.sub( name, -#Common.Off ) == Common.Off
end

Common.CreateStat = function( name, type, source )
    local ret = Ext.Stats.Get( name )
    if ret then
        return ret
    end
    return Ext.Stats.Create( name, type, source )
end

Common.CleanSpell = function( spell, name, type )
    local function mainoff( str )
        str = tostring( str )
        if type then
            str = string.gsub( str, "OffHand", "MainHand" )
            str = string.gsub( str, "Offhand", "Main" )
            str = string.gsub( str, "OffHandWeaponAttack", "WeaponAttack" )
        else
            str = string.gsub( str, "MainHand", "OffHand" )
            str = string.gsub( str, "Main", "Offhand" )
            str = string.gsub( str, "WeaponAttack", "OffHandWeaponAttack" )
            str = string.gsub( str, "OffHandOffHandWeaponAttack", "OffHandWeaponAttack" )
        end

        return str
    end

    spell.TooltipDamageList = mainoff( spell.TooltipDamageList )
    spell.TooltipAttackSave = mainoff( spell.TooltipAttackSave )
    spell.DescriptionParams = mainoff( spell.DescriptionParams )
    if spell.SpellRoll then
        local roll = spell.SpellRoll
        for key,i in pairs( roll ) do
            pcall( function() roll[ key ] = mainoff( i ) end )
        end
        spell.SpellRoll = roll
    end
    if spell.SpellProperties then
        for _,e in ipairs( spell.SpellProperties ) do
            if e.TextKey == "CastOffhand" then
                e.TextKey = "Disabled"
            else
                for _,i in ipairs( e.Functors ) do
                    pcall(
                        function()
                            i.WeaponType = mainoff( i.WeaponType )
                            if string.find( i.ProjectileSpell, name ) then
                                i.ProjectileSpell = name .. Common.Off
                            end
                        end
                    )
                end
            end
        end
    end
    if spell.SpellSuccess then
        for _,e in ipairs( spell.SpellSuccess ) do
            if e.TextKey == "CastOffhand" then
                e.TextKey = "Disabled"
            else
                for _,i in ipairs( e.Functors ) do
                    pcall( function() i.WeaponType = mainoff( i.WeaponType ) end )
                end
            end
        end
    end
    if spell.SpellFail then
        for _,e in ipairs( spell.SpellFail ) do
            if e.TextKey == "CastOffhand" then
                e.TextKey = "Disabled"
            end
        end
    end
end

Common.RefreshDualStatus = function( p )
    Common.UnlearnOffHand( p )
    Common.ActiveDebuff = false
    Osi.RemovePassive( p, "Penalty_DualWielding" )
    Osi.ObjectTimerCancel( p, Common.Key )
end

Common.CheckDualStatus = function( p )
    local ent = Ext.Entity.Get( p )
    if not ent then return end
    local dual = ent:GetComponent( "DualWielding" )
    if not dual then return end

    local passive = Common.GetDebt( p ) == 0

    if not dual.RangedUI then
        Common.Ranged = false
        dual.RangedToggledOn = false
    else
        Common.Ranged = dual.RangedToggledOn
    end

    if not dual.MeleeUI then
        Common.Melee = false
        dual.MeleeToggledOn = false
    else
        Common.Melee = dual.MeleeToggledOn
    end

    if Common.Ranged and not passive then
        Osi.AddPassive( p, "Ranged_DualWielding" )
    else
        Osi.RemovePassive( p, "Ranged_DualWielding" )
    end

    if Common.Melee and not passive then
        Osi.AddPassive( p, "Melee_DualWielding" )
    else
        Osi.RemovePassive( p, "Melee_DualWielding" )
    end

    dual.ToggledOn = false
end

Common.ExchangeSpell = function( p, spell )
    local name = ""
    if Common.OffHandSpell( spell ) then
        name = string.sub( spell, 1, -#Common.Off - 1 )
        Osi.RemoveSpell( p, spell )
        Osi.RemoveBoosts( p, "UnlockSpellVariant( SpellId('" .. name .. "'), ModifyIconGlow())", 0, Common.Key, "" )
    else
        name = spell .. Common.Off
        Osi.AddSpell( p, name )
        Osi.AddBoosts( p, "UnlockSpellVariant( SpellId('" .. name .. "'), ModifyIconGlow())", Common.Key, "" )
    end

    local ent = Ext.Entity.Get( p )
    if not ent then return end
    local hot = ent:GetComponent( "HotbarContainer" )
    if not hot then return end

    for _,i in ipairs( hot.Containers[ hot.ActiveContainer ] ) do
        for _,e in pairs( i.Elements ) do
            if e.SpellId.Prototype == spell then
                e.SpellId.Prototype = name
                e.SpellId.OriginatorPrototype = name
                goto done
            end
        end
    end

    :: done ::
    ent:Replicate( "HotbarContainer" )
end

Common.UnlearnOffHand = function( p )
    local ent = Ext.Entity.Get( p )
    if not ent then
        return
    end

    local book = ent.SpellBook
    if not book then
        return
    end

    for _,i in ipairs( book.Spells ) do
        local name = tostring( i.Id.Prototype )
        if Common.OffHandSpell( name ) then
            Common.ExchangeSpell( p, name )
        end
    end
end

return Common