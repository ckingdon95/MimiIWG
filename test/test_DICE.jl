using ExcelReaders
using MimiIWG
using Test
using XLSX: readxlsx

@testset "DICE" begin

    @testset "API" begin

        m = MimiIWG.get_model(DICE, MimiIWG.scenarios[1])
        run(m)

        md = MimiIWG.get_marginaldamages(DICE, MimiIWG.scenarios[1])

        scc1 = MimiIWG.compute_scc(DICE, MimiIWG.scenarios[1])
        scc2 = MimiIWG.compute_scc(DICE, MimiIWG.scenarios[1], domestic = true)
        @test scc2 == 0.1 * scc1

        tmp_dir = joinpath(@__DIR__, "tmp")
        MimiIWG.run_scc_mcs(DICE, trials=2, output_dir = tmp_dir, domestic = true)
        rm(tmp_dir, recursive=true)

        # make sure old and new discounting keyword args work
        scc_old = MimiIWG.compute_scc(DICE, USG1; gas=:CO2, year=2020, discount=0.025)
        scc_new = MimiIWG.compute_scc(DICE, USG1; gas=:CO2, year=2020, prtp=0.025)
        @test scc_old ≈ scc_new atol = 1e-12
    
    end

    @testset "Deterministic SC-CO2 validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_2018_12_18_12_56_deterministic.xlsx")
        xf = readxlsx(validation_file)

        _atol = 1e-8

        for scenario in MimiIWG.scenarios
            @info("Testing DICE SC-CO2 $(MimiIWG.dice_scenario_convert[scenario])...")
            @testset "$(string(scenario))" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = xf["$(MimiIWG.dice_scenario_convert[scenario])_$(discount)_2010-2050"]["A2:I2"]
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = MimiIWG.compute_scc(DICE, scenario; gas=:CO2, year=year, prtp=discount)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end

    end 

    
    @testset "Deterministic SC-CH4 validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_SCCH4_MC1.xlsx")
        xf = readxlsx(validation_file)

        _atol = 1e-5

        for scenario in MimiIWG.scenarios
            @info("Testing DICE SC-CH4 $(MimiIWG.dice_scenario_convert[scenario])...")
            @testset "$(string(scenario))" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = xf["$(MimiIWG.dice_scenario_convert[scenario])_$(discount)_2010-2050"]["A2:I2"]
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = MimiIWG.compute_scc(DICE, scenario; gas=:CH4, year=year, prtp=discount)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end
    end 

    @testset "Deterministic SC-N2O validation" begin 

        validation_file = joinpath(@__DIR__, "../data/validation/DICE/SCC_DICE2010_EPA_SCN2O_MC1.xlsx")
        xf = readxlsx(validation_file)

        _atol = 1e-5

        for scenario in MimiIWG.scenarios
            @info("Testing DICE SC-N2O $(MimiIWG.dice_scenario_convert[scenario])...")
            @testset "$(string(scenario))" begin 
                for discount in [0.025, 0.03, 0.05]
                    validation_data = xf["$(MimiIWG.dice_scenario_convert[scenario])_$(discount)_2010-2050"]["A2:I2"]
                    for (i, year) in enumerate(2010:5:2050)
                        iwg_scc = validation_data[i]
                        mimi_scc = MimiIWG.compute_scc(DICE, scenario; gas=:N2O, year=year, prtp=discount)
                        @test iwg_scc ≈ mimi_scc atol = _atol
                    end
                end
            end
        end
    end

    @testset "Deterministic Ramsey SCC" begin 
        
        scc1 = MimiIWG.compute_scc(DICE, MimiIWG.USG1, prtp = 0.01, eta = 1., gas = :CO2, year = 2020)
        scc2 = MimiIWG.compute_scc(DICE, MimiIWG.USG1, prtp = 0.01, eta = 1.5, gas = :CO2, year = 2020)

        scc3 = MimiIWG.compute_scc(DICE, MimiIWG.USG1, prtp = 0.03, eta = 1., gas = :CO2, year = 2020)
        scc4 = MimiIWG.compute_scc(DICE, MimiIWG.USG1, prtp = 0.03, eta = 1.5, gas = :CO2, year = 2020)

        @test scc1 > scc2 > scc3 > scc4

    end
end 
