include("helper_functions.jl")
include("../misc/IDX_conversing.jl")


function trace_line_in_patch(Snapshot_meta::Snapshot_metadata, patch::Patch_NML, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat})
    LLC = patch.LLC_NAT
    Size = patch.SIZE
    URC = LLC .+ Size
    cells = get_integer_patch_size(Snapshot_meta)
    dir_unit = dir / sqrt(sum(dir.^2))

    # Convert physical coordinates to local indices, accounting for dimensions with only one cell
    local_point = get_local_pos(patch, point)
    
    indices = []
    push!(indices, local_pos_to_index(local_point))

    # Traverse along the positive direction within the bounds of the patch
    new_local_point = local_point .+ dir_unit
    while all(new_local_point .>= 0.0) && all(new_local_point .< cells)
        push!(indices, local_pos_to_index(new_local_point))
        new_local_point = new_local_point .+ dir_unit
    end

    point_right = new_local_point

    # Traverse along the negative direction within the bounds of the patch
    new_local_point = local_point .- dir_unit
    while all(new_local_point .>= 0.0) && all(new_local_point .< cells)
        push!(indices, local_pos_to_index(new_local_point))
        new_local_point = new_local_point .- dir_unit
    end

    point_left = new_local_point

    indices = sort!(unique(indices))


    global_left = get_global_pos(patch, point_left)
    global_right = get_global_pos(patch, point_right)

    return indices, global_left, global_right
end



function trace_1D_line(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat}, trace_dir :: String,
    all_patches , all_indices)

if trace_dir == "left"
left_point = point
patch = find_patch(Snapshot_meta, left_point)
while patch != nothing
    indices, left_point, _ = trace_line_in_patch(Snapshot_meta, patch, left_point, dir)
    push!(all_indices,indices)
    push!(all_patches, patch.ID)
    patch = find_patch(Snapshot_meta, left_point)
end


elseif trace_dir == "right"
right_point = point
patch = find_patch(Snapshot_meta, right_point)

while patch != nothing
    indices, _, right_point = trace_line_in_patch(Snapshot_meta, patch, right_point, dir)
    push!(all_indices,indices)
    push!(all_patches, patch.ID)
    patch = find_patch(Snapshot_meta, right_point)
end
else
error("wrong trace direction given")
end 

end

function Slice_1D(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat})

NV = Snapshot_meta.SNAPSHOT.NV
patch_size = get_integer_patch_size(Snapshot_meta)

total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
total_var_size, total_var_size_in_bytes = (Int(total_size / NV), Int(total_size_in_bytes / NV))


#--------------- first find all patches and cell indices that lie on the line ------------------
initial_patch = find_patch(Snapshot_meta, point)
if initial_patch === nothing
    error("Point outside simulation domain")
end

indices, left, right = trace_line_in_patch(Snapshot_meta, initial_patch, point, dir)
all_indices = []
all_patches = []

push!(all_indices,indices)
push!(all_patches, initial_patch.ID)

#--------- trace the line to the left and to the rith -------------------------
trace_1D_line(Snapshot_meta, left, dir, "left", all_patches, all_indices)
trace_1D_line(Snapshot_meta, right, dir, "right", all_patches, all_indices)
#-----------------------------------------------------------------------------
#-------------------------------------------------------------------------------------------


#---------------- Find patch position in data file and sort accordingly -------------------
#----------- find data position index for each patch ----------------
patch_indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in all_patches]
#-------------------------------------------------------------------

#-------------- Sort the indices in ascending order ----------------
sorted_IDs = sortperm(patch_indices)
patch_indices = patch_indices[sorted_IDs]
all_indices = all_indices[sorted_IDs]
patch_index_diff = [patch_indices[1] - 0; diff(patch_indices)]
#--------------------------------------------------------------------
#-------------------------------------------------------------------------------------


#------------ Allocate data arrays ------------------------------------------------------
#-------- total number of points in the line ------------------------
n_points = sum(length.(all_indices))
data = zeros(n_points, Snapshot_meta.SNAPSHOT.NV)
line_pos = zeros(n_points)
line_3D = zeros(3, n_points)
#--------------------------------------------------------------------------------------------

#---------- not yet implemented for multiple data file -----------------------------------------
data_files = [Snapshot_meta.PATCHES[index].DATA_FILE for index in patch_indices]
if length(unique(data_files)) > 1
    @warn "Data file different - uses non-optimized load_patches_var function"
    error(" Not implemented yet")
    return all_data
end
#--------------------------------------------------------------------------------------------


data_file = data_files[1]
#----------- location in data array -----------
data_index = 1
#--------------------------------------------

#---------------- open data file ------------------------------------------------------------------------
f = open(data_file, "r")
#---------------------------------------------------------------------------------------------------

#------------------ Loop through all patches that the line crosses --------------------------------
for i in 1:length(patch_indices)
if (patch_index_diff[i] - 1 > 0)
    # Move pointer to the next position in the file
    seek(f, position(f) + total_size_in_bytes * (patch_index_diff[i] - 1))
end


#------------ find local indices and their offsets ----------------
offset = [index_to_linear_offset(index, patch_size) for index in all_indices[i]]
offset_diff = [offset[1] - 0; diff(offset)]
last_offset = index_to_linear_offset(patch_size, patch_size)
#------------------------------------------------------------------------

data_index_temp = data_index

#------------------------------------ loop through all variables ------------------------------------
for k in 1:NV
    data_index_temp = data_index
    for j in 1:length(all_indices[i])


        #----------  Move pointer to the next cell index in the patch ------------------------
        if (offset_diff[j] - 1 > 0)
            seek(f, position(f) +  sizeof(Float32) * (offset_diff[j] - 1))
        end
        #----------------------------------------------------------------------------------

        
        #-------------------- find position on line and global 3D line position -------------
        pos = index_to_local_pos(all_indices[i][j])
        pos = get_global_pos(Snapshot_meta.PATCHES[patch_indices[i]], pos)
        l_pos, l_3d_pos = project_onto_line(point, dir, pos )
        if k ==1 
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
    if offset[end] < last_offset
        seek(f, position(f) + sizeof(Float32) * (last_offset + 1 - offset[end]))
    end
    #--------------------------------------------------------------------------------------


end
#---------------------------------------------------------------------------------------------------
data_index = data_index_temp


end
#---------------------------------------------------------------------------------------------------

#------------------ close the data file ---------------------------------------------
close(f)
#-------------------------------------------------------------------------------------




#------ sort output 
sorted_indices = sortperm(line_pos)
data = data[sorted_indices, :]
line_pos = line_pos[sorted_indices]
line_3D = line_3D[:, sorted_indices]
#-


#return all_patches, all_indices
return data , line_pos, line_3D
end