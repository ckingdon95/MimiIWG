
"""
Returns a Monte Carlo Simulation object over the uncertain parameters used by the IWG for the PAGE model.
    The only changes are that sens_climatesensitivity is now a RV with Empirical Roe and Baker Distribution,
    and tcr_transientresponse and emuc_utilityconvexity are no longer RVs. Latin Hypercube sampling is used.
"""
function get_page_mcs()

    mcs = @defsim begin

        # ADDITIONAL IWG DISTRIBUTIONAL PARAMETER:
        ClimateTemperature.sens_climatesensitivity = EmpiricalDistribution(RB_cs_values, RB_cs_probs)

        # Use Latin Hypercube Sampling
        sampling(LHSData)

        # ORIGINAL PAGE RANDOM VARIABLES:
        
        ############################################################################
        # Define random variables (RVs) - for UNSHARED parameters
        ############################################################################
        
        # each component should have the same value for its save_savingsrate,
        # so we use an RV here because in the model this is not an explicitly
        # shared parameter, then assign below in component section
        rv(RV_save_savingsrate) = TriangularDist(10, 20, 15)
        GDP.save_savingsrate = RV_save_savingsrate
        MarketDamages.save_savingsrate = RV_save_savingsrate
        NonMarketDamages.save_savingsrate = RV_save_savingsrate
        SLRDamages.save_savingsrate = RV_save_savingsrate

        # each component should have the same value for its tcal_CalibrationTemp
        # so we use an RV here because in the model this is not an explicitly
        # shared parameter, then assign below in component section
        rv(RV_tcal_CalibrationTemp) = TriangularDist(2.5, 3.5, 3.)
        MarketDamages.tcal_CalibrationTemp = RV_tcal_CalibrationTemp
        NonMarketDamages.tcal_CalibrationTemp = RV_tcal_CalibrationTemp

        # CO2cycle
        co2cycle.air_CO2fractioninatm = TriangularDist(57, 67, 62)
        co2cycle.res_CO2atmlifetime = TriangularDist(50, 100, 70)
        co2cycle.ccf_CO2feedback = TriangularDist(4, 15, 10)
        co2cycle.ccfmax_maxCO2feedback = TriangularDist(30, 80, 50)
        co2cycle.stay_fractionCO2emissionsinatm = TriangularDist(0.25, 0.35, 0.3)

        # SulphateForcing
        SulphateForcing.d_sulphateforcingbase = TriangularDist(-0.8, -0.2, -0.4)
        SulphateForcing.ind_slopeSEforcing_indirect = TriangularDist(-0.8, 0, -0.4)

        # ClimateTemperature
        ClimateTemperature.rlo_ratiolandocean = TriangularDist(1.2, 1.6, 1.4)
        ClimateTemperature.pole_polardifference = TriangularDist(1, 2, 1.5)
        ClimateTemperature.frt_warminghalflife = TriangularDist(10, 65, 30)
        # ClimateTemperature.tcr_transientresponse = TriangularDist(1, 2.8, 1.3)

        # SeaLevelRise
        SeaLevelRise.s0_initialSL = TriangularDist(0.1, 0.2, 0.15)
        SeaLevelRise.sltemp_SLtemprise = TriangularDist(0.7, 3., 1.5)
        SeaLevelRise.sla_SLbaselinerise = TriangularDist(0.5, 1.5, 1.)
        SeaLevelRise.sltau_SLresponsetime = TriangularDist(500, 1500, 1000)

        # GDP
        GDP.isat0_initialimpactfxnsaturation = TriangularDist(20, 50, 30) 

        # MarketDamages
        MarketDamages.iben_MarketInitialBenefit = TriangularDist(0, .3, .1)
        MarketDamages.W_MarketImpactsatCalibrationTemp = TriangularDist(.2, .8, .5)
        MarketDamages.pow_MarketImpactExponent = TriangularDist(1.5, 3, 2)
        MarketDamages.ipow_MarketIncomeFxnExponent = TriangularDist(-.3, 0, -.1)

        # NonMarketDamages
        NonMarketDamages.iben_NonMarketInitialBenefit = TriangularDist(0, .2, .05)
        NonMarketDamages.w_NonImpactsatCalibrationTemp = TriangularDist(.1, 1, .5)
        NonMarketDamages.pow_NonMarketExponent = TriangularDist(1.5, 3, 2)
        NonMarketDamages.ipow_NonMarketIncomeFxnExponent = TriangularDist(-.2, .2, 0)

        # SLRDamages
        SLRDamages.scal_calibrationSLR = TriangularDist(0.45, 0.55, .5)
        # SLRDamages.iben_SLRInitialBenefit = TriangularDist(0, 0, 0) # only usable if lb <> ub
        SLRDamages.W_SatCalibrationSLR = TriangularDist(.5, 1.5, 1)
        SLRDamages.pow_SLRImpactFxnExponent = TriangularDist(.5, 1, .7)
        SLRDamages.ipow_SLRIncomeFxnExponent = TriangularDist(-.4, -.2, -.3)

        # Discountinuity
        Discontinuity.rand_discontinuity = Uniform(0, 1)
        Discontinuity.tdis_tolerabilitydisc = TriangularDist(2, 4, 3)
        Discontinuity.pdis_probability = TriangularDist(10, 30, 20)
        Discontinuity.wdis_gdplostdisc = TriangularDist(5, 25, 15)
        Discontinuity.ipow_incomeexponent = TriangularDist(-.3, 0, -.1)
        Discontinuity.distau_discontinuityexponent = TriangularDist(20, 200, 50)

        # EquityWeighting
        EquityWeighting.civvalue_civilizationvalue = TriangularDist(1e10, 1e11, 5e10)
        # EquityWeighting.ptp_timepreference = TriangularDist(0.1,2,1)
        # EquityWeighting.emuc_utilityconvexity = TriangularDist(0.5,2,1)       # IWG does not sample this; instead use constant discounting
                
        ############################################################################
        # Define random variables (RVs) - for SHARED parameters
        ############################################################################

        # shared parameter linked to components: MarketDamages, NonMarketDamages, 
        # SLRDamages, Discountinuity
        wincf_weightsfactor["USA"] = TriangularDist(.6, 1, .8)
        wincf_weightsfactor["OECD"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["USSR"] = TriangularDist(.2, .6, .4)
        wincf_weightsfactor["China"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["SEAsia"] = TriangularDist(.4, 1.2, .8)
        wincf_weightsfactor["Africa"] = TriangularDist(.4, .8, .6)
        wincf_weightsfactor["LatAmerica"] = TriangularDist(.4, .8, .6)

        # shared parameter linked to components: AdaptationCosts, AbatementCosts
        automult_autonomouschange = TriangularDist(0.5, 0.8, 0.65)

        # the following variables need to be set, but set the same in all 4 abatement cost components
        # note that for these regional variables, the first region is the focus region (EU), which is set in the preceding code, and so is always one for these variables
        
        emitf_uncertaintyinBAUemissfactor["USA"] = TriangularDist(0.8, 1.2, 1.0)
        emitf_uncertaintyinBAUemissfactor["OECD"] = TriangularDist(0.8, 1.2, 1.0)
        emitf_uncertaintyinBAUemissfactor["USSR"] = TriangularDist(0.65, 1.35, 1.0)
        emitf_uncertaintyinBAUemissfactor["China"] = TriangularDist(0.5, 1.5, 1.0)
        emitf_uncertaintyinBAUemissfactor["SEAsia"] = TriangularDist(0.5, 1.5, 1.0)
        emitf_uncertaintyinBAUemissfactor["Africa"] = TriangularDist(0.5, 1.5, 1.0)
        emitf_uncertaintyinBAUemissfactor["LatAmerica"] = TriangularDist(0.5, 1.5, 1.0)
        
        q0f_negativecostpercentagefactor["USA"] = TriangularDist(0.75, 1.5, 1.0)
        q0f_negativecostpercentagefactor["OECD"] = TriangularDist(0.75, 1.25, 1.0)
        q0f_negativecostpercentagefactor["USSR"] = TriangularDist(0.4, 1.0, 0.7)      
        q0f_negativecostpercentagefactor["China"] = TriangularDist(0.4, 1.0, 0.7)
        q0f_negativecostpercentagefactor["SEAsia"] = TriangularDist(0.4, 1.0, 0.7)
        q0f_negativecostpercentagefactor["Africa"] = TriangularDist(0.4, 1.0, 0.7)
        q0f_negativecostpercentagefactor["LatAmerica"] = TriangularDist(0.4, 1.0, 0.7)
        
        cmaxf_maxcostfactor["USA"] = TriangularDist(0.8, 1.2, 1.0)
        cmaxf_maxcostfactor["OECD"] = TriangularDist(1.0, 1.5, 1.2)
        cmaxf_maxcostfactor["USSR"] = TriangularDist(0.4, 1.0, 0.7)
        cmaxf_maxcostfactor["China"] = TriangularDist(0.8, 1.2, 1.0)
        cmaxf_maxcostfactor["SEAsia"] = TriangularDist(1, 1.5, 1.2)
        cmaxf_maxcostfactor["Africa"] = TriangularDist(1, 1.5, 1.2)
        cmaxf_maxcostfactor["LatAmerica"] = TriangularDist(0.4, 1.0, 0.7)
        
        cf_costregional["USA"] = TriangularDist(0.6, 1, 0.8)
        cf_costregional["OECD"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["USSR"] = TriangularDist(0.2, 0.6, 0.4)
        cf_costregional["China"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["SEAsia"] = TriangularDist(0.4, 1.2, 0.8)
        cf_costregional["Africa"] = TriangularDist(0.4, 0.8, 0.6)
        cf_costregional["LatAmerica"] = TriangularDist(0.4, 0.8, 0.6)

        # Other
        q0propmult_cutbacksatnegativecostinfinalyear = TriangularDist(0.3, 1.2, 0.7)
        qmax_minus_q0propmult_maxcutbacksatpositivecostinfinalyear = TriangularDist(1, 1.5, 1.3)
        c0mult_mostnegativecostinfinalyear = TriangularDist(0.5, 1.2, 0.8)
        curve_below_curvatureofMACcurvebelowzerocost = TriangularDist(0.25, 0.8, 0.45)
        curve_above_curvatureofMACcurveabovezerocost = TriangularDist(0.1, 0.7, 0.4)
        cross_experiencecrossoverratio = TriangularDist(0.1, 0.3, 0.2)
        learn_learningrate = TriangularDist(0.05, 0.35, 0.2)
 
        # NOTE: the below can probably be resolved into unique, unshared parameters with the same name
        # in the new Mimi paradigm of shared and unshared parameters, but for now this will 
        # continue to work!

        # AbatementCosts
        AbatementCostParametersCO2_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50, 75, 0)
        AbatementCostParametersCH4_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-25, 100, 0)
        AbatementCostParametersN2O_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50, 50, 0)
        AbatementCostParametersLin_emit_UncertaintyinBAUEmissFactorinFocusRegioninFinalYear = TriangularDist(-50, 50, 0)
        
        AbatementCostParametersCO2_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0, 40, 20)
        AbatementCostParametersCH4_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0, 20, 10)
        AbatementCostParametersN2O_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0, 20, 10)
        AbatementCostParametersLin_q0propinit_CutbacksinNegativeCostinFocusRegioninBaseYear = TriangularDist(0, 20, 10)
        
        AbatementCostParametersCO2_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-400, -100, -200)
        AbatementCostParametersCH4_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-8000, -1000, -4000)
        AbatementCostParametersN2O_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-15000, 0, -7000)
        AbatementCostParametersLin_c0init_MostNegativeCostCutbackinBaseYear = TriangularDist(-400, -100, -200)
        
        AbatementCostParametersCO2_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(60, 80, 70)
        AbatementCostParametersCH4_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(35, 70, 50)
        AbatementCostParametersN2O_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(35, 70, 50)
        AbatementCostParametersLin_qmaxminusq0propinit_MaxCutbackCostatPositiveCostinBaseYear = TriangularDist(60, 80, 70)
        
        AbatementCostParametersCO2_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(100, 700, 400)
        AbatementCostParametersCH4_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(3000, 10000, 6000)
        AbatementCostParametersN2O_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(2000, 60000, 20000)
        AbatementCostParametersLin_cmaxinit_MaximumCutbackCostinFocusRegioninBaseYear = TriangularDist(100, 600, 300)
        
        AbatementCostParametersCO2_ies_InitialExperienceStockofCutbacks = TriangularDist(100000, 200000, 150000)
        AbatementCostParametersCH4_ies_InitialExperienceStockofCutbacks = TriangularDist(1500, 2500, 2000)
        AbatementCostParametersN2O_ies_InitialExperienceStockofCutbacks = TriangularDist(30, 80, 50)
        AbatementCostParametersLin_ies_InitialExperienceStockofCutbacks = TriangularDist(1500, 2500, 2000)

        # AdaptationCosts
        AdaptiveCostsSeaLevel_cp_costplateau_eu = TriangularDist(0.01, 0.04, 0.02)
        AdaptiveCostsSeaLevel_ci_costimpact_eu = TriangularDist(0.0005, 0.002, 0.001)
        AdaptiveCostsEconomic_cp_costplateau_eu = TriangularDist(0.005, 0.02, 0.01)
        AdaptiveCostsEconomic_ci_costimpact_eu = TriangularDist(0.001, 0.008, 0.003)
        AdaptiveCostsNonEconomic_cp_costplateau_eu = TriangularDist(0.01, 0.04, 0.02)
        AdaptiveCostsNonEconomic_ci_costimpact_eu = TriangularDist(0.002, 0.01, 0.005)
    
        # save(ClimateTemperature.sens_climatesensitivity)

    end

    return mcs

