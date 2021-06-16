
other_GHG_input_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/CH4N20emissions_annualversion.xls")
f = openxl(other_GHG_input_file)

dice_annual_years = Vector{Int}(readxl(f, "CH4annual!A2:A301")[:])
decades = dice_annual_years[1]:10:dice_annual_years[end] - 9
E_CH4A_all = readxl(f, "CH4annual!B2:F301")
E_N2OA_all = readxl(f, "N20annual!B2:F301")

function _get_marginal_gas_model(scenario_num::Int, gas::Symbol, year::Int)

    gas in [:CH4, :N2O] || error("Unknown gas :$gas. Available gases are :CH4 and :N2O.")

    year in dice_annual_years || error("Invalid year $year. Must be within $(dice_annual_years[1])-$(dice_annual_years[end]).")
    year_index = findfirst(isequal(year), dice_annual_years)

    m = Model()
    set_dimension!(m, :time, dice_annual_years)
    set_dimension!(m, :decades, decades)
    add_comp!(m, IWG_DICE_simple_gas_cycle, :gas)
    set_param!(m, :gas, :E_CH4A, E_CH4A_all[:, scenario_num])
    set_param!(m, :gas, :E_N2OA, E_N2OA_all[:, scenario_num])

    mm = create_marginal_model(m)

    m2 = mm.modified
    if gas == :CH4
        pulse_E = E_CH4A_all[:, scenario_num]
        pulse_E[year_index] = pulse_E[year_index] + 1.
        update_param!(m2, :E_CH4A, pulse_E)
    else
        pulse_E = E_N2OA_all[:, scenario_num]
        pulse_E[year_index] = pulse_E[year_index] + 1.
        update_param!(m2, :E_N2OA, pulse_E)
    end

    return mm
end

function _get_dice_additional_forcing(scenario_num::Int, gas::Symbol, year::Int)

    mm = _get_marginal_gas_model(scenario_num, gas, year)
    run(mm)

    if gas == :CH4
        return mm[:gas, :F_CH4]
    else
        return mm[:gas, :F_N2O]
    end
end
