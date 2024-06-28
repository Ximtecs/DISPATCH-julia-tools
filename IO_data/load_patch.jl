include("helper_functions.jl")
include("../misc/IDX_conversing.jl")


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


#---------------- load a single variable for a single patch ----------------
function load_patch_var(Snapshot_meta::Snapshot_metadata, patch_ID::Int, var :: String)
    patch_size = get_integer_patch_size(Snapshot_meta)
    # Find the index of the patch with the given ID
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)

    NV = Snapshot_meta.SNAPSHOT.NV
    IDX = Snapshot_meta.IDX

    #------ index of the variable -------------------------
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------

    #----- size of each patch -------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    #----- size of each variable -------------------------
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------

    data_file = Snapshot_meta.PATCHES[index].DATA_FILE

    # Create a vector to store the single variable data
    var_data = Vector{Float32}(undef, total_var_size)

    f = open(data_file,"r")
    # Move pointer to the start of the data for the patch
    if index > 1 
        seek(f, position(f) + total_size_in_bytes * (index - 1))
    end
    # Move pointer to the start of the data for the variable
    if iv > 1 
        seek(f, position(f) + total_var_size_in_bytes * (iv - 1))
    end
    # Read the data for the single variable
    read!(f, var_data)
    close(f)

    var_data = reshape(var_data, patch_size...)
    return var_data
end
#--------------------------------------------------------------------------------


#---------------- load a single variable for multiple patches ----------------
function load_patches_var(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int}, var::String)

    #-------------- If only 1 ID is given, just use load_patch_var function ----------------
    if length(patch_IDs) == 1
        var_data = load_patch_var(Snapshot_meta, patch_IDs[1], var)
        return [var_data]
    end
    #--------------------------------------------------------------------------------------------

    #----------- find data position index for each patch ----------------
    indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in patch_IDs]
    #-------------------------------------------------------------------
    
    NV = Snapshot_meta.SNAPSHOT.NV
    IDX = Snapshot_meta.IDX

    #------ index of the variable -------------------------
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------

    #----- size of each patch -------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    #----- size of each variable -------------------------
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------

    #----------------- initialize the data array -------------------------    
    all_data = []
    #---------------------------------------------------------------------

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        for patch_ID in patch_IDs
            var_data = load_patch_var(Snapshot_meta, patch_ID, var)
            push!(all_data, var_data)
        end

        return all_data
    end
    #--------------------------------------------------------------------------------------------

    #------- If patches have same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches

    #----------------------------------------------------------------------
    patch_size = get_integer_patch_size(Snapshot_meta)

    #-------------- Sort the indices in ascending order ----------------
    sorted_indices = sortperm(indices)
    indices = indices[sorted_indices]
    #--------------------------------------------------------------------

    #------------ find the difference between the indices ----------------
    #            This is used to move the pointer in the file
    index_diff = zeros(Int, length(indices))
    index_diff[1] = indices[1] - 1
    for i in 2:length(indices)
        index_diff[i] = indices[i] - indices[i-1]
    end
    #---------------------------------------------------------------------

    data_file = data_files[1]
    f = open(data_file, "r")
    for i in 1:length(indices)
        var_data = Vector{Float32}(undef, total_var_size)

        if (index_diff[i] - 1 > 0)
            # Move pointer to the next position in the file
            seek(f, position(f) + total_size_in_bytes * (index_diff[i] - 1))
        end

        # Move pointer to the start of the data for the variable
        if iv > 1
            seek(f, position(f) + total_var_size_in_bytes * (iv - 1))
        end
        # Read the data for the single variable
        read!(f, var_data)


        #-------- move pointer to the start of the next patch ----------------
        if iv < NV
            seek(f, position(f) + total_var_size_in_bytes * (NV - iv))
        end 
        #----------------------------------------------------------------


        var_data = reshape(var_data, patch_size...)
        push!(all_data, var_data)
    end
    close(f)
    #--------------------------------------------

    #---------- to get the correct order of the patches ----------------
    all_data = all_data[sorted_indices]
    #-------------------------------------------------------------------

    return all_data
end
#--------------------------------------------------------------------------------
