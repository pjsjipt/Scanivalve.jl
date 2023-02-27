using Dates
import DataStructures: OrderedDict


mutable struct DSA3217 <: AbstractScanivalve
    "Device name"
    devname::String
    "IP adress"
    ipaddr::IPv4
    "TCP/IP port"
    port::Int
    "Data acquisition buffer"
    buffer::CircMatBuffer{UInt8}
    "Data aquisition task handling"
    task::DaqTask
    "Channel information"
    chans::DaqChannels{Vector{Int}}
    "Scanivalve configuration"
    config::DaqConfig
    "Use threading"
    usethread::Bool
end

"Returns the IP address of the device"
ipaddr(dev::DSA3217) = dev.ipaddr

"Returns the port number used for TCP/IP communication"
portnum(dev::DSA3217) = dev.port

DAQCore.devtype(dev::DSA3217) = "DSA3217"

"Is DSA3217 acquiring data?"
DAQCore.isreading(dev::DSA3217) = isreading(dev.task)

"How many samples have been read?"
DAQCore.samplesread(dev::DSA3217) = samplesread(dev.task)

"Convert number to string justifying to the right by padding with zeros"
numstring(x::Integer, n=2) = string(10^n+x)[2:end]

function Base.show(io::IO, dev::DSA3217)
    println(io, "Scanivalve DSA3217")
    println(io, "    Dev Name: $(devname(dev))")
    println(io, "    IP: $(string(dev.ipaddr))")
end

"""
`openscani(ipaddr::IPv4, port=23,  timeout=5)`
`openscani(dev::DSA3217,  timeout=5)`
`openscani(fun::Function, ipaddr::IPv4, port=23, timeout=5)`
`openscani(fun::Function, dev::DSA3217, timeout=5)`

Open a TCP/IP connection to scanivalve.

## Arguments

 * `ipaddr` IP Address in `IPv4` format
 * `port` TCP/IP port
 * `timeout` Timeout to wait while trying to connect to scanivalve
 * `fun` Function that is executed after opening the function.

The best way to use this function is to use `do` construct:

```julia
open(dev) do sock
    # Do stuff with the socket
end
```
"""
function openscani(ipaddr::IPv4, port=23,  timeout=5)
        
    sock = TCPSocket()
    t = Timer(_ -> close(sock), timeout)
    try
        connect(sock, ipaddr, port)
    catch e
        if isa(e, InterruptException)
            throw(InterruptException())
        else
            error("Could not connect to $ipaddr ! Turn on the device or set the right IP address!")
        end
    finally
        close(t)
    end
    
    return sock
end

openscani(dev::DSA3217,  timeout=5) = openscani(ipaddr(dev), portnum(dev), timeout)


function openscani(fun::Function, ip, port=23, timeout=5)
    io = openscani(ip, port, timeout)
    try
        fun(io)
    catch e
        throw(e)
    finally
        close(io)
    end
end

function openscani(fun::Function, dev::DSA3217, timeout=5)
    io = openscani(ipaddr(dev), portnum(dev), timeout)
    try
        fun(io)
    catch e
        throw(e)
    finally
        close(io)
    end
end