end

function page_scenario_func(mcs::SimulationInstance, tup::Tuple)
    # Unpack the scenario arguments
    (scenario_choice, rate) = tup 
    global scenario_num = Int(scenario_choice)
    global rate_num = findfirst(isequal(rate), Mimi.payload(mcs)[1])

    # Build the page versions for this scenario
    base, marginal = mcs.models
    update_param!(base, :scenario_num, scenario_num)
    update_param!(marginal, :scenario_num, scenario_num)
    update_param!(base, :ptp_timepreference, rate * 100)  # update the pure rate of time preference for this scenario's discount rate
    update_param!(marginal, :ptp_timepreference, rate * 100)  # update the pure rate of time preference for this scenario's discount rate

    Mimi.build!(base)
    Mimi.build!(marginal)
end 

function page_post_trial_func(mcs::SimulationInstance, trialnum::Int, ntimesteps::Int, tup::Tuple)

    # Access the models
    base, marginal = mcs.models 
    
    # Unpack the payload object 
    discount_rates, discount_factors, discontinuity_mismatch, gas, perturbation_years, SCC_values, SCC_values_domestic, md_values = Mimi.payload(mcs)

    DF = discount_factors[rate_num]
    td_base = base[:EquityWeighting, :td_totaldiscountedimpacts]
    if SCC_values_domestic !== nothing 
        td_base_domestic = sum(base[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])  # US is the second region
    end
    EMUC = base[:EquityWeighting, :emuc_utilityconvexity]
    UDFT_base = DF .* (base[:EquityWeighting, :cons_percap_consumption][:, 1] / base[:EquityWeighting, :cons_percap_consumption_0][1]).^(-EMUC)    

    for (j, pyear) in enumerate(perturbation_years)
        idx = getpageindexfromyear(pyear)

        perturb_marginal_page_emissions!(base, marginal, gas, pyear)
        run(marginal)

        # Stores `true` if the base and marginal models trigger the discontinuity damages in different timesteps (0 otherwise)
        discontinuity_mismatch[trialnum, j, scenario_num, rate_num] = base[:Discontinuity, :occurdis_occurrencedummy] != marginal[:Discontinuity, :occurdis_occurrencedummy]

        td_marginal = marginal[:EquityWeighting, :td_totaldiscountedimpacts]   
        pulse_size = gas == :CO2 ? 100_000 : 1          
        scc = ((td_marginal / UDFT_base[idx]) - (td_base / UDFT_base[idx])) / pulse_size * page_inflator

        if SCC_values_domestic !== nothing 
            td_marginal_domestic = sum(marginal[:EquityWeighting, :addt_equityweightedimpact_discountedaggregated][:, 2])
            scc_domestic = ((td_marginal_domestic / UDFT_base[idx]) - (td_base_domestic / UDFT_base[idx])) / pulse_size * page_inflator
            SCC_values_domestic[trialnum, j, scenario_num, rate_num] = scc_domestic
        end
        SCC_values[trialnum, j, scenario_num, rate_num] = scc   

        if md_values !== nothing 
            base_impacts = base[:EquityWeighting, :wit_equityweightedimpact]
            marg_impacts = marginal[:EquityWeighting, :wit_equityweightedimpact]
        
            marg_damages = (marg_impacts .- base_impacts) ./ (gas == :CO2 ? 100_000 : 1) .* page_inflator
            md_values[j, scenario_num, :, trialnum] = sum(marg_damages, dims=2) # sum along second dimension to get global values
        end
    end 
end
