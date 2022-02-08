



mutable struct DSA3217 <: AbstractScanivalve
    ipaddr::IPv4
    port::Int
    params::Dict{Symbol,Any}
    buffer::CircMatBuffer{UInt8}
    task::DAQTask
    chans::Vector{Int}
    channames::Vector{String}
    conf::DAQConfig
end

"Returns the IP address of the device"
ipaddr(dev::DSA3217) = dev.ipaddr
portnum(dev::DSA3217) = dev.port

AbstractDAQs.isreading(dev::DSA3217) = isreading(dev.task)
AbstractDAQs.samplesread(dev::DSA3217) = samplesread(dev.task)

numstring(x::Integer, n=2) = string(10^n+x)[2:end]

function Base.show(io::IO, dev::DSA3217)
    println(io, "Scanivalve DSA3217")
    println(io, "    Dev Name: $(daqdevname(dev))")
    println(io, "    IP: $(string(dev.ipaddr))")
end


function openscani(ipaddr::IPv4, port=23,  timeout=5)
        
    sock = TCPSocket()
    t = Timer(_ -> close(sock), timeout)
    try
        connect(sock, ipaddr, port)
    catch e
        error("Could not connect to $ipaddr ! Turn on the device or set the right IP address!")
    finally
        close(t)
    end
    
    return sock
end

openscani(dev::DSA3217,  timeout=5) = openscani(ipaddr(dev), portnum(dev), timeout)

function openscani(fun::Function, ipaddr::IPv4, port=23, timeout=5)
    
    io = openscani(ipaddr, port, timeout)
    try
        fun(io)
    finally
        close(io)
    end
    
end

openscani(fun::Function, dev::DSA3217, timeout=5) =
    openscani(fun, ipaddr(dev), portnum(dev), timeout)




function DSA3217(devname="Scanivalve", ipaddr="191.30.80.131";
                 timeout=5, buflen=300_000, tag="", sn="")
    
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
    
    params = Dict{Symbol,Any}(:FPS=>1, :AVG=>16, :PERIOD=>500, :TIME=>1,:XSCANTRIG=>0, :EU=>1, :UNITSCAN=>"PA")

    ipars = Dict{String,Int}("FPS"=>1, "AVG"=>16, "PERIOD"=>500, "TIME"=>1,
                             "EU"=>1, "XSCANTRIG"=>0)
    spars = Dict{String,String}("UNITSCAN"=>"PA")
    fpars = Dict{String,Float64}()
    
    conf = DAQConfig(ipars, fpars, spars,
                   devname=devname, ip=ipaddr, model="DSA3217", sn=sn,tag=tag)
    task = DAQTask()
    buf = CircMatBuffer{UInt8}(112, buflen)
    chn = "P" .* numstring.(1:16)
    return DSA3217(ip, port, params, buf, task, collect(1:16), chn, conf)
    
     
    
end


function daqpacketsize(::Type{DSA3217}, eu=1, time=1)
    if time==0
        return (eu==0) ? 72 : 104 
    else
        return (eu==0) ? 80 : 112
    end
end

daqparam(dev, param) = dev.params[param]

framesize(dev::DSA3217) = daqpacketsize(DSA3217, daqparam(dev,:EU), daqparam(dev,:TIME))


                                            
deltat(dev) = 16*daqparam(dev,:PERIOD)*1e-6 * daqparam(dev,:AVG)


function stopscan(dev::DSA3217)
    tsk = dev.task
    
    if isreading(tsk)
        tsk.stop = true
    end
end

    

function scan!(dev::DSA3217)

    tsk = dev.task
    isreading(tsk) && error("DSA is already reading!")

    cleartask!(tsk)

    buf = dev.buffer
    fps = daqparam(dev, :FPS)
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
    
    δt = deltat(dev) # Time per frame
    stopped = false
    
    openscani(dev) do sock
        println(sock, "SCAN")
        tsk.isreading = true
        t0 = time_ns()
        b = nextbuffer(buf)
        readbytes!(sock, b, fsize)
        t1 = time_ns()
        settiming!(tsk, t0, t1, 1)
        tsk.nread += 1
        for i in 2:fps1
            if tsk.stop
                stopped = true
                println(sock, "STOP")
                sleep(0.5)
                break
            end
            
            b = nextbuffer(buf)
            readbytes!(sock, b, fsize)
            tn = time_ns()
            tsk.nread += 1
            settiming!(tsk, t1, tn, i-1)
            
        end

        tsk.isreading = false

        # If we stopped, try to read another frame
        if stopped
            delay = max(2δt, 1.0)
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
        end
    end
    return
