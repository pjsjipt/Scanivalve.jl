module Scanivalve

using Sockets
using AbstractDAQ

export AbstractDAQ, DSA3217
export close, numchans, listscan, listzero, listgain, listoffset, listdelta
export scan!, stopscan, isreading, samplesread, scanconfig, daqparam
export clearbuffer!
export daqread, daqstart, daqacquire, daqconfig, daqconfigdev, daqstop

abstract type AbstractScanivalve <: AbstractPressureScanner end



include("dsa3200packets.jl")
include("dsa3217.jl")



end
