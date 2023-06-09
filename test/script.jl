import Base.Threads: @spawn
import RDatasets: dataset

@testset "open close manually" begin
    db = Surreal(URL)
    @test db.client_state == SurrealdbWS.ConnectionState(0)
    #conncet
    connect(db, timeout=30)
    @test db.client_state == SurrealdbWS.ConnectionState(1)
    # close
    close(db)
    @test db.client_state ==  SurrealdbWS.ConnectionState(2)
end

Surreal(URL, npool=5) do db
    connect(db, timeout=30)
    @testset "sign in" begin
        res = signin(db, user="root", pass="root")
        @test res === nothing
    end
    @testset "use" begin
        res = use(db, namespace="test", database="test")
        @test res === nothing
    end
end

#DEFINE TABLE user for authenticate
Surreal(URL) do db
    connect(db, timeout=30)
    res = signin(db, user="root", pass="root")
    res = use(db, namespace="test", database="test")
    # config for signup...
    user_set = query(db, sql=
    """DEFINE TABLE user SCHEMAFULL
      PERMISSIONS
        FOR select, update WHERE id = \$auth.id, 
        FOR create, delete NONE;
        DEFINE FIELD user ON user TYPE string;
        DEFINE FIELD pass ON user TYPE string;
        DEFINE INDEX idx_user ON user COLUMNS user UNIQUE;
        DEFINE SCOPE allusers
        SESSION 10m
        SIGNUP ( CREATE user SET  user = \$user, pass = crypto::argon2::generate(\$pass))
        SIGNIN ( SELECT * FROM user WHERE user = \$user AND crypto::argon2::compare(pass, \$pass) )
      """
    )
end

@testset "sign up" begin
    global token = Surreal(URL) do db
        connect(db, timeout=30)
        res = signup(db, vars=Dict("ns" =>"test", "db"=>"test",  "sc" => "allusers", "user"=>"test_user", "pass"=>"test_user_pass"))
        @test res === nothing
        db.token
    end
end

@testset "authenticate" begin
    Surreal(URL) do db
        connect(db, timeout=30)
        res = authenticate(db, token=token)
        @test res === nothing
    end
end

#sync query
df_boston = dataset("MASS", "Boston")
Surreal(URL, npool=1) do db
    connect(db, timeout=30)
    signin(db, user="root", pass="root")
    use(db, namespace="test", database="test")

    @testset "sync create" begin
        for (i, d) in enumerate(eachrow(df_boston))
            data = Dict((names(d) .=> values(d)))
            thing = "price:$(string(i))"
            res = create(db, thing=thing, data=data)
            @test res !== nothing
        end
    end

    @testset "update" begin
        res = update(db, thing="price", data=Dict("price"=>1000.0))
        @test res !== nothing
    end

    @testset "change" begin
        res = change(db, thing="price", 
            data=Dict(
                "city"=> "Boston",
                "tags"=> ["Harrison, D. and Rubinfeld, D.L. (1978)", "house"]
            )
        )
        @test res !== nothing
    end
    @testset "select" begin
        res = select(db, thing="price:1")
        @test res !== nothing
    end

    @testset "delete" begin
        res = delete(db, thing="price")
        @test res !== nothing
    end

    @testset "info" begin
        res = info(db)
        @test res === nothing
    end

    @testset "ping" begin
        res = info(db)
        @test res === nothing
    end
end

#async create
Surreal(URL, npool=10) do db
    connect(db, timeout=30)
    signin(db, user="root", pass="root")
    use(db, namespace="test", database="test")
    @testset "async create" begin
        res = []
        @sync begin
            for (i, d) in enumerate(eachrow(df_boston))
                data = Dict((names(d) .=> values(d)))
                thing = "price:$(string(i))"
                push!(res, @spawn create(db, thing=thing, data=data))
            end
        end
        res = fetch.(res)
        for val in res
            @test res !== nothing
        end
    end
end


@testset "errors" begin
   db = Surreal("ws://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   db = Surreal("https://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   db = Surreal("http://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   @test_throws TaskFailedException info(db)
end