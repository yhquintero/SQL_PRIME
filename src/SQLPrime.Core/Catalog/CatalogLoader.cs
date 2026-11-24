using System.Text.Json;

namespace SQLPrime.Core.Catalog;

public static class CatalogLoader
{
    private static readonly JsonSerializerOptions JsonOptions = new() { PropertyNameCaseInsensitive = true };

    public static InstallerCatalog Load(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("Catalog file not found", path);
        var json = File.ReadAllText(path);
        var catalog = JsonSerializer.Deserialize<InstallerCatalog>(json, JsonOptions)
                      ?? throw new InvalidDataException("Catalog is empty or invalid");
        Validate(catalog);
        return catalog;
    }

    public static void Validate(InstallerCatalog catalog)
    {
        if (catalog.SchemaVersion < 1) throw new InvalidDataException("schemaVersion must be >= 1");
        if (catalog.Installers is null) throw new InvalidDataException("installers is required");
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var i in catalog.Installers)
        {
            if (string.IsNullOrWhiteSpace(i.Name)) throw new InvalidDataException("Installer name is required");
            if (!seen.Add(i.Name)) throw new InvalidDataException($"Duplicate installer: {i.Name}");
            if (i.Size <= 0) throw new InvalidDataException($"Invalid size: {i.Name}");
            if (!string.IsNullOrWhiteSpace(i.Sha256) && i.Sha256.Length != 64)
                throw new InvalidDataException($"Invalid sha256: {i.Name}");
            if (!string.IsNullOrWhiteSpace(i.DirectUrl) && !i.DirectUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
                throw new InvalidDataException($"directUrl must be https: {i.Name}");
        }
    }
}

public sealed class InstallerCatalog
{
    public int SchemaVersion { get; set; }
    public string? Publisher { get; set; }
    public string? Note { get; set; }
    public List<InstallerPackage> Installers { get; set; } = new();
}