"""
```
DSA3217(devname="Scanivalve", ipaddr="191.30.80.131";
                 timeout=5, buflen=100_000, tag="", sn="", usethread=true)
```

Create an `AbstractDAQ` device that is used to communicate with DSA3217.

## Arguments

 * `devname`: String with name assigned to the specific `DSA3217` device.
 * `ipaddr`: IP address of pressure scanner.
 * `timeout`: timeout to wait while trying to connect to scanivalve.
 * `buflen`: size of buffer used to store data acquired.
 * `tag`: string with device tag.
 * `sn`: string with serial number of the device.
 * `usethread`: `Bool` specifying whether to use thread when acquiring data asynchronously.

If `usethread` is `false`, `@async` is used. Remember that to use threads, `Julia` should be started with `-t N` (N is the number of threads):
```
julia -t 4    # Starts julia with 4 threads.
```

   
## Input channels

After establishing connection with the DSA3217, all 16 channels are available and named 
`P01` through `P16`. This can be changed using the method [`daqaddinput`](@ref).

## Data acquisition configuration

To configure the data acquisition, there are two possibilities:

 - [`daqconfigdev`](@ref) Uses notation and terminology from DSA3217's manual to configure
 - [`daqconfig`](@ref) Uses parameters such as sampling frequency and total acquisition time

## Acquiring data

To do a synchronous data acquisition, method [`daqacquire`](@ref) should be used. In this case, the function blocks until data acquisition is finalized.

For asynchronous data acquisition, the method [`daqstart`](@ref) starts data aquisition. To read the data use method [`daqread`](@ref). This method will wait until data acquisition is over.

Method [`isreading`](@ref) checks whether data acquisition is going on. [`samplesread`](@ref) returns.

[`daqstop`](@ref) interrupts an asynchronous data acquisition task.  

## Examples
```jldoctest
julia> using Scanivalve

julia> scani = DSA3217("dpref", "191.30.80.131")
Scanivalve DSA3217
    Dev Name: dpref
    IP: 191.30.80.131

julia> daqaddinput(scani, 1:4, names=["ptot", "pest", "prtot", "prest"])

julia> daqconfigdev(scani, PERIOD=500, AVG=10, FPS=10)

julia> p = daqacquire(scani);

julia> daqstart(scani)
Task (runnable) @0x00007fa61d769e40

julia> p = daqread(scani);

```
"""
function DSA3217(devname="Scanivalve", ipaddr="191.30.80.131";
                 timeout=5, buflen=100_000, tag="", sn="", usethread=true)
    
    ip = IPv4(ipaddr)
    port = 23

    openscani(ip, port, timeout) do s
        buffer = zeros(Int8, 0, 0)
        println(s, "SET EU 1")
        println(s, "SET AVG 16")
        println(s, "SET PERIOD 500")
        println(s, "SET FPS 1")
        println(s, "SET BIN 1")
        println(s, "SET XSCANTRIG 0")
        println(s, "SET UNITSCAN PA")
        println(s, "SET TIME 1")
    end

    conf = DaqConfig(ip=ipaddr, port=port, model="3217", tag=tag,
                     sn=sn)

    iparam!(conf, "FPS"=>1, "AVG"=>16, "PERIOD"=>500, "TIME"=>1,
            "XSCANTRIG"=>0, "EU"=>1)
    sparam!(conf, "UNITSCAN"=>"PA")
    
    
    task = DaqTask()
    buf = CircMatBuffer{UInt8}(112, buflen)
    chn = "P" .* numstring.(1:16,2)
    chans = DaqChannels(chn, collect(1:16))
    
    return DSA3217(devname, ip, port, buf, task, chans, conf, usethread)
    
    
end

const UNIT_TABLE = ["ATM", "BAR", "CMHG", "CMH2O", "DECIBAR", "TORR",
                    "FTH2O", "GCM2", "INHG", "INH2O", "KGCM2",
                    "KGM2", "KIPIN2", "KNM2", "KPA", "MBAR",
                    "MH2O", "MMHG", "MPA", "NCM2", "NM2",
                    "QZFT2", "QZIN2", "PA", "PSF", "PSI"]

const UNIT_MAP = Dict("ATM"=>"atm", "BAR"=>"bar", "CMHG"=>"cmHg",
                      "CMH2O"=>"cmH₂O", "DECIBAR"=>"dbar", "TORR"=>"torr",
                      "FTH2O"=>"ftH₂O", "GCM2"=>"g/cm²", "INHG"=>"inHg",
                      "INH2O"=>"inH₂O", "KGCM2"=>"kg/cm²","KGM2"=>"kg/m²",
                      "KIPIN2"=>"kip/in²", "KNM2"=>"kN/m²", "KPA"=>"kPa",
                      "MBAR"=>"mbar", "MH2O"=>"mH₂O", "MMHG"=>"mmHg",
                      "MPA"=>"MPa", "NCM2"=>"N/cm²", "NM2"=>"N/m²",
                      "QZFT2"=>"QZ/ft²", "QZIN2"=>"QZ/in²", "PA"=>"Pa",
                      "PSF"=>"psf", "PSI"=>"psi")

