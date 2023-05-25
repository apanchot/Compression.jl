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
        # for b in digits(UInt8,h, base=2,pad=4)
        #     push!(bitarr, b)
        # end
        append!(bitarr, hex2bit(h))
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
                    # for b in digits(UInt8,h, base=2,pad=4)
                    #     push!(bitarr, b)
                    # end
                    append!(bitarr, hex2bit(h))
                end
            else
                push!(bitarr, UInt8(1))
                # println("1: ",v)
                # for b in digits(UInt8,curlz, base=2,pad=4) # leading zeroes # pad with 4?
                #     push!(bitarr, b)
                # end
                append!(bitarr, hex2bit(curlz))
                for b in digits(UInt8,16-curtz-curlz, base=2,pad=5) # num of significant bits # pad with 5?
                    push!(bitarr, b)
                end
                for h in v[curtz+1:16-curlz] # significant bits
                    # for b in digits(UInt8,h, base=2,pad=4)
                    #     push!(bitarr, b)
                    # end
                    append!(bitarr, hex2bit(h))
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
    bitarrct = 2
    vt2 = UInt64(0)
    hz = UInt8(0) #  num of hex zeros 
    vt = UInt64(0)
    hsd = UInt8(0) # num of significant digits
    while bitarrct <= vals.chunks[1]
        # println(vals[ii:ii+1])
        if vals[ii] == UInt8(0) # xor is 0, value is same as last
            bitarr[bitarrct] = bitarr[bitarrct-1]
            bitarrct += 1
            ii += 1
        else
            ii += 1
            if vals[ii] == UInt8(1) # xor is 0, value is same as last
                ii += 1
                hz = UInt8(0) # num of hex zeros , mult by 4 to get bit
                for (i,tt) in enumerate(vals[ii:ii+3])
                    hz += tt * 2 ^ (i-1)
                end
                hsd = UInt8(0) # num of significant digits , mult by 4 to get bit
                for (i,tt) in enumerate(vals[ii+4:ii+8])
                    hsd += tt * 2 ^ (i-1)
                end
                vt = reverse(vals[ii+9:ii+8+hsd*4]) # important bits
                # println(reverse(vt))
                for _ in 1:hz*4 # add first bits
                    pushfirst!(vt,UInt8(0))
                end
                for _ in 1:64-length(vt) # add last bits
                    push!(vt,UInt8(0))
                end

                vt2 = UInt64(0) # get UInt64 from vt bits
                for (i,tt) in enumerate(reverse(vt))
                    vt2 += tt * 2 ^ (i-1)
                end
                bitarr[bitarrct] = xor(bitarr[bitarrct-1],UInt64(vt2))
                bitarrct += 1
                ii = ii+9+hsd*4 # move index to next
            else # second control bit is 0
                ii += 1
                # reuse hsd and hz from last time
                vt = vals[ii:ii+hsd*4-1] # important bits
                # println(reverse(vt))
                # println(hz)
                # for _ in 1:hz*4 # add first bits
                #     push!(vt,UInt8(0))
                # end
                for _ in 1:16-hz-hsd
                    vt = vt << 4
                end
                # for _ in 1:64-length(vt) # add last bits
                #     pushfirst!(vt,UInt8(0))
                # end
                # println(vt)

                vt2 = UInt64(0) # get UInt64 from vt bits
                for (i,tt) in enumerate(vt)
                    vt2 += tt * 2 ^ (i-1)
                end
                bitarr[bitarrct] = xor(bitarr[bitarrct-1],UInt64(vt2))
                bitarrct += 1
                ii = ii+hsd*4 # move index to next

            end

        end
    end
    return bitarr
end


n=Int(1e6)
v = sort(rand(n))
# v = rand(n)

@time x = xorf(v)

length(x)/(n*64)
@time xorunpackbits(x)
reinterpret.(Float64,xorunpackbits(x)) == v





reinterpret(UInt64,
sum([x*2^(i-1) for (i,x) in enumerate([0, 0, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 1, 0, 0, 1, 1, 1, 0, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1])])
)

UInt32(0x0a) << 4 << 4
UInt8(1)
@time bitreverse(UInt8(0xf))