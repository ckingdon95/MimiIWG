
_dice_simdef = @defsim begin
    # Use the Roe and Baker distribution defined in a file, read in in src/core/constatns.jl
    t2xco2 = EmpiricalDistribution(RB_cs_values, RB_cs_probs)
    # save(climatedynamics.t2xco2)
end 

"""
    Returns a Monte Carlo Simulation object with one random variable for climate sensitivity over the 
    Roe Baker distrtibution used by the IWG for DICE.
"""
function get_dice_mcs()
    return deepcopy(_dice_simdef) 
end

function dice_scenario_func(mcs::SimulationInstance, tup::Tuple)
    (scenario_choice,) = tup
    global scenario_num = Int(scenario_choice)

    base, marginal = mcs.models
    set_param!(base, :IWGScenarioChoice, :scenario_num, scenario_num)
    set_param!(marginal, :IWGScenarioChoice, :scenario_num, scenario_num)

    Mimi.build(base)
    Mimi.build(marginal)
end

function dice_post_trial_func(mcs::SimulationInstance, trial::Int, ntimesteps::Int, tup::Tuple)
    (name,) = tup
    (base, marginal) = mcs.models

    prtp, eta, model_years, horizon, gas, perturbation_years, SCC_values, SCC_values_domestic = Mimi.payload(mcs)

    last_idx = horizon - 2005 + 1
    annual_years = dice_years[1]:horizon

    base_consump = base[:neteconomy, :C] 
    cpc = base[:neteconomy, :CPC]
    g_decades = [NaN, [(cpc[t]/cpc[t-1])^(1/10) - 1 for t in 2:length(cpc)]...]
    g = reduce(vcat, map(x->fill(x, 10), g_decades))

    for (idx, pyear) in enumerate(perturbation_years)

        # Call the marginal model with perturbations in each year
        perturb_dice_marginal_emissions!(marginal, gas, pyear)
        run(marginal)

        marg_consump = marginal[:neteconomy, :C]
        md = (base_consump .- marg_consump)  * _dice_normalization_factor(gas)     # get marginal damages
        annual_md = _interpolate(md, dice_years, annual_years)  # get annual marginal damages

        first_idx = pyear - 2005 + 1

        for (i, rho) in enumerate(prtp), (j, _eta) in enumerate(eta)
            scc = scc_discrete(annual_md[first_idx:last_idx], prtp, _eta, g[first_idx:last_idx])
            SCC_values[trial, idx, scenario_num, i, j] = scc 
        end
    end
end
