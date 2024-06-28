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


#----------------- Load all variables for multiple patches ----------------
function load_patches_data(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int})

    NV = Snapshot_meta.SNAPSHOT.NV

    #-------------- If only 1 ID is given, just use load_patch_data function ----------------
    if length(patch_IDs) == 1
        patch_data = load_patch_data(Snapshot_meta, patch_IDs[1])
        return reshape(patch_data, size(patch_data)..., NV, 1)
    end
    #--------------------------------------------------------------------------------------------

    #----------- find data position index for each patch ----------------
    indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in patch_IDs]
    #-------------------------------------------------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    
    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    all_data = Array{Float32}(undef, patch_size..., NV, length(patch_IDs))
    #---------------------------------------------------------------------

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_data function"
        for (i, patch_ID) in enumerate(patch_IDs)
            patch_data = load_patch_data(Snapshot_meta, patch_ID)
            all_data[:,:,:,:, i] = patch_data
        end

        return all_data
    end
    #--------------------------------------------------------------------------------------------

    #------- If patches have the same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches

    #-------------- Sort the indices in ascending order ----------------
    sorted_indices = sortperm(indices)
    indices = indices[sorted_indices]
    #--------------------------------------------------------------------

    #------------ find the difference between the indices ----------------
    #            This is used to move the pointer in the file
    index_diff = [indices[1]; diff(indices)]
    #---------------------------------------------------------------------

    data_file = data_files[1]
    f = open(data_file, "r")
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
        patch_data = reshape(data, patch_size..., NV)
        all_data[:,:,:,:, i] = patch_data
    end
    close(f)
    #--------------------------------------------

    #---------- to get the correct order of the patches ----------------
    all_data = all_data[:,:,:,:, sorted_indices]
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
        return reshape(var_data, size(var_data)..., 1)
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
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV), Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------

    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    all_data = Array{Float32}(undef, patch_size..., length(patch_IDs))
    #---------------------------------------------------------------------

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        for (i, patch_ID) in enumerate(patch_IDs)
            var_data = load_patch_var(Snapshot_meta, patch_ID, var)
            all_data[:, :, :, i] = var_data
        end

        return all_data
    end
    #--------------------------------------------------------------------------------------------

    #------- If patches have same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches

    #-------------- Sort the indices in ascending order ----------------
    sorted_indices = sortperm(indices)
    indices = indices[sorted_indices]
    #--------------------------------------------------------------------

    #------------ find the difference between the indices ----------------
    #            This is used to move the pointer in the file
    index_diff = [indices[1]; diff(indices)]
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
        all_data[:, :, :, i] = var_data
    end
    close(f)
    #--------------------------------------------

    #---------- to get the correct order of the patches ----------------
    all_data = all_data[:, :, :, sorted_indices]
    #-------------------------------------------------------------------

    return all_data
end
#--------------------------------------------------------------------------------


#---------------- load multiple variables for a single patch ----------------
function load_patch_vars(Snapshot_meta::Snapshot_metadata, patch_ID::Int, vars::Vector{String})
    patch_size = get_integer_patch_size(Snapshot_meta)
    # Find the index of the patch with the given ID
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)

    NV = Snapshot_meta.SNAPSHOT.NV
    IDX = Snapshot_meta.IDX

    #------ indices of the variables -------------------------
    ivs = [get_idx_value(IDX, var) for var in vars]
    #----------------------------------------------------

    #----- size of each patch -------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    #----- size of each variable -------------------------
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV), Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------

    data_file = Snapshot_meta.PATCHES[index].DATA_FILE

    #----------------- initialize the data array -------------------------    
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = Vector{Float32}(undef, total_var_size)
    end
    #---------------------------------------------------------------------

    # Sort the ivs and get the sorted variables
    sorted_iv_indices = sortperm(ivs)
    sorted_ivs = ivs[sorted_iv_indices]
    sorted_vars = vars[sorted_iv_indices]

    # Calculate the differences between the sorted ivs
    iv_diff = [sorted_ivs[1] - 0; diff(sorted_ivs)]

    f = open(data_file, "r")
    # Move pointer to the start of the data for the patch
    if index > 1 
        seek(f, position(f) + total_size_in_bytes * (index - 1))
    end

    for i in 1:length(sorted_vars)
        var = sorted_vars[i]
        iv = sorted_ivs[i]
        var_data = all_var_data[var]

        # Move pointer to the start of the data for the variable
        if (iv_diff[i] - 1 > 0 )
            seek(f, position(f) + total_var_size_in_bytes * (iv_diff[i] - 1))
        end

        # Read the data for the single variable
        read!(f, var_data)
        all_var_data[var] = reshape(var_data, patch_size...)
    end
    close(f)

    return all_var_data
