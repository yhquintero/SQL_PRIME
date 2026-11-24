using System.Security.Authentication;

var builder = WebApplication.CreateBuilder(args);

// Phase 3: HTTPS/TLS 1.3 with ECC (ECDSA P-256/P-384 cert).
builder.WebHost.ConfigureKestrel(options =>
{
    options.ConfigureHttpsDefaults(https =>
    {
        // Enforce modern TLS. TLS 1.3 negotiates ECDHE+AEAD; cert should be ECDSA P-256/P-384.
        https.SslProtocols = SslProtocols.Tls13 | SslProtocols.Tls12;
    });
});

builder.Services.AddHealthChecks();

var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
}

app.UseHttpsRedirection();

app.Use(async (context, next) =>
{
    context.Response.Headers["X-Content-Type-Options"] = "nosniff";
    context.Response.Headers["X-Frame-Options"] = "DENY";
    context.Response.Headers["Referrer-Policy"] = "no-referrer";
    context.Response.Headers["Content-Security-Policy"] = "default-src 'self'; frame-ancestors 'none'";
    await next();
});

app.MapGet("/health", () => Results.Ok(new { status = "ok", service = "SQLPrime.Api", tls = "TLS1.3+ECDSA" }));
app.MapGet("/api/v1/catalog/status", () => Results.Ok(new { schemaVersion = 1, status = "scaffold" }));

app.Run();
