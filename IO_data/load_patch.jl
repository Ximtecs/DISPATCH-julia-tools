include("helper_functions.jl")
include("../misc/IDX_conversing.jl")

#---------- Functions to get information from a single patch or an array of patches from a single snapshot -------------
#----------------- Load all varialbes for a single patch ----------------
function load_patch(Snapshot_meta :: Snapshot_metadata, patch_ID :: Int)
    #---------- find the index of the patch with the given ID ----------------
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    #-------------------------------------------------------------------------
    #--------------- get the data file for the patch ----------------
    data_file = Snapshot_meta.PATCHES[index].DATA_FILE
    #-------------------------------------------------------------------
    #---------- initialize the data array ----------------
    patch_size = get_integer_patch_size(Snapshot_meta)
    NV =  Snapshot_meta.SNAPSHOT.NV
    data = zeros(Float32, patch_size... , NV)
    #-----------------------------------------------------
    #----------------------------------------------------------------------
    f = open(data_file,"r")
    #---------- move pointer to the correct position in the file ---------------
    move_file_pointer_patch(f, Snapshot_meta, index)
    #------------------------------------------------------------------------------
    #------------ read the data from the file ----------------
    read!(f, data)
    #----------------------------------------------------------------
    close(f)
    #--------------------------------------------
    return data
end
#--------------------------------------------------------------------------------

#----------------- Load all variables for multiple patches ----------------
function load_patch(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int})
    NV = Snapshot_meta.SNAPSHOT.NV
    #-------------- If only 1 ID is given, call function again with 1D input function ----------------
    if length(patch_IDs) == 1
        patch_data = load_patch(Snapshot_meta, patch_IDs[1])
        return reshape(patch_data, size(patch_data)..., NV, 1)
    end
    #--------------------------------------------------------------------------------------------
    #--------------- find the indices of the patches ----------------
    indices, sorted_indices, index_diff = get_sorted_patch_IDs(Snapshot_meta, patch_IDs)
    #-------------------------------------------------------------------
    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    all_data = zeros(Float32, patch_size..., NV, length(patch_IDs))
    #---------------------------------------------------------------------
    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_data function"
        for (i, patch_ID) in enumerate(patch_IDs)
            patch_data = load_patch(Snapshot_meta, patch_ID)
            all_data[:,:,:,:, i] = patch_data
        end
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #------- If patches have the same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches
    data_file = data_files[1]
    f = open(data_file, "r")
    for i in 1:length(indices)
        data = @view all_data[:,:,:,:, i]
        #-------------------- move pointer to next patch position ----------
        move_file_pointer_patch(f, Snapshot_meta, index_diff[i])
        #-----------------------------------------------------------------

        #------------ read the data from the file ----------------
        read!(f, data)
        #----------------------------------------------------------------
    end
    close(f)
    #--------------------------------------------
    #---------- sort data in same order as patch_IDs ----------------
    all_data = all_data[:,:,:,:, sorted_indices]
    #-------------------------------------------------------------------
    return all_data
end
#--------------------------------------------------------------------------------

#---------------- load a single variable for a single patch ----------------
function load_patch(Snapshot_meta::Snapshot_metadata, patch_ID::Int, var :: String)
    #------ integer index of the variable -------------------------
    IDX = Snapshot_meta.IDX
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------
    #---------- find the index of the patch with the given ID ----------------
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    #-------------------------------------------------------------------------
    #--------------- get the data file for the patch ----------------
    data_file = Snapshot_meta.PATCHES[index].DATA_FILE
    #-------------------------------------------------------------------
    #---------- initialize the data array ----------------
    patch_size = get_integer_patch_size(Snapshot_meta)
    data = zeros(Float32, patch_size...)
    #-----------------------------------------------------
    #---------- Open data file ----------------
    f = open(data_file,"r")
    #--------------------------------------------
    #---------- move file pointer to the correct patch and variable position ----------------
    move_file_pointer_patch(f, Snapshot_meta, index)
    move_file_pointer_var(f, Snapshot_meta,  iv)
    #-------------------------------------------------------------------------------------------
    # -------- read patch data for the variable ----------------
    read!(f, data)
    #---------------------------------------------------------
    close(f)
    return data
end
#--------------------------------------------------------------------------------

