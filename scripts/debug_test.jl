# Debug test script
println("Starting debug test...")

# Test 1: Check if file exists
warehouse_file = joinpath(@__DIR__, "..", "src", "WarehouseForecast.jl")
println("Looking for WarehouseForecast.jl at: $warehouse_file")
println("File exists: $(isfile(warehouse_file))")

if isfile(warehouse_file)
    println("\nFull file contents:")
    println("=" ^ 60)
    content = read(warehouse_file, String)
    println(content)
    println("=" ^ 60)
else
    println("❌ File not found!")
    exit(1)
end

# Test 2: Try to include the file
try
    println("\nTrying to include WarehouseForecast.jl...")
    include(warehouse_file)
    println("✅ Include successful")
catch e
    println("❌ Include failed:")
    println(e)
    exit(1)
end

# Test 3: Check if module is available
try
    println("\nTrying to use Main.WarehouseForecast...")
    using Main.WarehouseForecast
    println("✅ Module import successful")
catch e
    println("❌ Module import failed:")
    println(e)
    exit(1)
end

# Test 4: Check available functions
println("\nAvailable functions in WarehouseForecast:")
for name in names(Main.WarehouseForecast)
    println("  - $name")
end

println("\n🎉 All tests passed!")