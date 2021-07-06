"""
    run_scc_mcs(model::model_choice; 
                gas::Union{Symbol, Nothing} = nothing,
                trials::Int = 10000,
                perturbation_years::Vector{Int} = _default_perturbation_years,
                discount_rates::Vector{Float64} = _default_discount_rates, 
                domestic::Bool = false,
                output_dir::Union{String, Nothing} = nothing, 
                save_trials::Bool = false,
                tables::Bool = true,
                drop_discontinuities::Bool = false,
                save_md::Bool = false)

Run the Monte Carlo simulation used by the IWG for calculating a distribution of SCC values for the 
Mimi model `model_choice` and the specified number of trials `trials`. The SCC is calculated for all 
5 socioeconomic scenarios, and for all specified `perturbation_years` and `discount_rates`. If `domestic` 
equals `true`, then SCC values will also be calculated using only domestic damages. 

`gas` may be one of :CO2, :CH4, or :N2O. If none is specified, it will default to :CO2.

`model_choice` must be one of the following enums: DICE, FUND, or PAGE.

Output files will be saved in the `output_dir`. If none is provided, it will default to "./output/". 
A new sub directory will be created each time this function is called, with the following name: "yyyy-mm-dd HH-MM-SS MODEL SC-\$gas MC\$trials".

Several keyword arguments allow for the following:
If `tables` equals `true`, then a set of summary statistics tables will also be saved in the output folder.

If `save_trials` equals `true`, then a file with all of the sampled input trial data will also be saved in the output folder. 

If `drop_discontinuities` equals `true`, then outliers from the PAGE model (runs where discontinuity damages are triggered
in different timesteps in the base and perturbed models) will not contribute to summary statistics. An additional folder
"discontinuity_mismatch" contains files identifying in which runs the discrepencies occured.

If `save_md` equals `true`, then global undiscounted marginal damages from each run of 
the simulation will be saved in a subdirectory "output/marginal_damages".
"""
function run_scc_mcs(model::model_choice; 
    gas::Union{Symbol,Nothing}=nothing,
    trials::Int=10000,
    perturbation_years::Vector{Int}=_default_perturbation_years,
    discount_rates::Vector{Float64}=_default_discount_rates, 
    domestic::Bool=false,
    output_dir::Union{String,Nothing}=nothing, 
    save_trials::Bool=false,
    tables::Bool=true,
    drop_discontinuities::Bool=false,
    save_md::Bool=false)

    # Check the gas
    if gas === nothing
        @warn("No `gas` specified in `run_scc_mcs`; will return the SC-CO2.")
        gas = :CO2
    elseif ! (gas in [:CO2, :CH4, :N2O])
        error("Unknown gas :$gas. Available gases are :CO2, :CH4, and :N2O.")
    end

    # Set up output directory for trials and saved values
    root_dir = (output_dir === nothing ? "output/" : output_dir)
    output_dir = joinpath(root_dir, "$(Dates.format(now(), "yyyy-mm-dd HH-MM-SS")) $(string(model)) SC-$gas MC$trials")

    # Get specific simulation arguments for the provided model choice
    if model == DICE 
        mcs = get_dice_mcs()
        scenario_args = [:scenario => scenarios, :rate => discount_rates]

        last_idx = _default_horizon - 2005 + 1
        discount_factors = Dict([rate => [(1 + rate)^y for y in 0:last_idx - 1] for rate in discount_rates]) # precompute discount factors
        nyears = length(dice_years) # Run the full length to 2405, but nothing past 2300 gets used for the SCC
        model_years = dice_years

        payload = Any[discount_rates, discount_factors, model_years, _default_horizon]
        
        scenario_func = dice_scenario_func
        post_trial_func = dice_post_trial_func

        base = get_dice_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_dice_model(USG1)
        add_dice_marginal_emissions!(marginal, gas)  # adds the marginal emissions component, but with no year specified, no pulse is added yet
        models = [base, marginal]

        domestic ? @warn("DICE is a global model. Domestic SCC values will be calculated as 10% of the global values.") : nothing

    elseif model == FUND 

        mcs = get_fund_mcs()
        scenario_args = [:scenarios => scenarios] 
        
        nyears = length(fund_years)
        model_years = fund_years

        payload = Any[discount_rates, model_years]

        scenario_func = fund_scenario_func
        post_trial_func = fund_post_trial_func

        # Get base and marginal models
        base = get_fund_model(USG1) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
        marginal = get_fund_model(USG1)
        add_fund_marginal_emissions!(marginal, gas=gas)   # adds the marginal emissions component, doesn't set the emission pulse till within MCS
        models = [base, marginal]

    elseif model == PAGE 

        mcs = get_page_mcs()
        scenario_args = [:scenarios => scenarios, :discount_rates => discount_rates]

        # Precompute discount factors for each of the discount rates
        discount_factors = [[(1 / (1 + r))^(Y - 2000) for Y in page_years] for r in discount_rates]
        model_years = page_years
        nyears = length(page_years)

        payload = Any[discount_rates, discount_factors]

        scenario_func = page_scenario_func
        post_trial_func = page_post_trial_func

        # Set the base and marginal models
        base, marginal = get_marginal_page_models(scenario_choice=USG1, gas=gas) # Need to set a scenario so the model can be built, but the scenarios will change in the simulation
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
        perturbation_years = model_years[_first_idx:_last_idx]  # figure out which years of the model's time index we need to use to cover all desired perturbation years
    end

    # For each run, this array will store whether there is a discrepency between the base and marginal models triggering the discontinuity damages in different timesteps
    if model == PAGE
        discontinuity_mismatch = Array{Bool,4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))
        push!(payload, discontinuity_mismatch)
    end

    # Make an array to hold all calculated scc values
    SCC_values = Array{Float64,4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))
    if domestic 
        SCC_values_domestic = Array{Float64,4}(undef, trials, length(perturbation_years), length(scenarios), length(discount_rates))
    else
        SCC_values_domestic = nothing 
    end

    # Make an array to hold undiscounted marginal damages, if specified
    if save_md
        if model == PAGE && discount_rates != [0.]
            error("Cannot save undiscounted marginal damages for PAGE unless `discount_rates = [0.]`")
        end
        md_values = Array{Float64,4}(undef, length(perturbation_years), length(scenarios), length(model_years), trials)
    else
        md_values = nothing
    end

    # Set the payload object
    push!(payload, [gas, perturbation_years, SCC_values, SCC_values_domestic, md_values]...)
    Mimi.set_payload!(mcs, payload)

    # Generate trials 
    trials_filepath = save_trials ? joinpath(output_dir, "trials.csv") : nothing 

    # Run the simulation
    sim_results = run(mcs, models, trials;
        trials_output_filename=trials_filepath, 
        ntimesteps=nyears,    
        scenario_func=scenario_func, 
        scenario_args=scenario_args,
        post_trial_func=post_trial_func
    )
    SCC_values, SCC_values_domestic, md_values = Mimi.payload(sim_results)[end - 2:end]

    # Save the marginal damage matrices
    if save_md
        md_dir = joinpath(output_dir, "marginal_damages/")
        mkpath(md_dir)
        for (i, year) in enumerate(perturbation_years)
            for (j, scen) in enumerate(scenarios)
                fn = joinpath(md_dir, "$scen $year.csv")
                writedlm(fn, hcat(model_years, md_values[i, j, :, :]), ',') # add model year labels as the first column in each file
            end
        end
    end

    # generic interpolation if user requested SCC values for years in between model_years
    if _need_to_interpolate
        new_SCC_values = Array{Float64,4}(undef, trials, length(all_years), length(scenarios), length(discount_rates))
        for i in 1:trials, j in 1:length(scenarios), k in 1:length(discount_rates)
            new_SCC_values[i, :, j, k] = _interpolate(SCC_values[i, :, j, k], perturbation_years, all_years)
        end
        SCC_values = new_SCC_values 

        if domestic 
            new_domestic_values = Array{Float64,4}(undef, trials, length(all_years), length(scenarios), length(discount_rates))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(discount_rates)
                new_domestic_values[i, :, j, k] = _interpolate(SCC_values_domestic[i, :, j, k], perturbation_years, all_years)
            end
            SCC_values_domestic = new_domestic_values
        end

        # reset perturbation years to all user requested years, unless model is PAGE, for which this is done below
    if model != PAGE
            perturbation_years = all_years
        end
    end
    
    # Save the information about which runs have a discrepency between base/marginal models of the discontinuity damages
    if model == PAGE
        # access the computed saved values from the simulation instance; it's the third item in the payload object for PAGE
        discontinuity_mismatch = Mimi.payload(sim_results)[3] 

        if _need_to_interpolate
            new_discontinuity_mismatch = Array{Bool}(undef, trials, length(all_years), length(scenarios), length(discount_rates))
            for i in 1:trials, j in 1:length(scenarios), k in 1:length(discount_rates)
                new_discontinuity_mismatch[i, :, j, k] = convert(Array{Bool}, _interpolate(discontinuity_mismatch[i, :, j, k], perturbation_years, all_years) .> 0)
            end
            discontinuity_mismatch = new_discontinuity_mismatch
            perturbation_years = all_years 
        end

        disc_dir = joinpath(output_dir, "discontinuity_mismatch/")
        # has the same 4-D array structure as the SCC values, so can use the same function to save them to files
        write_scc_values(discontinuity_mismatch, disc_dir, perturbation_years, discount_rates)

        disc_sum = dropdims(sum(discontinuity_mismatch, dims=(1, 3)), dims=(1, 3)) # summary table of how many occured (rows are perturbation years, columns are discount rates)
        writedlm(joinpath(disc_dir, "discontinuity_summary.csv"), disc_sum, ',') 
    end

    # Save the SCC values
    scc_dir = joinpath(output_dir, "SC-$gas/")
    write_scc_values(SCC_values, scc_dir, perturbation_years, discount_rates)
    if domestic 
        model == DICE ? SCC_values_domestic = SCC_values .* 0.1 : nothing   # domestic values for DICE calculated as 10% of global values
        write_scc_values(SCC_values_domestic, scc_dir, perturbation_years, discount_rates, domestic=true)
    end

    # Build the stats tables
    if tables
        make_percentile_tables(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities)
        make_stderror_tables(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities)
        make_summary_table(output_dir, gas, discount_rates, perturbation_years, drop_discontinuities)
    end

    nothing
end