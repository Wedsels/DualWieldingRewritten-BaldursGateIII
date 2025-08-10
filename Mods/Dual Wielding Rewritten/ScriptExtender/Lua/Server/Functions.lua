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

            if next( equip.Returns ) then
                Osi.SetWeaponUnsheathed( uuid, 0, 1 )
            end
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

    _F.Status = function( uuid )
        local Check
        Check = function( type, status )
            local wield = _V.Duals[ uuid ]
            local ent = Ext.Entity.Get( uuid )
            if not wield or not ent then return end

            local two = Osi.HasPassive( uuid, "FightingStyle_TwoWeaponFighting" ) == 1

            local statuses = {}

            if status == "Base" then
                statuses = { _V.Status().Base }
            elseif status == "Penalty" then
                local s = _V.Status( wield.Equip.Ranger and math.max( wield.Equip.RangedMain, wield.Equip.RangedOffhand ) or math.max( wield.Equip.MeleeMain, wield.Equip.MeleeOffhand ) )
                statuses = wield.Equip.Ranger and ( two and { s.PenaltyTwoWeaponRanged } or { s.PenaltyRanged } ) or ( two and { s.PenaltyTwoWeaponMelee } or { s.PenaltyMelee } )
            elseif status == "Melee" then
                local m = _V.Status( wield.Equip.MeleeMain )
                local o = _V.Status( wield.Equip.MeleeOffhand )
                statuses = two and { m.MeleeTwoWeaponMain, o.MeleeTwoWeaponOff } or { m.MeleeMain, o.MeleeOff }
            elseif status == "Ranged" then
                local m = _V.Status( wield.Equip.RangedMain )
                local o = _V.Status( wield.Equip.RangedOffhand )
                statuses = two and { m.RangedTwoWeaponMain, o.RangedTwoWeaponOff } or { m.RangedMain, o.RangedOff }
            end

            if type == 1 and wield.Status[ status ] then
                local all = true
                for i,n in ipairs( statuses ) do
                    if wield.Status[ status ][ i ] ~= n then
                        all = false
                        break
                    end
                end
                if all then return end
            end

            if type == 0 and wield.Status[ status ] then
                Check( 2, status )
                Ext.Timer.WaitFor( 500, function() Check( 1, status ) end )
            elseif type == 1 then
                for _,s in ipairs( statuses ) do
                    Osi.ApplyStatus( uuid, s, -1 )
                end

                wield.Status[ status ] = statuses
            elseif type == 2 and wield.Status[ status ] then
                for _,s in ipairs( wield.Status[ status ] ) do
                    Osi.RemoveStatus( uuid, s )
                end

                wield.Status[ status ] = nil
            end
        end

        local function Apply( status )
            return {
                Update = function() Check( 0, status ) end,
                Apply = function() Check( 1, status ) end,
                Remove = function() Check( 2, status ) end
            }
        end

        return {
            Base = Apply( "Base" ),
            Penalty = Apply( "Penalty" ),
            Melee = Apply( "Melee" ),
            Ranged = Apply( "Ranged" )
        }
    end

    _F.RemoveSpells = function( uuid )
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

    _F.RemoveDualEffects = function( uuid )
        _F.Status( uuid ).Penalty.Remove()
        _F.RemoveSpells( uuid )
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
            roll[ "CastOffhand" ] = roll[ "Default" ] or roll[ "Cast" ]
            spell.SpellRoll = roll
        end
        if spell.SpellProperties then
            for _,p in ipairs( spell.SpellProperties ) do
                -- if p.TextKey == "CastOffhand" then
                --     p.TextKey = "Default"
                -- else
                    for _,f in ipairs( p.Functors ) do
                        f.FunctorUuid = _F.GenerateUUID()
                        pcall( function() f.WeaponType = _F.MainOff( f.WeaponType, type ) end )
                        pcall( function() if f.ProjectileSpell == name then f.ProjectileSpell = name .. _V.Off end end )
                    end
                -- end
            end
        end
        if spell.SpellSuccess then
            for _,e in ipairs( spell.SpellSuccess ) do
                -- if e.TextKey == "CastOffhand" then
                --     e.TextKey = "Default"
                -- else
                    for _,i in ipairs( e.Functors ) do
                        pcall( function() i.WeaponType = _F.MainOff( i.WeaponType, type ) end )
                    end
                -- end
            end
        end
        -- if spell.SpellFail then
        --     for _,e in ipairs( spell.SpellFail ) do
        --         if e.TextKey == "CastOffhand" then
        --             e.TextKey = "Default"
        --         end
        --     end
        -- end

        spell:Sync()
    end

    _F.CheckDualStatus = function( uuid )
        local ent = Ext.Entity.Get( uuid )
        if not ent then return end
        local dual = ent:GetComponent( "DualWielding" )
        if not dual then return end

        if not _V.Duals[ uuid ] then
            _V.Duals[ uuid ] = {
                Ranged = false,
                Melee = false,
                Time = -1,
                Status = {},
                Data = {},
                Equip = {
                    Ranger = false,
                    Melee = {},
                    MeleeMain = 0,
                    MeleeOffhand = 0,
                    Ranged = {},
                    RangedMain = 0,
                    RangedOffhand = 0,
                    Returns = {}
                },
                Generate = true
            }
        end

        local d = _V.Duals[ uuid ]

        local rangemain = Osi.GetEquippedItem( uuid, "Ranged Main Weapon" )
        d.Equip.Ranger = rangemain == Osi.GetEquippedWeapon( uuid )

        for _,w in ipairs( { "Melee", "Ranged" } ) do
            for _,h in ipairs( { "Main", "Offhand" } ) do
                local data = Ext.Entity.Get( Osi.GetEquippedItem( uuid, w .. " " .. h .. " Weapon" ) )
                local weapon = data and data.Data and Ext.Stats.Get( data.Data.StatsId )
                if weapon then
                    d.Equip[ w .. h ] = weapon.Weight
                else
                    d.Equip[ w .. h ] = 0
                end
            end
        end

        _F.Status( uuid ).Base.Apply()

        for _,i in ipairs( { "Ranged", "Melee" } ) do
            if not dual[ i .. "UI" ] then
                d[ i ] = false
                dual[ i .. "ToggledOn" ] = false
            else
                d[ i ] = dual[ i .. "ToggledOn" ]
            end

            if d[ i ] then
                _F.Status( uuid )[ i ].Apply()
            else
                _F.Status( uuid )[ i ].Remove()
            end
        end

        if d.Melee or d.Ranged then
            _F.Status( uuid ).Base.Apply()
        else
            _F.Status( uuid ).Base.Remove()
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

    _F.CreateStatuses = function()
        local function stat( weight, boost, twoweapon )
            weight = 1.5 + weight * 3
            weight = math.floor( weight + 0.5 )
            weight = weight * _V.Penalty
            if twoweapon then
                weight = weight * _V.TwoWeaponFighting
            end

            return boost .. " " .. string.format( "%.0f", -weight ) .. " )"
        end

        for _,n in ipairs( Ext.Stats.GetStats( "Weapon" ) ) do
            local item = Ext.Stats.Get( n )
            local weight = item.Weight

            if weight then
                local w = _V.Status( weight )
                for key,val in pairs( w ) do
                    w[ key ] = _F.CreateStat( val, "StatusData" )
                end

                for _,i in ipairs( { w.PenaltyMelee, w.PenaltyRanged, w.PenaltyTwoWeaponMelee, w.PenaltyTwoWeaponRanged } ) do
                    i.StatusType = "BOOST"
                    i.Icon = "statIcons_OffBalanced"
                    i.DisplayName = "h548f722ed45a4f2884dbb90e778e1fb4e12d"
                    i.Description = "h6568bed6a92f4137ab6dfcf00d93ef6ad603"
                    i.StillAnimationType = "Weakened"
                    i.StillAnimationPriority = "Weakened"
                    i.RemoveEvents = { "OnAttacked" }
                    i.RemoveConditions = "IsAttack() and HasDamageEffectFlag( DamageFlags.Hit )"
                    i.StackId = "DWRPenalty"
                    i.StatusGroups = { "SG_Helpable_Condition" }
                end

                for _,i in ipairs( { w.MeleeMain, w.MeleeOff, w.MeleeTwoWeaponMain, w.MeleeTwoWeaponOff, w.RangedMain, w.RangedOff, w.RangedTwoWeaponMain, w.RangedTwoWeaponOff } ) do
                    i.StatusType = "BOOST"
                    i.StatusPropertyFlags = { "DisableOverhead", "DisableCombatlog", "DisablePortraitIndicator", "IgnoreResting" }
                    i.DisplayName = i.Name:find( "TwoWeapon" ) and "h67baff50fc6f4d6987de105926be4a5aef2a" or "h4b5c93a924be436fb848aba0569c02035cg3"
                    i.StackId = "DWR" .. ( i.Name:find( "Melee" ) and "Melee" or "Ranged" ) .. ( i.Name:find( "Main" ) and "Main" or "Off" )
                end

                w.PenaltyMelee.Boosts = stat( weight, "AC(" )
                w.PenaltyRanged.Boosts = stat( weight, "AC(" )

                w.PenaltyTwoWeaponMelee.Boosts = stat( weight, "AC(", true )
                w.PenaltyTwoWeaponRanged.Boosts = stat( weight, "AC(", true )

                w.MeleeMain.Boosts = stat( weight, "RollBonus( MeleeWeaponAttack," )
                w.MeleeOff.Boosts = stat( weight, "RollBonus( MeleeOffHandWeaponAttack," )

                w.MeleeTwoWeaponMain.Boosts = stat( weight, "RollBonus( MeleeWeaponAttack,", true )
                w.MeleeTwoWeaponOff.Boosts = stat( weight, "RollBonus( MeleeOffHandWeaponAttack,", true )

                w.RangedMain.Boosts = stat( weight, "RollBonus( RangedWeaponAttack," )
                w.RangedOff.Boosts = stat( weight, "RollBonus( RangedOffHandWeaponAttack," )

                w.RangedTwoWeaponMain.Boosts = stat( weight, "RollBonus( RangedWeaponAttack,", true )
                w.RangedTwoWeaponOff.Boosts = stat( weight, "RollBonus( RangedOffHandWeaponAttack,", true )

                for _,val in pairs( w ) do
                    --- @diagnostic disable-next-line: undefined-field
                    val:Sync()
                end
            end
        end
    end

    _F.UpdateText = function()
        Ext.Loca.UpdateTranslatedString(
            "h5153f9f3g7dcbg45d9gae1bgd19f398959a2",
            "Improve stability and become more adept at twin weapons.\n\n" ..
            "The dual-wielding <LSTag Tooltip=\"AttackRoll\">Accuracy</LSTag> and <LSTag Tooltip=\"ArmourClass\">Armour Class</LSTag> penalties apply at " .. string.format( "%.0f", _V.TwoWeaponFighting * 100.0 ) .. "% of their normal effect."
        )
    end

    return _F
end