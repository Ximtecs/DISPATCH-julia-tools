include("helper_functions.jl")
include("../misc/IDX_conversing.jl")



function load_snapshot_PIC(Snapshot_meta :: Snapshot_metadata, INCLUDE_PARTICLES :: Bool)
        #--------- basic information about the snapshot and the patches ------
        n_patches = Snapshot_meta.n_particle_patches
        N_SPECIES = Snapshot_meta.N_SPECIES
        NV_PARTICLE_FIELDS =  Snapshot_meta.PARTICLES[1].NV_PARTICLE_FIELDS
        n_particles = Snapshot_meta.N_PARTICLES
        DO_PARTICLES = Snapshot_meta.IO.DO_PARTICLES
        snapshot = Snapshot_meta.SNAPSHOT
        #--------------------------------------------------------------------

        if INCLUDE_PARTICLES
            if n_patches == 0 || !DO_PARTICLES
                @warn "Trying to include particles but no particles in snapshot"
                return []
            end
        end

        #---------- allocate array -------------------------------
        all_q = []
        all_r = []
        all_p = []
        all_w = []
        all_e = []
        all_nr = []
        all_ids = [] # patch ID for each particle
        all_pos = [] # Global position of each particle
        if INCLUDE_PARTICLES
            for i in 1:N_SPECIES
                q   = zeros(Int32,   (3,n_particles[i]));
                r   = zeros(Float32, (3,n_particles[i]));
                p   = zeros(Float32, (3,n_particles[i]));
                w   = zeros(Float32, (  n_particles[i]));
                e   = zeros(Float32, (  n_particles[i]));
                nr  = zeros(Int32,   (  n_particles[i]));   
                ids = zeros(Int32,   (  n_particles[i]));
                pos = zeros(Float32, (3,n_particles[i]));

                push!(all_q,q)
                push!(all_r,r)
                push!(all_p,p)
                push!(all_w,w)
                push!(all_e,e)
                push!(all_nr,nr)
                push!(all_ids,ids)
                push!(all_pos,pos)
            end 
        end
        patch_size = get_integer_patch_size(Snapshot_meta)
        mem_size = get_mem_size(Snapshot_meta)
        mem_size = mem_size[1:3] #drop NV
        all_data = zeros(Float32,mem_size..., NV_PARTICLE_FIELDS)
        #-----------------------------------------------------------------

        particle_index = [ 1 for i in 1:N_SPECIES]

        #---------- if patches have different data files load them each individually ------------
        data_files = [patch.DATA_FILE for patch in Snapshot_meta.PARTICLES]
        if length(unique(data_files)) > 1
            error("loading snapshot with different data files not implemented yet")
            #TODO - should be quite similar to below but loop through unique(data_files) list
            #----- should create a list of each patch in that file and loop through it 
        else 
            #------ if patches have same data file juust go through it to load all patches --------
            #---------- Open data file ----------------
            data_file = data_files[1]
            f = open(data_file,"r")
            #-----------------------------------------
            for i in 1:n_patches
                particle_patch = Snapshot_meta.PARTICLES[i]

                #------ find memory offset for the patch ------
                ID = particle_patch.ID
                patch_index = findfirst(patch -> patch.ID == ID, Snapshot_meta.PATCHES)
                patch = Snapshot_meta.PATCHES[patch_index]
                mem_offset = get_patch_mem_offset(Snapshot_meta,patch)
                #----------------------------------------------
     
                #---------- get subview of global memory and load data directly into global array --------------
                data = @view all_data[mem_offset[1]:mem_offset[1]+patch_size[1]-1,mem_offset[2]:mem_offset[2]+patch_size[2]-1,mem_offset[3]:mem_offset[3]+patch_size[3]-1,:]
  
                #----------- Read the data for the patch  --------------------
                read!(f, data)
                #-----------------------------------------------------------
                

                #----------------- If particles are included are included handle them ----------------
                if DO_PARTICLES
                    n_particles_in_patch = particle_patch.M

                    #--------- Check if include flag is given in function only read particles if true otherwise, skip them ---------
                    if INCLUDE_PARTICLES
                        for j in 1:N_SPECIES
                            #---------- create subviews of global arrays for each particle array ----------------
                            q_data  = @view all_q[j][:,particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            r_data  = @view all_r[j][:,particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            p_data  = @view all_p[j][:,particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            w_data  = @view all_w[j][  particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            e_data  = @view all_e[j][  particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            nr_data = @view all_nr[j][ particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]

                            ids_data = @view all_ids[j][particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            pos_data = @view all_pos[j][:,particle_index[j]:particle_index[j]+n_particles_in_patch[j]-1]
                            #--------------------------------------------------------------------------------------------------------------

                            #----------- Read the data for the particles  --------------------
                            read!(f, q_data)
                            read!(f, r_data)
                            read!(f, p_data)
                            read!(f, w_data)
                            read!(f, e_data)
                            read!(f, nr_data)
                            #-----------------------------------------------------------
                            #------- Add array with information on patch ID for each particle -----------
                            ids_data .= ID
                            #--------------------------------------------------------------------------------

                            #---------- Calculate and store global position of each particle ---------------
                            global_pos  = calc_global_pos(q_data, r_data, patch, snapshot)
                            pos_data .= global_pos
                            #--------------------------------------------------------------------------------

                            #---------- Update particle index for next patch ----------------
                            particle_index[j] += n_particles_in_patch[j]
                            #--------------------------------------------------------------
                        end
                    else
                        #---------- Skip the particles in the patch ----------------
                        particle_size_in_byte = ( 3 + 3 + 3 + 1 + 1 + 1) * sizeof(Float32)  * sum(n_particles_in_patch) 
                        seek(f,  position(f) + particle_size_in_byte )
                        #---------------------------------------------------------
                    end
                    #--------------------------------------------------------------------------------------------------------------

                end 
                #-------------------------------------------------------------------------------------------
            end 


            close(f)
            #--------------------------------------------------------------------------------
        end


        return all_data, all_q, all_r, all_p, all_w, all_e, all_nr, all_pos, all_ids
end