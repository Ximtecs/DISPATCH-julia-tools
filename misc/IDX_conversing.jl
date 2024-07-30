include("../IO/Snapshot_meta_structs.jl")


function get_idx_value(idx::IDX_NML, key::String)
    # Dictionary to map input strings to field names
    field_map = Dict(
        "D" => :D, "d" => :D, "rho" => :D, "density" => :D, "Density" => :D, "mass density" => :D, "Mass Density" => :D,
        "E" => :E, "e" => :E, "energy" => :E, "Energy" => :E, "energy density" => :E, "Energy Density" => :E,
        "ET" => :ET, "total energy" => :ET, "Total Energy" => :ET, "total energy density" => :ET, "Total Energy Density" => :ET,
        "S" => :S, "entropy" => :S, "Entropy" => :S,
        "PX" => :PX, "px" => :PX, "mom_x" => :PX, "mom x" => :PX, "momentum x" => :PX, "Momentum X" => :PX, "momentum x component" => :PX, "Momentum X Component" => :PX,
        "PY" => :PY, "py" => :PY, "mom_y" => :PX, "mom y" => :PX, "momentum y" => :PY, "Momentum Y" => :PY, "momentum y component" => :PY, "Momentum Y Component" => :PY,
        "PZ" => :PZ, "pz" => :PZ, "mom_z" => :PX, "mom z" => :PX, "momentum z" => :PZ, "Momentum Z" => :PZ, "momentum z component" => :PZ, "Momentum Z Component" => :PZ,
        "BX" => :BX, "Bx" => :BX, "bx" => :BX, "magnetic field x" => :BX, "Magnetic Field X" => :BX, "magnetic field x component" => :BX, "Magnetic Field X Component" => :BX,
        "BY" => :BY, "By" => :BY, "by" => :BY, "magnetic field y" => :BY, "Magnetic Field Y" => :BY, "magnetic field y component" => :BY, "Magnetic Field Y Component" => :BY,
        "BZ" => :BZ, "Bz" => :BZ, "bz" => :BZ, "magnetic field z" => :BZ, "Magnetic Field Z" => :BZ, "magnetic field z component" => :BZ, "Magnetic Field Z Component" => :BZ,
        "QR" => :QR,
        "TT" => :TT,
        "PHI" => :PHI, "phi" => :PHI,
        "P1" => :P1,
        "P2" => :P2,
        "P3" => :P3,
        "B1" => :B1,
        "B2" => :B2,
        "B3" => :B3,
        "EX" => :EX, "Ex" => :EX, "ex" => :EX, "electric field x" => :EX, "Electric Field X" => :EX, "electric field x component" => :EX, "Electric Field X Component" => :EX,
        "EY" => :EY, "Ey" => :EY, "ey" => :EY, "electric field y" => :EY, "Electric Field Y" => :EY, "electric field y component" => :EY, "Electric Field Y Component" => :EY,
        "EZ" => :EZ, "Ez" => :EZ, "ez" => :EZ, "electric field z" => :EZ, "Electric Field Z" => :EZ, "electric field z component" => :EZ, "Electric Field Z Component" => :EZ,
        "JX" => :JX, "Jx" => :JX, "jx" => :JX, "current density x" => :JX, "Current Density X" => :JX, "current density x component" => :JX, "Current Density X Component" => :JX,
        "JY" => :JY, "Jy" => :JY, "jy" => :JY, "current density y" => :JY, "Current Density Y" => :JY, "current density y component" => :JY, "Current Density Y Component" => :JY,
        "JZ" => :JZ, "Jz" => :JZ, "jz" => :JZ, "current density z" => :JZ, "Current Density Z" => :JZ, "current density z component" => :JZ, "Current Density Z Component" => :JZ,
        "RPHI" => :RPHI
    )
    
    # Convert the key to the corresponding field name
    if haskey(field_map, key)
        field_name = field_map[key]
        return getfield(idx, field_name)
    else
        error("Invalid key: $key")
    end
end