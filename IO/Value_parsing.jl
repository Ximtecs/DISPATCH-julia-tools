function parse_array(value::String)
    elements = split(value, ",")
    parsed_elements = String[]
    for element in elements
        element = strip(element)
        if occursin(r"\*", element)
            parts = split(element, "*")
            count = parse(Int, strip(parts[1]))
            repeated_value = strip(parts[2])
            append!(parsed_elements, fill(repeated_value, count))
        else
            push!(parsed_elements, element)
        end
    end
    return join(parsed_elements, ",")[1:end-1]
end


function parse_value(value::String, type::DataType)
    if type == Int
        return parse(Int, strip(value, ','))
    elseif type == Float64
        return parse(Float64, strip(value, ','))
    elseif type == Bool
        return strip(value, ',') == "T"
    elseif type == String
        return strip(strip(value, ','), ''')
    elseif type == Vector{Int}
        array_str = parse_array(value)
        return [parse(Int, val) for val in split(array_str, ',')]
    elseif type == Vector{Float64}
        array_str = parse_array(value)
        return [parse(Float64, val) for val in split(array_str, ',')]
    elseif type == Vector{Bool}
        array_str = parse_array(value)
        return [val == "T" for val in split(array_str, ',')]
    else
        error("Unsupported data type: $type")
    end
end