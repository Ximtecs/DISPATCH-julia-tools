include("helper_functions.jl")
include("../misc/IDX_conversing.jl")



function load_snapshot_particles(Snapshot_meta :: Snapshot_metadata)
        #--------- basic information about the snapshot and the patches ------
        n_patches = Snapshot_meta.N_PARTICLE_PATCHES
        n_particles = Snapshot_meta.N_PARTICLES
        DO_PARTICLES = Snapshot_meta.DO_PARTICLES
        snapshot = Snapshot_meta.SNAPSHOT
        #--------------------------------------------------------------------

        if n_patches == 0 || !DO_PARTICLES
            @error "Trying to include particles but no particles in snapshot"
        end

        N_SPECIES = Snapshot_meta.PARTICLES[1].N_SPECIES

        #---------- allocate array -------------------------------
        all_q = []
        all_r = []
        all_p = []
        all_w = []
        all_e = []
        all_nr = []
        all_ids = [] # patch ID for each particle
        all_pos = [] # Global position of each particle
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
        #-----------------------------------------------------------------

        particle_index = [ 1 for i in 1:N_SPECIES]

        #---------- if patches have different data files load them each individually ------------
        data_files = [patch.DATA_FILE for patch in Snapshot_meta.PARTICLES]
        if length(unique(data_files)) > 1
            for data_file in unique(data_files)
                f = open(data_file,"r")
                for i in 1:n_patches
                    
                    particle_patch = Snapshot_meta.PARTICLES[i]

                    if (particle_patch.DATA_FILE != data_file)
                        continue
                    end

                    #------ find memory offset for the patch ------
                    ID = particle_patch.ID
                    patch_index = findfirst(patch -> patch.ID == ID, Snapshot_meta.PATCHES)
                    patch = Snapshot_meta.PATCHES[patch_index]
                    #----------------------------------------------
     
                    #----------------- loop over species and load them -------------------------------
                    n_particles_in_patch = particle_patch.M
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
                        global_pos  = calc_global_particle_pos(q_data, r_data, patch, snapshot)
                        pos_data .= global_pos
                        #--------------------------------------------------------------------------------
    
                        #---------- Update particle index for next patch ----------------
                        particle_index[j] += n_particles_in_patch[j]
                        #--------------------------------------------------------------
                    end
                        #--------------------------------------------------------------------------------------------------------------
                    #-------------------------------------------------------------------------------------------
                end 
                close(f)
                #--------------------------------------------------------------------------------
            end 


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
                #----------------------------------------------
 
                #----------------- loop over species and load them -------------------------------
                n_particles_in_patch = particle_patch.M
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
                    global_pos  = calc_global_particle_pos(q_data, r_data, patch, snapshot)
                    pos_data .= global_pos
                    #--------------------------------------------------------------------------------

                    #---------- Update particle index for next patch ----------------
                    particle_index[j] += n_particles_in_patch[j]
                    #--------------------------------------------------------------
                end
                    #--------------------------------------------------------------------------------------------------------------
                #-------------------------------------------------------------------------------------------
            end 


            close(f)
            #--------------------------------------------------------------------------------
        end

        for j in 1:N_SPECIES
            sorted_indices = sortperm(all_nr[j][:])
            all_q[j] = all_q[j][:,sorted_indices]
            all_r[j] = all_r[j][:,sorted_indices]
            all_p[j] = all_p[j][:,sorted_indices]
            all_w[j] = all_w[j][sorted_indices]
            all_e[j] = all_e[j][sorted_indices]
            all_nr[j] = all_nr[j][sorted_indices]
            all_ids[j] = all_ids[j][sorted_indices]
            all_pos[j] = all_pos[j][:,sorted_indices]
        end


        return all_q, all_r, all_p, all_w, all_e, all_nr, all_pos, all_ids
end