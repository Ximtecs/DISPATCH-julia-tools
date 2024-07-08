include("helper_functions.jl")
include("../misc/IDX_conversing.jl")

function load_snapshot(Snapshot_meta :: Snapshot_metadata)
    #--------- basic information about the snapshot and the patches ------
    n_patches = Snapshot_meta.n_patches
    #--------------------------------------------------------------------
    #---------- allocate array -------------------------------
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)
    all_data = zeros(Float32,mem_size...)
    #-----------------------------------------------------------------
    #---------- if patches have different data files load them each individually ------------
    data_files = [patch.DATA_FILE for patch in Snapshot_meta.PATCHES]
    if length(unique(data_files)) > 1
        error("loading snapshot with different data files not implemented yet")
        #TODO - should be quite similar to below but loop through unique(data_files) list
        #----- should create a list of each patch in that file and loop through it 
    else 
        #------ if patches have same data file juust go through it to load all patches --------
        #---------- Open data file ----------------
        data_file = data_files[1]
        f = open(data_file,"r")
        #-----------------------------------------
        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------
            #---------- get subview of global memory and load data directly into global array --------------
            data = @view all_data[mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1,:]
            #------------------------------------------------------------------------------------------------
            #----------- Read the data for the patch  --------------------
            read!(f, data)
            #-----------------------------------------------------------
        end 
        close(f)
        #--------------------------------------------------------------------------------
    end
    #--------------------------------------------------------------------------------------------


    return all_data
end 


function load_snapshot(Snapshot_meta :: Snapshot_metadata, var :: String)
    #--------- basic information about the snapshot and the patches ------
    n_patches = Snapshot_meta.n_patches
    #--------------------------------------------------------------------
    #------ index of the variable -------------------------
    IDX = Snapshot_meta.IDX
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------
    #---------- allocate array -------------------------------
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)[1:3] #drop NV
    all_data = zeros(Float32,mem_size...)
    #-----------------------------------------------------------------
    #---------- if patches have different data files load them each individually ------------
    data_files = [patch.DATA_FILE for patch in Snapshot_meta.PATCHES]
    if length(unique(data_files)) > 1
        error("loading snapshot with different data files not implemented yet")
        #TODO - should be quite similar to below but loop through unique(data_files) list
        #----- should create a list of each patch in that file and loop through it 
    else 
        #------ if patches have same data file juust go through it to load all patches --------
        
        #---------- Open data file ----------------
        data_file = data_files[1]
        f = open(data_file,"r")
        #-----------------------------------------
        #---------- move file pointer to the correct patch and variable position ----------------
        move_file_pointer_var(f, Snapshot_meta,  iv)
        #--------------------------------------------------------------------------------------

        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------

            #---------- get subview of global memory and load data directly into global array --------------
            data = @view all_data[mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1]
            #------------------------------------------------------------------------------------------------
            
            #----------- Read the data for the single variable --------------------
            read!(f, data)
            #---------------------------------------------------------------------

            #--------- mvoe file pointer to the variable of the next patch ----------------
            move_file_pointer_next_patch(f, Snapshot_meta, 1)
            #----------------------------------------------------------------
        end 
        close(f)
        #--------------------------------------------------------------------------------
    end
    #--------------------------------------------------------------------------------------------
    return all_data
end 


function load_snapshot(Snapshot_meta :: Snapshot_metadata, vars::Vector{String})
    #---------- If only 1 var is given, just call the function for that variable ----------------
    if length(vars) == 1
        data = load_snapshot(Snapshot_meta, vars[1])
        all_var_data = Dict{String, Array{Float32, 4}}()
        all_var_data[vars[1]] = data
        return all_var_data
    end
    #-------------------------------------------------------------------------------------------
    #--------- basic information about the snapshot and the patches ------
    n_patches = Snapshot_meta.n_patches
    #--------------------------------------------------------------------
    #----------------- initialize the data array -------------------------    
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)[1:3] #drop NV
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = zeros(Float32,mem_size...)
    end
    #---------------------------------------------------------------------
    #---------- if patches have different data files load them each individually ------------
    data_files = [patch.DATA_FILE for patch in Snapshot_meta.PATCHES]
    if length(unique(data_files)) > 1
        error("loading snapshot with different data files not implemented yet")
        #TODO - should be quite similar to below but loop through unique(data_files) list
        #----- should create a list of each patch in that file and loop through it 
    else 
        #------ if patches have same data file juust go through it to load all patches --------
        #------ integer index of the variable -------------------------
        ivs, sorted_vars, sorted_iv_indices, iv_diff = get_sorted_vars(Snapshot_meta, vars)
        #----------------------------------------------------
        #---------- Open data file ----------------
        data_file = data_files[1]
        f = open(data_file, "r")
        #--------------------------------------------
        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------
            for j in 1:length(sorted_vars)
                #------------- Get subview of the data array for the variable ----------------
                var = sorted_vars[j]
                data = @view all_var_data[var][mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1]
                #------------------------------------------------------------------------------------------------
                #---------- move file pointer to the correct variable position ----------------
                move_file_pointer_var(f, Snapshot_meta, iv_diff[j])
                #--------------------------------------------------------------------------------------
                #----------- Read the data for the single variable --------------------
                read!(f, data)
                #----------------------------------------------------------------
            end
            #--------- mvoe file pointer to the start of the next patch ----------------
            move_file_pointer_next_patch(f, Snapshot_meta, ivs[end])
            #---------------------------------------------------------------------------

        end
        close(f)
    end
    return all_var_data
end