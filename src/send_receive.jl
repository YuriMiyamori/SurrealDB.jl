import JSON: json, parse
import UUIDs: uuid4
import Dates: DateTime


"""
    generate_uuid()::String

Generate a UUID.
# Returns
A UUID as a string.
"""
generate_uuid()::String = string(uuid4())


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
function send_receive(db::Surreal; method::String, params::Union{Nothing, Tuple, AbstractVector}=nothing)
    # Check Connection State
    if db.client_state != CONNECTED
        throw(ErrorException("Not connected to Surreal server."))
    end

    # TODO
    # typed_params = type_annotate(params)

    # set sending data to server as json
    data_send = isnothing(params) ? Dict("id"=>generate_uuid(), "method"=>method) : Dict("id"=>generate_uuid(), "method"=>method, "params"=>params)
    # take available websocket from channel, if not available, wait for it
    ws = take!(db.ws_ch)
    send(ws, json(data_send))
    data_receive = receive(ws)
    # put websocket back to channel
    put!(db.ws_ch, ws)

    # Parse response
    response = parse(data_receive)
    # Check response has Error
    haskey(response, "error") && throw(ErrorException(response["error"]["message"]))
    data_send["id"] != response["id"] && throw(ErrorException(
        "Response ID does not match request ID. sent id is $(data_send["id"]) but response id is $(response["id"]))"))

    return  response["result"] |> parse_chain
end


"""
    parse_chain(v::Vector{AbstractDict})

TBW
"""
function parse_chain(v::Vector{AbstractDict})
	if length(v) == 1
		return parse_chain(v[1])
	else
		return parse_chain.(v)
	end
end

"""
    parse_chain(d::AbstractDict)

TBW
"""
function parse_chain(d::AbstractDict)
	for (k, v) in d
		d[k] = parse_chain(v)
	end
	return d
end

"""
    parse_chain(s)

TBW
"""
function parse_chain(s)
	tryparse_raw(Float64, s)	|> s ->
	tryparse_raw(DateTime, s)	|> s ->
	identity(s)
end

"""
    parse_chain(s::AbstractVector)

TBW
"""
function parse_chain(s::AbstractVector)
	parse_chain.(s)
end

"""
    tryparse_raw(dist_type::DataType, s::String)::Union{dist_type, String}

TBW
"""
function tryparse_raw(dist_type::DataType, s::String)::Union{dist_type, String}
	res = tryparse(dist_type, s)
	return res === nothing ? s : res
end

# match s except for string
"""
    tryparse_raw(dist_type::DataType, s)

TBW
"""
tryparse_raw(dist_type::DataType, s) = s