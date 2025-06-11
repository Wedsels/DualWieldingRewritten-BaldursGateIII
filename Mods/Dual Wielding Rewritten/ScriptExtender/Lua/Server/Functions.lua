--- @param _V _V
return function( _V )
    --- @class _F
    local _F = {}

    _F.OffHandSpell = function( name )
        return string.sub( name, -#_V.Off ) == _V.Off
    end

    _F.CreateStat = function( name, type, source )
        return Ext.Stats.Get( name ) or Ext.Stats.Create( name, type, source )
    end

    _F.InCombat = function( uuid )
        return Osi.IsInCombat( uuid ) == 1 or Osi.IsInForceTurnBasedMode( uuid ) == 1
    end

    _F.UUID = function( target )
        if type( target ) == "userdata" and target.Uuid then
            return string.sub( target.Uuid.EntityUuid, -36 )
        elseif type( target ) == "string" then
            return string.sub( target, -36 )
        end
    end

    _F.Index = function( tbl, val )
        for i,v in ipairs( tbl ) do
            if val == v then
                return i
            end
        end
    end

    _F.Hip = {
        Apply = function( uuid )
            uuid = _F.UUID( uuid )
            if not uuid then return end

            if Osi.IsInCombat( uuid ) == 1 then return end

            for data,_ in pairs( _V.Hips ) do
                Ext.StaticData.Get( data, "EquipmentType" ).WeaponType_OneHanded = "Small1H"
            end

            Osi.SetWeaponUnsheathed( uuid, 1, 1 )
            Osi.SetWeaponUnsheathed( uuid, 0, 1 )
        end,
        Remove = function()
            for data,type in pairs( _V.Hips ) do
                Ext.StaticData.Get( data, "EquipmentType" ).WeaponType_OneHanded = type
            end
        end
    }

    _F.Boost = function( uuid, boost )
        local function Check( type )
            local dual = _V.Duals[ uuid ]
            if not dual then return end

            local boo = _V.Boosts( uuid )[ boost ]
            if type ~= 2 and boo == dual.Boost[ boost ] or type == 0 and dual.Boost[ boost ] == "" then return end

            if dual.Boost[ boost ] then
                Osi.RemoveBoosts( uuid, dual.Boost[ boost ], 0, _V.Key, "" )
            end

            if type == 2 then
                dual.Boost[ boost ] = ""
            else
                dual.Boost[ boost ] = boo
                Osi.AddBoosts( uuid, boo, _V.Key, "" )
                if boo:find( " 0 " ) then
                    Ext.Timer.WaitFor( 500, function() Osi.RemoveBoosts( uuid, boo, 0, _V.Key, "" ) end )
                end
            end
        end

        return {
            Update = function() Check( 0 ) end,
            Apply = function() Check( 1 ) end,
            Remove = function() Check( 2 ) end
        }
    end

    _F.RemoveDualEffects = function( uuid )
        _F.Boost( uuid, "Penalty" ).Remove()

        local ent = Ext.Entity.Get( uuid )
        if not ent then return end

        local book = ent.SpellBook
        if not book then return end

        for _,i in ipairs( book.Spells ) do
            if _F.OffHandSpell( i.Id.Prototype ) then
                _F.ExchangeSpell( uuid, i.Id.Prototype )
            end
        end
    end

    _F.MainOff = function( str )
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

    _F.CleanSpell = function( spell, name, type )
        spell.TooltipDamageList = _F.MainOff( spell.TooltipDamageList )
        spell.TooltipAttackSave = _F.MainOff( spell.TooltipAttackSave )
        spell.DescriptionParams = _F.MainOff( spell.DescriptionParams )
        if spell.SpellRoll then
            local roll = spell.SpellRoll
            for key,i in pairs( roll ) do
                pcall( function() roll[ key ] = _F.MainOff( i ) end )
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
                                i.WeaponType = _F.MainOff( i.WeaponType )
                                if string.find( i.ProjectileSpell, name ) then
                                    i.ProjectileSpell = name .. _V.Off
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
                        pcall( function() i.WeaponType = _F.MainOff( i.WeaponType ) end )
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

    _F.CheckDualStatus = function( uuid )
        local ent = Ext.Entity.Get( uuid )
        if not ent then return end
        local dual = ent:GetComponent( "DualWielding" )
        if not dual then return end

        _V.Duals[ uuid ] = _V.Duals[ uuid ] or {
            Ranged = false,
            Melee = false,
            Time = -1,
            Boost = {},
            Data = {}
        }
        local d = _V.Duals[ uuid ]
        _F.Boost( uuid, "Base" ).Apply()

        for _,i in ipairs( { "Ranged", "Melee" } ) do
            if not dual[ i .. "UI" ] then
                d[ i ] = false
                dual[ i .. "ToggledOn" ] = false
            else
                d[ i ] = dual[ i .. "ToggledOn" ]
            end

            if d[ i ] then
                _F.Boost( uuid, i ).Apply()
            else
                _F.Boost( uuid, i ).Remove()
            end
        end

        dual.ToggledOn = false
    end

    _F.AddSpell = function( ent, uuid, spell )
        if not ent then return end

        Osi.AddSpell( uuid, spell )

        ent.SpellBook.Spells[ #ent.SpellBook.Spells + 1 ] = {
            CastRequirements = {
                { CastContext = 1, Requirements = {} },
                { CastContext = 2, Requirements = {} },
                { CastContext = 4, Requirements = {} }
            },
            Charged = true,
            CooldownType = "Default",
            Id =
            {
                OriginatorPrototype = spell,
                ProgressionSource = "00000000-0000-0000-0000-000000000000",
                Prototype = spell,
                Source = "00000000-0000-0000-0000-000000000000",
                SourceType = "Boost"
            },
            NumCharges = -1,
            PreferredCastingResource = "00000000-0000-0000-0000-000000000000",
            PrepareType = "AlwaysPrepared",
            SpellCastingAbility = "Intelligence",
            UsedCharges = -1
        }

        ent:Replicate( "SpellBook" )
    end

    _F.ExchangeSpell = function( uuid, spell )
        local ent = Ext.Entity.Get( uuid )
        local dual = _V.Duals[ uuid ]
        if not ent or not dual then return end

        local hotbar = false

        local name = ""
        if _F.OffHandSpell( spell ) then
            local data = dual.Data[ spell ]

            if data and data.Charge - 1 > 0 then
                data.Charge = data.Charge - 1
            else
                name = string.sub( spell, 1, -#_V.Off - 1 )
                Osi.RemoveSpell( uuid, spell )
                Osi.RemoveBoosts( uuid, "UnlockSpellVariant( SpellId( '" .. name .. "' ), ModifyIconGlow() )", 0, _V.Key, "" )

                dual.Data[ spell ] = nil
                hotbar = true
            end
        else
            name = spell .. _V.Off
            local data = dual.Data[ name ]

            if data then
                data.Charge = data.Charge + 1
            else
                _F.AddSpell( ent, uuid, name )
                Osi.AddBoosts( uuid, "UnlockSpellVariant( SpellId( '" .. name .. "' ), ModifyIconGlow() )", _V.Key, "" )

                dual.Data[ name ] = {
                    Charge = 1,
                    Time = 0
                }
                hotbar = true
            end
        end

        if hotbar then
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
    end

    return _F
end