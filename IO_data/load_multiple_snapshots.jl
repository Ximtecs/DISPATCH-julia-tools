using Base.Threads
include("load_snapshot.jl")
include("../IO/Snapshot_parser.jl")


function load_multiple_snapshots(data_folder :: String, i_start :: Int, i_end :: Int, stride :: Int)
    #---------------- count number of snapshots ------------
    n_snaps = Int(floor( (i_end - i_start) / stride) + 1)
    #------------------------------------------------------
    #------  Get initial snapshot and memory size  --------
    initial_snapshot = read_snapshot(data_folder, i_start);
    mem_size = get_mem_size(initial_snapshot)
    #------------------------------------------------------

    #------ Allocate memory for all snapshots -------------
    all_data = zeros(Float32,mem_size..., n_snaps)
    all_t = zeros(Float32,n_snaps)
    #------------------------------------------------------


    #-------- Loop through all snapshots and load them into the allocated memory ---------
    Threads.@threads for snap in i_start:stride:i_end
        iter = Int(((snap - i_start) / stride) + 1 )
        Snapshot_meta = read_snapshot(data_folder, snap);
        all_data[:,:,:,:,iter] = load_snapshot(Snapshot_meta)
        all_t[iter] = Snapshot_meta.SNAPSHOT.TIME
    end
    #---------------------------------------------------------------------------------------

    return all_data, all_t
end

function load_multiple_snapshots(data_folder :: String, var :: String, i_start :: Int, i_end :: Int, stride :: Int)
    #---------------- count number of snapshots ------------
    n_snaps = Int(floor( (i_end - i_start) / stride) + 1)
    #------------------------------------------------------
    #------  Get initial snapshot and memory size  --------
    initial_snapshot = read_snapshot(data_folder, i_start);
    mem_size = get_mem_size(initial_snapshot)[1:3] #drop NV
    #------------------------------------------------------
    #------ Allocate memory for all snapshots -------------
    all_data = zeros(Float32,mem_size..., n_snaps)
    all_t = zeros(Float32,n_snaps)
    #------------------------------------------------------


    #-------- Loop through all snapshots and load them into the allocated memory ---------
    Threads.@threads for snap in i_start:stride:i_end
        iter = Int(((snap - i_start) / stride) + 1 )
        Snapshot_meta = read_snapshot(data_folder, snap);
        all_data[:,:,:,iter] = load_snapshot(Snapshot_meta, var)
        all_t[iter] = Snapshot_meta.SNAPSHOT.TIME
    end
    #---------------------------------------------------------------------------------------

    return all_data, all_t
end


function load_multiple_snapshots(data_folder :: String, vars :: Vector{String}, i_start :: Int, i_end :: Int, stride :: Int)
    #---------------- count number of snapshots ------------
    n_snaps = Int(floor( (i_end - i_start) / stride) + 1)
    #------------------------------------------------------
    #------  Get initial snapshot and memory size  --------
    initial_snapshot = read_snapshot(data_folder, i_start);
    mem_size = get_mem_size(initial_snapshot)[1:3] #drop NV
    #------------------------------------------------------
    #------ Allocate memory for all snapshots -------------
    all_var_data = Dict{String, Array{Float32}}()
    for var in vars
        all_var_data[var] = zeros(Float32,mem_size..., n_snaps)
    end
    all_t = zeros(Float32,n_snaps)
    #------------------------------------------------------


    #-------- Loop through all snapshots and load them into the allocated memory ---------
    Threads.@threads for snap in i_start:stride:i_end
        iter = Int(((snap - i_start) / stride) + 1 )
        Snapshot_meta = read_snapshot(data_folder, snap);
        data =  load_snapshot(Snapshot_meta, vars)
        for var in vars
            all_var_data[var][:,:,:,iter] = data[var]
        end
        all_t[iter] = Snapshot_meta.SNAPSHOT.TIME
    end
    #---------------------------------------------------------------------------------------

    return all_var_data, all_t
end