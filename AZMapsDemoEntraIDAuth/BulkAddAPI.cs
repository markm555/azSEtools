/*
** This program requires Azure MAPS Data Contributor permission to work
*/

using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text;
using System.Threading.Tasks;
using Microsoft.Identity.Client;
using System.Web;

class Program
{

    private static readonly string tenantId = "<Tenanat ID>";
    private static readonly string clientId = "<Client ID>";
    private static readonly string clientSecret = "<Client Secret>";
    private static readonly string mapsClientId = "<Map Service Client ID, not SPN Client ID>";
    private static readonly string scope = "https://atlas.microsoft.com/.default";
    private static readonly string authority = $"https://login.microsoftonline.com/{tenantId}/2.0";
    private static readonly string batchUrl = "https://atlas.microsoft.com/search/address/batch/json?api-version=1.0";

    static async Task Main()
    {
        var app = ConfidentialClientApplicationBuilder.Create(clientId)
            .WithClientSecret(clientSecret)
            .WithAuthority(new Uri($"https://login.microsoftonline.com/{tenantId}/v2.0")) // Explicitly using v2.0
            .Build();

        string[] scopes = new[] { "https://atlas.microsoft.com/.default" };
        var result = await app.AcquireTokenForClient(scopes).ExecuteAsync();
        string accessToken = result.AccessToken;

        // Define the address list.  In this case I have the addresses of the Microsoft offices in 4 major Texas cities.
        var addresses = new[]
        {
            "10900 Stonelake Blvd, Austin, TX",
            "7000 George Bush, Irving, TX",
            "401 Sontera Blvd, San Antonio, TX",
            "750 Town and Country Blvd, Houston, TX"
        };

        // Create batch payload
        var batchItems = addresses.Select(addr => new { addressLine = addr }).ToArray();
        var batchPayload = new { batchItems };
        string payloadJson = System.Text.Json.JsonSerializer.Serialize(batchPayload);

        // Create HTTP request to Azure Maps Batch Geocode endpoint
        var httpClient = new HttpClient();
        var request = new HttpRequestMessage(HttpMethod.Post, "https://atlas.microsoft.com/geocode:batch?api-version=2023-06-01")
        {
            Content = new StringContent(payloadJson, Encoding.UTF8, "application/json")
        };
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        request.Headers.Add("x-ms-client-id", mapsClientId); // Azure Maps resource client ID

        // Send request and read response
        var response = await httpClient.SendAsync(request);
        var responseBody = await response.Content.ReadAsStringAsync();

        Console.WriteLine("Batch Geocode Response:");
        Console.WriteLine(responseBody);
    }
}