#---------------- load a single variable for multiple patches ----------------
function load_patch(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int}, var::String)
    #-------------- If only 1 ID is given, just use load_patch function ----------------
    if length(patch_IDs) == 1
        var_data = load_patch(Snapshot_meta, patch_IDs[1], var)
        return reshape(var_data, size(var_data)..., 1)
    end
    #--------------------------------------------------------------------------------------------
    #------ index of the variable -------------------------
    IDX = Snapshot_meta.IDX
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------
    #--------------- find the indices of the patches ----------------
    indices, sorted_indices, index_diff = get_sorted_patch_IDs(Snapshot_meta, patch_IDs)
    #-------------------------------------------------------------------
    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    all_data = zeros(Float32, patch_size..., length(patch_IDs))
    #---------------------------------------------------------------------
    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        for (i, patch_ID) in enumerate(patch_IDs)
            var_data = load_patch(Snapshot_meta, patch_ID, var)
            all_data[:, :, :, i] = var_data
        end
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #------- If patches have same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches
    data_file = data_files[1]
    f = open(data_file, "r")
    for i in 1:length(indices)
        #---------- subview of the data array to contain a single patch ----------------
        var_data = @view all_data[:, :, :, i]
        #----------------------------------------------------------------------------
        #---------- move file pointer to the correct patch and variable position ----------------
        move_file_pointer_patch(f, Snapshot_meta, index_diff[i])
        move_file_pointer_var(f, Snapshot_meta,  iv)
        #--------------------------------------------------------------------------------------
        #----------- Read the data for the single variable --------------------
        read!(f, var_data)
        #----------------------------------------------------------------
        #--------- move file pointer to the start of the next patch ----------------
        move_file_pointer_next_patch(f, Snapshot_meta, iv)
        #----------------------------------------------------------------
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
function load_patch(Snapshot_meta::Snapshot_metadata, patch_ID::Int, vars::Vector{String})
    #---------- find the index of the patch with the given ID ----------------
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    #-------------------------------------------------------------------------
    #--------------- get the data file for the patch ----------------
    data_file = Snapshot_meta.PATCHES[index].DATA_FILE
    #-------------------------------------------------------------------
    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = zeros(Float32, patch_size...)
    end
    #---------------------------------------------------------------------
    #------ integer index of the variable -------------------------
    ivs, sorted_vars, sorted_iv_indices, iv_diff = get_sorted_vars(Snapshot_meta, vars)
    #----------------------------------------------------
    #---------- Open data file ----------------
    f = open(data_file,"r")
    #--------------------------------------------
    #---------- move file pointer to the correct patch  position ----------------
    move_file_pointer_patch(f, Snapshot_meta, index)
    #-------------------------------------------------------------------------------------------
    for i in 1:length(sorted_vars)
        #------------- Get subview of the data array for the variable ----------------
        var = sorted_vars[i]
        var_data = @view all_var_data[var][:,:,:]
        #--------------------------------------------------------------------------------

        #---------- move file pointer to the correct variable position ----------------
        move_file_pointer_var(f, Snapshot_meta, iv_diff[i])
        #-------------------------------------------------------------------------------------------
        # -------- read patch data for the variable ----------------
        read!(f, var_data)
        #---------------------------------------------------------
    end
    close(f)
    return all_var_data
end
#--------------------------------------------------------------------------------

#----------------- Load multiple variables for multiple patches ----------------
function load_patch(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int}, vars::Vector{String})
    #-------------- If only 1 ID is given, just use load_patch with a single patch  ----------------
    if length(patch_IDs) == 1
        var_data = load_patch(Snapshot_meta, patch_IDs[1], vars)
        #------- reshape to still get an array including patches ----------------
        for (key, value) in var_data
            var_data[key] = reshape(value, size(value)..., 1)
        end
        #--------------------------------------------------------------------------------
        return var_data
    end
    #--------------------------------------------------------------------------------------------

    #--------------- find the indices of the patches ----------------
    indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, patch_IDs)
    #-------------------------------------------------------------------
    

    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    data_size = [patch_size..., length(patch_IDs)]
    all_var_data = Dict{String, Array{Float32, 4}}()
    for var in vars
        all_var_data[var] = zeros(Float32,data_size...)
    end

    #---------- if patches have different data files load them each individually ------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        error(" Not implemented yet")

        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #------- If patches have same data file load them all together -------------------
    #        Here we only have to open the file once and read all the patches

    #------ integer index of the variable -------------------------
    ivs, sorted_vars, sorted_iv_indices, iv_diff = get_sorted_vars(Snapshot_meta, vars)
    #----------------------------------------------------

    #---------- Open data file ----------------
    data_file = data_files[1]
    f = open(data_file,"r")
    #--------------------------------------------
    for i in 1:length(indices)
        #---------- move file pointer to the correct patch  position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        #-------------------------------------------------------------------------------------------
        for j in 1:length(sorted_vars)
            #------------- Get subview of the data array for the variable ----------------
            var = sorted_vars[j]
            var_data = @view all_var_data[var][:,:,:,i]
            #--------------------------------------------------------------------------------
            #---------- move file pointer to the correct variable position ----------------
            move_file_pointer_var(f, Snapshot_meta, iv_diff[j])
            #-------------------------------------------------------------------------------------------
            #----------- Read the data for the single variable --------------------
            read!(f, var_data)
            #----------------------------------------------------------------
        end
        #--------- mvoe file pointer to the start of the next patch ----------------
        move_file_pointer_next_patch(f, Snapshot_meta, ivs[end])
        #---------------------------------------------------------------------------
    end
    close(f)
    #--------------- sort all variables in the same order as patch_IDs ----------------
    for var in keys(all_var_data)
        all_var_data[var] = all_var_data[var][:,:,:,sorted_indices]
    end 
    #--------------------------------------------------------------------------------------------
    return all_var_data
end
#--------------------------------------------------------------------------------
