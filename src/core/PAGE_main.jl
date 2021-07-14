"""
Returns the IWG version of the PAGE 2009 model for the specified scenario.
"""
function get_page_model(scenario_choice::Union{scenario_choice, Nothing}=nothing)

    # Get original version of PAGE
    m = MimiPAGE2009.get_model()

    # Nowe we need to reset the time dimension from the default PAGE2009 years 
    # to the IWG PAGE years, or  
    #
    # FROM: [2009, 2010, 2020, 2030, 2040, 2050, 2075, 2100, 2150, 2200]
    # TO: [2010, 2020, 2030, 2040, 2050, 2060, 2080, 2100, 2200, 2300]
    #
    # however this reset is illeagl in current resetting time dimension protocol
    # because it moves the start year forward.  The following is a backdoor way 
    # to make this change but is unsafe in the way it handles parameter time labels
    # so it SHOULD NOT be replicated or altered. In the future we should return 
    # and change page_years to start in 2009 with a missing value and then 
    # continue to 2300. [Lisa Rennels May 4 2021]
    
    dim = Mimi.Dimension(page_years)
    Mimi._propagate_time_dim!(m.md, dim)
    Mimi._propagate_first_last!(m.md; first = page_years[1], last = page_years[end])

    # Replace modified components
    replace!(m, :GDP => IWG_PAGE_GDP)
    replace!(m, :ClimateTemperature => IWG_PAGE_ClimateTemperature)

    # Load all of the IWG parameters from excel that aren't scenario specific
    set_param!(m, :ClimateTemperature, :sens_climatesensitivity, _page_iwg_params["sens_climatesensitivity"])

    # Update y_year_0 and y_year parameters used by components
    update_param!(m, :y_year_0, 2000)
    update_param!(m, :y_year, page_years)

    # Update all parameter values (and their timesteps) from the iwg parameters
    for (k, v) in _page_iwg_params
        if Symbol(k) in keys(Mimi.model_params(m))
            if size(v) == (10, 8) || size(v) == (10,)
                update_param!(m, Symbol(k), v)
            else
                update_param!(m, Symbol(k), v)
            end
        else
            set_param!(m, Symbol(k), v)
        end
    end

    # Add the scenario choice component and load all the scenario parameter values
    add_comp!(m, IWG_PAGE_ScenarioChoice, :IWGScenarioChoice; before = :co2emissions)
    set_dimension!(m, :scenarios, length(scenarios))
    set_page_all_scenario_params!(m)
    
    # Set the scenario number if a scenario_choice was provided
    if scenario_choice !== nothing 
        scenario_num = Int(scenario_choice)
        set_param!(m, :IWGScenarioChoice, :scenario_num, scenario_num)
    end

    return m
end

"""
set_page_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Boolean = true)
    m: a Mimi model with and IWGScenarioChoice component
    comp_name: the name of the IWGScenarioChoice component in the model, defaults to :IWGScenarioChoice
    connect: whether or not to connect the outgoing variables to the other components who depend on them as parameter values
"""
function set_page_all_scenario_params!(m::Model; comp_name::Symbol = :IWGScenarioChoice, connect::Bool = true)

    # reshape each array of values into one array for each param, then set that value in the model
    for (k, v) in _page_scenario_params_dict
        _size = size(v[1])
        param = zeros(_size..., 5)
        for i in 1:5
            param[[1:l for l in _size]..., i] = v[i]
        end
        set_param!(m, comp_name, Symbol("$(k)_all"), param)
    end

    if connect 
        connect_param!(m, :GDP => :gdp_0, comp_name => :gdp_0)
        connect_all!(m, [:GDP, :EquityWeighting], comp_name => :grw_gdpgrowthrate)
        connect_all!(m, [:Discontinuity, :MarketDamages, :NonMarketDamages, :SLRDamages], comp_name => :GDP_per_cap_focus_0_FocusRegionEU)
        connect_all!(m, [:GDP, :Population], comp_name => :pop0_initpopulation)
        connect_all!(m, [:EquityWeighting, :Population], comp_name => :popgrw_populationgrowth)
        connect_all!(m, [:co2emissions => :e0_baselineCO2emissions, :AbatementCostsCO2 => :e0_baselineemissions, :AbatementCostParametersCO2 => :e0_baselineemissions], comp_name => :e0_baselineCO2emissions)
        connect_param!(m, :co2cycle => :e0_globalCO2emissions, comp_name => :e0_globalCO2emissions)
        connect_all!(m, [:co2emissions => :er_CO2emissionsgrowth, :AbatementCostsCO2 => :er_emissionsgrowth], comp_name => :er_CO2emissionsgrowth)
        connect_param!(m, :co2forcing => :f0_CO2baseforcing, comp_name => :f0_CO2baseforcing)
        connect_param!(m, :TotalForcing => :exf_excessforcing, comp_name => :exf_excessforcing)
    end
