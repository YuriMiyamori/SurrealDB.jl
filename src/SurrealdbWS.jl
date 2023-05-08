module SurrealdbWS

export Surreal,
connect,
signin,
signup,
use,
select,
create,
update,
query,
merge,
patch,
delete,
close,
ping,
info

import Base64: base64encode
import HTTP.Sockets: send
import HTTP.WebSockets: WebSocket, close, receive
import HTTP.openraw
import JSON: json, parse
import UUIDs: uuid4




@enum ConnectionState CONNECTING=0 CONNECTED=1 DISCONNECTED=2

struct TimeoutError <: Exception
    msg::String
end
Base.showerror(io::IO, e::TimeoutError) = print(io, e.msg)

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
    ws::Union{Nothing, WebSocket}
end

Surreal(url::String, token::Union{Nothing, String}=nothing) = Surreal(url, token, CONNECTING, nothing)

"""
    Surreal(f::Function, url::Union{Nothing, String}=nothing, token::Union{Nothing, String}=nothing)
Apply the function `f` to the result of `Surreal(url, token)` and close the db
descriptor upon completion.
# Examples
```jldoctest
julia> Surreal("ws://db:8000/rpc") do db
            connect(db)
            signin(db,user="root", pass="root")
            use(db, namespace="test", database="test")
            create(db, thing="person",
                    data = Dict("user"=> "me","pass"=> "safe","marketing"=> true,
                                "tags"=> ["python", "documentation"]))
            update(db, thing="person",
                    data = Dict("user"=> "you","pass"=> "very safe","marketing"=> true,
                                "tags"=> ["python", "good"]))
        end
```
"""
function Surreal(f::Function, url::String, token::Union{Nothing, String}=nothing)
    db = Surreal(url, token)
    try
        f(db)
    finally
        close(db)
    end
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
    if occursin("https", db.url)
        db.url = replace(db.url, "https://" => "wss://")
    elseif occursin("http", db.url)
        db.url = replace(db.url, "http://" => "ws://")
    end
    if !occursin("/rpc", db.url)
        db.url *= "/rpc"
    end
    headers = [
        "Upgrade" => "websocket",
        "Connection" => "Upgrade",
        "Sec-WebSocket-Key" => base64encode(rand(UInt8, 16)),
        "Sec-WebSocket-Version" => "13"
    ]
    tsk = Threads.@spawn openraw("GET", db.url, headers)
    res = timedwait(()->istaskdone(tsk),timeout, pollint=0.05) #:ok or :timeout
    if res == :timed_out 
        throw(TimeoutError("Connection timed out. Check your url($(db.url)). Or set timeout($(timeout) sec) to larger value and try again."))
    end
    socket, _ = fetch(tsk)
    db.ws = WebSocket(socket)
    db.client_state = CONNECTED
    nothing
end


"""
    signin(db::Surreal; user::String, pass::String)::Union{String, Nothing}
Signs this connection in to a specific authentication scope.
# Arguments
- `user`: username in signin query
- `pass`: password in signin query
# Examples:
```jldoctest
julia> signin(db, user="root", pass="root")
```
"""
function signin(db::Surreal; user::String, pass::String)::Nothing
    params = Dict("id" => generate_uuid(),"method"=>"signin",
                "params" => [Dict("user"=> user, "pass"=> pass),]
            )
    db.token = send_receive(db, params)
    nothing
end

"""
    signup(db::Surreal; user::String, pass::String)::Union{String, Nothing}
    Signs this connection up to a specific authentication scope.
#Arguments
- `user`: username in signup query
- `pass`: password in signup query
# Examples
```jldoctest
julia> signup(db, user="bob", pass="123456")
```
"""
function signup(db::Surreal; user::String, pass::String)::Nothing
    params = Dict("id" => generate_uuid(),"method"=>"signup",
                "params" => [Dict("user"=> user, "pass"=> pass),]
            )
    db.token = send_receive(db, params)
    nothing
end

