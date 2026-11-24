using SQLPrime.Core.Integrity;
using Xunit;

namespace SQLPrime.Core.Tests.Integrity;

public class HashVerifierTests
{
    [Fact]
    public void Verify_ReturnsInvalidWhenHashMismatch()
    {
        var tmp = Path.GetTempFileName();
        try
        {
            File.WriteAllBytes(tmp, [1, 2, 3]);
            var result = HashVerifier.Verify(tmp, expectedSize: 3, expectedSha256: new string('0', 64));
            Assert.True(result.Exists);
            Assert.True(result.SizeMatches);
            Assert.False(result.Sha256Matches);
            Assert.False(result.IsValid);
        }
        finally { File.Delete(tmp); }
    }

    [Fact]
    public void ComputeSha256_ReturnsExpectedLength()
    {
        var tmp = Path.GetTempFileName();
        try
        {
            File.WriteAllText(tmp, "abc");
            var hash = HashVerifier.ComputeSha256(tmp);
            Assert.Equal(64, hash.Length);
        }
        finally { File.Delete(tmp); }
    }
}
