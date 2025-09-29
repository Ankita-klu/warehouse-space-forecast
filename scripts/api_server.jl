# warehouse_api_server.jl - Complete Warehouse Forecast API

using HTTP, JSON3, Sockets, CSV, DataFrames, Dates
using Statistics

# Load your warehouse modules
include("../src/WarehouseForecast.jl")
include("../src/arima_forecast.jl")

using Main.WarehouseForecast
using Main.ARIMAForecast

# Global variables for cached data
cached_data = nothing
last_updated = nothing

function load_warehouse_data()
    global cached_data, last_updated
    
    println("📊 Loading warehouse data...")
    
    incoming_file = joinpath(@__DIR__, "..", "data", "incoming_shipments.csv")
    outgoing_file = joinpath(@__DIR__, "..", "data", "outgoing_shipments.csv")
    
    if !isfile(incoming_file) || !isfile(outgoing_file)
        return nothing
    end
    
    try
        shipments = load_data(incoming_file, outgoing_file)
        aggregates = compute_aggregates(shipments)
        aggregates = add_rolling_average(aggregates, window=3)
        
        cached_data = aggregates
        last_updated = now()
        
        println("✅ Data loaded: $(nrow(aggregates)) days of data")
        return aggregates
    catch e
        println("❌ Error loading data: $e")
        return nothing
    end
end

function router(req::HTTP.Request)
    println("📨 $(req.method) $(req.target)")
    
    try
        # CORS headers for web access
        headers = [
            "Content-Type" => "application/json",
            "Access-Control-Allow-Origin" => "*",
            "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers" => "Content-Type"
        ]
        
        # Handle preflight requests
        if req.method == "OPTIONS"
            return HTTP.Response(200, headers, "")
        end
        
        # Routes
        if req.target == "/" || req.target == "/health"
            return handle_health(headers)
            
        elseif req.target == "/api/current" || req.target == "/current"
            return handle_current(headers)
            
        elseif startswith(req.target, "/api/forecast") || startswith(req.target, "/forecast")
            # Parse query parameters for forecast horizon
            uri = HTTP.URI(req.target)
            params = HTTP.queryparams(uri)
            days = parse(Int, get(params, "days", "7"))
            
            return handle_forecast(headers, days)
            
        elseif req.target == "/api/reload" || req.target == "/reload"
            return handle_reload(headers)
            
        else
            return HTTP.Response(404, headers, 
                                JSON3.write(Dict("error" => "Not found", 
                                               "path" => req.target)))
        end
        
    catch e
        println("❌ Error: $e")
        return HTTP.Response(500, 
                            ["Content-Type" => "application/json"],
                            JSON3.write(Dict("error" => string(e))))
    end
end

function handle_health(headers)
    response = Dict(
        "status" => "ok",
        "service" => "Warehouse Forecast API",
        "version" => "1.0",
        "uptime" => "$(round((now() - last_updated).value / 1000, digits=2))s",
        "data_loaded" => !isnothing(cached_data),
        "last_updated" => isnothing(last_updated) ? "never" : string(last_updated)
    )
    
    return HTTP.Response(200, headers, JSON3.write(response))
end

function handle_current(headers)
    if isnothing(cached_data)
        load_warehouse_data()
    end
    
    if isnothing(cached_data)
        return HTTP.Response(500, headers, 
                            JSON3.write(Dict("error" => "No data available")))
    end
    
    # Get current occupancy stats
    current_occupancy = cached_data.Occupancy[end]
    avg_occupancy = mean(cached_data.Occupancy)
    max_occupancy = maximum(cached_data.Occupancy)
    min_occupancy = minimum(cached_data.Occupancy)
    
    # Recent trend (last 7 days)
    recent_data = cached_data[max(1, end-6):end, :]
    trend = recent_data.Occupancy[end] - recent_data.Occupancy[1]
    
    response = Dict(
        "current_occupancy" => round(current_occupancy, digits=2),
        "average_occupancy" => round(avg_occupancy, digits=2),
        "max_occupancy" => round(max_occupancy, digits=2),
        "min_occupancy" => round(min_occupancy, digits=2),
        "recent_trend" => trend > 0 ? "increasing" : "decreasing",
        "trend_value" => round(trend, digits=2),
        "last_date" => string(cached_data.Date[end]),
        "data_points" => nrow(cached_data)
    )
    
    return HTTP.Response(200, headers, JSON3.write(response))
end

function handle_forecast(headers, days=7)
    if isnothing(cached_data)
        load_warehouse_data()
    end
    
    if isnothing(cached_data)
        return HTTP.Response(500, headers, 
                            JSON3.write(Dict("error" => "No data available")))
    end
    
    println("🔮 Generating forecast for $days days...")
    
    # Generate forecast
    forecast_df = run_arima_forecast(cached_data, steps=days, 
                                    save_path="results/api_forecast.csv")
    
    if nrow(forecast_df) == 0
        return HTTP.Response(500, headers, 
                            JSON3.write(Dict("error" => "Forecast generation failed")))
    end
    
    # Convert to JSON-friendly format
    forecast_data = [
        Dict(
            "date" => string(forecast_df.Date[i]),
            "predicted_occupancy" => round(forecast_df.Forecast[i], digits=2)
        )
        for i in 1:nrow(forecast_df)
    ]
    
    response = Dict(
        "forecast_horizon" => days,
        "generated_at" => string(now()),
        "forecasts" => forecast_data,
        "summary" => Dict(
            "avg_forecast" => round(mean(forecast_df.Forecast), digits=2),
            "max_forecast" => round(maximum(forecast_df.Forecast), digits=2),
            "min_forecast" => round(minimum(forecast_df.Forecast), digits=2)
        )
    )
    
    return HTTP.Response(200, headers, JSON3.write(response))
end

function handle_reload(headers)
    println("🔄 Reloading warehouse data...")
    
    result = load_warehouse_data()
    
    if isnothing(result)
        return HTTP.Response(500, headers, 
                            JSON3.write(Dict("error" => "Failed to reload data")))
    end
    
    response = Dict(
        "status" => "success",
        "message" => "Data reloaded successfully",
        "data_points" => nrow(result),
        "date_range" => "$(minimum(result.Date)) to $(maximum(result.Date))"
    )
    
    return HTTP.Response(200, headers, JSON3.write(response))
end

# Main execution
function start_server(host="127.0.0.1", port=8080)
    # Check if port is available
    try
        test_server = listen(IPv4(host), port)
        close(test_server)
    catch
        println("❌ Port $port is already in use!")
        println("   Kill existing processes: pkill julia")
        exit(1)
    end
    
    # Load initial data
    load_warehouse_data()
    
    # Print startup info
    println("=" ^ 70)
    println("🚀 Warehouse Forecast API Server")
    println("=" ^ 70)
    println("📍 Server: http://$host:$port")
    println()
    println("📡 Available Endpoints:")
    println("   GET  /                     - Health check")
    println("   GET  /health               - Health check")
    println("   GET  /current              - Current occupancy stats")
    println("   GET  /forecast?days=7      - Get forecast (default: 7 days)")
    println("   GET  /reload               - Reload warehouse data")
    println()
    println("📝 Example requests:")
    println("   curl http://$host:$port/current")
    println("   curl http://$host:$port/forecast?days=14")
    println()
    println("Press Ctrl+C to stop")
    println("=" ^ 70)
    println()
    
    try
        HTTP.serve(router, host, port; verbose=false)
    catch e
        if isa(e, InterruptException)
            println("\n👋 Server stopped")
        else
            println("\n❌ Server error: $e")
            rethrow(e)
        end
    end
end

# Start the server
start_server()