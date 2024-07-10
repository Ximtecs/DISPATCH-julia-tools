using LinearAlgebra
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

#-------- Translate a patch local floating point position to a global position -------------------
function get_local_pos(patch::Patch_NML, global_pos::AbstractVector{<:AbstractFloat} )
    return (global_pos - patch.LLC_NAT) ./ patch.DS
end
#-------------------------------------------------------------------------------------------

#------- Translate a global floating point position to a patch local position -------------------
function get_global_pos(patch::Patch_NML, local_pos::AbstractVector{<:AbstractFloat} )
    return  local_pos .* patch.DS + patch.LLC_NAT
end
#-------------------------------------------------------------------------------------------------


#----------- Translate a local floating point position to an array index ---------------------
#-------------- The index is based on cell centered location 
#-------------- He add 1e-10 to include 0.0 but exclude upper patch limit to numerical precision
function local_pos_to_index(local_pos::AbstractVector{<:AbstractFloat} )
    return round.(Int,local_pos .+ 0.5 .+ 1e-10)
end
#--------------------------------------------------------------------------------------------------

#----------- Translate an index to a local position ----------------
function index_to_local_pos(index :: Vector{Int})
    return index .- (0.5 - 1e-10)
end
#-----------------------------------------------------------------------------


#----------- determine if point is in a patch -----------------------
function in_patch(patch::Patch_NML, point::AbstractVector{<:AbstractFloat})
    LLC = patch.LLC_NAT # Lower left corner
    Size = patch.SIZE
    URC = LLC .+ Size # Upper right corner
    is_in_patch = all(LLC .<= point) && all(point .< URC)
    return is_in_patch
end
#-------------------------------------------------------------------------------------

#----------- Find the first patch in the snapshot where the point lies within -------
function find_patch(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat})
    for patch in Snapshot_meta.PATCHES
        if in_patch(patch, point)
            return patch
        end
    end
    return nothing
end
#------------------------------------------------------------------------------------

#----------- Find a patch in a list of neighbohrs where a point is within the neighbohr --------
function find_patch(Snapshot_meta::Snapshot_metadata, point::AbstractVector{<:AbstractFloat}, NBOR_IDS::Vector{Int})
    for id in NBOR_IDS
        index = findfirst(patch -> patch.ID == id, Snapshot_meta.PATCHES)
        if index !== nothing && in_patch(Snapshot_meta.PATCHES[index], point)
            return Snapshot_meta.PATCHES[index]
        end
    end
    return nothing
end
#-------------------------------------------------------------------------------------------


#--------- project a position into a line 
#--------- returns the 1D position on the line and the closets 3D position ---
#-------- Assume 'point' is the center of the 1D line ------------------------
function project_onto_line(point::AbstractVector{<:AbstractFloat}, dir::AbstractVector{<:AbstractFloat}, position::AbstractVector{<:AbstractFloat})
    dir_unit = dir / sqrt(sum(dir.^2))  # Ensure the direction vector is a unit vector
    point_to_position = position .- point  # Vector from the point on the line to the position

    # Project point_to_position onto dir_unit
    t = dot(point_to_position, dir_unit)  # This is the scalar projection of point_to_position onto dir_unit

    # Calculate the closest point on the line
    closest_point = point .+ t .* dir_unit

    return t, closest_point
end
#---------------------------------------------------------------------------


function index_to_byte_offset(index::Vector{Int}, patch_size::Vector{Int}, datatype::Type)
    # Ensure the index vector has three elements (x, y, z)
    @assert length(index) == 3 "Index must have three elements (x, y, z)"
    @assert length(patch_size) == 3 "Dimensions must have three elements (nx, ny, nz)"
    
    # Calculate the linear offset in a column-major order
    x, y, z = index
    nx, ny, nz = patch_size
    linear_index = (x - 1) + (y - 1) * nx + (z - 1) * nx * ny
    
    # Calculate the byte offset by multiplying with the size of the data type
    byte_offset = linear_index * sizeof(datatype)

    return byte_offset
