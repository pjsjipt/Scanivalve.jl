module Scanivalve

using Sockets


export AbstractDAQ, DSA3217
export close, numchans, listscan, listzero, listgain, listoffset, listdelta


abstract type AbstractDAQ end
abstract type AbstractPressureScanner <: AbstractDAQ end
abstract type AbstractScanivalve <: AbstractPressureScanner end

mutable struct DAQTask{DAQ <: AbstractDAQ}
    daq::DAQ
    isreading::Bool
    nread::Int
    buffer::Matrix{UInt8}
end

    
    
mutable struct DSA3217 <: AbstractScanivalve
    socket::TCPSocket
    buffer::Matrix{UInt8}
    samplesread::Int
end

function DSA3217(ipaddr="191.30.80.131"; timeout=5)

    s = openscani(ipaddr, 23, timeout)
    buffer = zeros(Int8, 0, 0)
    println(s, "SET EU 1")
    println(s, "SET AVG 100")
    println(s, "SET PERIOD 500")
    println(s, "SET FPS 1")
    println(s, "SET BIN 1")
    println(s, "SET XSCANTRIG 0")
    println(s, "SET UNITSCAN PA")
    println(s, "SET TIME 0")
    
    

    return DSA3217(s, buffer, 0)
     
    
end


mutable struct DSA3017 <: AbstractScanivalve
    socket::TCPSocket
    period::Int
    fps::Int
    avg::Int
    unit::String
    time::Int
    xtrig::Bool
    buffer::Matrix{UInt8}
    
end


struct DSA3200Status
    ptype::Int16
    pad::NTuple{78,UInt8}
    status::NTuple{20,UInt8}
    pad2::NTuple{80,UInt8}
end

struct DSA3200ScanRaw
    ptype::Int16
    pad::Int16
    frame::Int32
    press::NTuple{16,Int16}
    temp::NTuple{16,Int16}
end

struct DSA3200ScanEU
    ptype::Int16
    pad::Int16
    frame::Int32
    press::NTuple{16,Float32}
    temp::NTuple{16,Int16}
end

struct DSA3200ScanRawTime
    ptype::Int16
    pad::Int16
    frame::Int32
    press::NTuple{16,Int16}
    temp::NTuple{16,Int16}
    time::Int32
    timeunit::Int32
end

struct DSA3200ScanEUTime
    ptype::Int16
    pad::Int16
    frame::Int32
    press::NTuple{16,Float32}
    temp::NTuple{16,Int16}
    time::Int32
    timeunit::Int32
end


#function readpacket!(


function openscani(ipaddr="191.30.80.131", port=23, timeout=5)
    sock = TCPSocket()
    t = Timer(_ -> close(sock), timeout)
    try
        println("Abrindo")
        connect(sock, ipaddr, port)
    catch e
        println("Pau!!")
        error("Could not connect to $ipaddr ! Turn on the device or set the right IP address!")
    finally
        close(t)
    end
    
    return sock
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


function scanconfig(dev::DSA3217; FPS=-1, PERIOD=-1, AVG=-1, TIME=-1, EU=-1,
                    UNITSCAN="", XSCANTRIG=-1)

    sock = socket(dev)
    if FPS > 0
        FPS = checkfps(dev, FPS)
        println(sock, "SET FPS $FPS")
    end

    if PERIOD >= 0
        PERIOD = checkperiod(dev, PERIOD)
        println(sock, "SET PERIOD $PERIOD")
    end
    
    if AVG >= 0
        AVG = checkavg(dev, AVG)
        println(sock, "SET AVG $AVG")
    end

    if XSCANTRIG >=0 
        XSCANTRIG = checkxscantrig(dev, XSCANTRIG)
        println(sock, "SET XSCANTRIG $XSCANTRIG")
    end

    if TIME >= 0
        TIME = checktime(dev, TIME)
        println(sock, "SET TIME $TIME")
    end

    if EU >= 0
        EU = checkeu(dev, EU)
        println(sock, "SET EU $EU")
    end

    if length(UNITSCAN) > 0
        println(sock, "SET UNITSCAN $UNITSCAN")
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


function scanpacket(dev::DSA3217)

    lst = listscan(dev)

    EU = parse(Int, lst["EU"])
    FPS = parse(Int, lst["FPS"])
    AVG = parse(Int, lst["AVG"])
    PERIOD = parse(Int, lst["PERIOD"])
    TIME = parse(Int, lst["TIME"])
    UNITSCAN = lst["UNITSCAN"]
    XSCANTRIG = parse(Int, lst["XSCANTRIG"])
    
    buflen = (FPS==0) ? buflen : FPS
    packlen = scanpacksize(dev, TIME, EU)
    buffer = zeros(UInt8, packlen, buflen)

    dev.buffer = buffer
    sock = socket(dev)
    println(sock, "SCAN")
    for i in 1:FPS
        read!(sock, view(buffer, :, i))
    end

    return buffer, (FPS=FPS, AVG=AVG, PERIOD=PERIOD, TIME=TIME,
                    UNITSCAN=UNITSCAN, EU=EU, XSCANTRIG=XSCANTRIG)


end

function asyncscanpacket(dev::DSA3217)

    lst = listscan(dev)

    EU = parse(Int, lst["EU"])
    FPS = parse(Int, lst["FPS"])
    AVG = parse(Int, lst["AVG"])
    PERIOD = parse(Int, lst["PERIOD"])
    TIME = parse(Int, lst["TIME"])
    UNITSCAN = lst["UNITSCAN"]
    XSCANTRIG = parse(Int, lst["XSCANTRIG"])
    
    buflen = (FPS==0) ? buflen : FPS
    packlen = scanpacksize(dev, TIME, EU)
    buffer = zeros(UInt8, packlen, buflen)

    dev.buffer = buffer
    sock = socket(dev)
    println(sock, "SCAN")
    dev.samplesread = 0
    @async for i in 1:FPS
        read!(sock, view(buffer, :, i))
        dev.samplesread += 1
    end

    println("ACABOU")

    return buffer, (FPS=FPS, AVG=AVG, PERIOD=PERIOD, TIME=TIME,
                    UNITSCAN=UNITSCAN, EU=EU, XSCANTRIG=XSCANTRIG)


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



end

