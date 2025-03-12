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
    res = join(parsed_elements, ",")
    if (res[end] == ',') 
        return res[1:end-1]
    else
        return res
    end
end


function parse_value(value::String, type::DataType)
    try
        if type == Int
            return parse(Int, strip(value, ','))
        elseif type == Float64
            return parse(Float64, strip(value, ','))
        elseif type == Bool
            return strip(value, ',') == "T"
        elseif type == String
            return strip(strip(value, ','), ''')
        elseif type == Vector{Int}
            if value == ""
                return Int[]
            else
                array_str = parse_array(value)
                return [parse(Int, val) for val in split(array_str, ',')]
            end
        elseif type == Vector{Float64}
            array_str = parse_array(value)
            return [parse(Float64, val) for val in split(array_str, ',')]
        elseif type == Vector{Bool}
            array_str = parse_array(value)
            return [val == "T" for val in split(array_str, ',')]
        else
            error("Unsupported data type: $type")
        end
    catch e
        println("Error parsing value: '$value'")
        println("with type: '$type'")
        rethrow(e)
    end
end