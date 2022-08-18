module Scanivalve

using Sockets
using DAQCore

export DSA3217
export daqread, daqstart, daqacquire, daqconfig, daqconfigdev
export daqzero, daqstop, daqaddinput, numchannels, daqchannels

"Base type for Scanivalve pressure scanners"
abstract type AbstractScanivalve <: AbstractPressureScanner end


include("dsa3200packets.jl")
include("dsa3217.jl")




end
