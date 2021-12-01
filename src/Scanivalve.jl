module Scanivalve

using Sockets


export AbstractDAQ, DSA3217
export close, numchans, listscan, listzero, listgain, listoffset, listdelta
export scan!, stopscan, isreading, samplesread, scanconfig, daqparam
export clearbuffer!
export daqread, daqstart, daqacquire

abstract type AbstractDAQ end
abstract type AbstractPressureScanner <: AbstractDAQ end
abstract type AbstractScanivalve <: AbstractPressureScanner end

mutable struct DAQTask{DAQ <: AbstractDAQ}
    isreading::Bool
    stop::Bool
    nread::Int
    idx::Int
    buffer::Matrix{UInt8}
end
DAQTask(::Type{DAQ}, packsize=112, npacks=300_000) where {DAQ<:AbstractDAQ} =
    DAQTask{DAQ}(false, false, 0, 0, zeros(UInt8, packsize, npacks))


numframes(task::DAQTask) = size(task.buffer, 2)
framesize(task::DAQTask) = size(task.buffer, 1)

isreading(task::DAQTask) = task.isreading
samplesread(task::DAQTask) = task.nread
buffer(task::DAQTask, i) = view(task.buffer, :, i)
function clearbuffer!(task::DAQTask)
    task.buffer .= 0
    return
end

function resizebuffer!(task::DAQTask, packsize, npacks)
    task.buffer = zeros(UInt8, packsize, npacks)
    return
end


include("dsa3200packets.jl")
include("dsa3217.jl")



end