"""
`daqpacketsize(::Type{DSA3217}, eu=1, time=1)`
"""
function daqpacketsize(::Type{DSA3217}, eu=1, time=1)
    if time==0
        return (eu==0) ? 72 : 104 
    else
        return (eu==0) ? 80 : 112
    end
end


"""
`framesize(dev::DSA3217)`

Return the size of a data acquisition frame. A frame contains a data from all channels.
"""
framesize(dev::DSA3217) = daqpacketsize(DSA3217, iparam(dev,"EU"),
                                        iparam(dev,"TIME"))


"""
`deltat(dev)`

Calculate the sampling interval calculated from data acquisition paramters:

 * `PERIOD` Time in μs between data acquisition in *each channel*
 * `AVG` Number of frames that are read before averaging.

"""                                            
deltat(dev) = 16*iparam(dev,"PERIOD")*1e-6 * iparam(dev,"AVG")


"""
`stopscan(dev::DSA3217)`

Change the `stop` field of `task::DAQTask` field of `DSA3217` object to `true`.
This will flag that data acquisition should stop.

"""
function stopscan(dev::DSA3217)
    tsk = dev.task
    
    if isreading(tsk)
        tsk.stop = true
    end
end

    
"""
`scan!(dev::DSA3217)`

Execute data acquisition from `DSA3217` devices. Present configuration should be used.

"""
function scan!(dev::DSA3217)

    # Check if data acquisition is already going on.
    tsk = dev.task
    isreading(tsk) && error("DSA is already reading!")

    # Clear stuff and adjust buffer.
    cleartask!(tsk)

    buf = dev.buffer
    fps = iparam(dev, "FPS")
    # For long data acquisition, buffer might have to be increased.
    if fps > capacity(buf) 
        resize!(buf, fps)
    end
    empty!(buf)
    
    fsize = framesize(dev)
    nfrs = length(buf)
    
    if fps == 0 # Read continously
        fps1 = typemax(Int32)
    else
        fps1 = fps
    end

    # Calculate time interval between frames
    δt = deltat(dev) # Time per frame
    stopped = false

    # Register time and date of data acquisition
    tsk.time = now()

    exthrown = false # No exception thrown!
    
    # Open socket, send SCAN command and acquire data.
    openscani(dev) do sock
        println(sock, "SCAN") # Flags scanivalve to start data acquisition
        tsk.isreading = true
        # Initial data acquisition instant
        t0 = time_ns()
        # Get memory to store first frame
        b = nextbuffer(buf)
        readbytes!(sock, b, fsize)
        # Get the time before second frame. Remember that
        # there might be some latency. But for scanivalve this is not very important
        # since the calculated sampling time (`deltat`) is fairly accurate.
        t1 = time_ns()
        settiming!(tsk, t0, t1, 1)
        tsk.nread += 1
        for i in 2:fps1
            # Check if data acquisition should stop ([`daqstop`]($ref) or
            # [`stopscan`](@ref) commands).
            try
                if tsk.stop
                    stopped = true
                    println(sock, "STOP")
                    sleep(0.5)
                    break
                end
                # Read next frame
                b = nextbuffer(buf)
                readbytes!(sock, b, fsize)
                tn = time_ns()
                tsk.nread += 1
                settiming!(tsk, t1, tn, i-1)
            catch e
                if isa(e, InterruptException)
                    # Ctrl-C captured!
                    # We want to stop the data acquisition safely and then rethwrow it!
                    tsk.stop = true
                    exthrown = true
                else
                    throw(e)
                end
            end
            
            
        end
        
        tsk.isreading = false

        # If we stopped, try to read another frame.
        # there might be something in the buffer. But we will ignore it
        if stopped
            delay = max(2δt, 1.0) # Let's give it some time.
            ev = Base.Event()
            Timer(_ -> begin
                      timeout=true
                      notify(ev)
                  end, delay)
            @async begin
                read(sock, fsize)
                read!(sock, buffer(tsk, idx))
                notify(ev)
            end
            wait(ev)
            if exthrown
                # Data acquisition stopped because of a Ctrl-C
                # We handled stopping DAQ smoothly and now we will rethrow
                throw(InterruptException())
            end
            
        end
    end
    return
end


