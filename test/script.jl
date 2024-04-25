import Base.Threads: @spawn
import RDatasets: dataset
import Random: rand,seed!

@testset "open close manually" begin
  db = Surreal(URL)
  @test db.client_state == SurrealdbWS.ConnectionState(0)
  #conncet
  connect(db)
  @test db.client_state == SurrealdbWS.ConnectionState(1)
  # close
  close(db)
  @test db.client_state ==  SurrealdbWS.ConnectionState(2)
end

Surreal(URL, npool=5) do db
  @testset "connect" begin
    connect(db, timeout=30)
  end
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
  connect(db, timeout=0.1)
  res = signin(db, user="root", pass="root")
  res = use(db, namespace="test", database="test")
  # config for signup...
  
  user_set = query(db, sql=
  """
  --sql
    DEFINE TABLE user SCHEMAFULL
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
    ;
  """
  )
end

@testset "sign up" begin
  global token = Surreal(URL) do db
    connect(db, timeout=30)
    res = signup(db, vars=Dict("ns" =>"test", "db"=>"test",  "sc" => "allusers", 
    "user"=>"test_user" * string(rand(UInt16)), "pass"=>"test_user_pass"))
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

seed!(42)
#sync create
df_boston = dataset("MASS", "Boston")
Surreal(URL, npool=1) do db
  connect(db, timeout=30)
  signin(db, user="root", pass="root")
  use(db, namespace="test", database="test")

  @testset "delete" begin
    res = delete(db, thing="price")
    @test res !== nothing
  end

  @testset "set" begin
    res = set(db, params=("lang","Julia"))
    @test res === nothing
  end
  @testset "unset" begin
    res = unset(db, name="lang")
    @test res === nothing
  end
  @testset "sync create" begin
    for (i, d) in enumerate(eachrow(df_boston[1:2,:]))
      data = Dict((names(d) .=> values(d)))
      thing = "price:$(i)"
      res = create(db, thing=thing, data=data)
      @test res !== nothing
    end
  end

  @testset "insert" begin
    res = insert(db, thing="price", data=Dict("price2"=>100.0))
    println(res)
    @test res !== nothing
  end

  @testset "update" begin
    res = update(db, thing="price", data=Dict("price"=>1000.0))
    @test res !== nothing
  end

  # @testset "patch" begin
  #     res = patch(db, thing="price", 
  #         data=Dict(
  #             "city"=> "Boston",
  #             "tags"=> ["Harrison, D. and Rubinfeld, D.L. (1978)", "house"]
  #         )
  #     )
  #     @test res !== nothing
  # end
  @testset "merge" begin
    res = merge(db, thing="price", data=Dict("in sale"=>true))
    @test res !== nothing
  end

  @testset "select" begin
    res = select(db, thing="price:1")
    println(res)
    @test res !== nothing
  end

  @testset "info" begin
    res = info(db)
    @test res === nothing
  end

  @testset "ping" begin
    res = ping(db)
    @test res === nothing
  end

  @testset "invalidate" begin
    res = invalidate(db)
    @test res === nothing
  end
end

# async create
seed!(43)
Surreal(URL, npool=5) do db
  connect(db, timeout=30)
  signin(db, user="root", pass="root")
  use(db, namespace="test", database="test")
  @testset "async create" begin
    res = []
    @sync begin
      for (i, d) in enumerate(eachrow(df_boston))
        data = Dict((names(d) .=> values(d)))
        thing = "price:$(i)_$(string(rand(UInt16)))"
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
