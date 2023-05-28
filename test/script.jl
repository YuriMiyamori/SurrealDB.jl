using Base.Threads

# open and close manually
df_boston = dataset("MASS", "Boston")
@testset "open close manually" begin
    db = Surreal(URL)
    @test db.client_state == SurrealdbWS.ConnectionState(0)
    #conncet
    connect(db, timeout=30)
    @test db.client_state == SurrealdbWS.ConnectionState(1)
    # signin
    res = signin(db, user="root", pass="root")
    @test res===nothing

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

    # set format 
    set_format(db, :json)
    set_format(db, :cbor)

    #close
    close(db)
    @test db.client_state ==  SurrealdbWS.ConnectionState(2)
end

@testset "sign up" begin
    global token =Surreal(URL) do db
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

@testset "do open statement" begin
    Surreal(URL) do db
        #connect
        connect(db, timeout=30)
        res = signin(db, user="root", pass="root")
        res = use(db, namespace="test", database="test")

        # create
        # set_format(db, :json)
        for (i, d) in enumerate(eachrow(df_boston))
            data = Dict((names(d) .=> values(d)))
            res = create(db, thing="price:$(i)", data = data)
            delete!(res, "id")
            @test isequal(keys(data), keys(res))
        end

        res = update(db, thing="price:1", data=Dict("price"=>1000.0))


        #query
        res = SurrealdbWS.merge(db, thing="price", 
            data=Dict(
                "city"=> "Boston",
                "tags"=> ["Harrison, D. and Rubinfeld, D.L. (1978)", "house"]
            )
        )
        res = select(db, thing="price:506")

        #delete
        res = delete(db, thing="price")

        #info
        @test info(db)===nothing
        #ping
        @test ping(db)===nothing
    end
end

@testset "errors" begin
   db = Surreal("ws://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   db = Surreal("https://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   db = Surreal("http://localhost:8099")
   @test_throws SurrealdbWS.TimeoutError connect(db, timeout=1)

   @test_throws ErrorException info(db)
end