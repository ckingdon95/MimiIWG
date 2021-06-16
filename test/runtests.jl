using Test

@testset "MimiIWG" begin

    using MimiIWG

    include("test_DICE.jl")
    include("test_FUND.jl")
    include("test_PAGE.jl")

end