"""
Valid units accepted by DSA3217.
"""
const validunits = ["ATM", "BAR", "CMHG", "CMH2O", "DECIBAR", "FTH2O", "GCM2",
                    "INHG", "INH2O", "KPA", "KGCM2", "KGM2", "KIPIN2", "KNM2",
                    "MH2O", "MMHG", "MPA", "NCM2", "MBAR", "OZFT2", "OZIN2",
                    "PA", "PSF", "NM2", "PSI", "TORR"]

"""
`daqconfig(dev::DSA3217; kw...)`

Generic configuration of data acquisition. Here we specify how many samples will be read
and how fast it should be read.

## Arguments

 * `dt`: period of time in seconds between samples
 * `rate`: sampling rate in Hz between samples
 * `nsamples`: number of samples that should be read
 * `time`: time in seconds that data should be acquired.

If `dt` is specified, 
```
rate = 1/dt
```

Either the number of samples should be configured or the acquisition time: 
```
time = nsamples * dt
```

Samples can be averaged. The `avg` parameter specifies how many samples should be averaged.
Attention: the sampling time (`dt`) is includes the averaging.

Trigger can also be specified.

 * `trigger == 0` Internal trigger
 * `trigger == 1` Use external trigger.

**Important** If a parameter is not used, previous configuration will be used. 
Remember to set the value of `avg`. The best option is to specify all the options.

## Example
```jldoctest
julia> daqconfig(scani, rate=100, nsamples=100, avg=1)

julia> p = daqacquire(scani);

julia> samplingrate(p)
100.0

julia> daqconfig(scani, dt=0.1, time=1, avg=1)

julia> p = daqacquire(scani);

julia> samplingrate(p)
10.0

```
"""
function DAQCore.daqconfig(dev::DSA3217; kw...)
    cmds = String[]
    
    if haskey(kw, :avg)
        avg = round(Int, kw[:avg])
        daqconfigdev(dev, AVG=avg)
    else
        avg = iparam(dev, "AVG")
    end
    

    if haskey(kw, :rate) && haskey(kw, :dt)
        error("Parameters `rate` and `dt` can not be specified simultaneously!")
    elseif haskey(kw, :rate) || haskey(kw, :dt)
        if haskey(kw, :rate)
            rate = kw[:rate]
            period = round(Int, 1.0 / (rate*16e-6*avg))
        else
            dt = kw[:dt]
            period = round(Int, dt / (16e-6*avg))
        end
        daqconfigdev(dev, PERIOD=period)
    else
        period = iparam(dev, "PERIOD")
    end
    
    if haskey(kw, :nsamples) && haskey(kw, :time)
        error("Parameters `nsamples` and `time` can not be specified simultaneously!")
    elseif haskey(kw, :nsamples) || haskey(kw, :time)
        if haskey(kw, :nsamples)
            nsamples = kw[:nsamples]
        else
            tt = kw[:time]
            dt = period * 16e-6 * avg
            nsamples = round(Int, tt / dt)
        end
        daqconfigdev(dev, FPS=nsamples)
    else
        nsamples = iparam(dev, "FPS")
    end
        
    if haskey(kw, :trigger)
        trigger = kw[:trigger]
        daqconfigdev(dev, XSCANTRIG=trigger)
    end
    

end


"""
`daqstart(dev::DSA3217)`

Start an asynchrounous data acquisition. 

If `dev.usethread == true`, a thread will be started with `@spawn`. Othwerwise, `@async` is used. This should be specified when creating the DSA3217 object ([`DSA3217`](@ref)).

## Example

```jldoctest
julia> daqconfig(scani, rate=100, time=10, avg=1) # 10s, 100 Hz

julia> @time begin
             daqstart(scani) # Start data
             sleep(5) # Wait 5s
             daqstop(scani) # Interrupt daq
             p = daqread(scani) # Read data
             size(p.data)
end
  6.531171 seconds (40.08 k allocations: 2.049 MiB, 1.86% compilation time)
(4, 487)

```
"""
function DAQCore.daqstart(dev::DSA3217)
    if isreading(dev)
        error("Scanivalve already reading!")
    end
    if dev.usethread
        tsk = Threads.@spawn scan!(dev)
    else
        tsk = @async scan!(dev)
    end
    dev.task.task = tsk
    return tsk
end