"""
    authenticate(db::Surreal; token::String)::Union{String, Nothing}
Authenticates the current connection with a JWT token.
# Arguments
- `token`: The token to use for the connection.
# Examples
```jldoctest
julia> authenticate(db, token="JWT token here")
```
"""
function authenticate(db::Surreal; token::String)::Nothing
    params = Dict("id" => generate_uuid(),"method"=>"authenticate",
                "params" => (token,)
            )
    db.token = send_receive(db, params)
    nothing
end

"""
    use(db::Surreal; namespace::String, database::String)

Switch to a specific namespace and database.
# Arguments
- `namespace`: Switches to a specific namespace.
- `database`: Switches to a specific database.
# Examples
```jldoctest
julia> use(db, namespace='test', database='test')
```
"""
function use(db::Surreal; namespace::String, database::String)::Nothing
    params = Dict("id" => generate_uuid(),"method"=>"use",
                "params" => (namespace, database)
            )
    return send_receive(db, params)
end

"""
    create(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
Create a record in the database.
This function will run the following query in the database:
create `thing` content `data`
# Arguments
- `thing`: The table or record ID.
- `data`: The document / record data to insert.
# Examples
```jldoctest
# Create a record with a random ID
julia> person = create(db, "person")
# Create a record with a specific ID
julia> record = create(db,"person:tobie", Dict(
    "name"=> "Tobie",
    "settings"=> Dict(
        "active"=> true,
        "marketing"=> true,
        ),
    )
"""
function create(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
    params = Dict("id" => generate_uuid(),"method"=>"create",
                "params" => (thing, data)
            )
    return send_receive(db, params)
end

"""
    select(db::Surreal; thing::String)
Selects all records in a table (or other entity),
or a specific record, in the database.
This function will run the following query in the database:
select * from `thing`
# Arguments
    `thing`: The table or record ID to select.
# Returns:
    The records.
# Examples
```jldoctest
# Select all records from a table (or other entity)
julia> people = select(db, "person")
# Select a specific record from a table (or other entity)
julia> person = select(db, "person:h5wxrf2ewk8xjxosxtyc")
```
"""
function select(db::Surreal; thing::String)
    params = Dict("id" => generate_uuid(),"method"=>"select",
                "params" => (thing,)
            )
    return send_receive(db, params)
end


"""
    update(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
Updates all records in a table, or a specific record, in the database.
This function replaces the current document / record data with the
specified data.
This function will run the following query in the database:
update `thing` content `data`
# Arguments
- `thing`: The table or record ID.
- `data`: The document / record data to insert.
# Examples:
```jldoctest
julia> # Update all records in a table
julia> person = update(db, "person")
julia> # Update a record with a specific ID
julia> record = update(db, "person=>tobie", Dict(
    "name"=> "Tobie",
    "settings"=> Dict(
    "active"=> true,
    "marketing"=> true,
    ),
    ))
```
"""
function update(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
    params = Dict("id" => generate_uuid(),"method"=>"create",
                "params" => (thing, data)
            )
    return send_receive(db, params)
end

"""
    query(db::Surreal; sql::String, vars::Union{Dict, Nothing}=nothing)

Runs a set of SurrealQL statements against the database.
# Arguments
`sql`: Specifies the SurrealQL statements.
`vars`: Assigns variables which can be used in the query.
# Returns
The records.
# Examples
```jldoctest
julia> # Assign the variable on the connection
julia> result = query(db, sql=r"create person; select * from type::table(\$tb)",vars=Dict("tb"=> "person"))
julia> # Get the first result from the first query
julia> result[0]["result"][0]
julia> # Get all of the results from the second query
julia> result[1]["result"]
```
"""
function query(db::Surreal; sql::String, vars::Union{Dict, Nothing}=nothing)
    params = Dict("id" => generate_uuid(),"method"=>"query",
                "params" => (sql, vars)
            )
    return send_receive(db, params)
end

"""
    merge(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)

Modifies by deep merging all records in a table, or a specific record, in the database.
This function merges the current document / record data with the
specified data.
This function will run the following query in the database:
update `thing` merge `data`
# Arguments
`thing`: The table name or the specific record ID to change.
`data`: The document / record data to insert.
# Examples
Update all records in a table
people = await db.merge("person", {
"updated_at":  str(datetime.datetime.utcnow())
})
Update a record with a specific ID
person = await db.merge("person:tobie", {
"updated_at": str(datetime.datetime.utcnow()),
"settings": {
"active": True,
},
})
"""
function merge(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
    params = Dict("id" => generate_uuid(),"method"=>"change",
                "params" => (thing, data)
            )
    return send_receive(db, params)
end

"""
    patch(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)

Applies JSON Patch changes to all records, or a specific record, in the database.
This function patches the current document / record data with
the specified JSON Patch data.
This function will run the following query in the database:
update `thing` patch `data`
# Arguments
`thing`: The table or record ID.
`data`: The data to modify the record with.
# Examples
```jldoctest
julia> # Update all records in a table
julia> people = patch(db, "person", Dict(
            "op"=> "replace", "path"=> "/created_at", "value"=> str(datetime.datetime.utcnow()) }])
julia> # Update a record with a specific ID
julia> person = patch(db, "person:tobie", [
                Dict("op"=> "replace", "path"=> "/settings/active", "value"=> false ),
                Dict("op"=> "add", "path"=> "/tags", "value"=> ["developer", "engineer"]),
                Dict("op"=> "remove", "path"=> "/temp"),
                ])
```
"""
function patch(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)
    params = Dict("id" => generate_uuid(),"method"=>"modify",
                "params" => (thing, data)
            )
    return send_receive(db, params)
end

"""
    delete(db::Surreal; thing::String)

Deletes all records in a table, or a specific record, from the database.
This function will run the following query in the database:
delete * from `thing`
# Arguments
`thing`: The table name or a record ID to delete.
# Examples
julia> # Delete all records from a table
julia> delete(db, "person")
julia> # Delete a specific record from a table
julia> delete(db, "person:h5wxrf2ewk8xjxosxtyc")
"""
function delete(db::Surreal; thing::String)
    params = Dict("id" => generate_uuid(),"method"=>"delete",
                "params" => (thing,)
            )
    return send_receive(db, params)
end

"""
    info(db::Surreal)

Retreive info about the current Surreal instance.
# Returns
    The information of the Surreal server.
"""
function info(db::Surreal)
    params = Dict("id" => generate_uuid(),"method"=>"info",
            )
    return send_receive(db, params)
end

"""
    ping(db::Surreal)

Ping the Surreal server.
"""
function ping(db::Surreal)
    params = Dict("id" => generate_uuid(),"method"=>"info",
            )
    return send_receive(db, params)
end
"""
    close(db::Surreal)

Closes the persistent connection to the database.
"""
function close(db::Surreal)::Nothing
    if db.client_state == CONNECTED
        close(db.ws)
    end

    db.client_state = DISCONNECTED
    nothing
end

"""
    generate_uuid()::String

Generate a UUID.
# Returns
A UUID as a string.
"""
function generate_uuid()::String
    return string(uuid4())
end


"""
    send_receive(db::Surreal, params::Dict)

Send a request to the Surreal server and receive a response.
# Arguments
`params`: The request to send.
# Returns
The response from the Surreal server.
# Raises
Exception: If the client is not connected to the Surreal server.
Exception: If the response contains an error.
"""
function send_receive(db::Surreal, params::Dict)::Union{Nothing, Dict{String, Any}, Vector{Dict{String, Any}}}
    # Check Connection State
    if db.client_state != CONNECTED
        throw(ErrorException("Not connected to Surreal server."))
    end

    # Send & Recieve
    t = Threads.@spawn begin
        send(db.ws, json(params))
        receive(db.ws)
    end

    # json to dict
    response = fetch(t) |> parse

    # Check response has Error
    haskey(response, "error") && throw(ErrorException(response["error"]["message"]))

    # res
    result = response["result"] 
    isnothing(result) && return nothing
    length(result) == 1 && return result[1]
    return convert(Vector{Dict{String, Any}}, result)
end
end
