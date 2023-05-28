# SurrealdbWS
[![Build Status](https://travis-ci.com/YuriMiyamori/SurrealdbWS.jl.svg?branch=main)](https://travis-ci.com/YuriMiyamori/SurrealdbWS.jl)
[![Coverage](https://codecov.io/gh/YuriMiyamori/SurrealdbWS.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/YuriMiyamori/SurrealdbWS.jl)


The [SurrealDB](https://surrealdb.com) driver for Julia via WebSocket(unofficial)

# Getting Started
First [install SurrealDB](https://surrealdb.com/install) if you haven't already.

## Installation
```julia
using Pkg
Pkg.add("SurrealdbWS")
```

## Usage

### Do-Block Syntax
```julia
using SurrealdbWS
Surreal("ws://localhost:8000/rpc") do db
    connect(db)
    signin(db, user="root", pass="root")
    use(db, namespace="test", database="test")
    create(db, thing="person",
            data = Dict("user"=> "Myra Eggleston",
                        "email"=> "eggleston@domain.com",
                        "marketing"=> true,
                        "tags"=> ["Julialang", "documentation", "CFD"]
                        )
                    )
    create(db, thing="person",
            data = Dict("user"=> "Domenico Risi",
                        "email"=> "domenico.risi@domain.com",
                        "marketing"=> false,
                        "tags"=> ["julialang", "bioinformatics"],
                        )
        )
    change(db, thing="person",data = Dict("computer science"=> true,))
    selcet(db, thing="person")
end
```

### Close manulally for e.g. notebooks
```julia
using SurrealdbWS
db = Surreal("ws://localhost:8000/rpc")
connect(db)
signin(db,user="root", pass="root")
use(db, namespace="test", database="test")
create(db, thing="person",
        data = Dict("user"=> "me","pass"=> "safe","marketing"=> true,
            "tags"=> ["python", "documentation"]))
delete(db, thing="person")
close(db)
```