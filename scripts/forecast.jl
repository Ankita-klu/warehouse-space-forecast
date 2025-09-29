using Pkg
# Activate project environment (optional if you have Project.toml)
# Pkg.activate("..")

# Load modules
include("../src/WarehouseForecast.jl")
include("../src/arima_forecast.jl")

using Main.WarehouseForecast
using Main.ARIMAForecast
using CSV, DataFrames

# File paths
incoming_file = joinpath(@__DIR__, "..", "data", "incoming_shipments.csv")
outgoing_file = joinpath(@__DIR__, "..", "data", "outgoing_shipments.csv")
output_csv   = joinpath(@__DIR__, "..", "results", "space_usage.csv")
output_plot  = joinpath(@__DIR__, "..", "results", "space_forecast_plot.png")

# Run pipeline
println("📦 Loading and processing shipment data...")
shipments = load_data(incoming_file, outgoing_file)
aggregates = compute_aggregates(shipments)
aggregates = add_rolling_average(aggregates, window=3)
save_results(aggregates, output_csv, output_plot)

println("✅ Forecast complete. Results saved in results/ folder.")

# Run ARIMA forecast
arima_output_csv  = joinpath(@__DIR__, "..", "results", "space_forecast_arima.csv")

println("📈 Running ARIMA-style forecast...")
forecast_df = run_arima_forecast(aggregates, p=2, d=1, q=1, steps=7, save_path=arima_output_csv)

if nrow(forecast_df) > 0
    println("📈 ARIMA forecast saved in results/ as CSV and PNG.")
else
    println("⚠️  ARIMA forecast failed, but basic results are available.")
end

println("🎉 All processing complete!")