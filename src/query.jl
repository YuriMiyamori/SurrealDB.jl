"""
`signin(db::Surreal; user::String, pass::String)::Union{String, Nothing}`

Sign this connection in to a specific authentication scope.

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
	tasks = [@spawn send_receive(db, method="signin", params=(params,)) for _ in 1:db.npool]
	db.token = fetch.(tasks) |> first
	nothing
end

"""
`signup(db::Surreal; user::String, pass::String)::Union{String, Nothing}`

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
	task = @spawn send_receive(db, method="signup", params=(vars,))
	db.token = fetch(task)
	nothing
end

"""
`authenticate(db::Surreal; token::Union{String, Nothing}=nothing)::Nothing`

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
		for _ in 1:db.npool
			@spawn send_receive(db, method="authenticate", params=(db.token,))
		end
	end
	nothing
end

"""
`invalidate(db::Surreal)::Nothing`

invalidate the user's session for the current connection
# Examples
```jldoctest
julia> invalidate(db)
```
"""
function invalidate(db::Surreal)::Nothing
	@sync begin
		for _ in 1:db.npool
			@spawn send_receive(db, method="invalidate")
		end
	end
	nothing
end

"""
`set(db::Surreal; key, value)::Nothing`

Assigns a value as a parameter for this connection.
# Arguments
- `key`: The key to assign the value to.
- `value`: The value to assign.
# Examples
```jldoctest
julia> set(db,key="lang", value="Julia")
```
"""
function set(db::Surreal; key::String, value::String)::Nothing
	@sync begin
		for _ in 1:db.npool
			@spawn send_receive(db, method="let", params=(key,value),)
		end
	end
	nothing
end


"""
`unset(db::Surreal; key::String)::Nothing`

unset a assigned parameter for this connection.
# Arguments
- `key`: The key to unassign.
# Examples
```jldoctest
julia> unset(db,key="lang")
```
"""
function unset(db::Surreal; key::String)::Nothing
	@sync begin
		for _ in 1:db.npool
			@spawn send_receive(db, method="unset", params=(key,))
		end
	end
	nothing
end

"""
`use(db::Surreal; namespace::String, database::String)`

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
		for _ in 1:db.npool
			@spawn send_receive(db, method="use", params=(namespace, database))
		end
	end
	nothing
end

"""
`create(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)`

Creates a record in the database.
# Arguments
- `thing`: The table or record ID.
- `data`: The document / record data to insert.
# Examples
###  Create a record with a random ID
```julia-repl
julia> create(db, "planet")
### Create a record with a specific ID
```julia-repl
julia> planet = insert(db,thing="planet",data=Dict("name"=>"Earth", "radius"=>6371,
  "satellites"=>[Dict("name"=>"Moon","radius"=>1737),]))
```
"""
function create(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
	task = @spawn send_receive(db, method="create", params=(thing, data))
	return fetch(task)
end

"""
`insert(db::Surreal; thing::String, data::Union{Dict, Nothing}=nothing)`

insert a record in the database.

# Arguments
- `thing::String`: The table or record ID.
- `data::Dict`: The document / record data to insert.
# Examples
### insert a record with a random ID
```julia-repl
julia> planet = insert(db,thing="planet",data=Dict("name"=>"Mars", "radius"=>3376,
  "satellites"=>[Dict("name"=>"Phobos","radius"=>11.1),Dict("name"=>"Deimos","radius"=>6.2]))
```
### insert a record with a specific ID
```julia-repl
julia> planet = insert(db,thing="planet:004",data=Dict("name"=>"Mars", "radius"=>3376,
  "satellites"=>[Dict("name"=>"Phobos","radius"=>11.1),Dict("name"=>"Deimos","radius"=>6.2]))
```
"""
function insert(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
	task = @spawn send_receive(db, method="insert", params=(thing, data))
	return fetch(task)
end

"""
`merge(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)`

merge a record in the database.
# Arguments
- `thing`: The table or record ID.
- `data`: The document / record data to merge.
# Examples
### merge a record with all records in a table
```julia-repl
julia> planet = merge(db, thing="planet", data=Dict("star"=>"Sun")))
```
### merge a record with a specific ID
```julia-repl
julia> planet = merge(db, thing="planet:003", data=Dict("star"=>"Sun")))
```
"""
function Base.merge(db::Surreal; thing::String, data::Union{AbstractDict, Nothing}=nothing)
	task = @spawn send_receive(db, method="merge", params=(thing, data))
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
julia> planet = select(db, thing="planet")
# Select a specific record from a table (or other entity)
julia> planet = select(db, thing="planet:003")
```
"""
function select(db::Surreal; thing::String)
	task = @spawn send_receive(db, method="select", params=(thing, ))
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
julia> result = query(db, sql="select * from type::table(\$tb)",vars=Dict("tb"=> "planet"))
julia> # Get the first result from the first query
julia> result[0]["result"][0]
```
"""
function query(db::Surreal; sql::String, vars::Union{AbstractDict, Nothing}=nothing)
	task = @spawn send_receive(db, method="query", params=(sql, vars))
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
	task = @spawn send_receive(db, method="patch", params=(thing, data))
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
	return fetch(task)
end

"""
	info(db::Surreal)

Retreive info about the current Surreal instance.
# Returns
	The information of the Surreal server.
"""
function info(db::Surreal)
	task = @spawn send_receive(db, method="info")
	return fetch(task)
end

"""
	ping(db::Surreal)

Ping the Surreal server.
"""
function ping(db::Surreal)
	task = @spawn send_receive(db, method="ping")
	return fetch(task)
end