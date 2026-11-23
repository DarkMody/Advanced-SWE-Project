using Npgsql;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Liveness: the app is running.
app.MapGet("/health", () => Results.Ok(new { status = "Healthy" }));

// Readiness: the app can reach the database.
app.MapGet("/health/db", async (IConfiguration config) =>
{
    try
    {
        await using var conn = new NpgsqlConnection(config.GetConnectionString("Default"));
        await conn.OpenAsync();
        return Results.Ok(new { status = "Healthy", database = "up" });
    }
    catch (Exception)
    {
        return Results.Json(new { status = "Unhealthy", database = "down" }, statusCode: 503);
    }
});

app.Run();
