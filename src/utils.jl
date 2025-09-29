using HTTP, JSON3

function router(req::HTTP.Request)
    if req.target == "/forecast"
        return HTTP.Response(200, JSON3.write(Dict("message" => "Hello from Julia API 🚀")))
    else
        return HTTP.Response(404, "Not found")
    end
end

println("🚀 API running at http://127.0.0.1:8080/forecast")
HTTP.serve(router, "127.0.0.1", 8080)
