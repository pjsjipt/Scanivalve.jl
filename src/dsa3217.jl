



mutable struct DSA3217 <: AbstractScanivalve
    socket::TCPSocket
    daqparams::Dict{Symbol,Int32}
    task::DAQTask{DSA3217}
end

isreading(dev::DSA3217) = isreading(dev.task)
samplesread(dev::DSA3217) = samplesread(dev.task)

clearbuffer!(dev::DSA3217) = clearbuffer!(dev.task)

function openscani(ipaddr="191.30.80.131", port=23, timeout=5)
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
    
function DSA3217(ipaddr="191.30.80.131"; timeout=5)

    s = openscani(ipaddr, 23, timeout)
    buffer = zeros(Int8, 0, 0)
    println(s, "SET EU 1")
    println(s, "SET AVG 16")
    println(s, "SET PERIOD 500")
    println(s, "SET FPS 1")
    println(s, "SET BIN 1")
    println(s, "SET XSCANTRIG 0")
    println(s, "SET UNITSCAN PA")
    println(s, "SET TIME 1")

    daqparams = Dict{Symbol,Int32}(:FPS=>1, :AVG=>16, :PERIOD=>500, :TIME=>1,:XSCANTRIG=>0, :EU=>1)
    
    task = DAQTask(DSA3217, 112)
    
    return DSA3217(s, daqparams, task)
     
    
end


function daqpacketsize(::Type{DSA3217}, eu=1, time=1)
    if time==0
        return (eu==0) ? 72 : 104 
    else
        return (eu==0) ? 80 : 112
    end
end

daqparam(dev, param) = dev.daqparams[param]

framesize(dev::DSA3217) = daqpacketsize(DSA3217, daqparam(dev,:EU), daqparam(dev,:TIME))


                                            
deltat(dev) = 16*daqparam(dev,:PERIOD)*1e-6 * daqparam(dev,:AVG)


function stopscan(dev::DSA3217)
    tsk = dev.task
    
    if isreading(tsk)
        tsk.stop = true
    end
end

function resizebuffer!(dev::DSA3217)
    tsk = dev.task
    fsize = framesize(tsk)
    nfrs = numframes(tsk)

    fps = daqparam(dev, :FPS)
    fsize1 = framesize(dev)

    should_resize = false

    if fsize1 != fsize
        should_resize = true
    end

    if nfrs < fps
        should_resize = true
    end

    if should_resize
        fps  = (fps==0) ? 300_000 : fps
        resizebuffer!(tsk, fsize1, fps)
    end
    return
end

    
        
    

function scan!(dev::DSA3217)
    
    resizebuffer!(dev)
    tsk = dev.task
    fsize = framesize(tsk)
    nfrs = numframes(tsk)
    
    isreading(tsk) && error("DSA is already reading!")
    
    fps = daqparam(dev, :FPS)
    if fps == 0 # Read continously
        fps = typemax(Int32)
    end
    sock = socket(dev)
    δt = deltat(dev) # Time per frame
    println(sock, "SCAN")
    
    tsk.isreading = true
    tsk.nread = 0
    tsk.idx = 0
    
    stopped = false
    for i in 1:fps
        idx = ((i-1) % nfrs) + 1
        read!(sock, buffer(tsk, idx))
        tsk.idx = idx
        tsk.nread += 1
        if tsk.stop
            stopped = true
            tsk.isreading = false
            break
        end
        
    end
    tsk.isreading = false
    # If we stopped, try to read another frame
    if stopped
        delay = minimum(3*δt, 1.0)
        ev = Base.Event()
        Timer(_ -> begin
                  timeout=true
                  notify(ev)
              end, delay)
        frame_read = false
        @async begin
            i = tsk.nread + 1
            idx = ((i-1) % nfrs) + 1
            read!(sock, buffer(tsk, idx))
            tsk.idx = idx
            tsk.nread += 1
            frame_read = true
            notify(ev)
        end
        wait(ev)
    end
    
end


function daqstart(dev::DSA3217, usethread=false)
    if isreading(dev)
        error("Scanivalve already reading!")
    end

    if usethread
        tsk = Threads.@spawn scan!(dev)
    else
        tsk = @async scan!(dev)
    end

    return tsk
end

