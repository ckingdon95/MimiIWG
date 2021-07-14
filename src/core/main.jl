"""
    get_model(model::model_choice, scenario_choice::Union{scenario_choice, Nothing} = nothing)

Return a Mimi model of the IWG version of the specified `model_choice` and with socioeconomic scenario `scenario_choice`.

`model_choice` must be one of the following enums: DICE, FUND, or PAGE.
`scenario_choice` can be one of the following enums: USG1, USG2, USG3, USG4, or USG5.
If `scenario_choice` is not specified in `get_model`, then the `:scenario_num` parameter in the `:IWGScenarioChoice` 
component must be set to an Integer in 1:5 before the model can be run.

Examples

≡≡≡≡≡≡≡≡≡≡

julia> m = MimiIWG.get_model(DICE, USG1)

julia> run(m)

julia> m2 = MimiIWG.get_model(FUND)

julia> using Mimi

julia> set_param!(m2, :IWGScenarioChoice, :scenario_num, 4)

julia> run(m2)
"""
function get_model(model::model_choice, scenario_choice::Union{scenario_choice, Nothing} = nothing)

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_model(scenario_choice)
    elseif model == FUND 
        return get_fund_model(scenario_choice)
    elseif model == PAGE 
        return get_page_model(scenario_choice)
    else
        error()
    end
end

"""
    get_marginaldamages(model::model_choice, scenario_choice::scenario_choice;
        gas::Union{Symbol, Nothing} = nothing, 
        year::Union{Int, Nothing} = nothing, 
        discount::Union{Float64, Nothing} = nothing, 
        regional::Bool = false)

Return an array of marginal damages from an additional metric ton of the specified 
`gas` in year `year` for the IWG version of the Mimi model `model_choice` with 
socioeconomic scenario `scenario_choice`. Future marginal damages will be discounted 
to the year `year` using constant discounting with the provided rate `discount`. 
If `discount` is not specified or equals nothing, then the returned values will be 
undiscounted. Units of the returned marginal damages values are [2007\$ / metric ton of `gas`].

If `regional` is `true`, then the returned array will have separate columns for each 
region of the model. Otherwise, values will be summed across regions to return global marginal damages.
`model_choice` must be one of the following enums: DICE, FUND, or PAGE.
`scenario_choice` must be one of the following enums: USG1, USG2, USG3, USG4, or USG5.
`gas` can be one of :CO2, :CH4, or :N2O, and will default to :CO2 if nothing is specified.
"""
function get_marginaldamages(model::model_choice, scenario_choice::scenario_choice; 
    gas::Union{Symbol, Nothing} = nothing,
    year::Union{Int, Nothing} = nothing, 
    discount::Union{Float64, Nothing} = nothing,
    regional::Bool = false)

    # Check the gas
    if gas === nothing
        @warn("No `gas` specified in `compute_scc`; will return the SC-CO2.")
        gas = :CO2
    elseif ! (gas in [:CO2, :CH4, :N2O])
        error("Unknown gas :$gas. Available gases are :CO2, :CH4, and :N2O.")
    end

    # Check the emissions year
    if year === nothing 
        @warn("No `year` provided to `get_marginaldamages`; will return marginal damages from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if discount === nothing 
        @warn("No `discount` provided to `get_marginaldamages`; will return undiscounted marginal damages.")
        discount = 0.
    end 

    # dispatch on provided model choice
    if model == DICE 
        return get_dice_marginaldamages(scenario_choice, gas, year, discount)
    elseif model == FUND 
        return get_fund_marginaldamages(scenario_choice, gas, year, discount, regional = regional)
    elseif model == PAGE 
        return get_page_marginaldamages(scenario_choice, gas, year, discount, regional = regional)
    else
        error()
    end

end

"""
    compute_scc(model::model_choice, scenario_choice::scenario_choice = nothing; 
        gas::Union{Symbol, Nothing} = nothing,
        year::Union{Int, Nothing} = nothing, 
        prtp::Union{Float64, Nothing} = nothing,
        eta::Float64 = 0.,
        domestic::Bool = false,
        discount::Union{Float64, Nothing} = nothing
        )

Return the deterministic Social Cost of the specified `gas` from one run of the IWG version of 
the Mimi model `model_choice` with socioeconomic scenario `scenario_choice` for the 
specified year `year` and discounting with rate specified by `prtp` and `eta`.` 

If `domestic` equals `true`, then only domestic damages are used to calculate the 
SCC. Units of the returned SCC value are [2007\$ / metric ton of `gas`]. 

`model_choice` must be one of the following enums: DICE, FUND, or PAGE.
`scenario_choice` must be one of the following enums: USG1, USG2, USG3, USG4, or USG5.
`gas` can be one of :CO2, :CH4, or :N2O, and will default to :CO2 if nothing is specified.
"""

function compute_scc(model::model_choice, scenario_choice::scenario_choice = nothing; 
    gas::Union{Symbol, Nothing} = nothing,
    year::Union{Int, Nothing} = nothing, 
    prtp::Union{Float64, Nothing} = nothing,
    eta::Float64 = 0.,
    domestic::Bool = false,
    discount::Union{Float64, Nothing} = nothing
    )

    if !isnothing(discount)
        @warn "The `discount` keyword is deprecated. Use `prtp` keyword for constant discounting instead. ",
        "Now returning the results of calling `compute_scc` with `prtp = $discount`",
        "and `eta = 0.` by default."

        prtp = discount
    end

    # Check the gas
    if gas === nothing
        @warn("No `gas` provided to `compute_scc`; will return the SC-CO2.")
        gas = :CO2
    elseif ! (gas in [:CO2, :CH4, :N2O])
        error("Unknown gas :$gas. Available gases are :CO2, :CH4, and :N2O.")
    end

    # Check the emissions year
    if year === nothing 
        @warn("No `year` provided to `compute_scc`; will return SCC from an emissions pulse in $_default_year.")
        year = _default_year
    end

    # Check the discount rate
    if prtp === nothing 
        @warn("No `prtp` provided to `compute_scc`; will return SCC for a discount rate of $(_default_discount * 100)%.")
        prtp = _default_discount
    end 

    # dispatch on provided model choice
    if model == DICE 
        return compute_dice_scc(scenario_choice, gas, year, prtp, eta = eta, domestic = domestic)
    elseif model == FUND 
        return compute_fund_scc(scenario_choice, gas, year, prtp, eta = eta, domestic = domestic)
    elseif model == PAGE 
        return compute_page_scc(scenario_choice, gas, year, prtp, eta = eta, domestic = domestic)
    else
        error()
    end

end
