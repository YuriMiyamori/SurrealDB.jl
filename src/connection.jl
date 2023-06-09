
struct TimeoutError <: Exception
    msg::String
end
Base.showerror(io::IO, e::TimeoutError) = print(io, e.msg)


function check_format(format::Symbol)::Nothing
    if format ∉(:json, :msgpack, :cbor)
        throw(ArgumentError("format must be :json or :msgpack or :cbor"))
    end
end


function generate_header()
    [   "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => base64encode(rand(UInt8, 16)),
        "Sec-WebSocket-Version" => "13"]
end

"""
    connect(db::Surreal, url::Union{Nothing, String}=nothing)
connect to a local or remote database endpoint
# Examples
```jldoctest
julia> db = Surreal()
julia> connect(db, "ws://127.0.0.1:8000/rpc")
julia> signin(db, user="root", pass="root")
# Connect to a remote endpoint
julia> db = Surreal()
julia> connect(db,"http://cloud.surrealdb.com/rpc")
julia> signin(db, user="root", pass="root")
```
"""
function connect(db::Surreal; timeout::Real=10.0)
    db.url = correct_url(db.url)
    db.ws_ch = Channel{WebSocket}(db.npool)
    @sync begin
        for _ in 1:db.npool
            @spawn begin
                task = @spawn openraw("GET", db.url, generate_header())
                res = timedwait(()->istaskdone(task),timeout, pollint=0.01) #:ok or :timeout
                if res == :timed_out 
                    throw(TimeoutError("Connection timed out. Check your url($(db.url)). Or set timeout($(timeout) sec) to larger value and try again."))
                end 
                @static VERSION ≥ v"1.7" && errormonitor(task)
                socket, _ = fetch(task)
                put!(db.ws_ch, WebSocket(socket))
            end
        end
    end

    db.client_state = CONNECTED
    nothing
end

"""
    close(db::Surreal)

Closes the persistent connection to the database.
"""
function close(db::Surreal)::Nothing
    if db.client_state == CONNECTED
        for _ in 1:db.npool
            ws = take!(db.ws_ch)
            close(ws)
            put!(db.ws_ch, ws)
        end
    end
    db.client_state = DISCONNECTED
    nothing
end