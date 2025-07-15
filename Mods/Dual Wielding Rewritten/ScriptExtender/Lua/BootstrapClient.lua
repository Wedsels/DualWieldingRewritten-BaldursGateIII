local _V = require( "Server.Variables" )
local _F = require( "Server.Functions" )( _V )

Ext.Events.StatsLoaded:Subscribe(
    function()
        local Sources = {
            Axe = Ext.StaticData.Get( "896f8a20-7dda-4bff-b726-08c3dacccc7b", "EquipmentType" ),
            Spear = Ext.StaticData.Get( "cb322434-365d-47bf-8357-e2f202dfb129", "EquipmentType" ),
            Staff = Ext.StaticData.Get( "b428632e-3137-47aa-ae8f-ddff6fc27cc8", "EquipmentType" ),
            Sword = Ext.StaticData.Get( "f85002a2-8e0e-4a49-aa0f-f52e987d3a3a", "EquipmentType" ),
            Hammer = Ext.StaticData.Get( "ab54402e-d3f3-497d-9b81-519b18afb827", "EquipmentType" )
        }

        for _,uuid in ipairs( Ext.StaticData.GetAll( "EquipmentType" ) ) do
            local data = Ext.StaticData.Get( uuid, "EquipmentType" )

            local one = data.WeaponType_OneHanded
            local two = data.WeaponType_TwoHanded

            local single = two:find( "1H" )

            local source
            if two == "Small1H" then
                source = Sources.Sword
            elseif two == "Polearm2H" or two == "Spear2H" then
                one = "Javelin1H"
                source = Sources.Spear
            elseif two == "Sword2H" then
                one = "Piercing1H"
                source = Sources.Spear
            elseif two == "Generic2H" then
                one = "Slashing1H"
                source = Sources.Sword
            elseif one == "Slashing1H" or one == "Small1H" then
                source = Sources.Sword
            elseif one == "Javelin1H" or one == "Slashing1H" or one == "Piercing1H" then
                source = Sources.Spear
            end

            if source then
                if two:find( "2H" ) then
                    data.BoneOffHandUnsheathed = source.BoneOffHandUnsheathed
                    data.BoneVersatileUnsheathed = source.BoneVersatileUnsheathed
                    data.SourceBoneVersatileSheathed = data.SourceBoneSheathed
                    data.SourceBoneVersatileUnsheathed = source.SourceBoneVersatileUnsheathed
                end

                data.WeaponType_OneHanded = one
                if data.BoneMainSheathed ~= "Dummy_Sheath_Hip_L" then
                    data.WeaponType_TwoHanded = single and "Sword2H" or data.WeaponType_TwoHanded
                end
            end

            if ( source or data.Name == "HandCrossbow" ) and single then
                data.BoneMainSheathed = "Dummy_Sheath_Hip_L"
                data.BoneOffHandSheathed = "Dummy_Sheath_Hip_R"
                data.BoneVersatileSheathed = "Dummy_Sheath_Hip_L"
            elseif source then
                data.BoneOffHandSheathed = source.BoneOffHandSheathed
                data.BoneVersatileSheathed = source.BoneVersatileSheathed
            end
        end

        for _,i in ipairs( Ext.Stats.GetStats( "Weapon" ) ) do
            local item = Ext.Stats.Get( i )

            local melee = false
            for _,p in ipairs( item[ "Weapon Properties" ] ) do
                if p == "Melee" or p == "Light" then
                    melee = true
                    item.BoostsOnEquipOffHand = item.BoostsOnEquipMainHand
                    item.PassivesOffHand = item.PassivesMainHand
                elseif p == "Versatile" then
                    goto continue
                end
            end

            if not melee then goto continue end

            local tbl = item[ "Weapon Properties" ]
            for _,p in ipairs( tbl ) do
                if p == "Twohanded" then
                    table.remove( tbl, _ )
                    break
                end
            end
            table.insert( tbl, "Versatile" )
            item[ "Weapon Properties" ] = tbl

            local count, die = item.Damage:match( "^(%d+)(d%d+)$" )
            local index = _F.Index( _V.Die, die )
            local damage
            local type = false
            if index then
                damage = _V.Die[ index + 1 ]
                if not damage then
                    damage = _V.Die[ index - 1 ]
                    type = true
                end
                damage = count .. damage
            else
                damage = item.Damage
            end
            if type then
                item.VersatileDamage = item.Damage
                item.Damage = damage
            else
                item.VersatileDamage = damage
            end

            :: continue ::
        end

        for name,type in pairs( _V.Spells ) do
            local spell = Ext.Stats.Get( name )

            spell.DualWieldingUseCosts = ""
            spell.TooltipDamageList = string.gsub( spell.TooltipDamageList, "Off", "Disabled" )
            spell.TooltipAttackSave = string.gsub( spell.TooltipAttackSave, "Off", "Disabled" )
            spell.DescriptionParams = string.gsub( spell.DescriptionParams, "Off", "Disabled" )

            local off = _F.CreateStat( name .. _V.Off, "SpellData", name )

            if type == false then
                spell.DualWieldingSpellAnimation =
                    "73afb4e5-8cfe-4479-95cf-16889597fee3,,;" ..
                    "7e67bfd0-2fc2-4d10-bed5-cfda9e660de5,,;" ..
                    "eb054308-7fce-4b85-bf4c-7a0031fda7ac,,;" ..
                    "0b0dc35b-4953-45c0-a9eb-8d3fef5e798a,,;" ..
                    "6ec808e1-e128-44ef-9361-a713bf86de8f,,;" ..
                    "b2e9c771-3497-444c-b360-23b4441985a1,,;" ..
                    "f920a0a6-f257-4ce4-8d17-2dcaa7bb7bbb,,;,,;,,"
                off.SpellAnimation =
                    "661cae72-6bc9-4e6d-98e2-89db9e03d6b5,,;" ..
                    "bf6ea370-a917-45b3-908d-35729c98db10,,;" ..
                    "4a789a60-04b8-4a26-b476-65cf26ca558b,,;" ..
                    "a11b8bcb-ba24-417a-aa86-4e4379c41ee2,,;" ..
                    "5eb39acc-ecbd-4940-84c8-a1e13668b865,,;,,;,,;,,;,,"
                off.DualWieldingSpellAnimation = off.SpellAnimation
                off.DisplayName = "h68d30360g0be4g4c36ga657geb25bdbb4daa;2"
            elseif type == true then
                spell.DualWieldingSpellAnimation =
                    "8b8bb757-21ce-4e02-a2f3-97d55cf2f90b,,;" ..
                    "6606c30b-be1c-4f17-ae6b-1a591c80b18c," ..
                    "366693ee-d97f-4294-a4dd-a2145ddc4e6a," ..
                    "9f2d32b9-529a-4b75-b3df-6e1ae1395280;" ..
                    "f4ac302b-1569-404f-bd52-1fe443e265df," ..
                    "479ee5da-2967-41e1-b7d1-a94e864a5f25," ..
                    "79323098-edb3-4993-ba50-9b5f705e9878;" ..
                    "e8a5c57f-855b-4227-acaa-11e8ce8d7d64," ..
                    "b5cb923d-0c08-4c20-89a9-44b9bf98c6cb," ..
                    "6282d127-0c06-4365-9d53-6f32ef350127;" ..
                    "7bb52cd4-0b1c-4926-9165-fa92b75876a3,,;" ..
                    "2b81c18b-9698-4262-a623-932c2bb1296d," ..
                    "ecbf9949-3b33-432c-b735-e47aaed0924a," ..
                    "e71a7c08-fdc1-4a0b-9a90-1c793c58553c;" ..
                    "0b07883a-08b8-43b6-ac18-84dc9e84ff50,,;,,;,,"
                off.SpellAnimation =
                    "8b8bb757-21ce-4e02-a2f3-97d55cf2f90b,,;" ..
                    "c1df9aea-8be9-4de3-bcbc-4e4c1e44dc37,,;" ..
                    "722df2d7-7898-4b0b-b930-5a850b55ccf0,,;" ..
                    "a693a7c3-e7e7-4edb-98dd-db5fd700663f,,;" ..
                    "7bb52cd4-0b1c-4926-9165-fa92b75876a3,,;" ..
                    "35f5cba8-3706-46d5-9a1e-2def9ba22473,,;" ..
                    "0b07883a-08b8-43b6-ac18-84dc9e84ff50,,;,,;,,"
                off.DualWieldingSpellAnimation = off.SpellAnimation
                off.DisplayName = "h3b04f82ag28deg481agb077gaacc255f4caf;1"
            end

            off.UseCosts = ""
            off.HitCosts = ""
            off.MemoryCost = 0
            off.RitualCosts = ""
            off.ContainerSpells = ""
            off.SpellContainerID = ""
            off.RequirementConditions = ""
            if off.RootSpellID and off.RootSpellID ~= "" then
                off.RootSpellID = off.RootSpellID .. _V.Off
            end
            if string.find( off.AlternativeCastTextEvents, "CastOffhand" ) then
                off.CastTextEvent = "CastOffhand"
            end

            local flags = spell.SpellFlags
            table.insert( flags, "CanDualWield" )
            spell.SpellFlags = flags

            for _,i in ipairs( flags ) do
                if i == "CanDualWield" or i == "IsLinkedSpellContainer" then
                    table.remove( flags, _ )
                end
            end
            off.SpellFlags = flags

            off.TooltipDamageList = _F.MainOff( off.TooltipDamageList, false )
            off.TooltipAttackSave = _F.MainOff( off.TooltipAttackSave, false )
            off.DescriptionParams = _F.MainOff( off.DescriptionParams, false )

            spell.TooltipDamageList = _F.MainOff( spell.TooltipDamageList, true )
            spell.TooltipAttackSave = _F.MainOff( spell.TooltipAttackSave, true )
            spell.DescriptionParams = _F.MainOff( spell.DescriptionParams, true )
        end

        local base = Ext.Stats.Create( _V.Status().Base, "StatusData" )
        base.StatusType = "BOOST"
        base.Icon = "PassiveFeature_MartialAdept"
        base.DisplayName = "h67baff50fc6f4d6987de105926be4a5aef2a;1"
        base.Description = "hae35af5067ca4c2cbd184564272886c9d169;1"
        base.Boosts = "TwoWeaponFighting()"
        base.StackId = base.Name
        base.StatusPropertyFlags = { "DisableOverhead", "DisableCombatlog", "IgnoreResting" }
    end
)