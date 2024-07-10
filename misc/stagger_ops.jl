#--------- stagger factors struct ------------------------
mutable struct stagger_factors
    lb :: Array{Int, 1}
    ub :: Array{Int, 1}
    ds ::  Array{Float64, 1}

    ax :: Float64
    ay :: Float64
    az :: Float64

    bx :: Float64
    by :: Float64
    bz :: Float64

    cx :: Float64
    cy :: Float64
    cz :: Float64

    aa :: Float64
    bb :: Float64
    cc :: Float64
    function stagger_factors(ax:: Float64, ay:: Float64, az:: Float64, bx:: Float64, by:: Float64, bz:: Float64, cx:: Float64, cy:: Float64, aa:: Float64,  bb:: Float64, cc:: Float64)
        new(zeros(Int32, 3), zeros(Int32, 3), zeros(Int32, 3), ax, ay, az, bx, by, bz, cx, cy, cz, aa, bb, cc)
    end 
end 
#------------------------------------------------------
#-------- function to set values --------
function set_prefactors(stagger_factors, lb, ub, ds)
    stagger_factors.lb = lb
    stagger_factors.ub = ub
    stagger_factors.ds = ds
end
#------------------------------------------------------
#------------ second order stuff ---------------------
cc = 0.
bb = 0.
aa =0.5

cx=0.
cy=0.
cz=0.

bx=0.    
by=0.    
bz=0.

ax=1.
ay=1.
az=1.

factors_2nd_order = stagger_factors(ax, ay, az, bx, by, bz, cx, cy, aa, bb, cc)
#------------------------------------------------------

#------------ forth order stuff ---------------------
cc = 0.
bb =- 1. / 16.
aa = 0.5 - bb

cx=0.
cy=0.
cz=0.

bx= - 1. / 24.     
by= - 1. / 24.     
bz= - 1. / 24. 

ax= 1 - 3. * bx
ay= 1 - 3. * by
az= 1 - 3. * bz

factors_4th_order = stagger_factors(ax, ay, az, bx, by, bz, cx, cy, aa, bb, cc)
#------------------------------------------------------

#------------ sixth order stuff ---------------------
cc = 3. / 256.
bb = -25. / 256
aa = 0.5 - bb - cc

cx= 3. / 640.
cy= 3. / 640.
cz= 3. / 640.

bx= - 25. / 384 #(-1. - 120. * cx) / 24.     
by= - 25. / 384 #(-1. - 120. * cy) / 24.     
bz= - 25. / 384 #(-1. - 120. * cz) / 24. 

ax= 1 - 3. * bx - 5. * cx
ay= 1 - 3. * by - 5. * cy
az= 1 - 3. * bz - 5. * cz

factors_6th_order = stagger_factors(ax, ay, az, bx, by, bz, cx, cy, aa, bb, cc)
#------------------------------------------------------



#------------ second order interpolations ------------------------------------------

    #-------- dn ------------------------------------------------------------
function interp_x_dn_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]:ub[3]
        for j in lb[2]:ub[2]
            for i in lb[1]+1:ub[1]
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i-1,j,k])
            end 
        end 
    end 
    return arr_out
end
function interp_y_dn_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]:ub[3]
        for j in lb[2]+1:ub[2]
            for i in lb[1]:ub[1]
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i,j-1,k])
            end 
        end 
    end 
    return arr_out
end
function interp_z_dn_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]+1:ub[3]
        for j in lb[2]:ub[2]
            for i in lb[1]:ub[1]
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i,j,k-1])
            end 
        end 
    end 
    return arr_out
end
    #---------------------------------------------------------------------------

    #-------- up ------------------------------------------------------------
function interp_x_up_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]:ub[3]
        for j in lb[2]:ub[2]
            for i in lb[1]:ub[1]-1
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i+1,j,k])
            end 
        end 
    end 
    return arr_out
end
function interp_y_up_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]:ub[3]
        for j in lb[2]:ub[2]-1
            for i in lb[1]:ub[1]
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i,j+1,k])
            end 
        end 
    end 
    return arr_out
end
function interp_z_up_2nd(stagger_factors, array_in)
    lb = stagger_factors.lb
    ub = stagger_factors.ub

    arr_out = zeros(size(array_in))
    for k in lb[3]:ub[3]-1
        for j in lb[2]:ub[2]
            for i in lb[1]:ub[1]
                arr_out[i,j,k] = stagger_factors.aa * ( array_in[i,j,k] + array_in[i,j,k+1])
            end 
        end 
    end 
    return arr_out
end
    #---------------------------------------------------------------------------
#------------------------------------------------------------------------------------------