import Base.Threads: @spawn
import RDatasets: dataset
import Random: rand,seed!
import NanoDates: NanoDate
using Dates
import DataFrames: DataFrame

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

Surreal(URL, npool=1) do db
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
    # res = authenticate(db, token=token)
    # @test res === nothing
  end
end

seed!(42)
#sync create
df_boston = dataset("MASS", "Boston")# [1:10,:]
Surreal(URL, npool=1) do db
  @testset "connection" begin
    connect(db, timeout=30)
    signin(db, user="root", pass="root")
    use(db, namespace="test", database="test")
  end

  @testset "delete" begin
    res = delete(db, thing="price")
    @test res !== nothing
  end

  @testset "set" begin
    res = set(db, key="lang", value="Julia")
    @test res === nothing
  end
  @testset "unset" begin
    res = unset(db, key="lang")
    @test res === nothing
  end
  @testset "sync create" begin
    for (i, d) in enumerate(eachrow(df_boston))
      data = Dict((names(d) .=> values(d)))
      thing = "price:$(i)"
      res = create(db, thing=thing, data=data)
    end
    res = query(db, sql = "SELECT * FROM price;")
    @test DataFrame(res)[:, names(df_boston)] == df_boston
  end

  @testset "update" begin
    res = update(db, thing="price:9999", data=Dict("price"=>1000.0))
    @test res !== nothing
    delete(db, thing="price:9999")
  end

  @testset "insert" begin
    res = insert(db, thing="price", data=Dict("p2"=>100.0))
    @test res !== nothing
    println(res)
    delete(db, thing=res[1]["id"])
  end

  @testset "select" begin
    for i in 1:size(df_boston, 1)
      thing = "price:$(i)"
      res = select(db, thing=thing)
      @test res !== nothing
    end
  end

  @testset "parse_extension" begin
    res = query(db, sql=
    """--sql
    SELECT * FROM <datetime> "2022-06-07T12:24:21.314211Z";
    """
    )
    @test res == [NanoDate("2022-06-07T12:24:21.314211")]

    res = query(db, sql=
    """--sql
    SELECT * FROM <duration> "1h30m20s1350ms";
    """
    )
    @test res == [Hour(1)+Minute(30)+Second(20)+Millisecond(1350)]

    # println("df:", df)
    # @test df == df_boston
  end
  @testset "merge" begin
    res = merge(db, thing="price", data=Dict("in sale"=>true))
    @test res !== nothing
  end

  @testset "select" begin
    res = select(db, thing="price:1")
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
Surreal(URL, npool=15) do db
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

  @testset "async select" begin
    res = []
    @sync begin
      for i in 1:size(df_boston, 1)
        thing = "price:$(i)"
        push!(res, @spawn select(db, thing=thing))
      end
    end
    res = fetch.(res)
    for val in res
      @test res !== nothing
    end
    # println(res)
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
