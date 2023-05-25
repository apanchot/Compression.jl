using ProfileView


function lz_zeros(vals::UInt64) 
    d = digits(UInt8,vals, base=16,pad=16)
    l = Int8(0)
    t = Int8(0)
    for (i,v) in enumerate(d) # smallest to largest bits / trailing to leading
        if v != UInt8(0)
            t = i-1
            break
        end
    end
    for (i,v) in enumerate(reverse(d)) # smallest to largest bits / trailing to leading
        if v != UInt8(0)
            l = i-1
            break
        end
    end
    return (l,t)
end

function hex2bit(h)
    return digits(UInt8,h, base=2,pad=4)
end






function xorf(vals::Vector{Float64})
    newvals = Vector{UInt64}(undef,length(vals)) # convert floats to uint
    vals = reinterpret.(UInt64,vals) 
    newvals[1] = vals[1]
    for i in 2:length(vals) # save first value uncompressed
        newvals[i] = xor(vals[i-1],vals[i]) # calculate xor values
    end
    # length(vals) < 10 && println(newvals)
    # println()
    return vcat(BitArray(digits(UInt64, length(vals), base=2, pad=64)), xorpackbits(newvals) )
end

function xorpackbits(vals::Vector{UInt64})
    bitarr = BitArray(undef,0)
    hex = digits.(UInt8,vals, base=16, pad=16) # keep in hex format
    for h in hex[1]
        for b in digits(UInt8,h, base=2,pad=4)
            push!(bitarr, b)
        end
    end
    prevlz = Int8(65)
    prevtz = Int8(65)
    curlz = Int8(0)
    curtz = Int8(0)
    for (i,v) in enumerate(hex[2:end])
        if vals[i+1] == UInt64(0)
            push!(bitarr, UInt8(0))
        else
            push!(bitarr, UInt8(1))
            curlz, curtz = lz_zeros(vals[i+1])
            # println(curlz,"-",curtz)
            if prevlz <= curlz && prevtz <= curtz && prevlz+prevtz+2 < curlz+curtz
                push!(bitarr, UInt8(0))
                # println("0: ",v)
                # println(v[prevtz+1:16-prevlz])
                for h in v[prevtz+1:16-prevlz] # significant bits
                    for b in digits(UInt8,h, base=2,pad=4)
                        push!(bitarr, b)
                    end
                end
            else
                push!(bitarr, UInt8(1))
                # println("1: ",v)
                for b in digits(UInt8,curlz, base=2,pad=4) # leading zeroes # pad with 4?
                    push!(bitarr, b)
                end
                for b in digits(UInt8,16-curtz-curlz, base=2,pad=5) # num of significant bits # pad with 5?
                    push!(bitarr, b)
                end
                for h in v[curtz+1:16-curlz] # significant bits
                    for b in digits(UInt8,h, base=2,pad=4)
                        push!(bitarr, b)
                    end
                end
                prevlz = curlz
                prevtz = curtz
            end
            
        end
    end
    # println(bitarr[65:end])
    while length(bitarr) % 64 > 0
        push!(bitarr, UInt8(0))
    end
    return bitarr
end

function xorunpackbits(vals::BitArray)
    bitarr = Vector{UInt64}(undef,vals.chunks[1])
    
    bitarr[1] = vals.chunks[2]
    ii = 129
    hz = UInt8(0) # num of hex zeros 
    hsd = UInt8(0) # num of significant digits
    vt = UInt64(0)
    bitarrit = 2
    iii = UInt8(0)
    while bitarrit <= vals.chunks[1]
        if vals[ii] == UInt8(0) # xor is 0, value is same as last
            bitarr[bitarrit] = bitarr[bitarrit-1]
            ii += 1
        else
            ii += 1
            if vals[ii] == UInt8(1) # xor is 0, value is same as last

                ii += 1
                hz = UInt8(0) # num of hex zeros , mult by 4 to get bit
                iii = UInt8(0)
            
                for tt in ii:ii+3
                    if vals[tt]
                        hz += UInt8(1) << iii #* 2 ^ (i-1)
                    end
                    iii += UInt8(1)
                end
                
                hsd = UInt8(0) # num of significant digits , mult by 4 to get bit
                iii = UInt8(0)
                for tt in ii+4:ii+8
                    if vals[tt]
                        hsd += UInt8(1) << iii #* 2 ^ (i-1)
                    end
                    iii += UInt8(1)
                end
                vt = UInt64(0)
                for i in ii+9:ii+8+hsd*4 # important bits
                    if vals[i]
                        vt += UInt64(1)
                        vt <<= 1
                    else
                        vt <<= 1
                    end
                end
                vt = bitreverse(vt)
                for _ in 1:hz*4-1
                    vt >>= 1
                end
                bitarr[bitarrit] = xor(bitarr[bitarrit-1],vt)
                ii = ii+9+hsd*4 # move index to next
                
            else # second control bit is 0
                ii += 1
                vt = UInt64(0)
                for i in ii:ii-1+hsd*4 # important bits
                    if vals[i]
                        vt += UInt64(1)
                        vt <<= 1
                    else
                        vt <<= 1
                    end
                end
                vt = bitreverse(vt)
                for _ in 1:hz*4-1
                    vt >>= 1
                end

                bitarr[bitarrit] = xor(bitarr[bitarrit-1],vt)
                ii = ii+hsd*4 # move index to next

            end

        end
        bitarrit += 1
    end
    return bitarr
end


n=Int(1e7)
v = sort(rand(n))
reinterpret.(UInt64,v)


@time x = xorf(v)

length(x)/(n*64)
# ProfileView.@profview 
@time xx = xorunpackbits(x)
reinterpret.(Float64,xx) == v


2^47


reinterpret(UInt64,'A')
