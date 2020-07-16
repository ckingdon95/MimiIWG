
# Model and scenario choices
@enum model_choice DICE FUND PAGE 
@enum scenario_choice USG1=1 USG2=2 USG3=3 USG4=4 USG5=5
const scenarios = [USG1, USG2, USG3, USG4, USG5]    # for use in iterating
# const tsd_scenario_names = ["IMAGE", "MERGE Optimistic", "MESSAGE", "MiniCAM Base", "5th Scenario"]

# Default values for user facing functions
const _default_year = 2020      # default perturbation year for marginal damages and scc
const _default_discount = 0.03  # 3% constant discounting
const _default_horizon = 2300   # Same as H (the variable name used by the IWG in DICE)
const _default_discount_rates = [.025, .03, .05]            # used by MCS
const _default_perturbation_years = 2010:5:2050             # years for which to calculate the SCC

# Roe and Baker climate sensitivity distribution file
const RBdistribution_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/2009 11 23 Calibrated R&B distribution.xls")
const RB_cs_values = Vector{Float64}(readxl(RBdistribution_file, "Sheet1!A2:A1001")[:, 1])  # cs values
const RB_cs_probs  = Vector{Float64}(readxl(RBdistribution_file, "Sheet1!B2:B1001")[:, 1])  # probabilities associated with those values

#------------------------------------------------------------------------------
# 1. DICE specific constants
#------------------------------------------------------------------------------

const iwg_dice_input_file = joinpath(@__DIR__, "../../data/IWG_inputs/DICE/SCC_input_EMFscenarios.xls")

const dice_ts = 10                              # length of DICE timestep: 10 years
const dice_years = 2005:dice_ts:2405   # time dimension of the IWG's DICE model

const dice_inflate = 122.58 / 114.52 # World GDP inflator 2005 => 2007

const dice_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the DICE-specific names used in the input files
    USG1 => "IMAGE",
    USG2 => "MERGEoptimistic",
    USG3 => "MESSAGE",
    USG4 => "MiniCAMbase",
    USG5 => "5thScenario"
)

const dice_scenario_specific_params = [
    :l,
    :E,
    :forcoth,
    :al,
    :k0
]

function _dice_normalization_factor(gas::Symbol)
    if gas == :CO2
        return 1e3 * 12/44  # Convert from trillion$/GtC/yr to $/tCO2/yr
    elseif gas in [:CH4, :N2O]
        return 1e6  # Convert from trillion$/MtX/yr to $/tX/yr
    else
        error("Unknown gas :$gas.")
    end
end

#------------------------------------------------------------------------------
# 2. FUND specific constants
#------------------------------------------------------------------------------

const iwg_fund_datadir = joinpath(@__DIR__, "../../data/IWG_inputs/FUND/")    

const fund_inflator = 1.3839  # 1990(?)$ => 2007$

const fund_years = 1950:2300   # number of years to include for the SCC calculation, even though model is run to 3000

const fund_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the FUND-specific names used in the input files
    USG1  => "IMAGE",
    USG2  => "MERGE Optimistic",
    USG3  => "MESSAGE",
    USG4  => "MiniCAM",
    USG5  => "Policy Level Average"
)

const fund_scenario_specific_params = [
    "globch4",
    "globn2o",
    "pgrowth",
    "ypcgrowth",
    "aeei",
    "acei"
]

function _fund_normalization_factor(gas::Symbol)
    if gas == :CO2
        return 1e-7 * 12/44     # Convert from /MtC for ten years to /tons CO2/year
    elseif gas == :CH4
        return 1e-7             # Convert from /MtCH4 for ten years to /tons CH4/year
    elseif gas == :N2O
        return 1e-7 * 28/44     # Convert from /MtN for ten years to /tons of N2O/year
    elseif gas == :SF6
        return 1e-7
    else
        error("Unknown gas :$gas.")
    end
end

#------------------------------------------------------------------------------
# 3. PAGE specific constants 
#------------------------------------------------------------------------------

const iwg_page_datadir = joinpath(@__DIR__, "../../data/IWG_inputs/PAGE/")
const iwg_page_input_file = joinpath(iwg_page_datadir, "PAGE09 v1.7 SCCO2 (550 Avg, for 2013 SCC technical update - Input files).xlsx")   # One input file used for RB distribution in mcs

const page_years = [2010, 2020, 2030, 2040, 2050, 2060, 2080, 2100, 2200, 2300]

const page_inflator = 1.225784    # 2000 USD => 2007 USD

# list of parameters that are different between the IWG scenarios
const page_scenario_specific_params = [
    "gdp_0",
    "grw_gdpgrowthrate",
    "GDP_per_cap_focus_0_FocusRegionEU",
    "pop0_initpopulation",
    "popgrw_populationgrowth",
    "e0_baselineCO2emissions",
    "e0_globalCO2emissions",
    "er_CO2emissionsgrowth",
    "f0_CO2baseforcing",
    "exf_excessforcing"
]

const page_scenario_convert = Dict{scenario_choice, String}(    # convert from standard names to the PAGE specific names used in the input files
    USG1  => "IMAGE",
    USG2  => "MERGE",
    USG3  => "MESSAGE",
    USG4  => "MiniCAM",
    USG5  => "550 Avg"
)
