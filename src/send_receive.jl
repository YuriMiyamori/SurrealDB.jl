import JSON: json
import UUIDs: uuid4
import NanoDates: NanoDate
import MsgPack: pack, unpack, Extension
using Dates

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
		throw(ErrorException("not connected to Surreal server."))
	end

	# set sending data to server as json
	data_send = isnothing(params) ? Dict("id"=>generate_uuid(), "method"=>method) : Dict("id"=>generate_uuid(), "method"=>method, "params"=>params)
  data_json = json(data_send)
	# take available websocket from channel, if not available, wait for it
	ws = take!(db.ws_ch)
	send(ws, data_json)
	data_receive = receive(ws)
	# put websocket back to channel
	put!(db.ws_ch, ws)
	# Parse response
	response = data_receive |> unpack |> parse_chain
	# Check response has Error
	haskey(response, "error") && throw(ErrorException("SurrealDB Error:" * response["error"]["message"]))
	data_send["id"] != response["id"] && throw(ErrorException(
		"Response ID does not match request ID. sent id is $(data_send["id"]) but response id is $(response["id"]))"))

	return  response["result"]
end

# parse
function parse_chain(ext::Extension)
  if ext.type == 1 # TAG_NONE
    return nothing
  elseif ext.type == 2 # TAG_UUID
    return String(ext.data)
   elseif ext.type == 3 # TAG_DECIMAL
    return Float64(String(ext.data))
  elseif ext.type == 4 # TAG_DURATION
    data = String(ext.data)
    codes = split(data, r"[0-9]+")[2:end] # duration codes like y, w, d, h, m, s, ms, us, ns
    volumes = split(data, r"[a-z]+")[1:end-1] |> x -> parse.(Int, x) # duration volumes
    d = Dict{String, Int}("y"=>0, "w"=>0, "d"=>0, "h"=>0, "m"=>0, "s"=>0, "ms"=>0, "us"=>0, "ns"=>0)
    for (code, volume) in zip(codes, volumes)
      d[code] = volume
    end

  return Year(d["y"])+Week(d["w"])+Day(d["d"])+
          Hour(d["h"])+Minute(d["m"])+Second(d["s"])+
          Millisecond(d["ms"])+Microsecond(d["us"])+Nanosecond(d["ns"])

  elseif ext.type == 5 # TAG_DATETIME
    return String(ext.data) |> NanoDate
  elseif ext.type == 6 # TAG_RECORDID
    return String(ext.data)
  end
  return error("Unknown extension type: $(ext.type)")
end

function parse_chain(d::AbstractDict)
	for (k, v) in d
		d[k] = parse_chain(v)
	end
	return Dict{String, Any}(d)
end

function parse_chain(s::AbstractVector)
	parse_chain.(s)
end

parse_chain(s) = s
