include("helper_functions.jl")
include("../misc/IDX_conversing.jl")

#-------------- Trace a line through a patch -------------
function trace_line_in_patch(Snapshot_meta::Snapshot_metadata, patch::Patch_NML, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat})
    #-------------- get number of cells in patch ----------------
    cells = get_integer_patch_size(Snapshot_meta)
    #------------------------------------------------------------
    #------- transform direction vector to unit vector ---------
    dir_unit = dir / sqrt(sum(dir.^2))
    #------------------------------------------------------------
    #------------- get local position of the point in the patch ----------------
    local_point = get_local_pos(patch, point)
    #---------------------------------------------------------------------------
    #--------- create cell index list and add the first cell index ------------
    indices = []
    push!(indices, local_pos_to_index(local_point))
    #---------------------------------------------------------------------------
    #------------ Traverse in the positive direction adding cell indices to the list -------
    new_local_point = local_point .+ dir_unit
    while all(new_local_point .>= 0.0) && all(new_local_point .< cells)
        push!(indices, local_pos_to_index(new_local_point))
        new_local_point = new_local_point .+ dir_unit
    end
    #----------------------------------------------------------------------------------------
    #--------- store the last point outside the patch ----------------
    point_right = new_local_point
    #----------------------------------------------------------------
    #------------ Traverse in the negative direction adding cell indices to the list -------
    new_local_point = local_point .- dir_unit
    while all(new_local_point .>= 0.0) && all(new_local_point .< cells)
        push!(indices, local_pos_to_index(new_local_point))
        new_local_point = new_local_point .- dir_unit
    end
    #----------------------------------------------------------------------------------------
    #--------- store the last point outside the patch ----------------
    point_left = new_local_point
    #----------------------------------------------------------------
    #------- sort indices and remove potential duplicates ---------
    indices = sort!(unique(indices))
    #--------------------------------------------------------------
    #---------- Convert left and right point outside domain to global coordinates -----------    
    global_left = get_global_pos(patch, point_left)
    global_right = get_global_pos(patch, point_right)
    #-----------------------------------------------------------------------------------------
    return indices, global_left, global_right
end


function trace_1D_line(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat})
    #-------------- Find initial patch ----------------
    initial_patch = find_patch(Snapshot_meta, point)
    #---------------------------------------------------
    #--------------- in no patch is found return error ----------------
    if initial_patch === nothing
        error("Point outside simulation domain")
    end
    #----------------------------------------------------------------
    #----------- create lists for patches and cell indices -------------
    all_indices = Vector{Vector{Vector{Int}}}()
    all_patches = Vector{Int}()
    #-----------------------------------------------------------------
    #---------- trace line in initial patch and add to lists ----------------
    indices, left_point, right_point = trace_line_in_patch(Snapshot_meta, initial_patch, point, dir)
    push!(all_indices,indices)
    push!(all_patches, initial_patch.ID)
    #------------------------------------------------------------------------
    #--------- Trace trhough snapshot until no patch is found in the "left" direction ----------------
    patch = find_patch(Snapshot_meta, left_point)
    while patch != nothing
        indices, left_point, _ = trace_line_in_patch(Snapshot_meta, patch, left_point, dir)
        push!(all_indices,indices)
        push!(all_patches, patch.ID)
        patch = find_patch(Snapshot_meta, left_point)
    end
    #--------------------------------------------------------------------------------------------
    #--------- Trace trhough snapshot until no patch is found in the "right" direction ----------------
    patch = find_patch(Snapshot_meta, right_point)
    while patch != nothing
        indices, _, right_point = trace_line_in_patch(Snapshot_meta, patch, right_point, dir)
        push!(all_indices,indices)
        push!(all_patches, patch.ID)
        patch = find_patch(Snapshot_meta, right_point)
    end
    #--------------------------------------------------------------------------------------------
    return all_patches, all_indices
end


