include("../src/SurrealdbWS.jl")
using .SurrealdbWS
using Test

const URL = "ws://surrealdb:8000"
# const URL = "ws://localhost:8001"
# include("notebook.jl")
include("script.jl")
# import Pkg; Pkg.add("HTTP")