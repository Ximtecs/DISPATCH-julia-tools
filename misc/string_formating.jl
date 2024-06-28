function int_to_fixed_length_string(number::Int, length::Int)
    number_str = string(number)
    return lpad(number_str, length, '0')
end