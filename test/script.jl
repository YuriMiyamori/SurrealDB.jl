using Base.Threads
@testset "script" begin

    Surreal(URL) do db
        @test db.client_state == SurrealdbWS.ConnectionState(0)

        #connect
        connect(db, timeout=30)
        @test db.client_state == SurrealdbWS.ConnectionState(1)

        # signin
        res = signin(db, user="root", pass="root")
        @test res===nothing

        # res = signup(db, user="test_user", pass="test_user")
        # @test res===nothing
        #use
        res = use(db, namespace="test", database="test")
        @test res===nothing

        # create
        df_boston = dataset("MASS", "Boston")
        set_format(db, :cbor)
        for (i, d) in enumerate(eachrow(df_boston))
            data = Dict((names(d) .=> values(d)))
            res = create(db, thing="price:$(i)", data = data)
            delete!(res, "id")
            @show(data)
            @show(res)
            @test isequal(keys(data), keys(res))
            break
        end

        res = query(db, sql="""create thing:float set num = <float> 4.2;""")
        @show(res)
        #query
        res = query(db, sql="""update price MERGE {
                city: "Boston",
                tags: ["Harrison, D. and Rubinfeld, D.L. (1978)", "house"]
            };"""
        )
        select(db, thing="price") |> display

        @test res["status"] == "OK"
    
        #delete
        res = delete(db, thing="price")
        # @test(typeof(res)==Vector{AbstractDict})

        #info
        @test info(db)===nothing
        #ping
        @test ping(db)===nothing
    end
end