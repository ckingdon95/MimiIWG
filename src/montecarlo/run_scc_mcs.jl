"""
    run_scc_mcs(model::model_choice; 
        gas::Union{Symbol, Nothing} = nothing,
        trials::Int = 10000,
        perturbation_years::Vector{Int} = _default_perturbation_years,
        discount_rates::Vector{Float64} = _default_discount_rates, 
        domestic::Bool = false,
        output_dir::String = nothing, 
        save_trials::Bool = false,
        tables::Bool = true)

Run the Monte Carlo simulation used by the IWG for calculating a distribution of SCC values for the 
Mimi model `model_choice` and the specified number of trials `trials`. The SCC is calculated for all 
5 socioeconomic scenarios, and for all specified `perturbation_years` and `discount_rates`. If `domestic` 
equals `true`, then SCC values will also be calculated using only domestic damages. 

`gas` may be one of :CO2, :CH4, or :N2O. If none is specified, it will default to :CO2.

`model_choice` must be one of the following enums: DICE, FUND, or PAGE.

Output files will be saved in the `output_dir`. If none is provided, it will default to "./output/". 
A new sub directory will be created each time this function is called, with the following name: "yyyy-mm-dd HH-MM-SS MODEL SC-\$gas MC\$trials".

If `tables` equals `true`, then a set of summary statistics tables will also be saved in the output folder.
If `save_trials` equals `true`, then a file with all of the sampled input trial data will also be saved in
the output folder.
"""
function run_scc_mcs(model::model_choice; 
    gas::Union{Symbol, Nothing} = nothing,
    trials::Int = 10000,
    perturbation_years::Vector{Int} = _default_perturbation_years,
    discount_rates::Union{Vector{Float64}, Nothing} = nothing,
    prtp::Union{Vector{Float64}, Nothing} = nothing, 
    eta::Union{Vector{Float64}, Nothing} = nothing, 
    domestic::Bool = false,
    output_dir::Union{String, Nothing} = nothing, 
    save_trials::Bool = false,
    tables::Bool = true)

    # Check the gas
    if gas === nothing
        @warn("No `gas` specified in `run_scc_mcs`; will return the SC-CO2.")
        gas = :CO2
    elseif ! (gas in [:CO2, :CH4, :N2O])
        error("Unknown gas :$gas. Available gases are :CO2, :CH4, and :N2O.")
    end

    if discount_rates != nothing 
        @warn("The keyword `discount_rates` is deprecated. Use the keyword `prtp` to provide constant discount rates.")
        prtp = discount_rates
    end
    if prtp === nothing 
        @warn("No `prtp` provided. Will run with the following rates: $_default_discount_rates.")
        prtp = _default_discount_rates
    end
    if eta === nothing
        @warn("No values provided for `eta`. Will run with eta=0.")
        eta = [0.]
    end

    # Set up output directory for trials and saved values
    root_dir = (output_dir === nothing ? "output/" : output_dir)
    output_dir = joinpath(root_dir, "$(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) $(string(model)) SC-$gas MC$trials")

    # Get specific simulation arguments for the provided model choice
    if model == DICE 
        mcs = get_dice_mcs()

        last_idx = _default_horizon - 2005 + 1
        # discount_factors = Dict([rate => [(1 + rate) ^ y for y in 0:last_idx-1] for rate in discount_rates]) # precompute discount factors
        nyears = length(dice_years) # Run the full length to 2405, but nothing past 2300 gets used for the SCC
        model_years = dice_years

        payload = Any[prtp, eta, model_years, _default_horizon]
        
        scenario_func = dice_scenario_func
        post_trial_func = dice_post_trial_func

        base = get_dice_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_dice_model(USG1)
        add_dice_marginal_emissions!(marginal, gas)  # adds the marginal emissions component, but with no year specified, no pulse is added yet
        models = [base, marginal]

        domestic ? @warn("DICE is a global model. Domestic SCC values will be calculated as 10% of the global values.") : nothing

    elseif model == FUND 

        mcs = get_fund_mcs()
        
        nyears = length(fund_years)
        model_years = fund_years

        payload = Any[prtp, eta, model_years]

        scenario_func = fund_scenario_func
        post_trial_func = fund_post_trial_func

        # Get base and marginal models
        base = get_fund_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_fund_model(USG1)
        add_fund_marginal_emissions!(marginal, gas=gas)   # adds the marginal emissions component, doesn't set the emission pulse till within MCS
        models = [base, marginal]

    elseif model == PAGE 

        mcs = get_page_mcs()

        # Precompute discount factors for each of the discount rates
        model_years = page_years
        nyears = length(page_years)

        payload = Any[prtp, eta]

        scenario_func = page_scenario_func
        post_trial_func = page_post_trial_func

        # Set the base and marginal models
        base, marginal = get_marginal_page_models(scenario_choice = USG1, gas = gas) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        models = [base, marginal]
    end

    # Check that the perturbation years are valid before running the simulation
    if minimum(perturbation_years) < minimum(model_years) || maximum(perturbation_years) > maximum(model_years)
        error("The specified perturbation years fall outside of the model's time index.")
    end

    # Check if any desired perturbation years need to be interpolated (aren't in the time index)
    _need_to_interpolate = ! all(y -> y in model_years, perturbation_years)
    if _need_to_interpolate
        all_years = copy(perturbation_years)    # preserve a copy of the original desired SCC years
        _first_idx = findlast(y -> y <= minimum(all_years), model_years)
        _last_idx = findfirst(y -> y >= maximum(all_years), model_years)
        perturbation_years = model_years[_first_idx : _last_idx]  # figure out which years of the model's time index we need to use to cover all desired perturbation years
    end

    # Make an array to hold all calculated scc values
    SCC_values = Array{Float64, 5}(undef, trials, length(perturbation_years), length(scenarios), length(prtp), length(eta))
    if domestic 
        SCC_values_domestic = Array{Float64, 5}(undef, trials, length(perturbation_years), length(scenarios), length(prtp), length(eta))
    else
        SCC_values_domestic = nothing 
    end

    # Set the payload object
    push!(payload, [gas, perturbation_years, SCC_values, SCC_values_domestic]...)
    Mimi.set_payload!(mcs, payload)

    # Generate trials 
    trials_filepath = save_trials ? joinpath(output_dir, "trials.csv") : nothing 

    # Run the simulation
    sim_results = run(mcs, models, trials;
        trials_output_filename = trials_filepath, 
        ntimesteps = nyears,    
        scenario_func = scenario_func, 
        scenario_args = [:scenario => scenarios],
        post_trial_func = post_trial_func,
        results_output_dir = joinpath(output_dir, "saved_variables")
    )
    SCC_values, SCC_values_domestic = Mimi.payload(sim_results)[end-1:end]

    # generic interpolation if user requested SCC values for years in between model_years
    if _need_to_interpolate
        new_SCC_values = Array{Float64, 5}(undef, trials, length(all_years), length(scenarios), length(prtp), length(eta))
        for i in 1:trials, j in 1:length(scenarios), k in 1:length(prtp), l in 1:length(eta)
            new_SCC_values[i, :, j, k, l] = _interpolate(SCC_values[i, :, j, k, l], perturbation_years, all_years)
        end
        SCC_values = new_SCC_values 

        if domestic 
            new_domestic_values = Array{Float64, 5}(undef, trials, length(all_years), length(scenarios), length(prtp), length(eta))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(prtp), l in 1:length(eta)
                new_domestic_values[i, :, j, k, l] = _interpolate(SCC_values_domestic[i, :, j, k, l], perturbation_years, all_years)
            end
            SCC_values_domestic = new_domestic_values
        end

        perturbation_years = all_years
    end
    
    # Save the SCC values
    scc_dir = joinpath(output_dir, "SC-$gas/")
    write_scc_values(SCC_values, scc_dir, perturbation_years, prtp, eta)
    if domestic 
        model == DICE ? SCC_values_domestic = SCC_values .* 0.1 : nothing   # domestic values for DICE calculated as 10% of global values
        write_scc_values(SCC_values_domestic, scc_dir, perturbation_years, prtp, eta, domestic=true)
    end

    # Build the stats tables
    if tables
        make_percentile_tables(output_dir, gas, prtp, eta, perturbation_years)
        make_stderror_tables(output_dir, gas, prtp, eta, perturbation_years)
        eta == [0.] ? make_summary_table(output_dir, gas, prtp, perturbation_years) : nothing
    end

    nothing
end