function Slice_1D(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat})
    #----------- Basic smapshot information ----- 
    NV = Snapshot_meta.SNAPSHOT.NV
    #------------------------------------------------
    #--------------- Find all patches and indices that the line crosses ---------------------
    all_patches, all_indices = trace_1D_line(Snapshot_meta, point, dir)
    #---------------------------------------------------------------------------------------------
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    #---------------------------------------------------------------------------------------------
    #------------ Allocate data arrays ------------------------------------------------------
    #-------- total number of points in the line ------------------------
    n_points = sum(length.(all_indices))
    data = zeros(n_points, NV)
    line_pos = zeros(n_points)
    line_3D = zeros(3, n_points)
    #--------------------------------------------------------------------------------------------
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
    #----------- location in data array -----------
    data_index = 1
    #--------------------------------------------
    #------------------ Loop through all patches that the line crosses --------------------------------
    for i in 1:length(patch_indices)
        #---------- move file pointer to the correct patch  position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, all_indices[i])
        #------------------------------------------------------------------------
        #------- Temporary data index counter ----------------------------
        data_index_temp = data_index
        #-------------------------------------------------------------------
        #------------------------------------ loop through all variables ------------------------------------
        for k in 1:NV
            #-------------- reset data index counter for each variable ---------------------
            data_index_temp = data_index
            #-----------------------------------------------------------------------------------
            for j in 1:length(all_indices[i])
                #----------  Move pointer to the next cell index in the patch ------------------------
                move_file_pointer_cell(f, offset_diff[j])
                #----------------------------------------------------------------------------------
                #-------------------- find position on line and global 3D line position -------------
                if k ==1 
                    pos = index_to_local_pos(all_indices[i][j])
                    pos = get_global_pos(Snapshot_meta.PATCHES[patch_indices[i]], pos)
                    l_pos, l_3d_pos = project_onto_line(point, dir, pos )
                    line_pos[data_index_temp] = l_pos
                    line_3D[:, data_index_temp] = l_3d_pos
                end
                #-------------------------------------------------------------------------------------
                #------------ read data -------------------------------------
                data[data_index_temp, k] = read(f, Float32)
                #-------------------------------------------------
                #---------- increase data index counter ----------------
                data_index_temp += 1
                #--------------------------------------------------------------
            end
            #-------------------- Move pointer to the next variable ------------------------------
            move_file_pointer_next_var(f, Snapshot_meta, offset[end])
            #--------------------------------------------------------------------------------------
        end
        #---------------------------------------------------------------------------------------------------
        data_index = data_index_temp
    end
    #---------------------------------------------------------------------------------------------------
    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------
    #------ sort output ----------------------------------------------------------------
    sorted_indices = sortperm(line_pos)
    data = data[sorted_indices, :]
    line_pos = line_pos[sorted_indices]
    line_3D = line_3D[:, sorted_indices]
    #-------------------------------------------------------------------------------------
    return data , line_pos, line_3D
end




function Slice_1D(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat},
    var :: String)
    #------ index of the variable -------------------------
    IDX = Snapshot_meta.IDX
    iv = get_idx_value(IDX, var)
    #----------------------------------------------------
    #--------------- Find all patches and indices that the line crosses ---------------------
    all_patches, all_indices = trace_1D_line(Snapshot_meta, point, dir)
    #---------------------------------------------------------------------------------------------
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    #---------------------------------------------------------------------------------------------
    #------------ Allocate data arrays ------------------------------------------------------
    #-------- total number of points in the line ------------------------
    n_points = sum(length.(all_indices))
    data = zeros(n_points)
    line_pos = zeros(n_points)
    line_3D = zeros(3, n_points)
    #--------------------------------------------------------------------------------------------
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
    #----------- location in data array -----------
    data_index = 1
    #--------------------------------------------
    #------------------ Loop through all patches that the line crosses --------------------------------
    for i in 1:length(patch_indices)
        #---------- move file pointer to the correct patch and variable position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        move_file_pointer_var(f, Snapshot_meta,  iv)
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, all_indices[i])
        #------------------------------------------------------------------------
        for j in 1:length(all_indices[i])
            #----------  Move pointer to the next cell index in the patch ------------------------
            move_file_pointer_cell(f, offset_diff[j])
            #----------------------------------------------------------------------------------
            #-------------------- find position on line and global 3D line position -------------
            pos = index_to_local_pos(all_indices[i][j])
            pos = get_global_pos(Snapshot_meta.PATCHES[patch_indices[i]], pos)
            l_pos, l_3d_pos = project_onto_line(point, dir, pos )
            line_pos[data_index] = l_pos
            line_3D[:, data_index] = l_3d_pos
            #-------------------------------------------------------------------------------------
            #------------ read data -------------------------------------
            data[data_index] = read(f, Float32)
            #-------------------------------------------------
            #---------- increase data index counter ----------------
            data_index += 1
            #--------------------------------------------------------------
        end
        #-------------------- Move pointer to the next variable ------------------------------
        move_file_pointer_next_var(f, Snapshot_meta, offset[end])
        #--------------------------------------------------------------------------------------
        #--------- move file pointer to the start of the next patch ----------------
        move_file_pointer_next_patch(f, Snapshot_meta, iv)
        #----------------------------------------------------------------
    end
    #---------------------------------------------------------------------------------------------------
    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------
    #------ sort output ----------------------------------------------------------------
    sorted_indices = sortperm(line_pos)
    data = data[sorted_indices, :]
    line_pos = line_pos[sorted_indices]
    line_3D = line_3D[:, sorted_indices]
    #-------------------------------------------------------------------------------------
    return data , line_pos, line_3D
