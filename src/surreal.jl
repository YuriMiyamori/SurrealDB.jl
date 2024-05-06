@enum ConnectionState CONNECTING=0 CONNECTED=1 DISCONNECTED=2

mutable struct Surreal
	url::String
	token::Union{Nothing, String}
	client_state::ConnectionState
	ws_ch ::Union{Nothing, Channel{WebSocket}}
	npool::Int
end

"""
`Surreal(url::String; npool=1)::Surreal`

Return a Surreal struct represents a Surreal server.
# Constructors
```julia-repl
Surreal(url::String)
Surreal(url::String, npool=4)
```
# Keyword arguments
- `url`: The URL of the Surreal server.
- `npool`: The number of connection pool. Default is 1.
# Examples
```jldoctest
julia> db = Surreal("ws://localhost:8000/rpc", npool=20)
Surreal("ws://localhost:8000/rpc", nothing, SurrealdbWS.CONNECTING, nothing, 20)

julia> db = Surreal("http://cloud.surrealdb.com/rpc")
Surreal("http://cloud.surrealdb.com/rpc", nothing, SurrealdbWS.CONNECTING, nothing, 1)
```
"""
function Surreal(url::String; npool=1)::Surreal
	return Surreal(
		url, 
		nothing,
		CONNECTING,
		nothing,
		npool
	)
end

"""
	Surreal(f::Function, url::String; npool=1)
Apply the function `f` to the result of `Surreal(url, npool)` and close the db
descriptor upon completion.
# Examples
```jldoctest
julia> Surreal("ws://localhost:8000/rpc", npool=1) do db
  connect(db)
	signin(db,user="root", pass="root")
	use(db, namespace="test", database="test")
	create(db, thing="person",
	data = Dict("user"=> "me","pass"=> "safe","marketing"=> true,
	"tags"=> ["Julia", "documentation"]))
end
```
"""
function Surreal(f::Function, url::String; npool=1)::Nothing
	db = Surreal(url, npool=npool)
	try
		f(db)
	finally
		close(db)
	end
  nothing
end

"""
correct_url(url::String)::String
Correct the URL to the correct format.
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