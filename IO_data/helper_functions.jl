include("../IO/Snapshot_meta_structs.jl")

#---------- Get the number of points in each patch - this depends on the presence of guard zones ----------------
function get_integer_patch_size(Snapshot_meta :: Snapshot_metadata)
    #---------------- number of points in each patch depends on the presence of guard zones ----------------
    Guard_zones = Snapshot_meta.IO.GUARD_ZONES
    if Guard_zones
        patch_size = Snapshot_meta.SNAPSHOT.GN
    else
        patch_size = Snapshot_meta.SNAPSHOT.N
    end
    #--------------------------------------------------------------------------------------------------------
    return patch_size
end
#--------------------------------------------------------------------------------


#----------------- Get size of memory array to store all patches for a single snapshot ----------------
function get_mem_size(Snapshot_meta :: Snapshot_metadata)
    patch_size = get_integer_patch_size(Snapshot_meta)
    patch_size = [Int(patch) for patch in patch_size]
    #n_patches = Snapshot_meta.n_patches
    Box_size = Snapshot_meta.SNAPSHOT.BOX

    patch_float_size = Snapshot_meta.PATCHES[1].SIZE
    patches_per_box = Box_size ./ patch_float_size

    patches_per_box = [Int(patch) for patch in patches_per_box]
    
    mem_size = [1,1,1,1]

    for i in 1:3
        if patch_size[i] > 1
            mem_size[i] = patch_size[i] * patches_per_box[i]
        end
    end
    mem_size[4] = Snapshot_meta.SNAPSHOT.NV

    return mem_size
end
#--------------------------------------------------------------------------------



#----------------- Get the offset in memory for a given patch ----------------
function get_patch_mem_offset(Snapshot_meta :: Snapshot_metadata, patch_params :: Patch_NML)
    Box_origin = Snapshot_meta.SNAPSHOT.ORIGIN
    patch_float_size = patch_params.SIZE

    # Calculate the size of each patch in integer units
    patch_int_size = get_integer_patch_size(Snapshot_meta)

    # Calculate the position of the lower left corner (LLC) of the patch relative to the origin
    position_relative_to_origin = patch_params.LLC_NAT .- Box_origin

    # Calculate the offset of the patch in terms of the number of patches from the origin
    patches_offset = floor.(position_relative_to_origin ./ patch_float_size)

    # Calculate the memory offset by multiplying the patches offset by the size of each patch in integer units
    mem_offset = Int.(patches_offset .* patch_int_size .+ 1)

    return mem_offset
end
#--------------------------------------------------------------------------------



#--------- Get the size of the memory array to store a single patch  ---------
function get_patch_size(Snapshot_meta :: Snapshot_metadata)
    patch_size = get_integer_patch_size(Snapshot_meta)
    total_size = prod(patch_size) * Snapshot_meta.SNAPSHOT.NV 
    size_in_bytes = total_size* sizeof(Float32)
    return total_size, size_in_bytes
end
#--------------------------------------------------------------------------------