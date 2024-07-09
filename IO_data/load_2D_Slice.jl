include("helper_functions.jl")
include("../misc/IDX_conversing.jl")


function patches_in_2d_slice(Snapshot_meta::Snapshot_metadata, patch_ID :: Int, point::AbstractVector{<:AbstractFloat}, normal = "z", patches :: Vector{Int} = Vector{Int}())
    #--------------- ADD the id to list of IDs ----------------
    push!(patches, patch_ID)
    #---------------------------------------------------------
    #---------------- Find the patch and its LLC ----------------
    patch_index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    patch = Snapshot_meta.PATCHES[patch_index]
    patch_LLC = patch.LLC_NAT
    #----------------------------------------------------------

    for nbor_id in patch.NBOR_NML.NBOR_IDS
        #---------------- Find the neighbor patch and its LLC ----------------
        nbor_index = findfirst(patch -> patch.ID == nbor_id, Snapshot_meta.PATCHES)
        nbor_patch = Snapshot_meta.PATCHES[nbor_index]
        nbor_LLC = nbor_patch.LLC_NAT
        #---------------------------------------------------------------------
        #----------------- find the direction of the neighbor patch ------------
        nbor_dir = Int.((nbor_LLC - patch_LLC) ./ patch.SIZE)
        #-----------------------------------------------------------------------
        #----------------- check if the patch is in the 2D slice ----------------
        if !(nbor_dir[1] == 0 && normal == "x" || nbor_dir[2] == 0 && normal == "y" || nbor_dir[3] == 0 && normal == "z")
            continue
        end 
        #-----------------------------------------------------------------------
        #Check if nbor_ID has already been added
        if !(nbor_id in patches)
            # Recursively call patches_in_2d_slice on nbor_id
            patches_in_2d_slice(Snapshot_meta, nbor_id, point, normal, patches)
        end  
    end
end


function indices_in_2D_slide(Snapshot_meta::Snapshot_metadata, patch_ID :: Int, point::AbstractVector{<:AbstractFloat}, normal = "z")
    patch_index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    patch = Snapshot_meta.PATCHES[patch_index]
    local_point = get_local_pos(patch, point)
    local_index = local_pos_to_index(local_point)

    local_indices = Vector{Vector{Int}}()
    global_positions = Vector{Vector{Float32}}()

    #TODO - Does not work with guard cells yet
    if normal == "x"
        for j in 1:patch.N[3]
            for i in 1:patch.N[2]
                index = [local_index[1], i, j]
                global_pos = get_global_pos(patch, index_to_local_pos(index))
                push!(local_indices, index)
                push!(global_positions, global_pos)
            end
        end
    elseif normal == "y"
        for j in 1:patch.N[3]
            for i in 1:patch.N[1]
                index = [i, local_index[2], j]
                global_pos = get_global_pos(patch, index_to_local_pos(index))
                push!(local_indices, index)
                push!(global_positions, global_pos)
            end
        end
    elseif normal == "z"
        for j in 1:patch.N[2]
            for i in 1:patch.N[1]
                index = [i, j, local_index[3]] 
                global_pos = get_global_pos(patch, index_to_local_pos(index))
                push!(local_indices, index)
                push!(global_positions, global_pos)
            end
        end
    else 
        error("Normal must be given as 'x', 'y' or 'z'")
    end

    return local_indices, global_positions

end

