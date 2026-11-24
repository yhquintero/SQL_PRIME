namespace SQLPrime.Core.Catalog;

public sealed record InstallerPackage(
    string Name,
    string Product,
    string ServicePack,
    string Kb,
    string Architecture,
    string Language,
    long SizeBytes,
    string? Sha256,
    string? DirectUrl,
    string? SupportUrl
);
