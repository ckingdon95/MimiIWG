using MimiIWG

# ------------------------------------------------------------------------------
# Deterministic single runs of SC-CH4 and SC-N2O
# ------------------------------------------------------------------------------

# DICE
scch4 = MimiIWG.compute_scc(DICE, USG1, gas=:CH4, year=2020, discount=0.025)
scn2o = MimiIWG.compute_scc(DICE, USG1, gas=:N2O, year=2020, discount=0.025)

# FUND
scch4 = MimiIWG.compute_scc(FUND, USG1, gas=:CH4, year=2020, discount=0.025)
scn2o = MimiIWG.compute_scc(FUND, USG1, gas=:N2O, year=2020, discount=0.025)

# PAGE
scch4 = MimiIWG.compute_scc(PAGE, USG1, gas=:CH4, year=2020, discount=0.025)
scn2o = MimiIWG.compute_scc(PAGE, USG1, gas=:N2O, year=2020, discount=0.025)

# ------------------------------------------------------------------------------
# Full Monte Carlo simulations for SC-CH4 and SC-N2O for each model
# ------------------------------------------------------------------------------

# DICE
# (will run for all 3 IWG discount rates if none are specified) 
MimiIWG.run_scc_mcs(DICE, gas=:CH4, trials=10_000, perturbation_years=[2020], output_dir="output")
MimiIWG.run_scc_mcs(DICE, gas=:N2O, trials=10_000, perturbation_years=[2020], output_dir="output")

# FUND
MimiIWG.run_scc_mcs(FUND, gas=:CH4, trials=10_000, perturbation_years=[2020], output_dir="output")
MimiIWG.run_scc_mcs(FUND, gas=:N2O, trials=10_000, perturbation_years=[2020], output_dir="output")

# PAGE
MimiIWG.run_scc_mcs(PAGE, gas=:CH4, trials=10_000, perturbation_years=[2020],  output_dir="output")
MimiIWG.run_scc_mcs(PAGE, gas=:N2O, trials=10_000, perturbation_years=[2020],  output_dir="output")
