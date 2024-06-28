include("helper_functions.jl")


#---------- Functions to get information from a single patch or an array of patches from a single snapshot -------------




#----------------- Load all varialbes for a single patch ----------------
function load_patch_data(Snapshot_meta :: Snapshot_metadata, patch_ID :: Int)

    patch_size = get_integer_patch_size(Snapshot_meta)
    #---------- find the index of the patch with the given ID ----------------
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    #-------------------------------------------------------------------------

    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    data_file = Snapshot_meta.PATCHES[index].DATA_FILE
    data = Vector{Float32}(undef, total_size)

    #----------------------------------------------------------------------
    f = open(data_file,"r")
    #---------- move pointer to the correct position in the file ---------------
    seek(f, position(f) + total_size_in_bytes * (index - 1))
    #------------------------------------------------------------------------------
    #------------ read the data from the file ----------------
    read!(f, data)
    #----------------------------------------------------------------
    close(f)
    #--------------------------------------------

    data = reshape(data, patch_size..., Snapshot_meta.SNAPSHOT.NV)
    return data
end
#--------------------------------------------------------------------------------


#----------------- Load all varialbes for a single patch ----------------
function load_patches_data(Snapshot_meta :: Snapshot_metadata, patch_IDs::Vector{Int})

    #-------------- If only 1 ID is given, just use load_patch_data function ----------------
    if length(patch_IDs) == 1
        patch_data = load_patch_data(Snapshot_meta, patch_IDs[1])
        return [patch_data]
    end
    #--------------------------------------------------------------------------------------------


    #----------- find data position index for each patch ----------------
    indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in patch_IDs]
    #-------------------------------------------------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    
    #----------------- initialize the data array -------------------------    
    all_data = []
    #---------------------------------------------------------------------

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_data function"
        for patch_ID in patch_IDs
            patch_data = load_patch_data(Snapshot_meta, patch_ID)
            push!(all_data, patch_data)
        end

        return all_data
    end
    #--------------------------------------------------------------------------------------------


    #------- If patches have same data file laod them all together -------------------
    #        Here we only have to open the file once and read all the patches

    #----------------------------------------------------------------------
    patch_size = get_integer_patch_size(Snapshot_meta)

    #-------------- Sort the indices in acesending order ----------------
    sorted_indices = sortperm(indices)
    indices = indices[sorted_indices]
    #--------------------------------------------------------------------

    #------------ find the difference between the indices ----------------
    #            This is used to move the pointer in the file
    index_diff = zeros(Int, length(indices))
    index_diff[1] = indices[1] - 1.
    for i in 2:length(indices)
        index_diff[i] = indices[i] - indices[i-1]
    end
    #---------------------------------------------------------------------

    
    data_file = data_files[1]
    f = open(data_file,"r")
    for i in 1:length(indices)
        index = indices[i]
        data = Vector{Float32}(undef, total_size)
        if (index_diff[i] - 1 > 0)
            #---------- move pointer to the next position in the file ---------------
            seek(f, position(f) + total_size_in_bytes * (index_diff[i] - 1))
            #------------------------------------------------------------------------------
        end
        #------------ read the data from the file ----------------
        read!(f, data)
        #----------------------------------------------------------------
        data = reshape(data, patch_size..., Snapshot_meta.SNAPSHOT.NV)
        push!(all_data, data)

    end
    close(f)
    #--------------------------------------------

    #---------- to get the correct order of the patches ----------------
    all_data = all_data[sorted_indices]
    #-------------------------------------------------------------------

    return all_data
end
#--------------------------------------------------------------------------------