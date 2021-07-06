"""
    Returns the IWG version of the DICE 2010 model for the specified scenario.
"""
function get_dice_model(scenario_choice::Union{scenario_choice,Nothing}=nothing)

    # Get the original default version of DICE2010
    m = MimiDICE2010.construct_dice()

    # Shorten the time index
    set_dimension!(m, :time, dice_years)

    disconnect_param!(m, :radiativeforcing, :MAT_final) # need to disconnect this param (not used in IWG version) before replacing co2cycle
    
    # Replace the IWG modified components
    replace!(m, :co2cycle => IWG_DICE_co2cycle)
    replace!(m, :radiativeforcing => IWG_DICE_radiativeforcing)
    replace!(m, :climatedynamics => IWG_DICE_climatedynamics)
    replace!(m, :neteconomy => IWG_DICE_neteconomy)

    # Delete the emissions component; emissions are now exogenous
    delete!(m, :emissions)

    # Update all IWG parameter values that are not scenario-specific
    iwg_params = load_dice_iwg_params()
    update_params!(m, iwg_params)

    # Add the scenario choice component and load all the scenario parameter values
    add_comp!(m, IWG_DICE_ScenarioChoice, :IWGScenarioChoice; before=:grosseconomy)
    set_dimension!(m, :scenarios, length(scenarios))
    set_dice_all_scenario_params!(m)
     
    # Set the scenario number if a scenario_choice was provided
    if scenario_choice !== nothing 
        scenario_num = Int(scenario_choice)
        set_param!(m, :IWGScenarioChoice, :scenario_num, scenario_num)
    end

    return m
end 

"""
set_dice_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Boolean = true)
    m: a Mimi model with and IWGScenarioChoice component
    comp_name: the name of the IWGScenarioChoice component in the model, defaults to :IWGScenarioChoice
    connect: whether or not to connect the outgoing variables to the other components who depend on them as parameter values
"""
function set_dice_all_scenario_params!(m::Model; comp_name::Symbol=:IWGScenarioChoice, connect::Bool=true)
    params_dict = Dict{Symbol,Array}([k => [] for k in dice_scenario_specific_params])

    # add an array of each scenario's value to the dictionary
    for scenario in scenarios
        params = load_dice_scenario_params(scenario)
        for p in dice_scenario_specific_params
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
        connect_all!(m, [:grosseconomy, :neteconomy], comp_name => :l)
        connect_param!(m, :co2cycle => :E, comp_name => :E)
        connect_param!(m, :radiativeforcing => :forcoth, comp_name => :forcoth)
        connect_param!(m, :grosseconomy => :al, comp_name => :al)
        connect_param!(m, :grosseconomy => :k0, comp_name => :k0)
    end

end

"""
    Returns a dictionary of the scenario-specific parameter values for the specified scenario.
"""
function load_dice_scenario_params(scenario_choice, scenario_file=nothing)

    # Input parameters from EPA's Matlab code
    A0    = 0.0303220  # First period total factor productivity, from DICE2010
    gamma = 0.3        # Labor factor productivity, from DICE2010
    delta = 0.1        # Capital depreciation rate [yr^-1], from DICE2010
    s     = 0.23       # Approximate optimal savings in DICE2010 
    
    params = Dict{Any,Any}()
    nyears = length(dice_years)

    # Get the scenario number
    idx = Int(scenario_choice)

    # All scenario data
    scenario_file = scenario_file === nothing ? iwg_dice_input_file : scenario_file
    f = openxl(scenario_file)

    Y = readxl(f, "GDP!B2:F32")[:, idx] * dice_inflate      # GDP
    N = readxl(f, "Population!B2:F32")[:, idx]              # Population
    E = readxl(f, "IndustrialCO2!B2:F32")[:, idx]           # Industrial CO2
    El = readxl(f, "LandCO2!B2:F32")[:, idx]                # Land CO2 
    Fex1 = readxl(f, "EMFnonCO2forcings!B2:F32")[:, idx]    # EMF non-CO2 forcings
    Fex2 = readxl(f, "OthernonCO2forcings!B2:B32")          # Other non-CO2 forcings
    Fex = Fex1 + Fex2                                       # All non-CO2 forcings

    # Use 2010 EMF value for dice period 2005-2015 etc. (need additional zeros to run past the 31st timestep)
    Y = [Y[2:end]; zeros(nyears - length(Y[2:end]))]
    N = [N[2:end]; zeros(nyears - length(N[2:end]))]
    E = [E[2:end]; zeros(nyears - length(E[2:end]))]
    El = [El[2:end]; zeros(nyears - length(El[2:end]))]
    Fex = [Fex[2:end]; zeros(nyears - length(Fex[2:end]))]

    # Set these scenario values in the parameter dictionary:
    params[:l] = N          # population
    params[:E] = El + E     # total CO2 emissions
    params[:forcoth] = Fex  # other forcings

    # Solve for implied path of exogenous technical change using the given GDP (Y data) 
    al = zeros(nyears)   
    K = zeros(nyears)
    al[1] = A0
    K[1] = (Y[1] / al[1] / (N[1]^(1 - gamma)))^(1 / gamma)
    for t in 2:nyears
        K[t] = K[t - 1] * (1 - delta)^10 + s * Y[t - 1] * 10
        al[t] = Y[t] / (N[t] + eps())^(1 - gamma) / (K[t] + eps())^gamma
    end

    # Update these parameters for grosseconomy component
    params[:al] = al    # total factor productivity
    params[:k0] = K[1]  # initial capital stock

    return params
