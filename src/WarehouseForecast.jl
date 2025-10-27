module WarehouseForecast

using CSV
using DataFrames
using Dates
using HTTP
using JSON3
using LibPQ
using Plots
using Statistics
using Tables

# Export main functions
export load_data, compute_aggregates, add_rolling_average, save_results

"""
    load_data(incoming_file::String, outgoing_file::String)

Load and merge incoming and outgoing shipment data from CSV files.
"""
function load_data(incoming_file::String, outgoing_file::String)
    # Read CSV files
    incoming = CSV.read(incoming_file, DataFrame)
    outgoing = CSV.read(outgoing_file, DataFrame)
    
    # Ensure date column is parsed correctly
    incoming.date = Date.(incoming.date)
    outgoing.date = Date.(outgoing.date)
    
    # Add direction labels
    incoming[!, :direction] = fill("incoming", nrow(incoming))
    outgoing[!, :direction] = fill("outgoing", nrow(outgoing))
    
    # Combine datasets
    shipments = vcat(incoming, outgoing)
    
    # Sort by date
    sort!(shipments, :date)
    
    return shipments
end

"""
    compute_aggregates(shipments::DataFrame)

Compute daily aggregates: sum of incoming, outgoing, and net occupancy.
"""
function compute_aggregates(shipments::DataFrame)
    # Group by date and direction, sum volumes
    grouped = combine(groupby(shipments, [:date, :direction]), :volume => sum => :total_volume)
    
    # Pivot to get incoming and outgoing columns
    incoming_df = filter(row -> row.direction == "incoming", grouped)
    outgoing_df = filter(row -> row.direction == "outgoing", grouped)
    
    # Get all unique dates
    all_dates = unique(shipments.date)
    sort!(all_dates)
    
    # Create result DataFrame
    result = DataFrame(Date = all_dates)
    
    # Add incoming volumes (0 if no data for that day)
    incoming_dict = Dict(row.date => row.total_volume for row in eachrow(incoming_df))
    result.incoming = [get(incoming_dict, d, 0) for d in all_dates]
    
    # Add outgoing volumes (0 if no data for that day)
    outgoing_dict = Dict(row.date => row.total_volume for row in eachrow(outgoing_df))
    result.outgoing = [get(outgoing_dict, d, 0) for d in all_dates]
    
    # Calculate net occupancy (cumulative sum)
    result.Occupancy = cumsum(result.incoming .- result.outgoing)
    
    return result
end

"""
    add_rolling_average(df::DataFrame; window::Int=3)

Add rolling average column to smooth occupancy trends.
"""
function add_rolling_average(df::DataFrame; window::Int=3)
    n = nrow(df)
    rolling_avg = zeros(n)
    
    for i in 1:n
        start_idx = max(1, i - window + 1)
        end_idx = i
        rolling_avg[i] = mean(df.Occupancy[start_idx:end_idx])
    end
    
    df.rolling_avg = rolling_avg
    return df
end

"""
    save_results(df::DataFrame, csv_path::String, plot_path::String)

Save aggregated data to CSV and create visualization.
"""
function save_results(df::DataFrame, csv_path::String, plot_path::String)
    # Save to CSV
    CSV.write(csv_path, df)
    println("✅ Results saved to: $csv_path")
    
    # Create plot
    plt = plot(df.Date, df.Occupancy, 
               label="Daily Occupancy", 
               lw=2, 
               title="Warehouse Space Usage Over Time",
               xlabel="Date", 
               ylabel="Net Occupancy (units)",
               legend=:topleft)
    
    plot!(plt, df.Date, df.rolling_avg, 
          label="3-day Rolling Avg", 
          lw=2, 
          linestyle=:dash)
    
    savefig(plt, plot_path)
    println("✅ Plot saved to: $plot_path")
    
    return nothing
end

end # module