using MimiIWG
using Random

N = 10_000

prtp = [0.]
eta = [1., 1.5, 2.]
perturbation_years = [2020]


gas = :CO2

Random.seed!(350)
MimiIWG.run_scc_mcs(DICE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(FUND, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(PAGE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

gas = :CH4

Random.seed!(350)
MimiIWG.run_scc_mcs(DICE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(FUND, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(PAGE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

gas = :N2O

Random.seed!(350)
MimiIWG.run_scc_mcs(DICE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(FUND, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")

Random.seed!(350)
MimiIWG.run_scc_mcs(PAGE, gas=gas, trials=N, perturbation_years=perturbation_years, prtp = prtp, eta =eta, output_dir = "output")