end


"""
    Returns a dicitonary of all of the necessary parameters that are the same for all IWG scenarios. (Does not include scenario-specific parameters.)
"""
function load_page_iwg_params()

    # Build a dictionary of values to return
    p = Dict{Any, Any}()

    # Specify the scenario parameter file path
    fn = joinpath(iwg_page_input_file)
    xf = readxlsx(fn)

    #------------------------
    # 1. BASE DATA sheet
    #------------------------

    # Socioeconomics
    p["lat_latitude"] = convert(Array{Float64}, xf["Base data"]["M24:M31"])[:, 1]
    # the rest of the Socioeconomics parameters are scenario-specific

    # Initial emissions (all but CO2)
    p["e0_baselineCH4emissions"] = convert(Array{Float64}, xf["Base data"]["G24:G31"])[:, 1]    # initial CH4 emissions
    p["AbatementCostsCH4_e0_baselineemissions"] = p["e0_baselineCH4emissions"]                      # same initial values, but different parameter name in the AbatementCosts component
    p["AbatementCostParametersCH4_e0_baselineemissions"] = p["e0_baselineCH4emissions"]             # same initial values, but different parameter name in the AbatementCostParameters component
    p["e_0globalCH4emissions"] = sum(p["e0_baselineCH4emissions"])                                  # sum to get global
    p["e0_baselineN2Oemissions"] = convert(Array{Float64}, xf["Base data"]["H24:H31"])[:, 1]    # initial N2O emissions
    p["AbatementCostsN2O_e0_baselineemissions"] = p["e0_baselineN2Oemissions"]                      # same initial values, but different parameter name in the AbatementCosts component
    p["AbatementCostParametersN2O_e0_baselineemissions"] = p["e0_baselineN2Oemissions"]             # same initial values, but different parameter name in the AbatementCostParameters component
    p["e_0globalN2Oemissions"] = sum(p["e0_baselineN2Oemissions"])                                  # sum to get global
    p["e0_baselineLGemissions"] = convert(Array{Float64}, xf["Base data"]["I24:I31"])[:, 1]     # initial Linear Gas emissions
    p["AbatementCostsLin_e0_baselineemissions"] = p["e0_baselineLGemissions"]                       # same initial values, but different parameter name in the AbatementCosts component
    p["AbatementCostParametersLin_e0_baselineemissions"] = p["e0_baselineLGemissions"]              # same initial values, but different parameter name in the AbatementCostParameters component
    p["e_0globalLGemissions"] = sum(p["e0_baselineLGemissions"])                                    # sum to get global
    p["se0_sulphateemissionsbase"] = convert(Array{Float64}, xf["Base data"]["J24:J31"])[:, 1]  # initial Sulphate emissions
    p["nf_naturalsfx"] = convert(Array{Float64}, xf["Base data"]["K24:K31"])[:, 1]              # natural Sulphate emissions

    p["rtl_0_realizedtemperature"] = convert(Array{Float64}, xf["Base data"]["L24:L31"])[:, 1]  # RTL0

    # Forcing slopes and bases (excludes CO2 base forcing)
    p["fslope_CO2forcingslope"] = xf["Base data"]["B14:B14"][1]     # CO2 forcing slope
    p["fslope_CH4forcingslope"] = xf["Base data"]["C14:C14"][1]     # CH4 forcing slope
    p["fslope_N2Oforcingslope"] = xf["Base data"]["D14:D14"][1]     # CO2 forcing slope
    p["fslope_LGforcingslope"] = xf["Base data"]["E14:E14"][1]      # LG forcing slope
    p["f0_CH4baseforcing"] = xf["Base data"]["C21:C21"][1]          # CH4 base forcing
    p["f0_N2Obaseforcing"] = xf["Base data"]["D21:D21"][1]          # CO2 base forcing
    p["f0_LGforcingbase"] = xf["Base data"]["E21:E21"][1]           # LG base forcing

    # stimulation, air fractions, and halflifes
    p["stim_CH4emissionfeedback"] = xf["Base data"]["C15:C15"][1] 
    p["air_CH4fractioninatm"] = xf["Base data"]["C17:C17"][1] 
    p["res_CH4atmlifetime"] = xf["Base data"]["C18:C18"][1] 
    p["stim_N2Oemissionfeedback"] = xf["Base data"]["D15:D15"][1] 
    p["air_N2Ofractioninatm"] = xf["Base data"]["D17:D17"][1] 
    p["res_N2Oatmlifetime"] = xf["Base data"]["D18:D18"][1] 
    p["stim_LGemissionfeedback"] = xf["Base data"]["E15:E15"][1] 
    p["air_LGfractioninatm"] = xf["Base data"]["E17:E17"][1] 
    p["res_LGatmlifetime"] = xf["Base data"]["E18:E18"][1] 

    # concentrations
    p["stay_fractionCO2emissionsinatm"] = xf["Base data"]["B16:B16"][1] / 100 # percent of CO2 emissions that stay in the air
    p["c0_CO2concbaseyr"] = xf["Base data"]["B19:B19"][1]               # CO2 base year concentration
    p["c0_baseCO2conc"] = p["c0_CO2concbaseyr"]
    p["ce_0_basecumCO2emissions"] = xf["Base data"]["B20:B20"][1]       # CO2 cumulative emissions
    p["c0_CH4concbaseyr"] = xf["Base data"]["C19:C19"][1]                 # CH4 base year concentration
    p["c0_baseCH4conc"] = p["c0_CH4concbaseyr"]
    p["c0_N2Oconcbaseyr"] = xf["Base data"]["D19:D19"][1]                 # N2O base year concentration
    p["c0_baseN2Oconc"] = p["c0_N2Oconcbaseyr"]
    p["c0_LGconcbaseyr"] = xf["Base data"]["E19:E19"][1]                # LG base year concentration

    # BAU emissions
    p["AbatementCostParametersCO2_bau_businessasusualemissions"] = convert(Array{Float64}, xf["Base data"]["C68:L75"]')
    p["AbatementCostParametersCH4_bau_businessasusualemissions"] = convert(Array{Float64}, xf["Base data"]["C77:L84"]')
    p["AbatementCostParametersN2O_bau_businessasusualemissions"] = convert(Array{Float64}, xf["Base data"]["C86:L93"]')
    p["AbatementCostParametersLin_bau_businessasusualemissions"] = convert(Array{Float64}, xf["Base data"]["C95:L102"]')

    #elasticity of utility
    p["emuc_utilityconvexity"] = xf["Base data"]["B10:B10"][1]

    #pure rate of time preference
    p["ptp_timepreference"] = xf["Base data"]["B8:B8"][1]

    #------------------------
    # 2. LIBRARY DATA sheet
    #------------------------

    p["sens_climatesensitivity"] = xf["Library data"]["C18:C18"][1]  # Climate sensitivity
    
    # p["cutbacks_at_neg_cost_grw"] = xf["Library data"]["C123:C123"][1]    # cutbacks at negative cost growth rate (??)
    # p["max_cutbacks_grw"] = xf["Library data"]["C125:C125"][1]        # Maximum cutbacks growth rate
    # p["most_neg_grw"] = xf["Library data"]["C127:C127"][1]           # Most negative cost growth rate
    
    # p["automult_autonomoustechchange"] = xf["Library data"]["C134:C134"][1]        # Autonomous technical change
    # p["auto"] = xf["Library data"]["C134:C134"][1]        # Autonomous technical change

    p["d_sulphateforcingbase"] = xf["Library data"]["C11:C11"][1]
    p["ind_slopeSEforcing_indirect"] = xf["Library data"]["C12:C12"][1]

    p["q0propmult_cutbacksatnegativecostinfinalyear"] = xf["Library data"]["C122:C122"][1]
    p["qmax_minus_q0propmult_maxcutbacksatpositivecostinfinalyear"] = xf["Library data"]["C124:C124"][1]
    p["c0mult_mostnegativecostinfinalyear"] = xf["Library data"]["C126:C126"][1]

    p["civvalue_civilizationvalue"] = xf["Library data"]["C44:C44"][1]

    #------------------------
    # 3. POLICY A sheet
    #------------------------

    # Emissions growth (all but CO2)
    p["er_CH4emissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B14:K21"]')    # CH4 emissions growth
    p["er_N2Oemissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B23:K30"]')    # N2O emissions growth
    p["er_LGemissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B32:K39"]')    # Lin emissions growth
    p["AbatementCostsCH4_er_emissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B14:K21"]')    # CH4 emissions growth
    p["AbatementCostsN2O_er_emissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B23:K30"]')    # N2O emissions growth
    p["AbatementCostsLin_er_emissionsgrowth"] = convert(Array{Float64}, xf["Policy A"]["B32:K39"]')    # Lin emissions growth
    
    p["pse_sulphatevsbase"] = convert(Array{Float64}, xf["Policy A"]["B41:K48"]')

    return p
end

# Only load these parameters once, and `get_model` uses this dictionary
_page_iwg_params = load_page_iwg_params()

function getpageindexfromyear(year)
    i = findfirst(isequal(year), page_years)
    if i == 0
        error("Invalid PAGE year: $year.")
    end 
    return i 
end

function getpageindexlengthfromyear(year)
    if year == 2010
        return 10
    end

    if year == 2300
        return 50
    end 
    
    i = findfirst(isequal(year), page_years)
    if i == 0
        error("Invalid PAGE year: $year.")
    end 

    return page_years[i] - page_years[i-1]
end

function getperiodlength(year)
    if year==2010
        return 10
    end

    i = getpageindexfromyear(year)

    return (page_years[i+1] - page_years[i-1]) / 2
end

"""
    Returns marginal damages each year from an additional emissions pulse in the specified year. 
    User must specify an IWG scenario `scenario_choice`.
    If no `year` is specified, will run for an emissions pulse in $_default_year.
    Default returns global values; specify `regional=true` for regional values or
    `domestic = true` for US values.
"""
function get_page_marginaldamages(scenario_choice::scenario_choice, gas::Symbol, year::Int, discount::Float64; domestic::Bool = false, regional::Bool=false, return_m::Bool = false)

    # Check the emissions year
    if ! (year in page_years)
        error("$year not a valid year; must be in model's time index $page_years.")
    end

    if domestic && regional
        error("Only one of `domestic` and `regional` can be true at once time.")
    end

    base, marginal = get_marginal_page_models(scenario_choice=scenario_choice, gas=gas, year=year, discount=discount)

    if discount == 0
        base_impacts = base[:EquityWeighting, :wit_equityweightedimpact]
        marg_impacts = marginal[:EquityWeighting, :wit_equityweightedimpact]
    else
        base_impacts = base[:EquityWeighting, :widt_equityweightedimpact_discounted]
        marg_impacts = marginal[:EquityWeighting, :widt_equityweightedimpact_discounted]
    end

    pulse_size = gas == :CO2 ? 100_000 : 1
    marg_damages = (marg_impacts .- base_impacts) ./ pulse_size

    if regional
        md = marg_damages
    elseif domestic
        md = marg_damages[:, 2] # US is the second region
    else # global
        md = sum(marg_damages, dims = 2)[:] # sum along second dimension to get global values and convert to Vector 
    end

    if return_m
        return (md, base)
    else
        return md
    end
end

@defcomp PAGE_marginal_CO2_emissions begin 
    er_CO2emissionsgrowth = Variable(index=[time,region], unit = "%")
    marginal_emissions_growth = Parameter(index=[time,region], unit = "%", default = zeros(10,8))
    function run_timestep(p, v, d, t)
        if is_first(t)
            v.er_CO2emissionsgrowth[:, :] = p.marginal_emissions_growth[:, :]
        end
    end
end

function get_marginal_page_models(; scenario_choice::Union{scenario_choice, Nothing}=nothing, gas::Symbol=:CO2, year=nothing, discount=nothing)

    base = get_page_model(scenario_choice)
    
    # NOTES:
    # - eta (m[:EquityWeighting, :emuc_utilityconvexity]) is zero in all scenarios 
    # - prtp (:ptp_timepreference) defaults to 3%

    if discount != nothing
        update_param!(base, :ptp_timepreference, discount * 100)
    end

    marginal = Model(base)

    if gas == :CO2
        add_comp!(marginal, PAGE_marginal_CO2_emissions, :marginal_emissions; before = :co2emissions)
        connect_param!(marginal, :co2emissions => :er_CO2emissionsgrowth, :marginal_emissions => :er_CO2emissionsgrowth)
        connect_param!(marginal, :AbatementCostsCO2 => :er_emissionsgrowth, :marginal_emissions => :er_CO2emissionsgrowth)
    elseif gas in [:CH4, :N2O]
        add_comp!(marginal, Mimi.adder, :marginal_forcing; before = :TotalForcing)
        set_param!(marginal, :marginal_forcing, :add, zeros(10))
        connect_param!(marginal, :marginal_forcing => :input, :IWGScenarioChoice => :exf_excessforcing, ignoreunits=true)
        connect_param!(marginal, :TotalForcing => :exf_excessforcing, :marginal_forcing => :output, ignoreunits=true)
    else
        error("Unknown gas :$gas.")
    end

    if year != nothing
        run(base)
        Mimi.build!(marginal)
        perturb_marginal_page_emissions!(base, marginal, gas, year)
        run(marginal)
    end

    return base, marginal
end


# Called after base has already been run. 
# For gas=:CO2, marginal's emission growth modified relative to base's values.
# This modifies emissions growth parameter in marginal's model instance's model definition, so that the isntance isn't decached.
# For other gases, it uses exogenously defined additional forcing pathways.
function perturb_marginal_page_emissions!(base::Model, marginal::Model, gas::Symbol, emissionyear::Int)

    if gas == :CO2
        i = getpageindexfromyear(emissionyear) 

        # Base model
        base_glob0_emissions = base[:co2cycle, :e0_globalCO2emissions]
        er_co2_a = base[:co2emissions, :er_CO2emissionsgrowth][i, :]
        e_co2_g = base[:co2emissions, :e_globalCO2emissions]    

        # Calculate pulse 
        ER_SCC = 100 * -100000 / (base_glob0_emissions * getperiodlength(emissionyear))
        pulse = er_co2_a - ER_SCC * (er_co2_a/100) * (base_glob0_emissions / e_co2_g[i])
        marginal_emissions_growth = copy(base[:co2emissions, :er_CO2emissionsgrowth])
        marginal_emissions_growth[i, :] = pulse

        # Marginal emissions model
        md = marginal.mi.md 
        model_param_name = Mimi.get_model_param_name(md,  :marginal_emissions, :marginal_emissions_growth) # TEMPORARY until we can use the new update_param! method
        update_param!(md, model_param_name, marginal_emissions_growth)    # this updates the marginal_emissions_growth parameter that both :er_CO2emissionsgrowth and :AbatementCostsCO2_er_emissionsgrowth are connected to from the PAGE_marginal_emissions comp
    else
        scenario_num = base[:IWGScenarioChoice, :scenario_num]
        forcing_shock = _get_page_forcing_shock(scenario_num, gas, emissionyear)
        update_param!(marginal.mi.md, :add, forcing_shock) # :add is a shared parameter since it is called with set_param! above
    end

    return nothing
end  

"""
    Returns the Social Cost of the specified `gas` for a given `year` and `discount` rate from one deterministic run of the IWG-PAGE model.
    User must specify an IWG scenario `scenario_choice`.
    If no `year` is specified, will return SCC for $_default_year.
    If no `prtp` is specified, will return SC for a prtp of $(_default_discount * 100)%.
"""
function compute_page_scc(scenario_choice::scenario_choice, gas::Symbol, year::Int, prtp::Float64; eta::Float64 = 0., domestic=false)

    # Check the emissions year
    _need_to_interpolate = false
    if year < page_years[1] || year > page_years[end]
        error("$year is not a valid year; can only calculate SCC within the model's time index $page_years.")
    elseif ! (year in page_years)
        _need_to_interpolate = true         # boolean flag for if the desired SCC years is in the middle of the model's time index
        mid_year = year     # save the desired SCC year to interpolate later
        year = filter(x-> x < year, page_years)[end]    # use the last year less than the desired year as the lower scc value
    end

    scc = _compute_page_scc(scenario_choice, gas, year, prtp, eta, domestic=domestic)

    if _need_to_interpolate     # need to calculate SCC for next year in time index as well, then interpolate for desired year
        lower_scc = scc
        next_year = page_years[findfirst(page_years, year) + 1] 
        upper_scc = compute_page_scc(scenario_choice, gas, next_year, prtp, eta=eta, domestic=domestic)
        scc = _interpolate([lower_scc, upper_scc], [year, next_year], [mid_year])[1]
    end 

    return scc
end

# helper function for computing SCC from two run models 
function _compute_page_scc(scenario_choice, gas, year, prtp, eta; domestic=false)

    # Get undiscounted marginal damages
    md, base = MimiIWG.get_page_marginaldamages(scenario_choice, gas, year, 0., return_m = true, domestic = domestic)   

    p_idx = MimiIWG.getpageindexfromyear(year)
    idx_lengths = [MimiIWG.getpageindexlengthfromyear(y) for y in MimiIWG.page_years]
    idx_lengths = [10, diff(page_years)...]
    cpc = sum(base[:GDP, :cons_consumption], dims=2) ./ sum(base[:GDP, :pop_population], dims=2)
    cpc = cpc[:] # just get the Array no Matrix
    
    g1 = NaN
    g = [g1, [(cpc[i]/cpc[i-1]) ^ (1/idx_lengths[i]) - 1 for i in 2:length(MimiIWG.page_years)]...]
    r = prtp .+ eta .* g

    df = zeros(length(MimiIWG.page_years))
    df[p_idx] = 1
    df[p_idx+1:end] = [prod([(1 + r[i])^(-1 * idx_lengths[i]) for i in p_idx+1:t]) for t in p_idx+1:length(MimiIWG.page_years)]
    
    md_disc = md .* df
    md_agg = md_disc .* base[:GDP, :yagg_periodspan]
    scc = sum(md_agg) * MimiIWG.page_inflator

    return scc

end

# old way of computing the scc when we didn't use eta at all and assumed constant
# discount 
function _compute_page_scc_old(scenario_choice, gas, year, prtp; domestic=false)

    base, marginal = get_marginal_page_models(scenario_choice=scenario_choice, gas=gas, year=year, discount=prtp)

    DF = [(1 / (1 + prtp)) ^ (Y - 2000) for Y in page_years]
    p_idx = getpageindexfromyear(year)

    if domestic
        td_base = sum(base[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])  # US is the second region; then sum across time
        td_marginal = sum(marginal[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])
    else 
        td_base = base[:EquityWeighting, :td_totaldiscountedimpacts]
        td_marginal = marginal[:EquityWeighting, :td_totaldiscountedimpacts] 
    end

    EMUC = base[:EquityWeighting, :emuc_utilityconvexity]

    UDFT = DF[p_idx] * (base[:EquityWeighting, :cons_percap_consumption][p_idx, 1] / base[:EquityWeighting, :cons_percap_consumption_0][1]) .^ (-EMUC)

    pulse_size = gas == :CO2 ? 100_000 : 1
    scc = ((td_marginal / UDFT) - (td_base / UDFT)) / pulse_size * page_inflator

    return scc
end