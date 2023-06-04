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
    params = Dict("user"=>user, "pass"=>pass)
    @sync begin
        tasks = [@spawn send_receive(db, method="signin", params=(params,)) for _ in 1:db.npool]
        @static if VERSION ≥ v"1.7"
            errormonitor.(tasks)
        end
        db.token = fetch(first(tasks))
    end
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
function signup(db::Surreal; vars::Dict)::Nothing
    if db.npool > 1
        throw(ArgumentError("signup is not supported in multipool mode"))
    end
    @sync begin
        task = @spawn send_receive(db, method="signup", params=(vars,))
        @static if VERSION ≥ v"1.7"
            errormonitor(task)
        end
        db.token = fetch(task)
    end
    nothing
end

"""
    authenticate(db::Surreal; token::Union{String, Nothing}=nothing)::Nothing
Authenticates the current connection with a JWT token.
# Arguments
- `token`: The token to use for the connection.
# Examples
```jldoctest
julia> authenticate(db, token="JWT token here")
```
"""
function authenticate(db::Surreal; token::Union{String, Nothing}=nothing)::Nothing
    if !isnothing(token)
        db.token = token
    end
    @sync begin
        tasks = [@spawn send_receive(db, method="authenticate", params=(db.token,)) for i in 1:db.npool]
        @static if VERSION ≥ v"1.7"
            errormonitor.(tasks)
        end
    end
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
    @sync begin
        tasks = [@spawn send_receive(db, method="use", params=(namespace, database)) for _ in 1:db.npool]
        @static if VERSION ≥ v"1.7"
            errormonitor.(tasks)
        end
    end
    nothing
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
function create(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
    task = @spawn send_receive(db, method="create", params=(thing, data))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
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
    task = @spawn send_receive(db, method="select", params=(thing, ))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
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
julia> record = update(db, "person:tobie", Dict(
    "name"=> "Tobie",
    "settings"=> Dict(
    "active"=> true,
    "marketing"=> true,
    ),
    ))
```
"""
function update(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
    task = @spawn send_receive(db, method="update", params=(thing, data))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
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
function query(db::Surreal; sql::String, vars::Union{AbstractDict, Nothing}=nothing)
    task = @spawn send_receive(db, method="query", params=(sql, vars))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
end

"""
    change(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)

Modifies by deep merging all records in a table, or a specific record, in the database.
This function merges the current document / record data with the
specified data.
This function will run the following query in the database:
update `thing` merge `data`
# Arguments
`thing`: The table name or the specific record ID to change.
`data`: The document / record data to insert.
# Examples
```jldoctest
# Update all records in a table
res = change(db, thing="person", data=Dict("active":  true))
```
"""
function change(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
    task = @spawn send_receive(db, method="change", params=(thing, data))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
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
function patch(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
    task = @spawn send_receive(db, method="modify", params=(thing, data))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
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
    task = @spawn send_receive(db, method="delete", params=(thing, ))
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
end

"""
    set_format(db::Surreal, format::String)

set format for transmission
# Arguments
`format`: The format to use for transmission. :json or :cbor
"""
function set_format(db::Surreal, format::Symbol)::Nothing
    check_format(format)
    tasks = [@spawn send_receive(db, method="format", params=(format, )) for _ in 1:db.npool]
    @static if VERSION ≥ v"1.7"
        errormonitor.(tasks)
    end
    fetch.(tasks)
    db.format = format
    nothing
end
"""
    info(db::Surreal)

Retreive info about the current Surreal instance.
# Returns
    The information of the Surreal server.
"""
function info(db::Surreal)
    task = @spawn send_receive(db, method="info")
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
end

"""
    ping(db::Surreal)

Ping the Surreal server.
"""
function ping(db::Surreal)
    task = @spawn send_receive(db, method="ping")
    @static if VERSION ≥ v"1.7"
        errormonitor(task)
    end
    return fetch(task)
end