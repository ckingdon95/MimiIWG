"""
    Returns the IWG version of the FUND3.8 model without any scenario parameters set yet. 
    Need to call apply_scenario!(m, scenario_choice) before this model can be run.
"""
function get_fund_model(scenario_choice::Union{scenario_choice, Nothing} = nothing)

    # Get the default FUND model
    m = getfund()

    # Replace the Impact Sea Level Rise component
    replace_comp!(m, IWG_FUND_impactsealevelrise, :impactsealevelrise)

    # Add Roe Baker Climate Sensitivity parameter and make connection from Climate Dynamics component
    add_comp!(m, IWG_RoeBakerClimateSensitivity, :roebakerclimatesensitivity; before = :climatedynamics)
    connect_param!(m, :climatedynamics, :climatesensitivity, :roebakerclimatesensitivity, :climatesensitivity)

    # Add the scenario choice component and load all the scenario parameter values
    add_comp!(m, IWG_FUND_ScenarioChoice, :IWGScenarioChoice; before = :population)
    set_dimension!(m, :scenarios, length(scenarios))
    set_fund_all_scenario_params!(m)
        
    # Set the scenario number if a scenario_choice was provided
    if scenario_choice !== nothing 
        scenario_num = Int(scenario_choice)
        set_param!(m, :IWGScenarioChoice, :scenario_num, scenario_num)
    end

    return m
end 

"""
set_fund_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Boolean = true)
    m: a Mimi model with and IWGScenarioChoice component
    comp_name: the name of the IWGScenarioChoice component in the model, defaults to :IWGScenarioChoice
    connect: whether or not to connect the outgoing variables to the other components who depend on them as parameter values
"""
function set_fund_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Bool = true)
    params_dict = Dict{String, Array}([k=>[] for k in fund_scenario_specific_params])

    # add an array of each scenario's value to the dictionary
    for scenario in scenarios
        params = load_fund_scenario_params(scenario)
        for p in fund_scenario_specific_params
            push!(params_dict[p], params[p])
        end
    end

    # reshape each array of values into one array for each param, then set that value in the model
    for (k, v) in params_dict
        _size = size(v[1])
        param = zeros(_size..., 5)
        for i in 1:5
            param[[1:l for l in _size]..., i] = v[i]
        end
        set_param!(m, comp_name, Symbol("$(k)_all"), param)
    end

    if connect 
        # Two global emissions values were previously endogenous; now set them to external IWG scenario values
        connect_param!(m, :climatech4cycle => :globch4, comp_name => :globch4)
        connect_param!(m, :climaten2ocycle => :globn2o, comp_name => :globn2o)

        # Socioeconomics
        connect_all!(m, [:population, :socioeconomic, :emissions], comp_name => :pgrowth)
        connect_all!(m, [:socioeconomic, :emissions], comp_name => :ypcgrowth)
        connect_param!(m, :emissions => :aeei, comp_name => :aeei)
        connect_param!(m, :emissions => :acei, comp_name => :acei)

    end
end

"""
    Returns a dictionary of FUND parameter values for the specified scenario.
"""
function load_fund_scenario_params(scenario_choice)

    scenario_file = joinpath(iwg_fund_datadir, "Parameter - EMF22 $(fund_scenario_convert[scenario_choice]).xlsm")

    scenario_params = Dict{Any, Any}()
    f = openxl(scenario_file)
    for p in ["ypcgrowth", "pgrowth", "AEEI", "ACEI", "ch4", "n2o"] 
        scenario_params[lowercase(p)] = readxl(f, "$(p)!B2:Q1052")
    end
    scenario_params["globch4"] = sum(Array{Float64,2}(scenario_params["ch4"]), dims = 2)[:] # sum horizontally for global emissions
    scenario_params["globn2o"] = sum(Array{Float64,2}(scenario_params["n2o"]), dims = 2)[:]

    return scenario_params
end

