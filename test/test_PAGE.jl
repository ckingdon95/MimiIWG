using MimiIWG
using DelimitedFiles

@testset "PAGE" begin

    @testset "API" begin

        m = MimiIWG.get_model(PAGE, MimiIWG.scenarios[1])
        run(m)

        md1 = MimiIWG.get_marginaldamages(PAGE, MimiIWG.scenarios[1])
        md2 = MimiIWG.get_marginaldamages(PAGE, MimiIWG.scenarios[1], regional=true)

        scc1 = MimiIWG.compute_scc(PAGE, MimiIWG.scenarios[1])
        scc2 = MimiIWG.compute_scc(PAGE, MimiIWG.scenarios[1], domestic=true)
        @test scc2 < scc1

        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(PAGE, trials=2, output_dir=tmp_dir, domestic=true)
        rm(tmp_dir, recursive=true)

    # test the drop discontinuities flag set to `true`
        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(PAGE, trials=2, output_dir=tmp_dir, domestic=true, drop_discontinuities=true)
        rm(tmp_dir, recursive=true)

    end

@testset "Deterministic SCC validation" begin 

    validation_dir = joinpath(@__DIR__, "../data/validation/PAGE/deterministic")
    files = readdir(validation_dir)

    _atol = 0.01    # one cent

    scenario_convert_flip = Dict([v => k for (k, v) in MimiIWG.page_scenario_convert]) # need to convert scenario names in the other direction from the validation data files

    for f in files
        validation_data = readdlm(joinpath(validation_dir, f), ',')
        scenario = String(split(f, ".")[1])

        @testset "$scenario" begin

            for line in 1:size(validation_data, 1)
                year        = Int(validation_data[line, 1])
                discount    = validation_data[line, 2]
                iwg_scc     = validation_data[line, 3] * MimiIWG.page_inflator     # 2000$ => $2007

                mimi_scc = MimiIWG.compute_scc(PAGE, scenario_convert_flip[scenario], year=year, discount=discount)
                # println(iwg_scc, ",", mimi_scc)
                @test iwg_scc ≈ mimi_scc atol = _atol
            end
        end
    end 

end 

end