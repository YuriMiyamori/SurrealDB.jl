@enum ConnectionState CONNECTING=0 CONNECTED=1 DISCONNECTED=2
"""
    Surreal(url::Union{Nothing, String}, token::Union{Nothing, String}, client_state::ConnectionState, ws::Union{Nothing, websocket}
A struct represents a Surreal server.
# Constructors
```julia 
Surreal()
Surreal(url::String)
```
# Keyword arguments
- url: The URL of the Surreal server.
# Examples
```jldoctest
db = Surreal("ws://127.0.0.1:8000/rpc")
db = Surreal("http://cloud.surrealdb.com/rpc")
```
"""
mutable struct Surreal
    url::String
    token::Union{Nothing, String}
    client_state::ConnectionState
    ws_ch ::Union{Nothing, Channel{WebSocket}}
    format::Symbol
    npool::Int
end

"""
    Surreal(url::String; npool=1)::Surreal

    A struct represents a Surreal server.
    # Constructors
    ```julia 
    Surreal(url::String)
    ```
    # Keyword arguments
    - url: The URL of the Surreal server.
    - npool: The number of connection pool. Default is 1.
    # Examples
    ```jldoctest
    db = Surreal("ws://localhost:8000/rpc", npool=20)
    db = Surreal("http://cloud.surrealdb.com/rpc")
    ```
"""
function Surreal(url::String; npool=1)::Surreal
    return Surreal(
        url, 
        nothing,
        CONNECTING,
        nothing,
        :json,
        npool
    )
end

"""
    Surreal(f::Function, url::String; npool=1)
Apply the function `f` to the result of `Surreal(url, npool)` and close the db
descriptor upon completion.
# Examples
```jldoctest
julia> Surreal("ws://localhost:8000/rpc") do db
            connect(db)
            signin(db,user="root", pass="root")
            use(db, namespace="test", database="test")
            create(db, thing="person",
                    data = Dict("user"=> "me","pass"=> "safe","marketing"=> true,
                                "tags"=> ["python", "documentation"]))
        end
```
"""
function Surreal(f::Function, url::String; npool=1)
    db = Surreal(url, npool=npool)
    try
        f(db)
    finally
        close(db)
    end
end

"""
    correct_url(url::String)::String

"""
function correct_url(url::String)::String
    if occursin("https", url)
        url = replace(url, "https://" => "wss://")
    elseif occursin("http", url)
        url = replace(url, "http://" => "ws://")
    end
    if !occursin("/rpc", url)
        url *= "/rpc"
    end
    url
end