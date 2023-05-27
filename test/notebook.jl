
@testset "notebook" begin
    # Surreal
    db = Surreal(URL)
    @test db.client_state == SurrealdbWS.ConnectionState(0)

    #connect
    connect(db)
    @test db.client_state == SurrealdbWS.ConnectionState(1)

    # signin
    res = signin(db, user="root", pass="root")
    @test res===nothing
    @show("sign in ", res)

    #info
    # @test info(db)===nothing
    #ping
    # @test ping(db)===nothing
    #close
    close(db)
    @test db.client_state ==  SurrealdbWS.ConnectionState(2)
end