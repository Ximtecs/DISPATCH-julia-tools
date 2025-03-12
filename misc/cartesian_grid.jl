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


    #-------------- Gets the x, y, z coordinates of the cell centers
    x_range = collect(range(ORIGIN[1] + 0.5 * ds[1], stop=ORIGIN[1] + BOX[1] - 0.5*ds[1], length=mem_size[1]))
    y_range = collect(range(ORIGIN[2] + 0.5 * ds[2], stop=ORIGIN[2] + BOX[2] - 0.5*ds[2], length=mem_size[2]))
    z_range = collect(range(ORIGIN[3] + 0.5 * ds[3], stop=ORIGIN[3] + BOX[3] - 0.5*ds[3], length=mem_size[3]))

    for i in 1:mem_size[1]
        for j in 1:mem_size[2]
            for k in 1:mem_size[3]
                x[i,j,k] = x_range[i]
                y[i,j,k] = y_range[j]
                z[i,j,k] = z_range[k]
            end
        end
    end
            
    if drop_dims
        x = drop_unit_dims(x)
        y = drop_unit_dims(y)
        z = drop_unit_dims(z)
    end


    return x, y, z, ds
end 


function get_xyz(Snapshot_meta :: Snapshot_metadata, drop_dims :: Bool, level :: Int)
    BOX = Snapshot_meta.SNAPSHOT.BOX
    ORIGIN = Snapshot_meta.SNAPSHOT.ORIGIN

    #-------- assumes no AMR 

    found_level = false
    i = 1
    while (! found_level)
        patch_level = Snapshot_meta.PATCHES[i].LEVEL
        if patch_level == level
            found_level = true
        else
            i += 1
        end
    end
    ds = Snapshot_meta.PATCHES[i].DS

    mem_size = get_mem_size(Snapshot_meta, level)[1:3]

    x = zeros(mem_size...)
    y = zeros(mem_size...)
    z = zeros(mem_size...)


    #-------------- Gets the x, y, z coordinates of the cell centers
    if mem_size[1] > 1
    x_range = collect(range(ORIGIN[1] + 0.5 * ds[1], stop=ORIGIN[1] + BOX[1] - 0.5*ds[1], length=mem_size[1]))
    else 
        x_range = [ORIGIN[1] + 0.5 * ds[1]]
    end
    if mem_size[2] > 1
    y_range = collect(range(ORIGIN[2] + 0.5 * ds[2], stop=ORIGIN[2] + BOX[2] - 0.5*ds[2], length=mem_size[2]))
    else
        y_range = [ORIGIN[2] + 0.5 * ds[2]]
    end
    if mem_size[3] > 1
    z_range = collect(range(ORIGIN[3] + 0.5 * ds[3], stop=ORIGIN[3] + BOX[3] - 0.5*ds[3], length=mem_size[3]))
    else
        z_range = [ORIGIN[3] + 0.5 * ds[3]]
    end


    for i in 1:mem_size[1]
        for j in 1:mem_size[2]
            for k in 1:mem_size[3]
                x[i,j,k] = x_range[i]
                y[i,j,k] = y_range[j]
                z[i,j,k] = z_range[k]
            end
        end
    end
            
    if drop_dims
        x = drop_unit_dims(x)
        y = drop_unit_dims(y)
        z = drop_unit_dims(z)
    end


    return x, y, z, ds
end 