end

const validunits = ["ATM", "BAR", "CMHG", "CMH2O", "DECIBAR", "FTH2O", "GCM2",
                    "INHG", "INH2O", "KPA", "KGCM2", "KGM2", "KIPIN2", "KNM2",
                    "MH2O", "MMHG", "MPA", "NCM2", "MBAR", "OZFT2", "OZIN2",
                    "PA", "PSF", "NM2", "PSI", "TORR"]

function AbstractDAQs.daqconfig(dev::DSA3217; kw...)
    cmds = String[]
    
    if haskey(kw, :avg)
        avg = round(Int, kw[:avg])
        daqconfigdev(dev, AVG=avg)
    else
        avg = dev.params[:AVG]
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
        period = dev.params[:PERIOD]
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
        nsamples = dev.params[:FPS]
    end
        
    if haskey(kw, :trigger)
        trigger = kw[:trigger]
        daqconfigdev(dev, XSCANTRIG=trigger)
    end
    

end



function AbstractDAQs.daqstart(dev::DSA3217, usethread=false)
    if isreading(dev)
        error("Scanivalve already reading!")
    end

    if usethread
        tsk = Threads.@spawn scan!(dev)
    else
        tsk = @async scan!(dev)
    end
    dev.task.task = tsk
    return tsk
end

function AbstractDAQs.daqaddinput(dev::DSA3217, chans=1:16; channames="P")

    cmin, cmax = extrema(chans)
    if cmin < 1 || cmax > 16
        throw(ArgumentError("Only channels 1-16 are available to DSA3217"))
    end

    if isa(channames, AbstractString) || isa(channames, Symbol)
        chn = string(channames) .* numstring.(chans)
    elseif length(channames) == length(chans)
        chn = string.(channames) .* string.(chans)
    else
        throw(ArgumentError("Argument `channames` should have length 1 or the length of `chans`"))
    end

    dev.chans = collect(chans)
    dev.channames = chn

    return
end

function AbstractDAQs.daqstop(dev::DSA3217)

    tsk = dev.task.task
    if !istaskdone(tsk) && istaskstarted(tsk)
        stopscan(dev)
        wait(tsk)
    end
    dev.task.stop = false
    dev.task.isreading = false
    
end


function readpressure(dev::DSA3217)
    isreading(dev) && error("Scanivalve still acquiring data!")

    tsk = dev.task
    buf = dev.buffer
    nsamples = length(buf)
    δt = getdaqtime(dev, nsamples)
    
    if daqparam(dev, :EU) > 0
        press = read_eu_press(buf, dev.chans)
    else
        error("Reading data without engineering units (EU=1) not implemented yet!")
    end
    return press, 1.0/δt
end

    
function AbstractDAQs.daqread(dev::DSA3217)

    # Check if the reading is continous
    if daqparam(dev, :FPS) == 0
        # Stop reading!
        daqstop(dev)
        sleep(0.1)
    end
    # Wait for task to end
    if !istaskdone(dev.task.task) && istaskstarted(dev.task.task)
        wait(dev.task.task)
        sleep(0.1)
    end
    
    # Get the data:
    return readpressure(dev)                      
end

function AbstractDAQs.daqacquire(dev::DSA3217)
    scan!(dev)
    return readpressure(dev)
end


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

function getdaqtime(dev, nfr)
    buf = dev.buffer
    b = buf[1,1] # Identify the packet

    # Sampling time from scan configuration and fallback value
    δt₀ = daqparam(dev, :AVG) * daqparam(dev, :PERIOD)*1e-6 * 16
    btype = daqparam(dev, :TIME)
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

function close(scani::DSA3217)
    openscani(dev) do s
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

numchans(scani::DSA3217) = 16
AbstractDAQs.numchannels(scani::DSA3217) = length(scani.chans)
AbstractDAQs.daqchannels(scani::DSA3217) = scani.channames

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

