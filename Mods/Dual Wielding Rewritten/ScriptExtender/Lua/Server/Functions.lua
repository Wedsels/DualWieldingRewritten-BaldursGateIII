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

    _F.GenerateUUID = function()
        return string.format(
            "%08x-%04x-4%03x-%x%03x-%012x",
            math.random( 0, 0xffffffff ),
            math.random( 0, 0xffff ),
            math.random( 0, 0x0fff ),
            math.random( 8, 11 ),
            math.random( 0, 0x0fff ),
            math.random( 0, 0xffffffffffff )
        )
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
            local equip = _V.Duals[ uuid ] and _V.Duals[ uuid ].Equip
            if not uuid or not equip then return end

            if Osi.IsInCombat( uuid ) == 1 then return end

            for _,data in ipairs( equip.Ranger and equip.Ranged or equip.Melee ) do
                local eq = Ext.StaticData.Get( data.Equipable.EquipmentTypeID, "EquipmentType" )
                if eq.BoneMainSheathed == "Dummy_Sheath_Hip_L" then
                    table.insert( equip.Returns, data )
                    data.Equipable.EquipmentTypeID = "2d85d633-d496-44a1-a643-0e95ef879a6d"
                    data:Replicate( "Equipable" )
                end
            end

            Osi.SetWeaponUnsheathed( uuid, 0, 1 )
        end,
        Remove = function( uuid )
            uuid = _F.UUID( uuid )
            local equip = _V.Duals[ uuid ] and _V.Duals[ uuid ].Equip
            if not uuid or not equip then return end

            for _,data in ipairs( equip.Returns ) do
                data.Equipable.EquipmentTypeID = data.ServerItem.Template.EquipmentTypeID
                data:Replicate( "Equipable" )
            end

            equip.Returns = {}
        end
    }

    _F.Boost = function( uuid, boost )
        local function Check( type )
            local dual = _V.Duals[ uuid ]
            local ent = Ext.Entity.Get( uuid )
            if not dual or not ent then return end

            local b = _V.Boosts( uuid )
            if not b then return end
            local boo = b[ boost ]
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

    _F.MainOff = function( str, type )
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
        if spell.SpellRoll then
            local roll = spell.SpellRoll
            for key,i in pairs( roll ) do
                roll[ key ] = _F.MainOff( i, type )
            end
            spell.SpellRoll = roll
        end
        if spell.SpellProperties then
            for _,p in ipairs( spell.SpellProperties ) do
                if p.TextKey == "CastOffhand" then
                    p.TextKey = "Disabled"
                else
                    for _,f in ipairs( p.Functors ) do
                        f.FunctorUuid = _F.GenerateUUID()
                        pcall( function() f.WeaponType = _F.MainOff( f.WeaponType, type ) end )
                        pcall( function() if f.ProjectileSpell == name then f.ProjectileSpell = name .. _V.Off end end )
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
                        pcall( function() i.WeaponType = _F.MainOff( i.WeaponType, type ) end )
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

        spell:Sync()
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
            Data = {},
            Equip = {
                Melee = {},
                Ranged = {},
                Returns = {},
            }
        }
        local d = _V.Duals[ uuid ]

        local function weight( type )
            local main = Ext.Entity.Get( Osi.GetEquippedItem( uuid, type .. " Main Weapon" ) )
            local off = Ext.Entity.Get( Osi.GetEquippedItem( uuid, type .. " Offhand Weapon" ) )
            if main and off then return main.Data.Weight + off.Data.Weight end
            return 0
        end

        local rangemain = Osi.GetEquippedItem( uuid, "Ranged Main Weapon" )
        d.Equip.Ranger = rangemain == Osi.GetEquippedWeapon( uuid )
        d.Equip.MeleeWeight = weight( "Melee" )
        d.Equip.RangedWeight = weight( "Ranged" )

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
        uuid = _F.UUID( uuid )
        local dual = _V.Duals[ uuid ]
        local ent = Ext.Entity.Get( uuid )
        if not ent or not dual then return end

        local offhand = _F.OffHandSpell( spell )

        local container
        local hotbar

        local name = ""
        if offhand then
            local data = dual.Data[ spell ]

            if data and data.Charge - 1 > 0 then
                data.Charge = data.Charge - 1
            else
                name = string.sub( spell, 1, -#_V.Off - 1 )
                local origin = Ext.Stats.Get( name )

                _F.CleanSpell( origin, name, true )
                Osi.RemoveSpell( uuid, spell )
                Osi.RemoveBoosts( uuid, "UnlockSpellVariant( SpellId( '" .. name .. "' ), ModifyIconGlow() )", 0, _V.Key, "" )

                dual.Data[ spell ] = nil
                hotbar = true
                container = origin.SpellContainerID
            end
        else
            name = spell .. _V.Off
            local data = dual.Data[ name ]

            if data then
                data.Charge = data.Charge + 1
            else
                _F.CleanSpell( Ext.Stats.Get( name ), spell, false )
                _F.AddSpell( ent, uuid, name )
                Osi.AddBoosts( uuid, "UnlockSpellVariant( SpellId( '" .. name .. "' ), ModifyIconGlow() )", _V.Key, "" )

                dual.Data[ name ] = {
                    Charge = 1,
                    Time = 0
                }
                hotbar = true
                container = Ext.Stats.Get( spell ).SpellContainerID
            end
        end

        if hotbar then
            local hot = ent:GetComponent( "HotbarContainer" )
            if not hot then return end

            local usecontainer = offhand and container and container ~= ""
            local compare = not usecontainer and container and container ~= ""

            for _,i in ipairs( hot.Containers[ hot.ActiveContainer ] ) do
                for _,e in pairs( i.Elements ) do
                    if compare and e.SpellId.Prototype == container or not compare and e.SpellId.Prototype == spell then
                        e.SpellId.Prototype = usecontainer and container or name
                        e.SpellId.OriginatorPrototype = usecontainer and container or name

                        goto done
                    end
                end
            end

            :: done ::
            ent:Replicate( "HotbarContainer" )
        end
    end

    _F.UpdateText = function()
        Ext.Loca.UpdateTranslatedString(
            "h5153f9f3g7dcbg45d9gae1bgd19f398959a2",
            "Improve stability and become more adept at twin weapons.\n\n" ..
            "The Dual Wielding <LSTag Tooltip=\"AttackRoll\">Accuracy</LSTag> and <LSTag Tooltip=\"ArmourClass\">Armour Class</LSTag> penalties apply at " .. _V.TwoWeaponFighting * 100.0 .. "% of their normal effect."
        )
    end

    return _F
end