function trace_2d_slice(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, normal :: String)
    #----------- Basic smapshot information ----- 
    NV = Snapshot_meta.SNAPSHOT.NV
    #------------------------------------------------
    #-------------- Find initial patch ----------------
    initial_patch = find_patch(Snapshot_meta, point)
    initial_ID = initial_patch.ID
    #---------------------------------------------------
    #--------------- in no patch is found return error ----------------
    if initial_patch === nothing
        error("Point outside simulation domain")
    end
    #----------- create lists for patches and cell indices -------------
    all_patches    = Vector{Int}()
    all_indices    =  Vector{Vector{Vector{Int}}}()
    all_global_pos = Vector{Vector{AbstractVector{<:AbstractFloat}}}()
    #-----------------------------------------------------------------
    patches_in_2d_slice(Snapshot_meta, initial_ID, point, normal, all_patches)
    
    #-------------- loop through all patches and find indices and global positions ----------------
    for i in 1:length(all_patches)
        indices, global_pos = indices_in_2D_slide(Snapshot_meta, all_patches[i], point, normal)
        push!(all_indices, indices)
        push!(all_global_pos, global_pos)
    end
    #-----------------------------------------------------------------------------------------------
    
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    all_patches = all_patches[sorted_indices]
    all_indices = all_indices[sorted_indices]
    all_global_pos = all_global_pos[sorted_indices]
    #---------------------------------------------------------------------------------------------
    


    #------------ Allocate memory for the data ----------------
    mem_size = get_mem_size(Snapshot_meta)
    if normal == "x"
        data = zeros(Float32, (mem_size[2], mem_size[3], NV))
        data_pos = zeros(Float32, (mem_size[2], mem_size[3], 2))
    elseif normal == "y"
        data = zeros(Float32, (mem_size[1], mem_size[3], NV))
        data_pos = zeros(Float32, (mem_size[1], mem_size[3], 2))
    elseif normal == "z"
        data = zeros(Float32, (mem_size[1], mem_size[2], NV))
        data_pos = zeros(Float32, (mem_size[1], mem_size[2], 2))
    else
        error("Normal must be given as 'x', 'y' or 'z'")
    end
    #---------------------------------------------------------
    #---------- not yet implemented for multiple data file -----------------------------------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in patch_indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        error(" Not implemented yet")
        #Maybe make the rest of the function another function that can be called from here and load_snapshot
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #---------------- open data file ------------------------------------------------------------------------
    data_file = data_files[1]
    f = open(data_file, "r")
    #---------------------------------------------------------------------------------------------------
    for i in 1:length(all_patches)
        indices = all_indices[i]
        global_pos = all_global_pos[i]
        patch = Snapshot_meta.PATCHES[patch_indices[i]]
        mem_offset = get_patch_mem_offset(Snapshot_meta, patch)
        #---------- move file pointer to the correct patch  position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, indices)
        #------------------------------------------------------------------------
        #------------------------------------ loop through all variables ------------------------------------
        for k in 1:NV
            for j in 1:length(indices)
                #----------  Move pointer to the next cell index in the patch ------------------------
                move_file_pointer_cell(f, offset_diff[j])
                #------------------------------------------------------------------------------------
                #----------- get global index  ------------------------------
                index = indices[j]
                global_index = mem_offset .+ index .- 1
                #-----------------------------------------------------------
                
                #----------------- read data and store in data array ------------------------------
                if normal == "x"
                    data[global_index[2], global_index[3], k] = read(f,Float32)
                elseif normal == "y"
                    data[global_index[1], global_index[3], k] = read(f,Float32)
                elseif normal == "z"
                    data[global_index[1], global_index[2], k] = read(f,Float32)
                end         
                #-----------------------------------------------------------------------------------

                #----------------- store position of the cell in data_pos array -----------------------
                if k == 1
                    if normal == "x"
                        data_pos[global_index[2], global_index[3], :] = [global_pos[j][2], global_pos[j][3]]
                    elseif normal == "y"
                        data_pos[global_index[1], global_index[3], :] = [global_pos[j][1], global_pos[j][3]]
                    elseif normal == "z"
                        data_pos[global_index[1], global_index[2], :] = [global_pos[j][1], global_pos[j][2]]
                    end       
                end 
                #-----------------------------------------------------------------------------------

            end
            #-------------------- Move pointer to the next variable ------------------------------
            move_file_pointer_next_var(f, Snapshot_meta, offset[end])
            #--------------------------------------------------------------------------------------

        end
        #---------------------------------------------------------------------------------------------------
    end

    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------

    return data, data_pos
    
end



