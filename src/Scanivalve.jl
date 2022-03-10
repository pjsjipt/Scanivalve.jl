module Scanivalve

using Sockets
using AbstractDAQs

export AbstractDAQ, DSA3217
export close, numchans, listscan, listzero, listgain, listoffset, listdelta
export scan!, stopscan, isreading, samplesread, scanconfig, daqparam
export clearbuffer!
export daqread, daqstart, daqacquire, daqconfig, daqconfigdev
export daqzero, daqstop, daqaddinput, numchannels, daqchannels
export DAQConfig, iparameters, fparameters, sparameters, devname
export daqdevip, daqdevmodel, daqdevserialnum, daqdevtag

"Base type for Scanivalve pressure scanners"
abstract type AbstractScanivalve <: AbstractPressureScanner end


include("dsa3200packets.jl")
include("dsa3217.jl")




end