end

"""
    Returns a dicitonary of IWG parameters that are the same for all IWG scenarios. (Does not include scenario-specific parameters.)
"""
function load_dice_iwg_params()

    params = Dict{Any,Any}()
    nyears = length(dice_years)

    # Replace some parameter values to match EPA's matlab code
    params[:S]          = repeat([0.23], nyears)    # previously called 'savebase'. :S in neteconomy
    params[:MIU]        = zeros(nyears)             # previously called 'miubase'-- :MIU in neteconomy;  make this all zeros so abatement in neteconomy is calculated as zero; EPA doesn't include abatement costs
    params[:a1]         = 0.00008162
    params[:a2]         = 0.00204626
    params[:b1]         = 0.00518162                # previously called 'slrcoeff'-- :b1 in SLR
    params[:b2]         = 0.00305776                # previously called 'slrcoeffsq'-- :b2 in SLR
    params[:t2xco2]     = 3.0

    return params
end

function get_dice_marginal_model(scen::scenario_choice; gas::Symbol, year::Int)
    base = get_dice_model(scen)
    mm = create_marginal_model(base)
    add_dice_marginal_emissions!(mm.modified, gas, year)
    return mm
end

"""
    Returns marginal damages each year from an additional ton of the specified `gas` in the specified year. 
 """
function get_dice_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64) 

    # Check the emissions year
    _is_mid_year = false
    if year < dice_years[1] || year > dice_years[end]
        error("$year is not a valid year; can only calculate marginal damages within the model's time index $dice_years.")
    elseif ! (year in dice_years)
        _is_mid_year = true         # boolean flag for if the desired year is in between values of the model's time index
        mid_year = year     # save the desired year to interpolate later
        year = dice_years[Int(floor((year - dice_years[1]) / dice_ts) + 1)]    # first calculate for the DICE year below the specified year
    end

    mm = get_dice_marginal_model(scenario_choice, gas=gas, year=year)
    run(mm)
    diff = -1. * mm[:neteconomy, :C] * _dice_normalization_factor(gas)

    if _is_mid_year     # need to calculate md for next year in time index as well, then interpolate for desired year
        lower_diff = diff
        next_year = dice_years[findfirst(isequal(year), dice_years) + 1]
        upper_diff = get_dice_marginaldamages(scenario_choice, gas, next_year, 0.)
        diff = [_interpolate([lower_diff[i], upper_diff[i]], [year, next_year], [mid_year])[1] for i in 1:length(lower_diff)]
    end 

    if discount != 0 
        nyears = length(dice_years)
        DF = zeros(nyears)
        first = findfirst(isequal(year), dice_years)
        DF[first:end] = [1 / (1 + discount)^t for t in 0:(nyears - first)]
        return diff .* DF
    else
        return diff
    end

end