# Function from original MimiFUND code, modified for IWG CH4 and N2O
function add_fund_marginal_emissions!(m, emissionyear = nothing; gas = :CO2, yearstorun = 1050)

    # Add additional emissions to m
    add_comp!(m, Mimi.adder, :marginalemission, before = :climateco2cycle, first = 1951)
    addem = zeros(yearstorun)
    if emissionyear != nothing 
        addem[MimiFUND.getindexfromyear(emissionyear)-1:MimiFUND.getindexfromyear(emissionyear) + 8] .= 1.0
    end
    set_param!(m, :marginalemission, :add, addem)

    # Reconnect the appropriate emissions in m
    if gas == :CO2
        connect_param!(m, :marginalemission, :input, :emissions, :mco2)
        connect_param!(m, :climateco2cycle, :mco2, :marginalemission, :output, repeat([missing], yearstorun + 1))
    elseif gas == :CH4
        connect_param!(m, :marginalemission, :input, :IWGScenarioChoice, :globch4)
        connect_param!(m, :climatech4cycle, :globch4, :marginalemission, :output, repeat([missing], yearstorun + 1))
    elseif gas == :N2O
        connect_param!(m, :marginalemission, :input, :IWGScenarioChoice, :globn2o)
        connect_param!(m, :climaten2ocycle, :globn2o, :marginalemission, :output, repeat([missing], yearstorun + 1))
    elseif gas == :SF6
        connect_param!(m, :marginalemission, :input, :emissions, :globsf6)
        connect_param!(m, :climatesf6cycle, :globsf6, :marginalemission, :output, repeat([missing], yearstorun + 1))
    else
        error("Unknown gas: $gas")
    end
end

"""
    Returns marginal damages each year from an additional emissions pulse of the specified `gas` in the specified `year`. 
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is sepcified, will run for an emissions pulse of CO2.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    If no `discount` is specified, will return undiscounted marginal damages.
    The `income_normalized` parameter indicates whether the damages from the marginal run should be scaled by the ratio of incomes between the base and marginal runs. 
"""
function get_fund_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; regional::Bool = false, income_normalized::Bool=true, return_m::Bool=false)

    # Check the emissions year
    if ! (year in fund_years)
        error("$year not a valid year; must be in model's time index $fund_years.")
    end

    base = get_fund_model(scenario_choice)
    marginal = Model(base)
    add_fund_marginal_emissions!(marginal, year, gas = gas)

    run(base)
    run(marginal)

    damages1 = base[:impactaggregation, :loss]
    if income_normalized
        damages2 = marginal[:impactaggregation, :loss] ./ marginal[:socioeconomic, :income] .* base[:socioeconomic, :income]
    else
        damages2 = marginal[:impactaggregation, :loss]
    end

    if regional
        diff = (damages2 .- damages1) * _fund_normalization_factor(gas) * fund_inflator
    else
        diff = sum((damages2 .- damages1), dims = 2) * _fund_normalization_factor(gas) * fund_inflator   
    end

    nyears = length(fund_years)
    if discount != 0 
        DF = zeros(nyears)
        first = MimiFUND.getindexfromyear(year)
        DF[first:end] = [1/(1+discount)^t for t in 0:(nyears-first)]
        md = diff[1:nyears, :] .* DF
    else
        md = diff[1:nyears, :]
    end

    if return_m
        return (md, base)
    else
        return md
    end
end

"""
    Returns the Social Cost of `gas` for a given `year` and `discount` rate from one deterministic run of the IWG-FUND model.
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is specified, will retrun the SC-CO2.
    If no `year` is specified, will return SC for $_default_year.
    If no `discount` is specified, will return SC for a discount rate of $(_default_discount * 100)%.
"""
function compute_fund_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, prtp::Float64, eta::Float64=0.; domestic::Bool = false, income_normalized::Bool = true)

    # Check the emissions year
    if !(year in fund_years)
        error("$year is not a valid year; can only calculate SCC within the model's time index $fund_years.")
    end

    if domestic
        all_md, m = get_fund_marginaldamages(scenario_choice, gas, year, 0., income_normalized = income_normalized, regional = true, return_m = true)
        md = all_md[:, 1]
    else
        md, m = get_fund_marginaldamages(scenario_choice, gas, year, 0., income_normalized = income_normalized, regional = false, return_m = true)
    end

    p_idx = MimiFUND.getindexfromyear(year)
    nyears = length(fund_years)

    global_cpc = m[:socioeconomic, :globalconsumption] ./ sum(m[:socioeconomic, :population], dims=2)    #per capita global consumption
    g = [global_cpc[t]/global_cpc[t-1] - 1 for t in p_idx:nyears]

    return scc_discrete(md[p_idx:end], prtp, eta, g) 
end