end
#--------------------------------------------------------------------------------


#----------------- Load multiple variables for multiple patches ----------------
function load_patches_vars(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int}, vars::Vector{String})
    NV = Snapshot_meta.SNAPSHOT.NV
    IDX = Snapshot_meta.IDX
    patch_size = get_integer_patch_size(Snapshot_meta)
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV), Int(total_size_in_bytes / NV))

    #-------------- If only 1 ID is given, just use load_patch_var function ----------------
    if length(patch_IDs) == 1
        var_data = load_patch_vars(Snapshot_meta, patch_IDs[1], vars)
        #------- reshape to still get an array including patches ----------------
        for (key, value) in var_data
            var_data[key] = reshape(value, size(value)..., 1)
        end
        #--------------------------------------------------------------------------------
        return var_data
    end
    #--------------------------------------------------------------------------------------------


    #----------- find data position index for each patch ----------------
    indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in patch_IDs]
    #-------------------------------------------------------------------
    
    #------ indices of the variables -------------------------
    ivs = [get_idx_value(IDX, var) for var in vars]
    #----------------------------------------------------


    data_size = (patch_size..., length(patch_IDs))

    all_var_data = Dict{String, Array{Float32, 4}}()
    for var in vars
        all_var_data[var] = zeros(Float32,data_size...)
    end

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        error(" Not implemented yet")

        #for (i, patch_ID) in enumerate(patch_IDs)
        #    var_data = load_patch_var(Snapshot_meta, patch_ID, var)
        #    all_data[:, :, :, i] = var_data
        #end
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    

    #-------------- Sort the indices in ascending order ----------------
    sorted_indices = sortperm(indices)
    patch_indices = indices[sorted_indices]
    patch_index_diff = [patch_indices[1] - 0; diff(patch_indices)]
    #--------------------------------------------------------------------


    #------------  Sort the ivs and get the sorted variables------------ 
    sorted_iv_indices = sortperm(ivs)
    sorted_ivs = ivs[sorted_iv_indices]
    sorted_vars = vars[sorted_iv_indices]
    iv_diff = [sorted_ivs[1] - 0; diff(sorted_ivs)]
    #-------------------------------------------------------------------

    data_file = data_files[1]
    f = open(data_file, "r")

    for i in 1:length(indices)
        if (patch_index_diff[i] - 1 > 0)
            # Move pointer to the next position in the file
            seek(f, position(f) + total_size_in_bytes * (patch_index_diff[i] - 1))
        end



        for j in 1:length(sorted_vars)
            var = sorted_vars[j]

            var_data = @view all_var_data[var][:,:,:,i]
            var_data_flat = reshape(var_data, :)

               # Move pointer to the start of the data for the variable
            if (iv_diff[j] - 1 > 0)
                seek(f, position(f) + total_var_size_in_bytes * (iv_diff[j] - 1))
            end

            read!(f, var_data_flat)

        end

        #-------- move pointer to the start of the next patch ----------------
        if sorted_ivs[end] < NV
            seek(f, position(f) + total_var_size_in_bytes * (NV - sorted_ivs[end]))
        end 
        #----------------------------------------------------------------

    end


    for var in keys(all_var_data)
        all_var_data[var] = all_var_data[var][:,:,:,sorted_indices]
    end 
    

    close(f)



    return all_var_data
    
end
#--------------------------------------------------------------------------------