checkfps(dev::DSA3217, fps) = clamp(fps, 1, 1_800_000)
checkperiod(dev::DSA3217, period) = clamp(period, 125, 65535)
checkavg(dev::DSA3217, avg) = clamp(avg, 1, 240)
checkxscantrig(dev::DSA3217, xtrig) = (xtrig != 1) ? 0 : 1
checktime(dev::DSA3217, t) = clamp(t, 0, 2)
checkeu(dev::DSA3217, eu) = (eu != 0) ? 1 : 0

const validparameters = [:FPS, :PERIOD, :AVG, :TIME, :EU, :UNITSCAN, :XSCANTRIG]

    
function AbstractDAQs.daqconfigdev(dev::DSA3217; kw...)

    k = keys(kw)
    cmds = String[]
    if :FPS ∈ k
        fps = kw[:FPS]
        if 0 ≤ fps < 1_000_000
            push!(cmds, "SET FPS $fps")
            dev.params[:FPS] = fps
        else
            throw(DomainError(fps, "FPS outside range (0 - 1000000)"))
        end
    end

    if :PERIOD ∈ k
        period = kw[:PERIOD]
        if 125 ≤ period ≤ 65535
            push!(cmds, "SET PERIOD $period")
            dev.params[:PERIOD] = period
        else
            throw(DomainError(period, "PERIOD outside range (126 - 65535)"))
        end
    end

    if :AVG ∈ k
        avg = kw[:AVG]
        if 1 ≤ avg ≤ 240
            push!(cmds, "SET AVG $avg")
            dev.params[:AVG] = avg
        else
            throw(DomainError(avg, "AVG outside range (1 - 240)"))
        end
    end

    if :TIME ∈ k
        tt = kw[:TIME]
        if 0 ≤ tt ≤ 2
            push!(cmds, "SET TIME $tt")
            dev.params[:TIME] = tt
        else
            throw(DomainError(tt, "TIME outside range (0-2)"))
        end
    end
    
    if :EU ∈ k
        eu = kw[:EU]
        if 0 ≤ eu ≤ 1
            push!(cmds, "SET EU $eu")
            dev.params[:EU] = eu
        else
            throw(DomainError(eu, "EU outside range (0 or 1)"))
        end
    end

    if :UNITSCAN ∈ k # User should check manually if the correct unit was used
        unitscan = kw[:UNITSCAN]
        if unitscan ∈ validunits
            push!(cmds, "SET UNITSCAN $unitscan")
        else
            throw(DomainError(unitscan, "Invalid unit!"))
        end
    end

    if :XSCANTRIG ∈ k
        xscantrig = kw[:EU]
        if 0 ≤ eu ≤ 1
            push!(cmds, "SET SCANTRIG $xscantrig")
            dev.params[:XSCANTRIG] = xscantrig
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
        updateconf!(dev::DSA3217)
    end
end

function updateconf!(dev::DSA3217)
    p = dev.params
    ipars = dev.conf.ipars
    spars = dev.conf.spars

    ipars["FPS"] = p[:FPS]
    ipars["AVG"] = p[:AVG]
    ipars["PERIOD"] = p[:PERIOD]
    ipars["TIME"] = p[:TIME]
    ipars["XSCANTRIG"] = p[:XSCANTRIG]
    ipars["EU"] = p[:EU]

    spars["UNITSCAN"] = p[:UNITSCAN]

    return
    
end

function AbstractDAQs.daqzero(dev::DSA3217; time=15)
    openscani(dev) do io
        println(io, "CALZ")
        sleep(time)
    end
end

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

function listany(dev::DSA3217, cmd, nparams)
    openscani(dev) do sock
        println(sock, "LIST $cmd\r")
        readnlines(sock, nparams)
    end
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
listzero(scani::DSA3217) = listanyval(scani, "Z", numchans(scani), Int)
listoffset(scani::DSA3217) = listanyval(scani, "O", numchans(scani), Float64)
listdelta(scani::DSA3217) = listanyval(scani, "O", numchans(scani), Float64)
listgain(scani::DSA3217) = listanyval(scani, "G", numchans(scani), Float64)


setparam(scani, param, val) =
    openscani(scani) do sock
        println(sock, "SET $param $val\r")
    end





