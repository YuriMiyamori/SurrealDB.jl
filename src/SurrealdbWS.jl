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
change,
patch,
delete,
close,
ping,
authenticate,
set_format,
info

import Base64: base64encode
import CBOR: decode, encode
import HTTP.Sockets: send
import HTTP.WebSockets: WebSocket, close, receive
import HTTP.openraw
import JSON: json, parse
import MsgPack: pack, unpack
import UUIDs: uuid4

using Base.Threads

include("surreal.jl")
include("connection.jl")
include("send_receive.jl")
include("query.jl")

end