function trace_2d_slice(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, normal :: String,
    var :: String)
    #------ index of the variable -------------------------
    IDX = Snapshot_meta.IDX
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------
    #-------------- Find initial patch ----------------
    initial_patch = find_patch(Snapshot_meta, point)
    initial_ID = initial_patch.ID
    #---------------------------------------------------
    #--------------- in no patch is found return error ----------------
    if initial_patch === nothing
        error("Point outside simulation domain")
    end
    #----------- create lists for patches and cell indices -------------
    all_patches    = Vector{Int}()
    all_indices    =  Vector{Vector{Vector{Int}}}()
    all_global_pos = Vector{Vector{AbstractVector{<:AbstractFloat}}}()
    #-----------------------------------------------------------------
    patches_in_2d_slice(Snapshot_meta, initial_ID, point, normal, all_patches)
    
    #-------------- loop through all patches and find indices and global positions ----------------
    for i in 1:length(all_patches)
        indices, global_pos = indices_in_2D_slide(Snapshot_meta, all_patches[i], point, normal)
        push!(all_indices, indices)
        push!(all_global_pos, global_pos)
    end
    #-----------------------------------------------------------------------------------------------
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    all_patches = all_patches[sorted_indices]
    all_indices = all_indices[sorted_indices]
    all_global_pos = all_global_pos[sorted_indices]
    #---------------------------------------------------------------------------------------------
    #------------ Allocate memory for the data ----------------
    mem_size = get_mem_size(Snapshot_meta)
    if normal == "x"
        data = zeros(Float32, (mem_size[2], mem_size[3]))
        data_pos = zeros(Float32, (mem_size[2], mem_size[3], 2))
    elseif normal == "y"
        data = zeros(Float32, (mem_size[1], mem_size[3]))
        data_pos = zeros(Float32, (mem_size[1], mem_size[3], 2))
    elseif normal == "z"
        data = zeros(Float32, (mem_size[1], mem_size[2]))
        data_pos = zeros(Float32, (mem_size[1], mem_size[2], 2))
    else
        error("Normal must be given as 'x', 'y' or 'z'")
    end
    #---------------------------------------------------------
    #---------- not yet implemented for multiple data file -----------------------------------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in patch_indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        error(" Not implemented yet")
        #Maybe make the rest of the function another function that can be called from here and load_snapshot
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #---------------- open data file ------------------------------------------------------------------------
    data_file = data_files[1]
    f = open(data_file, "r")
    #---------------------------------------------------------------------------------------------------
    #---------------------------------------------------------------------------------------------------
    for i in 1:length(all_patches)
        indices = all_indices[i]
        global_pos = all_global_pos[i]
        patch = Snapshot_meta.PATCHES[patch_indices[i]]
        mem_offset = get_patch_mem_offset(Snapshot_meta, patch)
        #---------- move file pointer to the correct patch and variable position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        move_file_pointer_var(f, Snapshot_meta,  iv)
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, indices)
        #------------------------------------------------------------------------
        #------------------------------------ loop through all variables ------------------------------------
            for j in 1:length(indices)
                #----------  Move pointer to the next cell index in the patch ------------------------
                move_file_pointer_cell(f, offset_diff[j])
                #------------------------------------------------------------------------------------
                #----------- get global index  ------------------------------
                index = indices[j]
                global_index = mem_offset .+ index .- 1
                #-----------------------------------------------------------
                
                #----------------- read data and store in data array ------------------------------
                if normal == "x"
                    data[global_index[2], global_index[3]] = read(f,Float32)
                elseif normal == "y"
                    data[global_index[1], global_index[3]] = read(f,Float32)
                elseif normal == "z"
                    data[global_index[1], global_index[2]] = read(f,Float32)
                end         
                #-----------------------------------------------------------------------------------

                #----------------- store position of the cell in data_pos array -----------------------
                if normal == "x"
                    data_pos[global_index[2], global_index[3], :] = [global_pos[j][2], global_pos[j][3]]
                elseif normal == "y"
                    data_pos[global_index[1], global_index[3], :] = [global_pos[j][1], global_pos[j][3]]
                elseif normal == "z"
                    data_pos[global_index[1], global_index[2], :] = [global_pos[j][1], global_pos[j][2]]
                end       
                #-----------------------------------------------------------------------------------
            end
            #-------------------- Move pointer to the next variable ------------------------------
            move_file_pointer_next_var(f, Snapshot_meta, offset[end])
            #--------------------------------------------------------------------------------------
            #--------- move file pointer to the start of the next patch ----------------
            move_file_pointer_next_patch(f, Snapshot_meta, iv)
            #----------------------------------------------------------------
        #---------------------------------------------------------------------------------------------------
    end

    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------

    return data, data_pos
    
end



