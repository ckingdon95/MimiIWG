# This component holds data for all IWG scenarios for FUND in its parameters, and the `scenario_num` parameter specifies which scenario to use.
# During the first timestep, values for the specified scenario are copied into the variables.
# Functions for loading in the necessaring parameters are defined in src/core/FUND_helper.jl
@defcomp IWG_FUND_ScenarioChoice begin

    scenarios = Index()

    # Variables (each one has its value set for the chosen scenario in the first timestep)
    globch4     = Variable(index=[time])
    globn2o     = Variable(index=[time])
    pgrowth     = Variable(index=[time, regions])
    ypcgrowth   = Variable(index=[time, regions])
    aeei        = Variable(index=[time, regions])
    acei        = Variable(index=[time, regions])

    # The number for which scenario to use 
    scenario_num = Parameter{Integer}()

    # Parameters (each one holds all five scenarios)
    globch4_all     = Parameter(index=[time, scenarios])
    globn2o_all     = Parameter(index=[time, scenarios])
    pgrowth_all     = Parameter(index=[time, regions, scenarios])
    ypcgrowth_all   = Parameter(index=[time, regions, scenarios])
    aeei_all        = Parameter(index=[time, regions, scenarios])
    acei_all        = Parameter(index=[time, regions, scenarios])

    function run_timestep(p, v, d, t)
        if is_first(t)
            # Get the specified scenario
            scenario_num = p.scenario_num
            if ! (scenario_num in d.scenarios)
                error("Invalid :scenario_num in :IWGScenarioChoice component: $scenario_num. :scenario_num must be in $(d.scenarios).")
            else
                # Copy over all of the values for that scenario
                v.globch4[:]        = p.globch4_all[:, scenario_num]
                v.globn2o[:]        = p.globn2o_all[:, scenario_num]
                v.pgrowth[:, :]     = p.pgrowth_all[:, :, scenario_num]
                v.ypcgrowth[:, :]   = p.ypcgrowth_all[:, :, scenario_num]
                v.aeei[:, :]        = p.aeei_all[:, :, scenario_num]
                v.acei[:, :]        = p.acei_all[:, :, scenario_num]

            end
        end
    end
end
