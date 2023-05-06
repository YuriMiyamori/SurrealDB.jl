using Surrealdb
using Test

PORT = 8000
@testset "Surrealdb.jl" begin
    # Surreal
    db = Surreal("ws://localhost:$PORT")
    @test db.client_state == Surrealdb.ConnectionState(0)

    #connect
    connect(db)
    @test db.client_state == Surrealdb.ConnectionState(1)

    # signin
    res = signin(db, user="root", pass="root")
    @test res===nothing

    # res = signup(db, user="test_user", pass="test_user")
    # @test res===nothing
    #use
    res = use(db, namespace="test", database="test")
    @test res===nothing

    # create
    data = Dict("user"=> "me","pass"=> "safe","marketing"=> true, "tags"=> ["python", "documentation"])
    res = create(db, thing="person", data = data)
    delete!(res, "id")
    @test isequal(data, res)

    #update
    data = Dict("user"=> "you","pass"=> "very safe","marketing"=> true, "tags"=> ["python", "good"])
    res = update(db, thing="person", data = data)
    delete!(res, "id")
    @test isequal(data, res)

    #query
    res = query(db, sql="""update person content {
            user: 'mark1',
            pass: 'more_safe2',
            tags: ['awesome2']
        };"""
    )
    @test res["status"] == "OK"
    
    #delete
    res = delete(db, thing="person")
    @test(typeof(res)==Vector{Dict{String, Any}})

    #info
    @test info(db)===nothing
    #ping
    @test ping(db)===nothing
    #close
    @test close(db)==Surrealdb.ConnectionState(2)
end
