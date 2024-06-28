using Printf
include("Snapshot_meta_structs.jl")
include("Value_parsing.jl")
include("../misc/string_formating.jl")


function parse_name_content_NML(content::String)
    matches = eachmatch(r"(?s)&.*?/", content)
    sections  = [match.match[2:end-3] for match in matches]

    params_list = []

    for (i, section) in enumerate(sections)
        lines = split(section, "\n")
        name = strip(lines[1])[1:end-4]
        content = join(lines[2:end], "\n")
        push!(params_list, (name, content))
    end

    return params_list
end
#--------------------------------------------------------------------------------------------------------

#----------- Creates a dictionary with parameters and values for a single section of an nml file ------
function parse_params(params::String)
    lines = split(params, "\n")
    param_dict = Dict{String, String}()
    current_key = ""
    for line in lines
        if contains(line, "=")
            key_value = split(line, "=")
            key = strip(key_value[1])
            value = replace(strip(key_value[2]), " " => "")
            param_dict[key] = value
            current_key = key
        elseif current_key != ""
            value = replace(strip(line), " " => "")
            param_dict[current_key] *= value
        end
    end
    return param_dict
end
#--------------------------------------------------------------------------------------------------------

function parse_SNAPSHOT_NML(params :: String)
    dict = parse_params(params)
    Snapshot_params = SNAPSHOT_NML(
        parse_value(dict["IOFORMAT"], Int),
        parse_value(dict["IOUT"], Int),
        parse_value(dict["TIME"], Float64),
        parse_value(dict["NTOTAL"], Int),
        parse_value(dict["BOX"], Vector{Float64}),
        parse_value(dict["LI"], Vector{Int}),
        parse_value(dict["UI"], Vector{Int}),
        parse_value(dict["NG"], Vector{Int}),
        parse_value(dict["GN"], Vector{Int}),
        parse_value(dict["N"], Vector{Int}),
        parse_value(dict["NV"], Int),
        parse_value(dict["MV"], Int),
        parse_value(dict["NT"], Int),
        parse_value(dict["GAMMA"], Float64),
        parse_value(dict["EOS_NAME"], String),
        parse_value(dict["OPACITY"], String),
        parse_value(dict["PERIODIC"], Vector{Bool}),
        parse_value(dict["GUARD_ZONES"], Bool),
        parse_value(dict["TIME_DERIVS"], Int),
        parse_value(dict["NO_MANS_LAND"], Bool),
        parse_value(dict["OMP_NTHREADS"], Int),
        parse_value(dict["MPI_SIZE"], Int),
        parse_value(dict["MESH_TYPE"], Int),
        parse_value(dict["MPI_DIMS"], Vector{Int}),
        parse_value(dict["REFINE_RATIO"], Int),
        parse_value(dict["ORIGIN"], Vector{Float64})
    )
    return Snapshot_params
end


function parse_IO_NML(params :: String)
    dict = parse_params(params)
    IO_params = IO_NML(
      parse_value(dict["FORMAT"], Int) ,
      parse_value(dict["NTOTAL"], Int) ,
      parse_value(dict["OUT_TIME"], Float64) ,
      parse_value(dict["GUARD_ZONES"], Bool) ,
      parse_value(dict["TIME_DERIVS"], Int) ,
      parse_value(dict["METHOD"], String) ,
      parse_value(dict["NML_VERSION"], Int) ,
      parse_value(dict["DO_GENERIC"], Bool) 
        )
    return IO_params
end

function parse_IDX_NML(params :: String)
    dict = parse_params(params)
    IDX_params = IDX_NML(
        parse_value(dict["D"], Int),
        parse_value(dict["E"], Int),
        parse_value(dict["ET"], Int),
        parse_value(dict["S"], Int),
        parse_value(dict["PX"], Int),
        parse_value(dict["PY"], Int),
        parse_value(dict["PZ"], Int),
        parse_value(dict["BX"], Int),
        parse_value(dict["BY"], Int),
        parse_value(dict["BZ"], Int),
        parse_value(dict["QR"], Int),
        parse_value(dict["TT"], Int),
        parse_value(dict["PHI"], Int),
        parse_value(dict["P1"], Int),
        parse_value(dict["P2"], Int),
        parse_value(dict["P3"], Int),
        parse_value(dict["B1"], Int),
        parse_value(dict["B2"], Int),
        parse_value(dict["B3"], Int),
        parse_value(dict["EX"], Int),
        parse_value(dict["EY"], Int),
        parse_value(dict["EZ"], Int),
        parse_value(dict["JX"], Int),
        parse_value(dict["JY"], Int),
        parse_value(dict["JZ"], Int),
        parse_value(dict["RPHI"], Int)
    )

end

