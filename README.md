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
res = Surreal("ws://localhost:8000/rpc") do db
  connect(db)
  signin(db, user="root", pass="root")
  use(db, namespace="test", database="test")
  create(db, thing="planet", data=Dict("name"=>"Earth","radius"=>6371))
  create(db, thing="planet", data=Dict("name"=>"Mars","radius"=>3389))
  create(db, thing="planet", data=Dict("name"=>"Jupiter","radius"=>58232))
  merge(db, thing="planet", data=Dict("Star"=>"Sun"))
  query(db, sql=
  """
  --sql
  SELECT * FROM planet WHERE radius<10_000;
  """
  )
  res
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