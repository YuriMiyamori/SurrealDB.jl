# include("../src/SurrealdbWS.jl")
using SurrealdbWS
import RDatasets: dataset
using Test

const URL = "ws://localhost:8001/rpc"
include("notebook.jl")
include("script.jl")
