module Scanivalve

using Sockets


export AbstractDAQ, DSA3217
export close, numchans, listscan, listzero, listgain, listoffset, listdelta


abstract type AbstractDAQ end
abstract type AbstractPressureScanner <: AbstractDAQ end
abstract type AbstractScanivalve <: AbstractPressureScanner end


mutable struct DSA3217 <: AbstractScanivalve
    socket::TCPSocket
    period::Int
    fps::Int
    avg::Int
    unit::String
    time::Int
    xtrig::Bool
    buffer::Matrix{UInt8}
    
end

function DSA3217(ipaddr="191.30.80.131")

    s = connect(ipaddr, 23)
    return DSA3217(s, -1, -1, -1, "", false)
    
end
import Base.close

function close(scani::DSA3217)
    close(socket(scani))
end

numchans(scani::DSA3217) = 16

socket(scani) = scani.socket

function readnlines(s, n=1)
    lst = String[]
    for i in 1:n
        push!(lst, readline(s))
    end
    return lst
end

function parse_dsa_set(lst)
    p = Dict{String,String}()
    for l in lst
        s = split(l, " ")
        p[s[2]] = s[3]
    end
    return p
end

function listany(scani::AbstractScanivalve, cmd, nparams)
    println(socket(scani), "LIST $cmd\r")
    lst = readnlines(socket(scani), nparams)
    return lst
end


listanydict(scani::AbstractScanivalve, cmd, nparams) = parse_dsa_set(listany(scani, cmd, nparams))

function listanyval(scani::AbstractScanivalve,
                    cmd, nparams, ::Type{T}=Int) where {T<:Real} 
    lst = listany(scani, cmd, nparams)
    nlst = length(lst)
    vals = zeros(T, nlst)
    
    for i in 1:nlst
        s = split(lst[i], " ")
        vals[i] = parse(T, s[3])
    end

    return vals
end

listscan(scani::DSA3217) = listanydict(scani, "S", 14)
listident(scani::DSA3217) = listanydict(scani, "I", 4)
listzero(scani::AbstractScanivalve) = listanyval(scani, "Z", numchans(scani), Int)
listoffset(scani::AbstractScanivalve) = listanyval(scani, "O", numchans(scani), Float64)
listdelta(scani::AbstractScanivalve) = listanyval(scani, "O", numchans(scani), Float64)
listgain(scani::AbstractScanivalve) = listanyval(scani, "G", numchans(scani), Float64)
setparam(scani, param, val) = println(socket(scani), "SET $param $val\r")



end