"""
    Adds a marginal emissions component to a DICE model for the specified `gas`.
    If a year is specified, 1 GtC is added to emissions in that year.
"""
function add_dice_marginal_emissions!(m::Model, gas::Symbol, year=nothing)

    if gas == :CO2
        add_comp!(m, Mimi.adder, :co2_pulse, before=:co2cycle)
        time = Mimi.dimension(m, :time)
        addem = zeros(length(time))

        if year != nothing 
            year_idx = findfirst(isequal(year), dice_years)
            if year_idx === nothing 
                error("year $year provided to add_dice_marginal_emissions! not in dice time dimension")
            end 
            addem[year_idx] = 1.0
        end 

        set_param!(m, :co2_pulse, :add, addem)
        connect_param!(m, :co2_pulse => :input, :IWGScenarioChoice => :E)    # connect to the model parameter (exogenous emissions)
        connect_param!(m, :co2cycle => :E, :co2_pulse => :output)

    elseif gas in [:CH4, :N2O]

        if year === nothing
            f_delta = zeros(length(dice_years))
        else
            scenario_num = Mimi.model_param(m, :scenario_num).value
            f_delta = [_get_dice_additional_forcing(scenario_num, gas, year)..., zeros(11)...]
        end
    
        add_comp!(m, Mimi.adder, :additional_forcing, before=:radiativeforcing)
        connect_param!(m, :additional_forcing => :input, :IWGScenarioChoice => :forcoth)
        set_param!(m, :additional_forcing, :add, f_delta)
        connect_param!(m, :radiativeforcing => :forcoth, :additional_forcing => :output)

    else
        error("Unknown gas :$gas")
    end
    nothing
end 

"""
    Perturbs the marginal emissions in the given index year for a DICE model.
    Marginal emissions component must already exist in the model.
"""
function perturb_dice_marginal_emissions!(marginal::Model, gas::Symbol, year::Int)

    if gas == :CO2
        year_idx = findfirst(isequal(year), dice_years)
        ci = Mimi.compinstance(marginal, :co2_pulse)
        pulse = Mimi.get_param_value(ci, :add)
        pulse.data[:] .= 0.0    # pulse is a timestep array, need to access the data array to reset to zero because pulse[:] .= 0 doesn't work even though it doesn't error
        pulse.data[year_idx] = 1.0

    elseif gas in [:CH4, :N2O]
        ci = Mimi.compinstance(marginal, :additional_forcing)
        pulse = Mimi.get_param_value(ci, :add)
        scenario_num = marginal[:IWGScenarioChoice, :scenario_num]
        pulse.data[:] = [_get_dice_additional_forcing(scenario_num, gas, year)..., zeros(11)...]

    else
        error("Unknown gas :$gas.")
    end
    nothing
end

"""
    Returns the Social Cost of the specified `gas` for a given `year` and `discount` rate 
    from one deterministic run of the IWG-DICE model for the specified scenario.
"""
function compute_dice_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; domestic::Bool=false, horizon::Int=_default_horizon)

    # Check if the emissions year is valid, and whether or not we need to interpolate
    _is_mid_year = false
    if year < dice_years[1] || year > dice_years[end]
        error("$year is not a valid year; can only calculate SCC within the model's time index $years.")
    elseif ! (year in dice_years)
        _is_mid_year = true         # boolean flag for if the desired SCC years is in between values of the model's time index
        mid_year = year     # save the desired SCC year to interpolate later
        year = dice_years[Int(floor((year - dice_years[1]) / dice_ts) + 1)]    # first calculate for the DICE year below the specified year
    end

    md = get_dice_marginaldamages(scenario_choice, gas, year, 0.)   # Get undiscounted marginal damages
    annual_years = dice_years[1]:horizon
    annual_md = _interpolate(md, dice_years, annual_years)   # Interpolate to annual timesteps

    DF = zeros(length(annual_years)) 
    first = findfirst(isequal(year), annual_years)
    DF[first:end] = [1 / (1 + discount)^t for t in 0:(length(annual_years) - first)]

    scc = sum(annual_md .* DF)

    if _is_mid_year     # need to calculate SCC for next year in time index as well, then interpolate for desired year
        lower_scc = scc
        next_year = dice_years[findfirst(isequal(year), dice_years) + 1]
        upper_scc = compute_dice_scc(scenario_choice, gas, next_year, discount, domestic=false, horizon=horizon)
        scc = _interpolate([lower_scc, upper_scc], [year, next_year], [mid_year])[1]
    end 

    if domestic
        @warn("DICE is a global model. Domestic SCC will be calculated as 10% of the global SCC value.")
        return 0.1 * scc
    else
        return scc 
    end
end