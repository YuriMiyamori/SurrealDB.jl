import CBOR: decode, encode
import JSON: json, parse
import MsgPack: pack, unpack
import UUIDs: uuid4



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
function send_receive(db::Surreal; method::String, params::Union{Nothing, Tuple, AbstractVector}=nothing)::Union{Nothing, String, AbstractDict, Vector{AbstractDict}}
    # Check Connection State
    if db.client_state != CONNECTED
        throw(ErrorException("Not connected to Surreal server."))
    end

    check_format(db.format)
    # typed_params = type_annotate(params)

    # take available websocket from channel, if not available, wait for it
    ws = take!(db.ws_ch)
    # send data to server as json
    data_send = isnothing(params) ? Dict("id"=>generate_uuid(), "method"=>method) : Dict("id"=>generate_uuid(), "method"=>method, "params"=>params)
    send(ws, json(data_send))
    data_receive = receive(ws)
    # put websocket back to channel
    put!(db.ws_ch, ws)

    # Parse response depending on format
    response = begin
        if db.format == :json
            parse(data_receive)
        elseif db.format == :msgpack
            unpack(data_receive)
        elseif db.format == :cbor
            decode(data_receive)
        end
    end
    # Check response has Error
    haskey(response, "error") && throw(ErrorException(response["error"]["message"]))
    data_send["id"] != response["id"] && throw(ErrorException(
        "Response ID does not match request ID. sent id is $(data_send["id"]) but response id is $(response["id"]))"))

    return  response["result"] |> convert_response
end

convert_response(res) = res
function convert_response(res::Vector)::Union{Vector{AbstractDict}, AbstractDict}
    length(res) == 1 && return res[1]
    return convert(Vector{AbstractDict}, res)
end
