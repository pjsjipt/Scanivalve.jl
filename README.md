# Scanivalve

A [Julia](https://julialang.org) package that provides an interface with [Scanivalve](http://scanivalve.com) pressure scanners. For now only DSA3217 scanners are supported but other scanners shouldn't be too hard to implement.

This Julia driver uses the interface provided by [AbstractDAQs.jl](https://github.com/pjsjipt/AbstractDAQs.jl).

## Basic usage

To connect to a DSA 3217 device, the method `DSA3217` should be used as shown in the following example:

```julia-repl
julia> using Scanivalve # Load the package

julia> scani = DSA3217("scanivalve", "191.30.80.131") # Create connection to the device
Scanivalve DSA3217
    Dev Name: scanivalve
    IP: 191.30.80.131

julia> daqconfigdev(scani, PERIOD=500, AVG=10, FPS=10) # Configure the device

julia> data = daqacquire(scani); # Acquire data synchronously

julia> daqstart(scani)
Task (runnable) @0x00007ff88d4266e0

julia> data = daqread(scani);
```

The method `DSA3217` is used to establish a connection to the scanivalve. The first argument
is part of the `AbstractDAQs` interface and it is just a name that is used to refer to
the device and data it produces. The second argument is the IP address of the scanner. For further information checkout the docstrings.

To configure data acquisition, the method `daqconfigdev`. This method uses parameters as named in the manual. It is the prefered way to configure the data acquisition. Method `daqconfig` uses a more generic interface where sample rate or period is specified and number of samples or data acquisition time.

Initially, all 16 channels are configured,

```julia-repl
julia> numchannels(scani)
16

julia> daqchannels(scani)
16-element Vector{String}:
 "P01"
 "P02"
 "P03"
 "P04"
 "P05"
 "P06"
 "P07"
 "P08"
 "P09"
 "P10"
 "P11"
 "P12"
 "P13"
 "P14"
 "P15"
 "P16"
```

but if only some channels are being used, this can be specified as well. *This will not have any effect on maximum sampling rate*. The names of the channels can also be changed:

```julia-repl
julia> daqaddinput(scani, [1,2,15,16], names=["Ptot", "Pest", "Prtot", "Prest"])


julia> numchannels(scani)
4

julia> daqchannels(scani)
4-element Vector{String}:
 "Ptot"
 "Pest"
 "Prtot"
 "Prest"
```


A zero calibration of the scanner is done using the `daqzero` method. To stop scanning during an asynchronous data acquisition, use the `daqstop` method.

See the docstrings and manual for more information.

