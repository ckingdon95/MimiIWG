"""
    Returns the IWG version of the FUND3.8 model without any scenario parameters set yet. 
    Need to call apply_scenario!(m, scenario_choice) before this model can be run.
"""
function get_fund_model(scenario_choice::Union{scenario_choice, Nothing} = nothing)

    # Get the default FUND model
    m = getfund()

    # Replace the Impact Sea Level Rise component
    replace!(m, :impactsealevelrise => IWG_FUND_impactsealevelrise)

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

    # reshape each array of values into one array for each param, then set that value in the model
    for (k, v) in _fund_scenario_params_dict
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

# Function from original MimiFUND code, modified for IWG CH4 and N2O and removing
# :SF6 for now as we validate that gas
function add_fund_marginal_emissions!(m, year = nothing; gas = :CO2, pulse_size = 1e7)

    # Add additional emissions to m
    add_comp!(m, MimiFUND.emissionspulse, before = :climateco2cycle)
    nyears = length(Mimi.time_labels(m))
    addem = zeros(nyears) 
    if year !== nothing 
        # pulse is spread over ten years, and emissions components is in Mt so divide by 1e7, and convert from CO2 to C if gas==:CO2 because emissions component is in MtC
        addem[MimiFUND.getindexfromyear(year):MimiFUND.getindexfromyear(year) + 9] .= pulse_size / 1e7 * MimiFUND._gas_normalization(gas)
    end
    set_param!(m, :emissionspulse, :add, addem)

    # Reconnect the appropriate emissions in m
    if gas == :CO2
        connect_param!(m, :emissionspulse, :input, :emissions, :mco2)
        connect_param!(m, :climateco2cycle, :mco2, :emissionspulse, :output)
    elseif gas == :CH4
        connect_param!(m, :emissionspulse, :input, :IWGScenarioChoice, :globch4)
        connect_param!(m, :climatech4cycle, :globch4, :emissionspulse, :output)
    elseif gas == :N2O
        connect_param!(m, :emissionspulse, :input, :IWGScenarioChoice, :globn2o)
        connect_param!(m, :climaten2ocycle, :globn2o, :emissionspulse, :output)
    else
        error("Unknown gas: $gas")
    end
end

"""
    Returns marginal damages each year from an additional emissions pulse of the specified `gas` in the specified `year`. 
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is sepcified, will run for an emissions pulse of CO2.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    The `income_normalized` parameter indicates whether the damages from the marginal run should be scaled by the ratio of incomes between the base and marginal runs. 
"""
function get_fund_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; regional::Bool = false, income_normalized::Bool=true, return_m::Bool = false)

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
        diff = (damages2 .- damages1) * 1e-7 * fund_inflator
    else
        diff = sum((damages2 .- damages1), dims = 2) * 1e-7 * fund_inflator   
    end

    nyears = length(fund_years)
    if discount != 0 
        DF = zeros(nyears)
        first = MimiFUND.getindexfromyear(year)
        DF[first:end] = [1/(1+prtp)^t for t in 0:(nyears-first)]
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
    Returns the Social Cost of `gas` for a given `year` and discount rate determined
    by `eta` and `prtp` from one deterministic run of the IWG-FUND model.
    User must specify an IWG scenario `scenario_choice`.
    If no `gas` is specified, will retrun the SC-CO2.
    If no `year` is specified, will return SC for $_default_year.
    If no `prtp` is specified, will return SC for a prtp of $(_default_discount * 100)%.
"""
function compute_fund_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, prtp::Float64; eta::Float64 = 0., domestic::Bool = false, income_normalized::Bool = true)

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