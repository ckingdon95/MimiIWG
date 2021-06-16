using MimiIWG
using Random

N = 10000
seed = 350

Random.seed!(seed)
MimiIWG.run_scc_mcs(DICE, gas=:CO2, trials=N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(FUND, gas=:CO2, trials=N)

Random.seed!(seed)
MimiIWG.run_scc_mcs(PAGE, gas=:CO2, trials=N)
