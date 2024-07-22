include("helper_functions.jl")
include("../misc/IDX_conversing.jl")


function load_patch_PIC(Snapshot_meta :: Snapshot_metadata, patch_ID :: Int)
    #---------- find the index of the patch with the given ID ----------------
    index = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PATCHES)
    index_PIC = findfirst(patch -> patch.ID == patch_ID, Snapshot_meta.PARTICLES)
    #-------------------------------------------------------------------------

    #--------------- get the data file for the patch ----------------
    data_file = Snapshot_meta.PARTICLES[index_PIC].DATA_FILE
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