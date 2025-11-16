--- @class _V
local _V = {}

_V.Off = "_DualOffHand"
_V.Key = "DualWieldingBalance"
_V.Die = { "d4", "d6", "d8", "d10", "d12" }
_V.Penalty = 1.0
_V.TwoWeaponFighting = 0.33
_V.LostFooting = true

--- @class Data
--- @field Charge number
--- @field Time number

--- @class Equip
--- @field Ranger boolean
--- @field MeleeMain number
--- @field MeleeOffhand number
--- @field RangedMain number
--- @field RangedOffhand number
--- @field Melee table< userdata, userdata >
--- @field Ranged table< userdata, userdata >
--- @field Returns table< userdata >

--- @class Wield
--- @field Ranged boolean
--- @field Melee boolean
--- @field Time number
--- @field Equip Equip
--- @field Status table < string, table< string > >
--- @field Data table < string, Data >
--- @field Generate boolean

--- @type table< string, Wield >
_V.Duals = {}

--- @type table < string, boolean >
_V.Spells = {}
for _,name in pairs( Ext.Stats.GetStats( "SpellData" ) ) do
    local spell = Ext.Stats.Get( name )

    if not string.find( name, "AttackOfOpportunity" ) and not spell.InterruptPrototype or spell.InterruptPrototype == "" and string.sub( name, -#_V.Off ) ~= _V.Off and tostring( spell.CastTextEvent ) ~= "CastOffhand" then
        local type
        local val
        if spell.SpellType == "Projectile" then
            type = "Ammunition"
            val = false
        elseif spell.SpellType == "Target" then
            type = "Melee"
            val = true
        end

        if type then
            for _,weapon in ipairs( spell.WeaponTypes ) do
                if weapon == type then
                    _V.Spells[ name ] = val
                    break
                end
            end
        end
    end
end

_V.Status = function( weight )
    weight = weight or 0
    local base = "RewrittenDualWielding"
    return {
        Base = base,
        PenaltyMelee = base .. "LostFootingMelee" .. weight,
        PenaltyRanged = base .. "LostFootingRanged" .. weight,
        PenaltyTwoWeaponMelee = base .. "LostFootingTwoWeaponMelee" .. weight,
        PenaltyTwoWeaponRanged = base .. "LostFootingTwoWeaponRanged" .. weight,
        MeleeMain = base .. "MeleeMain" .. weight,
        RangedMain = base .. "RangedMain" .. weight,
        MeleeOff = base .. "MeleeOff" .. weight,
        RangedOff = base .. "RangedOff" .. weight,
        MeleeTwoWeaponMain = base .. "MeleeTwoWeaponMain" .. weight,
        RangedTwoWeaponMain = base .. "RangedTwoWeaponMain" .. weight,
        MeleeTwoWeaponOff = base .. "MeleeTwoWeaponOff" .. weight,
        RangedTwoWeaponOff = base .. "RangedTwoWeaponOff" .. weight
    }
end

--- @type table< number, boolean >
_V.Weights = {}

return _V