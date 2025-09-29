module WarehouseForecast

export load_data, compute_aggregates, add_rolling_average, save_results

using CSV, DataFrames, Dates, Plots, Statistics

# Simple rolling average function (no external utils needed)
function rolling_average(data::Vector, window::Int)
    n = length(data)
    result = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        end_idx = i
        result[i] = mean(data[start_idx:end_idx])
    end
    
    return result
end

"""
    load_data(incoming_file, outgoing_file)

Load incoming and outgoing shipment CSVs.
Each file should have: date, volume
"""
function load_data(incoming_file::String, outgoing_file::String)
    incoming = CSV.read(incoming_file, DataFrame)
    outgoing = CSV.read(outgoing_file, DataFrame)

    # Standardize column names
    function standardize_columns!(df)
        # Find date column
        date_cols = ["date", "Date", "DATE", "timestamp", "Timestamp"]
        date_col = nothing
        for col in date_cols
            if col in names(df)
                date_col = col
                break
            end
        end
        
        if date_col !== nothing && date_col != "date"
            rename!(df, date_col => "date")
        elseif date_col === nothing
            error("No date column found. Expected one of: $date_cols")
        end
        
        # Find volume column  
        vol_cols = ["volume", "Volume", "VOLUME", "quantity", "Quantity", "amount", "Amount"]
        vol_col = nothing
        for col in vol_cols
            if col in names(df)
                vol_col = col
                break
            end
        end
        
        if vol_col !== nothing && vol_col != "volume"
            rename!(df, vol_col => "volume")
        elseif vol_col === nothing
            df[!, :volume] = ones(nrow(df))
            println("  ⚠️  No volume column found, using count of records")
        end
        
        # Ensure date column is Date type
        if eltype(df.date) != Date
            df.date = Date.(df.date)
        end
    end

    standardize_columns!(incoming)
    standardize_columns!(outgoing)

    incoming[!, :direction] .= "incoming"
    outgoing[!, :direction] .= "outgoing"

    return vcat(incoming, outgoing)
end

"""
    compute_aggregates(shipments::DataFrame)

Compute cumulative incoming, outgoing, and occupancy.
"""
function compute_aggregates(shipments::DataFrame)
    grouped = combine(groupby(shipments, [:date, :direction]),
                    :volume => sum => :daily_volume)

    wide = unstack(grouped, :direction, :daily_volume, fill=0.0)
    
    # Ensure we have both columns
    if !("incoming" in names(wide))
        wide[!, :incoming] = zeros(nrow(wide))
    end
    if !("outgoing" in names(wide))
        wide[!, :outgoing] = zeros(nrow(wide))
    end

    sort!(wide, :date)

    wide[!, :cumulative_incoming] = cumsum(wide.incoming)
    wide[!, :cumulative_outgoing] = cumsum(wide.outgoing)
    wide[!, :occupancy] = wide.cumulative_incoming .- wide.cumulative_outgoing
    
    # Ensure non-negative occupancy
    wide[!, :occupancy] = max.(0.0, wide.occupancy)

    # Rename columns to match ARIMA expectations
    rename!(wide, :date => :Date, :occupancy => :Occupancy)

    return wide
end

"""
    add_rolling_average(df, window)

Add rolling average of occupancy.
"""
function add_rolling_average(df::DataFrame; window::Int=3)
    df[!, :rolling_avg] = rolling_average(df.Occupancy, window)
    return df
end

"""
    save_results(df, output_csv, output_plot)

Save CSV and plot of occupancy.
"""
function save_results(df::DataFrame, output_csv::String, output_plot::String)
    CSV.write(output_csv, df)

    plt = plot(df.Date, df.Occupancy, label="Occupancy", lw=2)
    plot!(plt, df.Date, df.rolling_avg, label="Rolling Avg", lw=2, ls=:dash)
    xlabel!("Date")
    ylabel!("Space Usage")
    savefig(plt, output_plot)
    
    return df
end

end