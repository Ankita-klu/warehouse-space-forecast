module ARIMAForecast

    using CSV, DataFrames, Dates, Plots, Statistics, LinearAlgebra

    export run_arima_forecast

    # Try to use StateSpaceModels, fallback to manual implementation
    HAS_STATESPACE = false
    try
        using StateSpaceModels
        global HAS_STATESPACE = true
        println("✅ StateSpaceModels available - using real ARIMA")
    catch
        println("⚠️  StateSpaceModels not available - using AR approximation")
    end

    """
        ar_model_forecast(y, p, steps)
    
    Simple AR(p) model using least squares (ARIMA approximation)
    """
    function ar_model_forecast(y::Vector{Float64}, p::Int, steps::Int)
        n = length(y)
        if n < p + 5  # Need enough data points
            error("Not enough data points for AR($p) model. Need at least $(p+5) points, got $n")
        end
        
        # Apply differencing (the 'I' in ARIMA)
        diff_y = diff(y)  # First difference to make stationary
        
        # Build AR model on differenced data
        m = length(diff_y)
        Y = diff_y[(p+1):m]
        X = zeros(length(Y), p + 1)  # +1 for intercept
        
        # Design matrix for AR(p)
        X[:, 1] .= 1.0  # Intercept
        for i in 1:length(Y)
            for j in 1:p
                X[i, j+1] = diff_y[p + i - j]
            end
        end
        
        # Least squares estimation
        coeffs = X \ Y
        
        # Forecast differenced series
        diff_forecasts = Float64[]
        extended_diff = copy(diff_y)
        
        for step in 1:steps
            next_diff = coeffs[1]  # Intercept
            for j in 1:p
                if length(extended_diff) >= j
                    next_diff += coeffs[j+1] * extended_diff[end-j+1]
                end
            end
            push!(diff_forecasts, next_diff)
            push!(extended_diff, next_diff)
        end
        
        # Convert back to levels (undo differencing)
        forecasts = Float64[]
        last_level = y[end]
        
        for i in 1:steps
            last_level += diff_forecasts[i]
            push!(forecasts, max(0.0, last_level))  # Ensure non-negative
        end
        
        return forecasts
    end

    """
        exponential_smoothing_forecast(y, steps)
    
    Double exponential smoothing with trend
    """
    function exponential_smoothing_forecast(y::Vector{Float64}, steps::Int)
        n = length(y)
        if n < 3
            error("Need at least 3 data points for exponential smoothing")
        end
        
        α = 0.3  # Level smoothing
        β = 0.1  # Trend smoothing
        
        # Initialize
        level = mean(y[1:3])
        trend = mean(diff(y[1:3]))
        
        # Apply double exponential smoothing
        for i in 2:n
            prev_level = level
            level = α * y[i] + (1 - α) * (level + trend)
            trend = β * (level - prev_level) + (1 - β) * trend
        end
        
        # Generate forecasts
        forecasts = Float64[]
        for step in 1:steps
            forecast_val = level + step * trend
            push!(forecasts, max(0.0, forecast_val))
        end
        
        return forecasts
    end

    """
        run_arima_forecast(data::DataFrame; steps=7, save_path="results/space_forecast_arima.csv")

    Fits an ARIMA model (or approximation) on warehouse occupancy and forecasts future values.
    """
    function run_arima_forecast(data::DataFrame; 
        p::Int=1, 
        d::Int=1, 
        q::Int=1, 
        steps::Int=7, 
        save_path::String="results/space_forecast_arima.csv")

        # Ensure data has Date and Occupancy columns
        @assert "Date" in names(data) && "Occupancy" in names(data) "Data must have Date and Occupancy columns"

        # Convert to vector for modeling
        y = Vector{Float64}(data.Occupancy)
        n = length(y)

        println("Running time series forecast with $(n) data points...")
        
        forecast_values = Float64[]
        method_used = ""

        try
            if HAS_STATESPACE && n >= 10
                # Use real ARIMA if available and enough data
                println("  Using StateSpaceModels ARIMA($p, $d, $q)...")
                model = StateSpaceModels.SARIMA(y; order=(p, d, q))
                StateSpaceModels.fit!(model)
                forecast_result = StateSpaceModels.forecast(model, steps)
                
                forecast_values = if hasfield(typeof(forecast_result), :expected_value)
                    forecast_result.expected_value
                elseif hasfield(typeof(forecast_result), :mean)
                    forecast_result.mean
                else
                    Vector{Float64}(forecast_result)
                end
                
                method_used = "ARIMA($p,$d,$q)"
                
            elseif n >= 8
                # Use AR approximation
                println("  Using AR($p) approximation...")
                forecast_values = ar_model_forecast(y, min(p, n÷3), steps)
                method_used = "AR($p) approximation"
                
            else
                # Use exponential smoothing for short series
                println("  Using exponential smoothing (short series)...")
                forecast_values = exponential_smoothing_forecast(y, steps)
                method_used = "Exponential Smoothing"
            end

            # Ensure we got the right number of forecasts
            if length(forecast_values) != steps
                forecast_values = forecast_values[1:min(steps, length(forecast_values))]
            end
            
            # Ensure non-negative forecasts
            forecast_values = max.(0.0, forecast_values)

            # Prepare future dates
            last_date = maximum(data.Date)
            future_dates = [last_date + Day(i) for i in 1:length(forecast_values)]

            # Prepare DataFrame
            forecast_df = DataFrame(Date=future_dates, Forecast=forecast_values)

            # Save results
            CSV.write(save_path, forecast_df)
            println("✅ Forecast saved to: $save_path")

            # Create plot
            plot_path = replace(save_path, ".csv" => ".png")
            
            plt = plot(data.Date, y, label="Historical Occupancy", lw=2, 
                      title="Warehouse Forecast ($method_used)", 
                      xlabel="Date", ylabel="Occupancy")
            
            plot!(plt, future_dates, forecast_values, 
                  label="$method_used Forecast", lw=2, linestyle=:dash)
            
            vline!(plt, [last_date], label="Forecast Start", linestyle=:dot, alpha=0.7)

            # Add confidence band for AR/ARIMA methods
            if method_used != "Exponential Smoothing" && length(y) > 5
                recent_std = std(y[max(1, end-10):end])
                upper = forecast_values .+ 1.96 * recent_std
                lower = max.(0.0, forecast_values .- 1.96 * recent_std)
                plot!(plt, future_dates, upper, fillrange=lower, alpha=0.2, 
                      label="95% Confidence", color=:gray)
            end

            savefig(plt, plot_path)
            println("✅ Plot saved to: $plot_path")
            println("✅ Method used: $method_used")

            return forecast_df

        catch e
            println("❌ Error during forecasting:")
            println(e)
            return DataFrame()
        end
    end

end # module