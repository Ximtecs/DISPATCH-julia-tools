struct IDX_NML
    D::Int
    E::Int
    ET::Int
    S::Int
    PX::Int
    PY::Int
    PZ::Int
    BX::Int
    BY::Int
    BZ::Int
    QR::Int
    TT::Int
    PHI::Int
    P1::Int
    P2::Int
    P3::Int
    B1::Int
    B2::Int
    B3::Int
    EX::Int
    EY::Int
    EZ::Int
    JX::Int
    JY::Int
    JZ::Int
    RPHI::Int
end

struct IO_NML
    FORMAT::Int
    NTOTAL::Int
    OUT_TIME::Float64
    GUARD_ZONES::Bool
    TIME_DERIVS::Int
    METHOD::String
    NML_VERSION::Int
    DO_GENERIC::Bool
    DO_PIC :: Bool
end

struct SNAPSHOT_NML
    IOFORMAT::Int
    IOUT::Int
    TIME::Float64
    NTOTAL::Int
    BOX::Vector{Float64}
    LI::Vector{Int}
    UI::Vector{Int}
    NG::Vector{Int}
    GN::Vector{Int}
    N::Vector{Int}
    NV::Int
    MV::Int
    NT::Int
    GAMMA::Float64
    EOS_NAME::String
    OPACITY::String
    PERIODIC::Vector{Bool}
    GUARD_ZONES::Bool
    TIME_DERIVS::Int
    NO_MANS_LAND::Bool
    OMP_NTHREADS::Int
    MPI_SIZE::Int
    MESH_TYPE::Int
    MPI_DIMS::Vector{Int}
    REFINE_RATIO::Int
    ORIGIN::Vector{Float64}
end


struct NBOR_NML
    PARENT_ID :: Int
    NBOR_IDS :: Vector{Int}
end


struct Patch_NML
    ID::Int
    POSITION::Vector{Float64} 
    SIZE::Vector{Float64} 
    LEVEL::Int
    DTIME::Float64
    ISTEP::Int
    DS::Vector{Float64} 
    NCELL::Vector{Int}
    N::Vector{Int}
    NW::Int
    VELOCITY::Vector{Float64} 
    QUALITY::Float64
    MESH_TYPE::Int
    KIND::String
    ETYPE::String
    RECORD::Int
    RANK::Int
    IPOS::Vector{Int} 
    COST::Float64
    CENTRE_NAT::Vector{Float64} 
    LLC_NAT::Vector{Float64}
    EROT1::Vector{Float64}
    EROT2::Vector{Float64}
    EROT3::Vector{Float64}
    NBOR_NML:: NBOR_NML # list of neighbors
    DATA_POS::Int # position in the data file
    DATA_FILE::String # data file
end

struct Particles_NML
    ID::Int
    N_SPECIES::Int
    DO_PARTICLES::Bool
    NV_PARTICLE_FIELDS::Int
    IS_ELECTRON::Vector{Bool}
    MASS::Vector{Float64}
    CHARGE::Vector{Float64}
    M::Vector{Int}
    DATA_POS :: Int
    DATA_FILE :: String
end

struct Snapshot_metadata
    IO :: IO_NML
    SNAPSHOT:: SNAPSHOT_NML
    IDX :: IDX_NML
    n_patches :: Int
    PATCHES :: Vector{Patch_NML}
    n_particle_patches :: Int
    N_SPECIES :: Int
    N_PARTICLES :: Vector{Int}
    PARTICLES :: Vector{Particles_NML}
    folder :: String
end 

