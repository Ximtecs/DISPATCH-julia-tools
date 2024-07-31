include("drop_unit_dims.jl")

function get_xyz(Snapshot_meta :: Snapshot_metadata, drop_dims :: Bool)
    BOX = Snapshot_meta.SNAPSHOT.BOX
    ORIGIN = Snapshot_meta.SNAPSHOT.ORIGIN

    #-------- assumes no AMR 
    ds = Snapshot_meta.PATCHES[1].DS

    mem_size = get_mem_size(Snapshot_meta)[1:3]

    x = zeros(mem_size...)
    y = zeros(mem_size...)
    z = zeros(mem_size...)

    x[:,:,:] .= collect(range(ORIGIN[1] + 0.5 * ds[1], stop=ORIGIN[1] + BOX[1] - 0.5*ds[1], length=mem_size[1]))
    y[:,:,:] .= collect(range(ORIGIN[2] + 0.5 * ds[2], stop=ORIGIN[2] + BOX[2] - 0.5*ds[2], length=mem_size[2]))
    z[:,:,:] .= collect(range(ORIGIN[3] + 0.5 * ds[3], stop=ORIGIN[3] + BOX[3] - 0.5*ds[3], length=mem_size[3]))
            
    if drop_dims
        x = drop_unit_dims(x)
        y = drop_unit_dims(y)
        z = drop_unit_dims(z)
    end


    return x, y, z, ds
end 