end

function Slice_1D(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat},
    vars :: Vector{String})
    #------ integer index of the variable -------------------------
    ivs, sorted_vars, sorted_iv_indices, iv_diff = get_sorted_vars(Snapshot_meta, vars)
    #----------------------------------------------------
    #--------------- Find all patches and indices that the line crosses ---------------------
    all_patches, all_indices = trace_1D_line(Snapshot_meta, point, dir)
    #---------------------------------------------------------------------------------------------
    #--------------- sort patches and indices according to patch position in data folder ---------
    patch_indices, sorted_indices, patch_index_diff = get_sorted_patch_IDs(Snapshot_meta, all_patches)
    #---------------------------------------------------------------------------------------------
    #------------ Allocate data arrays ------------------------------------------------------
    #-------- total number of points in the line ------------------------
    n_points = sum(length.(all_indices))
    line_pos = zeros(n_points)
    line_3D = zeros(3, n_points)
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = zeros(Float32, n_points)
    end
    #--------------------------------------------------------------------------------------------
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
    #----------- location in data array -----------
    data_index = 1
    #--------------------------------------------
    #------------------ Loop through all patches that the line crosses --------------------------------
    for i in 1:length(patch_indices)
        #---------- move file pointer to the correct patch  position ----------------
        move_file_pointer_patch(f, Snapshot_meta, patch_index_diff[i])
        #---------------------------------------------------------------------------
        #------------ find local indices and their offsets ----------------
        offset, offset_diff = get_cell_indices_offset(Snapshot_meta, all_indices[i])
        #------------------------------------------------------------------------
        #------- Temporary data index counter ----------------------------
        data_index_temp = data_index
        #-------------------------------------------------------------------
        for k in 1:length(sorted_vars)
            #-------------- reset data index counter for each variable ---------------------
            data_index_temp = data_index
            #-----------------------------------------------------------------------------------
            #--------------------
            var = sorted_vars[k]
            #-------------------
            #---------- move file pointer to the correct variable position ----------------
            move_file_pointer_var(f, Snapshot_meta, iv_diff[k])
            #-------------------------------------------------------------------------------------------
            for j in 1:length(all_indices[i])
                #----------  Move pointer to the next cell index in the patch ------------------------
                move_file_pointer_cell(f, offset_diff[j])
                #----------------------------------------------------------------------------------
                #-------------------- find position on line and global 3D line position -------------
                if k ==1 
                    pos = index_to_local_pos(all_indices[i][j])
                    pos = get_global_pos(Snapshot_meta.PATCHES[patch_indices[i]], pos)
                    l_pos, l_3d_pos = project_onto_line(point, dir, pos )
                    line_pos[data_index_temp] = l_pos
                    line_3D[:, data_index_temp] = l_3d_pos
                end
                #-------------------------------------------------------------------------------------
                #------------ read data -------------------------------------
                all_var_data[var][data_index_temp] = read(f, Float32)
                #-------------------------------------------------
                #---------- increase data index counter ----------------
                data_index_temp += 1
                #--------------------------------------------------------------
            end
            #-------------------- Move pointer to the next variable ------------------------------
            move_file_pointer_next_var(f, Snapshot_meta, offset[end])
            #--------------------------------------------------------------------------------------
        end
        #---------------------------------------------------------------------------------------------------
        data_index = data_index_temp
        #--------- mvoe file pointer to the start of the next patch ----------------
        move_file_pointer_next_patch(f, Snapshot_meta, ivs[end])
        #---------------------------------------------------------------------------
    end
    #---------------------------------------------------------------------------------------------------
    #------------------ close the data file ---------------------------------------------
    close(f)
    #-------------------------------------------------------------------------------------
    #------ sort output ----------------------------------------------------------------
    sorted_indices = sortperm(line_pos)
    for var in vars
        all_var_data[var] = all_var_data[var][sorted_indices]
    end
    line_pos = line_pos[sorted_indices]
    line_3D = line_3D[:, sorted_indices]
    #-------------------------------------------------------------------------------------
    return all_var_data , line_pos, line_3D

end