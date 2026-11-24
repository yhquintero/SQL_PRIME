using SQLPrime.Core.Catalog;
using Xunit;

namespace SQLPrime.Core.Tests.Catalog;

public class CatalogLoaderTests
{
    [Fact]
    public void Validate_ThrowsOnDuplicateName()
    {
        var catalog = new InstallerCatalog
        {
            SchemaVersion = 1,
            Installers =
            [
                new InstallerPackage { Name = "a.exe", Product = "10.0", Sp = "SP4", Kb = "1", Arch = "x64", Lang = "ENU", Size = 1, DirectUrl = "https://example.test/a.exe" },
                new InstallerPackage { Name = "a.exe", Product = "10.0", Sp = "SP4", Kb = "1", Arch = "x86", Lang = "ENU", Size = 1, DirectUrl = "https://example.test/b.exe" }
            ]
        };
        Assert.Throws<InvalidDataException>(() => CatalogLoader.Validate(catalog));
    }

    [Fact]
    public void Validate_ThrowsOnNonHttpsDirectUrl()
    {
        var catalog = new InstallerCatalog
        {
            SchemaVersion = 1,
            Installers = [new InstallerPackage { Name = "a.exe", Product = "10.0", Sp = "SP4", Kb = "1", Arch = "x64", Lang = "ENU", Size = 1, DirectUrl = "http://example.test/a.exe" }]
        };
        Assert.Throws<InvalidDataException>(() => CatalogLoader.Validate(catalog));
    }
}
