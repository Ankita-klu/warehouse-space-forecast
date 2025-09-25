# 📦 Warehouse Space Utilization Forecast

This project forecasts **warehouse space usage over time** to avoid overflow or underuse.  
It uses **incoming/outgoing shipment data** to compute:
- Cumulative incoming & outgoing volumes
- Current occupancy
- Rolling averages
- Forecast trends (plots + CSV outputs)

---

## 📂 Project Structure
warehouse-space-forecast/
├─ src/ # Core Julia modules
│ ├─ WarehouseForecast.jl
│ └─ utils.jl
│
├─ scripts/ # Main runnable files
│ └─ forecast.jl
│
├─ data/ # Input data
│ ├─ incoming_shipments.csv
│ ├─ outgoing_shipments.csv
│ └─ README.md
│
├─ results/ # Outputs
│ ├─ space_usage.csv
│ ├─ space_forecast.csv
│ └─ space_forecast_plot.png
│
├─ docs/ # Documentation
│ └─ methodology.md
│
├─ README.md # Project overview
└─ .gitignoregit status