function trace_2d_slice(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, normal :: String,
    vars :: Vector{String})
    #------ integer index of the variable -------------------------
    ivs, sorted_vars, sorted_iv_indices, iv_diff = get_sorted_vars(Snapshot_meta, vars)
    #----------------------------------------------------
    #-------------- Find initial patch ----------------
    initial_patch = find_patch(Snapshot_meta, point)
    initial_ID = initial_patch.ID
    #---------------------------------------------------
    #--------------- in no patch is found return error ----------------
    if initial_patch === nothing
        error("Point outside simulation domain")
    end
    #----------- create lists for patches and cell indices -------------
    all_patches    = Vector{Int}()
    all_indices    =  Vector{Vector{Vector{Int}}}()
    all_global_pos = Vector{Vector{AbstractVector{<:AbstractFloat}}}()
    #-----------------------------------------------------------------
    patches_in_2d_slice(Snapshot_meta, initial_ID, point, normal, all_patches)
    
    #-------------- loop through all patches and find indices and global positions ----------------
    for i in 1:length(all_patches)
        indices, global_pos = indices_in_2D_slide(Snapshot_meta, all_patches[i], point, normal)
        push!(all_indices, indices)
        push!(all_global_pos, global_pos)
    end
    #-----------------------------------------------------------------------------------------------
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    all_patches = all_patches[sorted_indices]
    all_indices = all_indices[sorted_indices]
    all_global_pos = all_global_pos[sorted_indices]
    #---------------------------------------------------------------------------------------------
    #------------ Allocate memory for the data ----------------
    mem_size = get_mem_size(Snapshot_meta)
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        if normal == "x"
            all_var_data[var] = zeros(Float32, (mem_size[2], mem_size[3]))
        elseif normal == "y"
            all_var_data[var] = zeros(Float32, (mem_size[1], mem_size[3]))
        elseif normal == "z"
            all_var_data[var] = zeros(Float32, (mem_size[1], mem_size[2]))
        else
            error("Normal must be given as 'x', 'y' or 'z'")
        end
    end
    if normal == "x"
        data_pos = zeros(Float32, (mem_size[2], mem_size[3], 2))
    elseif normal == "y"
        data_pos = zeros(Float32, (mem_size[1], mem_size[3], 2))
    elseif normal == "z"
        data_pos = zeros(Float32, (mem_size[1], mem_size[2], 2))
    else
        error("Normal must be given as 'x', 'y' or 'z'")
    end
    #---------------------------------------------------------
    #---------- not yet implemented for multiple data file -----------------------------------------
    data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in patch_indices]
    if length(unique(data_files)) > 1
        @warn "Data file different - uses non-optimized load_patches_var function"
        error(" Not implemented yet")
        #Maybe make the rest of the function another function that can be called from here and load_snapshot
        return all_data
    end
    #--------------------------------------------------------------------------------------------
    #---------------- open data file ------------------------------------------------------------------------
    data_file = data_files[1]
    f = open(data_file, "r")
    #---------------------------------------------------------------------------------------------------
    #---------------------------------------------------------------------------------------------------
    for i in 1:length(all_patches)
        indices = all_indices[i]
        global_pos = all_global_pos[i]
        patch = Snapshot_meta.PATCHES[patch_indices[i]]
        mem_offset = get_patch_mem_offset(Snapshot_meta, patch)
        #---------- move file pointer to the correct patch and variable position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, indices)
        #------------------------------------------------------------------------
        #------------------------------------ loop through all variables ------------------------------------
        for k in 1:length(sorted_vars)
            #--------------------
            var = sorted_vars[k]
            #-------------------
            #---------- move file pointer to the correct variable position ----------------
            move_file_pointer_var(f, Snapshot_meta, iv_diff[k])
            #-------------------------------------------------------------------------------------------
            for j in 1:length(indices)
                #----------  Move pointer to the next cell index in the patch ------------------------
                move_file_pointer_cell(f, offset_diff[j])
                #------------------------------------------------------------------------------------
                #----------- get global index  ------------------------------
                index = indices[j]
                global_index = mem_offset .+ index .- 1
                #----------------------------------------------------------- 
                #----------------- read data and store in data array ------------------------------
                if normal == "x"
                    all_var_data[var][global_index[2], global_index[3]] = read(f,Float32)
                elseif normal == "y"
                    all_var_data[var][global_index[1], global_index[3]] = read(f,Float32)
                elseif normal == "z"
                    all_var_data[var][global_index[1], global_index[2]] = read(f,Float32)
                end         
                #-----------------------------------------------------------------------------------
                #----------------- store position of the cell in data_pos array -----------------------
                if k == 1
                    if normal == "x"
                        data_pos[global_index[2], global_index[3], :] = [global_pos[j][2], global_pos[j][3]]
                    elseif normal == "y"
                        data_pos[global_index[1], global_index[3], :] = [global_pos[j][1], global_pos[j][3]]
                    elseif normal == "z"
                        data_pos[global_index[1], global_index[2], :] = [global_pos[j][1], global_pos[j][2]]
                    end      
                end 
                #-----------------------------------------------------------------------------------
            end
            #-------------------- Move pointer to the next variable ------------------------------
            move_file_pointer_next_var(f, Snapshot_meta, offset[end])
            #--------------------------------------------------------------------------------------
        end
        #--------- move file pointer to the start of the next patch ----------------
        move_file_pointer_next_patch(f, Snapshot_meta, ivs[end])
        #----------------------------------------------------------------
    end
    #---------------------------------------------------------------------------------------------------
    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------
    return all_var_data, data_pos
end