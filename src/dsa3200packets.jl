
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


