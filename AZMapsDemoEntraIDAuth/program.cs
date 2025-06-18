using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Threading.Tasks;
using Microsoft.Identity.Client;
using System.Web;

class Program
{
    static async Task Main(string[] args)
    {
        // Azure AD app registration
        string tenantId = "<Your Tenant ID>";
        string clientId = "<Your Client ID>";
        string clientSecret = "<Your Secret>";

        string mapsClientId = "<Your Azure Maps Client ID (not your SPN Client ID>"; // from Azure Maps account

        // Acquire token using MSAL
        var app = ConfidentialClientApplicationBuilder.Create(clientId)
            .WithClientSecret(clientSecret)
            .WithAuthority(new Uri($"https://login.microsoftonline.com/{tenantId}"))
            .Build();

        string[] scopes = new[] { "https://atlas.microsoft.com/.default" };
        var result = await app.AcquireTokenForClient(scopes).ExecuteAsync();
        string accessToken = result.AccessToken;


        // Prepare address query
        string address = "500 W 2nd St, Austin, TX";
        string encodedAddress = HttpUtility.UrlEncode(address);

        // Build REST API request
        string url = $"https://atlas.microsoft.com/search/address/json?api-version=1.0&query={encodedAddress}";

        using var httpClient = new HttpClient();
        httpClient.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        httpClient.DefaultRequestHeaders.Add("x-ms-client-id", mapsClientId); // This is critical for Entra ID auth

        var response = await httpClient.GetAsync(url);
        string content = await response.Content.ReadAsStringAsync();

        Console.WriteLine("Response:");
        Console.WriteLine(content);

    }
}