"""
`daqaddinput(dev::DSA3217, chans=1:16; names="P")`

Specify input channels.

The DSA3217 always reads all 16 channels. Choosing a smaller 
number of channels will not make data acquisition faster. But it may
be convenient to forget some of them. 

## Arguments

 * `chans`: an abstract vector with the index of channels that should be used.
 * `names`: names of channels (see next)

## Channel names

The `names` keyword argument is used to specify the names of the channels used.

If a single string is specified, the channel names will be this string followed by
the index (padded by 1 zero at most). See example.

Individual channels can be named but in this case, every single channel should be named.

## See also 

[`DSA3217`](@ref), [`daqconfig`](@ref), [`daqconfigdev`](@ref), [`daqacquire`](@ref), 
[`daqstart`](@ref), [`daqread`](@ref)

## Example
```jldoctest
julia> daqaddinput(scani, 8:12, names="press")

julia> daqchannels(scani)
5-element Vector{String}:
 "press08"
 "press09"
 "press10"
 "press11"
 "press12"

julia> daqaddinput(scani, 1:4, names=["ptot", "pest", "prtot", "prest"])

julia> daqchannels(scani)
4-element Vector{String}:
 "ptot"
 "pest"
 "prtot"
 "prest"
```
"""
function DAQCore.daqaddinput(dev::DSA3217, chans=1:16; names="P")

    cmin, cmax = extrema(chans)
    if cmin < 1 || cmax > 16
        throw(ArgumentError("Only channels 1-16 are available to DSA3217"))
    end

    if isa(names, AbstractString) || isa(names, Symbol)
        chn = string(names) .* numstring.(chans)
    elseif length(names) == length(chans)
        chn = string.(names)
    else
        throw(ArgumentError("Argument `names` should have length 1 or the length of `chans`"))
    end
    
    dev.chans.physchans = collect(chans)
    dev.chans.channels = chn
  
    n = length(chans)
    chanidx = OrderedDict{String,Int}()
    for i in 1:n
        chanidx[chn[i]] = i
    end
    dev.chans.chanmap = chanidx

    return
end

"""
`daqstop(dev::DSA3217)`

Interrupt asynchronous data acquisition. 

## Example

```jldoctest
julia> daqconfig(scani, rate=100, time=10, avg=1) # 10s, 100 Hz

julia> @time begin
             daqstart(scani) # Start data
             sleep(5) # Wait 5s
             daqstop(scani) # Interrupt daq
             p = daqread(scani) # Read data
             size(p.data)
end
  6.531171 seconds (40.08 k allocations: 2.049 MiB, 1.86% compilation time)
(4, 487)

```

"""
function DAQCore.daqstop(dev::DSA3217)

    tsk = dev.task.task
    if !istaskdone(tsk) && istaskstarted(tsk)
        stopscan(dev)
        wait(tsk)
    end
    dev.task.stop = false
    dev.task.isreading = false
    
end


"""
`readpressure(dev::DSA3217)`

Reads pressure, sampling rate and acquisition start time from buffer.

"""
function readpressure(dev::DSA3217)
    isreading(dev) && error("Scanivalve still acquiring data!")

    tsk = dev.task
    buf = dev.buffer
    nsamples = length(buf)
    δt = getdaqtime(dev, nsamples)
    
    if iparam(dev, "EU") > 0
        press = read_eu_press(buf, dev.chans.physchans)
    else
        error("Reading data without engineering units (EU=1) not implemented yet!")
    end
    
    return press, 1.0/δt, tsk.time
end

export meastime, samplingrate, measdata, measinfo

"""
`daqread(dev::DSA3217)`

Wait until data acquisition ends and read data.

If continous data acqisition is used, this function will stop data acquisition and return data. 

Data acquisition starts with [`daqstart`](@ref) command. 

To just to get the data already acquired, there will be function [`daqpeek`](@ref) that has 
not been implemented yet.

## Return value

This function returns a [`DAQCore.MeasData`](@ref) object that contains the data as 
well as sampling rate and other meta data.

## Usage
See example for [`daqstart`](@ref) command. 

"""
function DAQCore.daqread(dev::DSA3217)

    # Check if the reading is continous
    if iparam(dev, "FPS") == 0
        # Stop reading!
        daqstop(dev)
        sleep(0.1)
    end
    # Wait for task to end
    wait(dev.task.task)
    
    # Get the data:
    P, fs, t = readpressure(dev)
    unit = sparam(dev,"UNITSCAN")
    sampling = DaqSamplingRate(fs, size(P,2), t)
    return MeasData(devname(dev), devtype(dev), sampling, P, dev.chans,
                    fill(unit, numchannels(dev.chans)))
                    
