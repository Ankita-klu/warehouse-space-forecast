# Warehouse Space Forecasting System

A Julia-based system for analyzing and forecasting warehouse space utilization using historical shipment data.

## Features

- 📊 **Historical Analysis**: Process incoming/outgoing shipment data
- 📈 **Time Series Forecasting**: ARIMA-style forecasting with multiple fallback methods
- 📉 **Visualizations**: Automated plot generation for trends and forecasts
- 🔄 **Rolling Averages**: Smooth occupancy trends
- 💾 **CSV Export**: Save results for further analysis

## Project Structure

```
warehouse-space-forecast/
├── data/
│   ├── incoming_shipments.csv    # Historical incoming shipments
│   └── outgoing_shipments.csv    # Historical outgoing shipments
├── src/
│   ├── WarehouseForecast.jl      # Main processing module
│   └── arima_forecast.jl         # Time series forecasting module
├── scripts/
│   └── forecast.jl               # Main execution script
├── results/                      # Generated outputs (CSV files and plots)
└── README.md
```

## Usage

1. **Prepare your data**: Place CSV files in the `data/` directory with columns:
   - Date column: `date`, `Date`, or `timestamp`
   - Volume column: `volume`, `quantity`, or `amount`

2. **Run the forecast**:
   ```bash
   julia scripts/forecast.jl
   ```

3. **Check results**: Output files will be saved in `results/`:
   - `space_usage.csv`: Historical occupancy data
   - `space_forecast_plot.png`: Historical trends visualization
   - `space_forecast_arima.csv`: Future forecasts
   - `space_forecast_arima.png`: Forecast visualization with confidence bands

## Forecasting Methods

The system automatically selects the best available forecasting method:

1. **ARIMA Models** (if StateSpaceModels.jl is available)
2. **AR Approximation** (autoregressive modeling with differencing)
3. **Exponential Smoothing** (for shorter time series)

## Requirements

- Julia 1.6+
- Required packages: `CSV`, `DataFrames`, `Dates`, `Plots`, `Statistics`
- Optional: `StateSpaceModels` (for full ARIMA functionality)

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/warehouse-space-forecast.git
   cd warehouse-space-forecast
   ```

2. Install Julia dependencies:
   ```julia
   using Pkg
   Pkg.add(["CSV", "DataFrames", "Dates", "Plots", "Statistics"])
   ```

3. Optionally install StateSpaceModels for advanced ARIMA:
   ```julia
   Pkg.add("StateSpaceModels")
   ```

## Example Output

The system generates:
- Historical occupancy trends
- 7-day forward forecasts
- Confidence intervals for predictions
- Rolling averages for trend smoothing

