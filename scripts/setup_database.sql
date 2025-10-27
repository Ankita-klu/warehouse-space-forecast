-- Create database
CREATE DATABASE warehouse_forecast;

-- Connect to it
\c warehouse_forecast

-- Create shipments table
CREATE TABLE shipments (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    volume FLOAT NOT NULL,
    direction VARCHAR(20) NOT NULL,
    category VARCHAR(100),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create forecasts table
CREATE TABLE forecasts (
    id SERIAL PRIMARY KEY,
    forecast_date DATE NOT NULL,
    predicted_occupancy FLOAT NOT NULL,
    model_type VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create occupancy_history table
CREATE TABLE occupancy_history (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL UNIQUE,
    incoming FLOAT DEFAULT 0,
    outgoing FLOAT DEFAULT 0,
    occupancy FLOAT NOT NULL,
    rolling_avg FLOAT
);

-- Create indexes
CREATE INDEX idx_shipments_date ON shipments(date);
CREATE INDEX idx_forecasts_date ON forecasts(forecast_date);
CREATE INDEX idx_occupancy_date ON occupancy_history(date);