end

"""
`daqacquire(dev::DSA3217)`

Execute a **s**ynchronous data acquisition. 


## Return value

This function returns a [`DAQCore.MeasData`](@ref) object that contains the data as 
well as sampling rate and other meta data.

## Usage
See example for [`DSA3217`](@ref) command. 

"""
function DAQCore.daqacquire(dev::DSA3217)
                    scan!(dev)
    P, fs, t = readpressure(dev)
    unit = sparam(dev, "UNITSCAN")
    sampling = DaqSamplingRate(fs, size(P,2), t)
    return MeasData(devname(dev), devtype(dev), sampling, P, dev.chans,
                    fill(unit, numchannels(dev.chans)))
end

"""
`read_eu_press(buf, chans)`

Reads pressure in engineering units (EU) from the data acquisition buffer.
   
"""
function read_eu_press(buf, chans)

    nt = length(buf)
    nch = length(chans)
    P = zeros(Float32, nch, nt)

    for i in 1:nt
        p1 = reinterpret(Float32, view(buf[i], 9:72))
        for k in 1:nch
            P[k,i] = p1[chans[k]]
        end
    end
    return P
end

"""
`getdaqtime(dev, nfr)`

Returns the mean sampling time. If no time is specified (paramter `TIME==0`), 
just calculate from acquisition parameters `PERIOD` and `AVG`. 

Otherwises, get the value from the frames.
Reads pressure in engineering units (EU) from the data acquisition buffer.
   
"""
function getdaqtime(dev, nfr)
    buf = dev.buffer
    b = buf[1,1] # Identify the packet

    # Sampling time from scan configuration and fallback value
    δt₀ = iparam(dev, "AVG") * iparam(dev, "PERIOD")*1e-6 * 16
    btype = iparam(dev, "TIME")
    if b == 0x04 || b == 0x05 || nfr==1 # No time
        # Calculate from scan configuration
        return δt₀
    else
        if b == 0x07  # EU with time
            bt1 = reinterpret(Int32, buf[105:108,1])[1]
            bt2 = reinterpret(Int32, buf[105:108,nfr])[1]
        elseif b == 0x06
            bt1 = reinterpret(Int32, buf[73:76,1])[1]
            bt2 = reinterpret(Int32, buf[73:76,nfr])[1]
        else # This shouldn't happen! Fallback
            return δt₀
        end
        ft = (btype==1) ? 1e6 : 1e3
        return  (bt2 - bt1) / (ft*(nfr-1))
    end
                            
end


        

function scan2press(dev::DSA3217, buf, info)

    
    nframes = info.FPS
    press = zeros(Float32, nframes, 16)

    
    if info.EU > 0
        for i in 1:nframes
            press[i,:] = reinterpret(Float32, view(buf, 9:72,i))
        end
    else
        for i in 1:nframes
            press[i,:] = Float32.(reinterpret(Int16, view(buf, 9:40, i)))
        end
    end
    return press

end



import Base.close

"""
`close(scani::DSA3217)`

Return scanivalve to a 'sane' configuration.
"""
function close(scani::DSA3217)
    openscani(scani) do s
        println(s, "SET EU 1")
        println(s, "SET AVG 100")
        println(s, "SET PERIOD 500")
        println(s, "SET FPS 1")
        println(s, "SET BIN 0")
        println(s, "SET XSCANTRIG 0")
        println(s, "SET UNITSCAN PA")
        println(s, "SET TIME 0")
    end
    
end

"Number of data acquisition channels"
numchans(scani::DSA3217) = 16
"Number of data acquisition channels"
DAQCore.numchannels(scani::DSA3217) = numchannels(scani.chans)
"Name of data acquisition channels"
DAQCore.daqchannels(scani::DSA3217) = daqchannels(scani.chans)

