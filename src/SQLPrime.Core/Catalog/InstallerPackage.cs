namespace SQLPrime.Core.Catalog;

public sealed class InstallerPackage
{
    public string Name { get; set; } = "";
    public string Product { get; set; } = "";
    public string Sp { get; set; } = "";
    public string Kb { get; set; } = "";
    public string Arch { get; set; } = "";
    public string Lang { get; set; } = "";
    public long Size { get; set; }
    public string? Sha256 { get; set; }
    public string? DirectUrl { get; set; }
    public string? Support { get; set; }
    public string? VerifiedAt { get; set; }
    public string? VerifiedFrom { get; set; }
}
