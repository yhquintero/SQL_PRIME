using System.Security.Authentication;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.WebHost.ConfigureKestrel(options =>
{
    options.ConfigureHttpsDefaults(https =>
    {
        https.SslProtocols = SslProtocols.Tls13 | SslProtocols.Tls12;
    });
});

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddFixedWindowLimiter("fixed", limiter =>
    {
        limiter.PermitLimit = 60;
        limiter.Window = TimeSpan.FromMinutes(1);
        limiter.QueueLimit = 0;
    });
});

var app = builder.Build();

app.UseRateLimiter();

app.Use(async (context, next) =>
{
    // Basic audit trail (Phase 3 scaffold). Replace with structured audit sink + auth identity.
    app.Logger.LogInformation("AUDIT {Method} {Path} {RemoteIp}", context.Request.Method, context.Request.Path, context.Connection.RemoteIpAddress);
    await next();
});

app.Use(async (context, next) =>
{
    context.Response.Headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains";
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    context.Response.Headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'; base-uri 'none'";
    await next();
});

app.MapGet("/health", () => Results.Ok(new
{
    status = "ok",
    service = "SQLPrime.Api",
    tls = "TLS 1.3 preferred, TLS 1.2 fallback",
    timestampUtc = DateTime.UtcNow
})).RequireRateLimiting("fixed");

app.Run();