#socket(scani) = scani.socket

function scanpacksize(dev::DSA3217, TIME=0, EU=1)
    if TIME==0
        if EU==1
            return 104
        else
            return 72
        end
    else
        if EU==1
            return 112
        else
            return 80
        end
    end

end

"Paramaters valid for `daqconfigdev`"
const validparameters = [:FPS, :PERIOD, :AVG, :TIME, :EU, :UNITSCAN, :XSCANTRIG]

"""
`daqconfigdev(dev::DSA3217; kw...)`

Configure data acquisition with parameters described in the manual.

The following parameters are available:

 * `FPS`: Integer specifying the number of frames (samples) to acquire
 * `PERIOD`: time spent in each pressure sensor in μs
 * `AVG`: Number of frames to average before outputing a mean frame
 * `TIME`: 0 - No time in frame, 1 or 2 (ms or μs)
 * `EU`: 1 if engineering units should be used (not implemented for non EU)
 * `UNITSCAN`: String with pressure units that should be used. Check `validunits` vector.
 * `XSCANTRIG`: 0 for internal trigger or 1 for external trigger.

See DSA3217 manual for further information.

## Examples

```jldoctest
julia> daqconfigdev(scani, PERIOD=500, AVG=10, FPS=10)

julia> p = daqacquire(scani);

julia> samplingrate(p)
12.5

julia> size(p.data)
(16, 10)
```

"""    
function DAQCore.daqconfigdev(dev::DSA3217; kw...)

    pp = Dict{Symbol, Any}()
    k = keys(kw)
    cmds = String[]
    if :FPS ∈ k
        fps = kw[:FPS]
        if 0 ≤ fps < 1_000_000
            push!(cmds, "SET FPS $fps")
            pp[:FPS] = fps
        else
            throw(DomainError(fps, "FPS outside range (0 - 1000000)"))
        end
    end
    if :PERIOD ∈ k
        period = kw[:PERIOD]
        if 125 ≤ period ≤ 65535
            push!(cmds, "SET PERIOD $period")
            pp[:PERIOD] = period
        else
            throw(DomainError(period, "PERIOD outside range (126 - 65535)"))
        end
    end

    if :AVG ∈ k
        avg = kw[:AVG]
        if 1 ≤ avg ≤ 240
            push!(cmds, "SET AVG $avg")
            pp[:AVG] = avg
        else
            throw(DomainError(avg, "AVG outside range (1 - 240)"))
        end
    end

    if :TIME ∈ k
        tt = kw[:TIME]
        if 0 ≤ tt ≤ 2
            push!(cmds, "SET TIME $tt")
            pp[:TIME] = tt
        else
            throw(DomainError(tt, "TIME outside range (0-2)"))
        end
    end
    
    if :EU ∈ k
        eu = kw[:EU]
        if 0 ≤ eu ≤ 1
            push!(cmds, "SET EU $eu")
            pp[:EU] = eu
        else
            throw(DomainError(eu, "EU outside range (0 or 1)"))
        end
    end

    if :XSCANTRIG ∈ k
        xscantrig = kw[:XSCANTRIG]
        if 0 ≤ xscantrig ≤ 1
            push!(cmds, "SET SCANTRIG $xscantrig")
            pp[:XSCANTRIG] = xscantrig
        else
            throw(DomainError(xscantrig, "XSCANTRIG should be either 0 or 1"))
        end
    end

    # Send commands to Scanivalve
    openscani(dev) do sock
        for c in cmds
            println(sock, c)
        end

        # Update conf field:
        updateconf!(dev::DSA3217, pp)
    end
end

"""
`updateconf!(dev::DSA3217)`

Update configuration from `params` field of `DSA3217` object.
"""
function updateconf!(dev::DSA3217, p::Dict{Symbol,Any})

    k = keys(p)
    :FPS ∈ k && iparam!(dev.config, "FPS", Int64(p[:FPS]))
    :AVG ∈ k && iparam!(dev.config, "AVG", Int64(p[:AVG]))
    :PERIOD ∈ k && iparam!(dev.config, "PERIOD", Int64(p[:PERIOD]))
    :TIME ∈ k && iparam!(dev.config, "TIME", Int64(p[:TIME]))
    :XSCANTRIG ∈ k && iparam!(dev.config, "XSCANTRIG", Int64(p[:XSCANTRIG]))
    :EU ∈ k && iparam!(dev.config, "EU", Int64(p[:EU]))
    
    return
    
