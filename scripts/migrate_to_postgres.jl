include("../src/database.jl")
using .Database

incoming = "data/incoming_shipments.csv"
outgoing = "data/outgoing_shipments.csv"

println("🚀 Starting migration...")
migrate_csv_to_db(incoming, outgoing)
println("🎉 Migration complete!")
