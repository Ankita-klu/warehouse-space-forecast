using HTTP, JSON3, CSV, DataFrames

# Load modules
include("../src/WarehouseForecast.jl")
include("../src/arima_forecast.jl")
using Main.WarehouseForecast, Main.ARIMAForecast

function forecast_handler(req::HTTP.Request)
    try
        # Run pipeline
        incoming_file = joinpath(@__DIR__, "..", "data", "incoming_shipments.csv")
        outgoing_file = joinpath(@__DIR__, "..", "data", "outgoing_shipments.csv")

        shipments = load_data(incoming_file, outgoing_file)
        aggregates = compute_aggregates(shipments)
        aggregates = add_rolling_average(aggregates, window=3)
        forecast_df = run_arima_forecast(aggregates, steps=7)

        return HTTP.Response(200, JSON3.write(forecast_df))
    catch e
        return HTTP.Response(500, "Error: $(e)")
    end
end

println("🚀 Starting API server on http://0.0.0.0:8080 ...")
HTTP.serve(forecast_handler, "0.0.0.0", 8080)