end

function index_to_linear_offset(index::Vector{Int}, patch_size::Vector{Int})
    # Ensure the index vector has three elements (x, y, z)
    @assert length(index) == 3 "Index must have three elements (x, y, z)"
    @assert length(patch_size) == 3 "Dimensions must have three elements (nx, ny, nz)"
    
    # Calculate the linear offset in a column-major order
    x, y, z = index
    nx, ny, nz = patch_size
    linear_index = (x - 1) + (y - 1) * nx + (z - 1) * nx * ny
    
    # Calculate the byte offset by multiplying with the size of the data type
    byte_offset = linear_index

    return byte_offset
end




#------------- Move the file pointer n_patches forward ----------------
function move_file_pointer_patch(f::IO, Snapshot_meta::Snapshot_metadata, n_patches :: Int)
    _, total_size_in_bytes = get_patch_size(Snapshot_meta)

    if n_patches > 1
        seek(f,  position(f) + total_size_in_bytes * (n_patches - 1))
    end
end
#--------------------------------------------------------------------------------


function move_file_pointer_var(f::IO, Snapshot_meta::Snapshot_metadata, n_var::Int)
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    NV = Snapshot_meta.SNAPSHOT.NV
    _, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))

    if n_var > 1
        seek(f, position(f) + total_var_size_in_bytes * (n_var - 1))
    end
end


function move_file_pointer_cell(f::IO, n_cell :: Int)
    if n_cell > 1
        seek(f, position(f) + sizeof(Float32) * (n_cell - 1))
    end
end

#------------ Move file pointer to start of the next patch
function move_file_pointer_next_patch(f::IO, Snapshot_meta::Snapshot_metadata, iv :: Int)
    total_size, total_size_in_bytes = get_patch_size(Snapshot_meta)
    NV = Snapshot_meta.SNAPSHOT.NV
    _, total_var_size_in_bytes = (Int(total_size / NV) , Int(total_size_in_bytes / NV))

    #-------- move pointer to the start of the next patch ----------------
    if iv < NV
        seek(f, position(f) + total_var_size_in_bytes * (NV - iv))
    end 
    #----------------------------------------------------------------
end


#---------- Move the pointer from cell index to beginning of the next variable ----------------
function move_file_pointer_next_var(f::IO, Snapshot_meta::Snapshot_metadata, cell_index :: Int)
    patch_size = get_integer_patch_size(Snapshot_meta)
    last_cell_index = index_to_linear_offset(patch_size, patch_size)

    if cell_index < last_cell_index
        seek(f, position(f) + sizeof(Float32) * (last_cell_index + 1 - cell_index))
    end

end
#-----------------------------------------------------------------------------------------------



function get_sorted_patch_IDs(Snapshot_meta::Snapshot_metadata, patch_IDs::Vector{Int})
    indices = [findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES) for patch_ID in patch_IDs]
    sorted_indices = sortperm(indices)
    indices = indices[sorted_indices]
    index_diff = [indices[1]; diff(indices)]

    return indices, sorted_indices, index_diff

end


function get_sorted_vars(Snapshot_meta::Snapshot_metadata, vars::Vector{String})
    ivs = [get_idx_value(Snapshot_meta.IDX, var) for var in vars]
    sorted_iv_indices = sortperm(ivs)
    ivs = ivs[sorted_iv_indices]
    vars = vars[sorted_iv_indices]
    iv_diff = [ivs[1]; diff(ivs)]

    return ivs, vars, sorted_iv_indices, iv_diff
end


function get_cell_indices_offset(Snapshot_meta::Snapshot_metadata, indices::Vector{Vector{Int}})
    patch_size = get_integer_patch_size(Snapshot_meta)
    offset = [index_to_linear_offset(index, patch_size) for index in indices]
    offset_diff = [offset[1]; diff(offset)]

    return offset, offset_diff
end


