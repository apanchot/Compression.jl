
function rlepack(input::String)
    return rlepack(codeunits(input))
end

function rlepack(input::Base.CodeUnits{UInt8, String})
    l = length(input)
    vals = fill(UInt16(0),l)
    temp::UInt16 = UInt16(0)
    lastval = input[1]
    ii = 1
    i = 2
    iii = 1
    while i <= l
        if input[i] == lastval
            i += 1
        else
            temp = input[i-1]
            temp <<= 8
            temp += UInt8(i-ii)
            vals[iii] = temp
            lastval = input[i]
            ii = i
            i += 1
            iii += 1
        end
    end
    temp = UInt16(input[end])
    temp <<= 8
    temp += UInt8(i-ii)
    vals[iii] = temp
    i = 1
    for _ in 1:l
        if vals[i] != 0x0000
            i+=1
        end
    end
    return vals[1:i-1]
end