function parse_NBOR_NML(params :: String)
    dict = parse_params(params)

    NBOR_params = NBOR_NML(
        parse_value(dict["PARENT_ID"], Int),
        parse_value(dict["NBOR_IDS"], Vector{Int})
    )

    return NBOR_params
end

function parse_PATCH_NML(params :: String, NBOR_params :: NBOR_NML, data_pos :: Int, data_file :: String)
    dict = parse_params(params)

    PATCH_params = Patch_NML(
        parse_value(dict["ID"], Int),
        parse_value(dict["POSITION"], Vector{Float64}),
        parse_value(dict["SIZE"], Vector{Float64}),
        parse_value(dict["LEVEL"], Int),
        parse_value(dict["DTIME"], Float64),
        parse_value(dict["ISTEP"], Int),
        parse_value(dict["DS"], Vector{Float64}),
        parse_value(dict["NCELL"], Vector{Int}),
        parse_value(dict["N"], Vector{Int}),
        parse_value(dict["NW"], Int),
        parse_value(dict["VELOCITY"], Vector{Float64}),
        parse_value(dict["QUALITY"], Float64),
        parse_value(dict["MESH_TYPE"], Int),
        parse_value(dict["KIND"], String),
        parse_value(dict["ETYPE"], String),
        parse_value(dict["RECORD"], Int),
        parse_value(dict["RANK"], Int),
        parse_value(dict["IPOS"], Vector{Int}),
        parse_value(dict["COST"], Float64),
        parse_value(dict["CENTRE_NAT"], Vector{Float64}),
        parse_value(dict["LLC_NAT"], Vector{Float64}),
        parse_value(dict["EROT1"], Vector{Float64}),
        parse_value(dict["EROT2"], Vector{Float64}),
        parse_value(dict["EROT3"], Vector{Float64}),
        NBOR_params,
        data_pos,
        data_file
    )

    return PATCH_params
end 


#--------------- load and store information in the snapshot.nml file ------------------------------
function parse_snapshot_nml(file_path::String)
    content = read(file_path, String)

    params_list = parse_name_content_NML(content)


    IO_content = [content for (name,content) in params_list if name == "IO"][1]
    IDX_content = [content for (name,content) in params_list if name == "IDX"][1]
    SNAPSHOT_content = [content for (name,content) in params_list if name == "SNAPSHOT"][1]


    IO_params = parse_IO_NML(IO_content)
    IDX_params = parse_IDX_NML(IDX_content)
    Snapshot_params = parse_SNAPSHOT_NML(SNAPSHOT_content)

    return IO_params, IDX_params, Snapshot_params
end 
#--------------------------------------------------------------------------------------------------------



#--------------- parse a single section with both NBOR_NML and Patch_NML information ------------------------------
function parse_patch(patch_param :: String, nbor_param :: String, data_pos :: Int, data_file :: String)
    NBOR_params = parse_NBOR_NML(nbor_param)
    Patch_params = parse_PATCH_NML(patch_param, NBOR_params, data_pos, data_file)

    return Patch_params
end 
#--------------------------------------------------------------------------------------------------------


#----------------- parse all pathces in a patches.nml file ------------------------------
function parse_patches_nml(file_path::String, data_file::String)
    content = read(file_path, String)
    params_list = parse_name_content_NML(content)

    params_list = params_list[2:end] # remove the IDX_NML section


    n_sections = size(params_list)[1]
    n_patches = Int(n_sections/2)
    patches_params = []

    data_pos = 1
    for i in 1:2:n_sections
        patch_param = params_list[i][2]
        nbor_param = params_list[i+1][2]

        PATCH_params = parse_patch(params_list[i][2], params_list[i+1][2], data_pos, data_file)
        push!(patches_params, PATCH_params)
        data_pos = data_pos + 1
    end 

    return patches_params, n_patches
end
#--------------------------------------------------------------------------------------------------------


#-------------- parse all meta information from a snapshot folder ------------------------------
function read_snapshot(folder)
    snapshot_nml_file = folder * "snapshot.nml"
    IO_params, IDX_params, Snapshot_params = parse_snapshot_nml(snapshot_nml_file)


    patches_params = []
    n_patches = 0 

    for MPI_rank in 0:Snapshot_params.MPI_SIZE-1
        patches_nml_file = folder * "rank_" * int_to_fixed_length_string(MPI_rank, 5) * "_patches.nml"
        data_file = folder * "snapshot_" * int_to_fixed_length_string(MPI_rank, 5) * ".dat"

        patches_params_rank, n_patches_rank = parse_patches_nml(patches_nml_file,data_file)
        patches_params = vcat(patches_params, patches_params_rank)
        n_patches = n_patches + n_patches_rank
    end 


    Snapshot_meta = Snapshot_metadata(IO_params, Snapshot_params, IDX_params, patches_params, n_patches, folder)

    return Snapshot_meta
end 
#--------------------------------------------------------------------------------------------------------
