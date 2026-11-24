using System.Security.Cryptography;

namespace SQLPrime.Core.Integrity;

public static class HashVerifier
{
    public static string ComputeSha256(string path)
    {
        if (!File.Exists(path)) throw new FileNotFoundException("File not found", path);
        using var stream = File.OpenRead(path);
        var hash = SHA256.HashData(stream);
        return Convert.ToHexString(hash).ToLowerInvariant();
    }

    public static FileVerificationResult Verify(string path, long? expectedSize = null, string? expectedSha256 = null)
    {
        var result = new FileVerificationResult { Path = path, Exists = File.Exists(path) };
        if (!result.Exists) return result;
        var fi = new FileInfo(path);
        result.ActualSize = fi.Length;
        result.SizeMatches = expectedSize is null || expectedSize <= 0 || fi.Length == expectedSize;
        if (!string.IsNullOrWhiteSpace(expectedSha256))
        {
            result.ActualSha256 = ComputeSha256(path);
            result.Sha256Matches = string.Equals(result.ActualSha256, expectedSha256, StringComparison.OrdinalIgnoreCase);
        }
        result.IsValid = result.SizeMatches && (result.Sha256Matches ?? true);
        return result;
    }
}

public sealed class FileVerificationResult
{
    public string Path { get; set; } = "";
    public bool Exists { get; set; }
    public long ActualSize { get; set; }
    public string? ActualSha256 { get; set; }
    public bool SizeMatches { get; set; }
    public bool? Sha256Matches { get; set; }
    public bool IsValid { get; set; }
}
