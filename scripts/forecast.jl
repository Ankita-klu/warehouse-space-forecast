using CSV, DataFrames, Statistics

incoming = CSV.read("data/incoming_shipments.csv", DataFrame)
outgoing = CSV.read("data/outgoing_shipments.csv", DataFrame)

println("Incoming:")
println(incoming)

println("Outgoing:")
println(outgoing)