end

"""
`daqzero(dev::DSA3217; time=15)`

Execute a hardware zero. The time parameter specifies how long the function should sleep
before returning.

"""
function DAQCore.daqzero(dev::DSA3217; time=15)
    openscani(dev) do io
        println(io, "CALZ")
        sleep(time)
    end
end


"""
`daqunits(dev::DSA3217, unit="PA")`

Set data acquisition pressure units to `unit`.
Available units are in constant [`UNIT_TABLE`].

"""
function DAQCore.daqunits(dev::DSA3217, unit)
    unit = uppercase(unit)
    # See if unit is valid
    unit ∉ UNIT_TABLE && error("Unknown unit $unit. Check manual.")

    # Program unit
    openscani(dev) do sock
        println(sock, "SET UNIT $unit")
    end
    dev.chans.units = UNIT_MAP[unit]
    sparam!(dev.config, "UNITSCAN", unit)
    
end

DAQCore.daqunits(dev::DSA3217) = sparam(dev.config, "UNITSCAN")
"""
`readmanylines(dev, cmd, delay=0.5)`

Several commands return data as a sequence of text lines. Read as many lines as possible
waiting for `delay` seconds before ending any attempt to read.

"""
function readmanylines(dev, cmd, delay=0.5)

    
    lst = String[]
    openscani(dev) do socket
        println(socket, cmd)
        timeout = false
        while !timeout
            ev = Base.Event()
            Timer(_ -> begin
                      timeout=true
                      notify(ev)
                  end, delay)
            @async begin
                line = readline(socket)
                push!(lst, line)
                notify(ev)
            end
            wait(ev)
        end
    end
    
    return lst
        
end

function readstatus(dev::DSA3217)
    openscani(dev) do s
        println(s, "STATUS")
        string(Char.(read(s, 180)[81:100])...)
    end
end






    
    
"""
`readnlines(s, n=1)`

Read `n` lines from open socket `s`.
"""    
function readnlines(s, n=1)
    lst = String[]
    for i in 1:n
        push!(lst, readline(s))
    end
    return lst
end

"""
`parse_dsa_set(lst)`

Usually configuration parameters from scanivalve are read as a collection of lines with 
the following format (each line):
```
SET PARAMETER VALUE
```

This function will create a `Dict{String,String}` from the list of lines with the format 
`d["PARAMETER"] = "VALUE"`
"""    
function parse_dsa_set(lst)
    p = Dict{String,String}()
    for l in lst
        s = split(l, " ")
        p[s[2]] = s[3]
    end
    return p
end

"""
`listany(dev::DSA3217, cmd, nparams)`

List any configuration parameter by sending command LIST cmd to scanivalve.
"""
function listany(dev::DSA3217, cmd, nparams)
    openscani(dev) do sock
        println(sock, "LIST $cmd\r")
        readnlines(sock, nparams)
    end
end


"""
`listanydict(dev::DSA3217, cmd, nparams)`

List any configuration parameter by sending command LIST cmd to scanivalve. 
Build a dictionary with the output.
"""
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

"Execute command LIST SCAN"
listscan(scani::DSA3217) = listanydict(scani, "S", 14)
"Execute command LIST I"
listident(scani::DSA3217) = listanydict(scani, "I", 4)
"Execute command LIST Z"
listzero(scani::DSA3217) = listanyval(scani, "Z", numchans(scani), Int)
"Execute command LIST O"
listoffset(scani::DSA3217) = listanyval(scani, "O", numchans(scani), Float64)
"Execute command LIST D"
listdelta(scani::DSA3217) = listanyval(scani, "O", numchans(scani), Float64)
"Execute command LIST G"
listgain(scani::DSA3217) = listanyval(scani, "G", numchans(scani), Float64)

"""
`setparam(scani, param, val)`

Set the value of a configuration paramenter on the scanivalve.
"""
setparam(scani, param, val) =
    openscani(scani) do sock
        println(sock, "SET $param $val\r")
    end





