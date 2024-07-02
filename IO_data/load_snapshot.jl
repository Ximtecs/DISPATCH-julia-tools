include("helper_functions.jl")
include("../misc/IDX_conversing.jl")

function load_snapshot(Snapshot_meta :: Snapshot_metadata)

    #--------- basic information about the snapshot and the patches ------
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)
    n_patches = Snapshot_meta.n_patches
    #--------------------------------------------------------------------

    #---------- allocate array -------------------------------
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
        data_file = data_files[1]
        f = open(data_file,"r")
        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------

            #---------- get subview of global memory and load data directly into global array --------------
            data = @view all_data[mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1,:]
            #------------------------------------------------------------------------------------------------

            read!(f, data)
        end 
        close(f)
        #--------------------------------------------------------------------------------
    end
    #--------------------------------------------------------------------------------------------


    return all_data
end 



function load_snapshot(Snapshot_meta :: Snapshot_metadata, var :: String)
    #--------- basic information about the snapshot and the patches ------
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)[1:3] #drop NV
    n_patches = Snapshot_meta.n_patches
    IDX = Snapshot_meta.IDX
    NV = Snapshot_meta.SNAPSHOT.NV
    #--------------------------------------------------------------------


    #------ index of the variable -------------------------
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------

    #----- size of each patch -------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    #----- size of each variable -------------------------
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------


    #---------- allocate array -------------------------------
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
        data_file = data_files[1]
        f = open(data_file,"r")

        # Move pointer to the start of the data for the variable
        if iv > 1 
            seek(f, position(f) + total_var_size_in_bytes * (iv - 1))
        end

        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------

            #---------- get subview of global memory and load data directly into global array --------------
            data = @view all_data[mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1]
            #------------------------------------------------------------------------------------------------
            read!(f, data)

        #-------- move pointer to the variable of the next patch ----------------
            seek(f, position(f) + total_var_size_in_bytes * (NV - 1))
        #----------------------------------------------------------------

        end 
        close(f)
        #--------------------------------------------------------------------------------
    end
    #--------------------------------------------------------------------------------------------

    return all_data
end 


function load_snapshot(Snapshot_meta :: Snapshot_metadata, vars::Vector{String})
    #--------- basic information about the snapshot and the patches ------
    patch_size = get_integer_patch_size(Snapshot_meta)
    mem_size = get_mem_size(Snapshot_meta)[1:3] #drop NV
    n_patches = Snapshot_meta.n_patches
    IDX = Snapshot_meta.IDX
    NV = Snapshot_meta.SNAPSHOT.NV
    #--------------------------------------------------------------------

    #------ indices of the variables -------------------------
    ivs = [get_idx_value(IDX, var) for var in vars]
    #----------------------------------------------------

    #----- size of each patch -------------------------
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    #----- size of each variable -------------------------
    total_var_size, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))
    #----------------------------------------------------------------

    #----------------- initialize the data array -------------------------    
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = zeros(Float32,mem_size...)
    end
    #---------------------------------------------------------------------

    #-----------   Sort the ivs and get the sorted variables ---------
    sorted_iv_indices = sortperm(ivs)
    sorted_ivs = ivs[sorted_iv_indices]
    sorted_vars = vars[sorted_iv_indices]
    iv_diff = [sorted_ivs[1] - 0; diff(sorted_ivs)]
    #--------------------------------------------------------------------

    #---------- if patches have different data files load them each individually ------------
    data_files = [patch.DATA_FILE for patch in Snapshot_meta.PATCHES]
    if length(unique(data_files)) > 1
        error("loading snapshot with different data files not implemented yet")
        #TODO - should be quite similar to below but loop through unique(data_files) list
        #----- should create a list of each patch in that file and loop through it 
    else 
        #------ if patches have same data file juust go through it to load all patches --------
        data_file = data_files[1]
        f = open(data_file, "r")


        for i in 1:n_patches
            #--------- get patch offset in memory -----------------------
            patch = Snapshot_meta.PATCHES[i]
            mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
            #------------------------------------------------------------
            for j in 1:length(sorted_vars)
                var = sorted_vars[j]
                #---------- get subview of global memory and load data directly into global array --------------
                data = @view all_var_data[var][mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1]
                #------------------------------------------------------------------------------------------------

                # Move pointer to the start of the data for the variable
                if (iv_diff[j] - 1 > 0)
                    seek(f, position(f) + total_var_size_in_bytes * (iv_diff[j] - 1))
                end
                read!(f, data)
            end

            #-------- move pointer to the start of the next patch ----------------
            if sorted_ivs[end] < NV
                seek(f, position(f) + total_var_size_in_bytes * (NV - sorted_ivs[end]))
            end 
            #----------------------------------------------------------------

        end
    end
    return all_var_data
end