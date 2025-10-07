module Database

using LibPQ, DataFrames, Dates, CSV

export connect_db, migrate_csv_to_db, load_from_db, save_forecast_to_db, save_occupancy_to_db

function connect_db()
    try
        conn = LibPQ.Connection("dbname=warehouse_forecast")
        println("✅ Connected to PostgreSQL")
        return conn
    catch e
        error("❌ Connection failed: $e")
    end
end

function migrate_csv_to_db(incoming_file::String, outgoing_file::String)
    println("📦 Migrating CSV data to PostgreSQL...")
    
    conn = connect_db()
    
    try
        incoming = CSV.read(incoming_file, DataFrame)
        outgoing = CSV.read(outgoing_file, DataFrame)
        
        incoming[!, :direction] = fill("incoming", nrow(incoming))
        outgoing[!, :direction] = fill("outgoing", nrow(outgoing))
        
        all_data = vcat(incoming, outgoing)
        
        for row in eachrow(all_data)
            query = """
            INSERT INTO shipments (date, volume, direction)
            VALUES ('$(row.date)', $(row.volume), '$(row.direction)');
            """
            execute(conn, query)
        end
        
        println("✅ Migrated $(nrow(all_data)) records to database")
        
    finally
        close(conn)
    end
end

function load_from_db()
    conn = connect_db()
    
    try
        result = execute(conn, "SELECT date, volume, direction FROM shipments ORDER BY date")
        df = DataFrame(result)
        
        # Keep lowercase to match WarehouseForecast expectations
        # Column names should already be lowercase from SQL
        
        println("✅ Loaded $(nrow(df)) records from database")
        return df
        
    finally
        close(conn)
    end
end

function save_forecast_to_db(forecast_df::DataFrame, model_type::String="ARIMA")
    conn = connect_db()
    
    try
        for row in eachrow(forecast_df)
            # Handle both Date and date column names
            date_val = hasproperty(row, :Date) ? row.Date : row.date
            forecast_val = hasproperty(row, :Forecast) ? row.Forecast : row.forecast
            
            query = """
            INSERT INTO forecasts (forecast_date, predicted_occupancy, model_type)
            VALUES ('$date_val', $forecast_val, '$model_type');
            """
            execute(conn, query)
        end
        
        println("✅ Saved $(nrow(forecast_df)) forecast records to database")
        
    finally
        close(conn)
    end
end

function save_occupancy_to_db(occupancy_df::DataFrame)
    conn = connect_db()
    
    try
        for row in eachrow(occupancy_df)
            # Handle both capitalized and lowercase column names
            date_val = hasproperty(row, :Date) ? row.Date : row.date
            occ_val = hasproperty(row, :Occupancy) ? row.Occupancy : row.occupancy
            
            query = """
            INSERT INTO occupancy_history (date, incoming, outgoing, occupancy, rolling_avg)
            VALUES ('$date_val', $(row.incoming), $(row.outgoing), 
                    $occ_val, $(row.rolling_avg))
            ON CONFLICT (date) DO UPDATE SET
                incoming = EXCLUDED.incoming,
                outgoing = EXCLUDED.outgoing,
                occupancy = EXCLUDED.occupancy,
                rolling_avg = EXCLUDED.rolling_avg;
            """
            execute(conn, query)
        end
        
        println("✅ Saved $(nrow(occupancy_df)) occupancy records to database")
        
    finally
        close(conn)
    end
end

end # module
