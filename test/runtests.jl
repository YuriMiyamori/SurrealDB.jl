# include("../src/SurrealdbWS.jl")
using SurrealdbWS
import RDatasets: dataset
using Test

const URL = "ws://localhost:8000/rpc"
include("notebook.jl")
include("script.jl")
