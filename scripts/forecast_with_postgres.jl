using DataFrames, Dates

include("../src/database.jl")
include("../src/WarehouseForecast.jl")
include("../src/arima_forecast.jl")

using .Database
using Main.WarehouseForecast
using Main.ARIMAForecast

println("🚀 Warehouse Forecast with PostgreSQL")
println("=" ^ 60)

println("\n📊 Loading from PostgreSQL...")
df = load_from_db()
println("Loaded ", size(df, 1), " records")

println("\n📈 Processing data...")
aggregates = compute_aggregates(df)
aggregates = add_rolling_average(aggregates, window=3)
println("Processed ", size(aggregates, 1), " days of data")

println("\n💾 Saving occupancy to database...")
save_occupancy_to_db(aggregates)

println("\n🔮 Running forecast...")
forecast_df = run_arima_forecast(aggregates, steps=7, 
                                save_path="results/forecast_postgres.csv")

if size(forecast_df, 1) > 0
    println("\n✅ Forecast Complete!")
    println("\n📊 7-Day Forecast:")
    println(forecast_df)
    
    println("\n💾 Saving forecast to database...")
    save_forecast_to_db(forecast_df, "ARIMA")
else
    println("\n⚠️  Forecast failed")
end

println("\n🎉 Done! All data saved to PostgreSQL")
