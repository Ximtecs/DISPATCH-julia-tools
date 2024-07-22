function drop_unit_dims(x::AbstractArray)
    return dropdims(x, dims = tuple( (d for d in 1:ndims(x) if size(x,d) == 1)...));
end