using System;
using System.IdentityModel.Tokens.Jwt;
using System.Linq;

class Program
{
    static void Main(string[] args)
    {
        string token = "your_jwt_token_here";

        Console.Write("Please enter your JWT token: ");
        token = Console.ReadLine();

        var handler = new JwtSecurityTokenHandler();
        var jsonToken = handler.ReadToken(token) as JwtSecurityToken;

        if (jsonToken != null)
        {
            var claims = jsonToken.Claims;

            foreach (var claim in claims)
            {
                Console.WriteLine($"{claim.Type}: {claim.Value}");
            }

            // Extract and convert iat, nbf, and exp claims
            var iatClaim = claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Iat)?.Value;
            var nbfClaim = claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Nbf)?.Value;
            var expClaim = claims.FirstOrDefault(c => c.Type == JwtRegisteredClaimNames.Exp)?.Value;

            if (iatClaim != null)
            {
                DateTime iatDateTime = UnixTimeStampToDateTime(long.Parse(iatClaim));
                Console.WriteLine($"iat: {iatDateTime} (Local: {ConvertToLocalTime(iatDateTime)})");
            }

            if (nbfClaim != null)
            {
                DateTime nbfDateTime = UnixTimeStampToDateTime(long.Parse(nbfClaim));
                Console.WriteLine($"nbf: {nbfDateTime} (Local: {ConvertToLocalTime(nbfDateTime)})");
            }

            if (expClaim != null)
            {
                DateTime expDateTime = UnixTimeStampToDateTime(long.Parse(expClaim));
                Console.WriteLine($"exp: {expDateTime} (Local: {ConvertToLocalTime(expDateTime)})");
            }
        }
        else
        {
            Console.WriteLine("Invalid token.");
        }
    }

    public static DateTime UnixTimeStampToDateTime(long unixTimeStamp)
    {
        // Unix timestamp is seconds past epoch
        DateTime dateTime = DateTimeOffset.FromUnixTimeSeconds(unixTimeStamp).UtcDateTime;
        return dateTime;
    }

    public static DateTime ConvertToLocalTime(DateTime dateTime)
    {
        TimeZoneInfo localZone = TimeZoneInfo.Local;
        DateTime localTime = TimeZoneInfo.ConvertTimeFromUtc(dateTime, localZone);
        return localTime;
    }
}

