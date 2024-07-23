using Base.Threads

include("load_snapshot_PIC.jl")
include("../IO/Snapshot_parser.jl")

function load_multiple_snapshots_PIC(data_folder :: String, INCLUDE_PARTICLES :: Bool, i_start :: Int, i_end :: Int, stride :: Int)
    #---------------- count number of snapshots ------------
    n_snaps = Int(floor( (i_end - i_start) / stride) + 1)
    #------------------------------------------------------
    #------  Get initial snapshot and memory size  --------
    initial_snapshot = read_snapshot(data_folder, i_start);
    NV_PARTICLE_FIELDS =  initial_snapshot.PARTICLES[1].NV_PARTICLE_FIELDS
    DO_PARTICLES = initial_snapshot.IO.DO_PARTICLES
    mem_size = get_mem_size(initial_snapshot)
    mem_size[4] = NV_PARTICLE_FIELDS
    #------------------------------------------------------

    #------ Allocate memory for all snapshots -------------
    all_data = zeros(Float32,mem_size..., n_snaps)
    all_t = zeros(Float32,n_snaps)

    all_q = []
    all_r = []
    all_p = []
    all_w = []
    all_e = []
    all_nr = []
    all_ids = [] # patch ID for each particle
    all_pos = [] # Global position of each particle

    #------------------------------------------------------

    lk = Base.ReentrantLock() 
    index_order = []

    #-------- Loop through all snapshots and load them into the allocated memory ---------
    Threads.@threads for snap in i_start:stride:i_end
        iter = Int(((snap - i_start) / stride) + 1 )
        Snapshot_meta = read_snapshot(data_folder, snap);
        all_data[:,:,:,:,iter], q, r, p, w, e, nr, pos, ids = load_snapshot_PIC(Snapshot_meta, INCLUDE_PARTICLES)
        all_t[iter] = Snapshot_meta.SNAPSHOT.TIME

        #------- push particles and store the order of the snapshots ----------------
        lock(lk) do
            push!(all_q, q)
            push!(all_r, r)
            push!(all_p, p)
            push!(all_w, w)
            push!(all_e, e)
            push!(all_nr, nr)
            push!(all_pos, pos)
            push!(all_ids, ids)

            push!(index_order, iter)
        end
        #---------------------------------------------------------------------------
    end
    #---------------------------------------------------------------------------------------

    sorted_indices = sortperm(index_order)

    all_q = all_q[sorted_indices]
    all_r = all_r[sorted_indices]
    all_p = all_p[sorted_indices]
    all_w = all_w[sorted_indices]
    all_e = all_e[sorted_indices]
    all_nr = all_nr[sorted_indices]
    all_ids = all_ids[sorted_indices]
    all_pos = all_pos[sorted_indices]


    return all_data, all_t, all_q, all_r, all_p, all_w, all_e, all_nr, all_ids, all_pos
end