function readpressure(dev::DSA3217)
    isreading(dev) && error("Scanivalve still acquiring data!")

    tsk = dev.task
    nsamples = samplesread(dev)
    buflen = numframes(tsk)
    idx = tsk.idx

    if daqparam(dev, :EU) > 0
        press = read_eu_press(tsk.buffer, buflen, nsamples, idx)
    else
        error("Reading data without engineering units (EU=1) not implemented yet!")
    end
    return press
end

    
function daqread(dev::DSA3217)

    # Wait for data
    while isreading(dev)
        sleep(0.1)
    end

    # Get the data:
    return readpressure(dev)                      
end

function daqacquire(dev::DSA3217)
    scan!(dev)
    return readpressure(dev)
end


function read_eu_press(buf, buflen, nsamples, idxlast)
    if nsamples <= buflen # All buffer was not overwritten
        return reinterpret(Float32, buf[9:72, 1:nsamples])
    else # Buffer overwritten
        # Get the older data (after idxlast)
        press1 = reinterpret(Float32, buf[9:72, (idx+1):buflen])
        press2 = reinterpret(Float32, buf[9:72, 1:idx])
        return hcat(press1, press2)
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
    s = socket(scani)
    println(s, "SET EU 1")
    println(s, "SET AVG 100")
    println(s, "SET PERIOD 500")
    println(s, "SET FPS 1")
    println(s, "SET BIN 0")
    println(s, "SET XSCANTRIG 0")
    println(s, "SET UNITSCAN PA")
    println(s, "SET TIME 0")
    close(socket(scani))
end

numchans(scani::DSA3217) = 16

socket(scani) = scani.socket

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

function scanconfig(dev::DSA3217; kw...)

    k = keys(kw)
    cmds = String[]
    if :FPS ∈ k
        fps = kw[:FPS]
        if 0 ≤ fps < 1_000_000
            push!(cmds, "SET FPS $fps")
            dev.daqparams[:FPS] = fps
        else
            throw(DomainError(fps, "FPS outside range (0 - 1000000)"))
        end
    end

    if :PERIOD ∈ k
        period = kw[:PERIOD]
        if 125 ≤ period ≤ 65535
            push!(cmds, "SET PERIOD $period")
            dev.daqparams[:PERIOD] = period
        else
            throw(DomainError(period, "PERIOD outside range (126 - 65535)"))
        end
    end

    if :AVG ∈ k
        avg = kw[:AVG]
        if 1 ≤ avg ≤ 240
            push!(cmds, "SET AVG $avg")
            dev.daqparams[:AVG] = avg
        else
            throw(DomainError(avg, "AVG outside range (1 - 240)"))
        end
    end

    if :TIME ∈ k
        tt = kw[:TIME]
        if 0 ≤ tt ≤ 2
            push!(cmds, "SET TIME $tt")
            dev.daqparams[:TIME] = tt
        else
            throw(DomainError(tt, "TIME outside range (0-2)"))
        end
    end
    
    if :EU ∈ k
        eu = kw[:EU]
        if 0 ≤ eu ≤ 1
            push!(cmds, "SET EU $eu")
            dev.daqparams[:EU] = eu
        else
            throw(DomainError(eu, "EU outside range (0 or 1)"))
        end
    end

    if :UNITSCAN ∈ k # User should check manually if the correct unit was used
        unitscan = kw[:UNITSCAN]
        push!(cmds, "SET UNITSCAN $unitscan")
        
    end

    if :XSCANTRIG ∈ k
        xscantrig = kw[:EU]
        if 0 ≤ eu ≤ 1
            push!(cmds, "SET SCANTRIG $xscantrig")
            dev.daqparams[:XSCANTRIG] = xscantrig
        else
            throw(DomainError(xscantrig, "XSCANTRIG should be either 0 or 1"))
        end
    end

    # Send commands to Scanivalve
    sock = socket(dev)

    for c in cmds
        println(sock, c)
    end
    
end



function readmanylines(dev, cmd, delay=0.5)


    socket = dev.socket
    lst = String[]
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
    
    return lst

end

function readstatus(dev::DSA3217)
    s = socket(dev)
    println(s, "STATUS")
    msg = string(Char.(read(s, 180)[81:100])...)
    return msg
end






    
function scan2time(dev, buf, info)
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




