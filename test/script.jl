
@testset "script" begin

    df_boston = dataset("MASS", "Boston")
    Surreal(URL) do db
        @test db.client_state == SurrealdbWS.ConnectionState(0)

        #connect
        connect(db)
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
        for (i, d) in enumerate(eachrow(df_boston))
            data = Dict((names(d) .=> values(d)))
            res = create(db, thing="price:$(i)", data = data)
            delete!(res, "id")
            @test isequal(keys(data), keys(res))
        end

        #update
        data = Dict("city"=> "Boston", "tags" => ["house", "good"])
        # res = update(db, thing="price:1", data = data)
        # @show(res)
        # delete!(res, "id")
        # @test isequal(data, res)

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
        @test(typeof(res)==Vector{AbstractDict{String, Any}})

        #info
        @test info(db)===nothing
        #ping
        @test ping(db)===nothing
    end
end