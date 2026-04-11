using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using Azure.Core;
using Azure.Identity;

internal static class Program
{
    // -------------------------------
    // REQUIRED SETTINGS (EDIT THESE)
    // -------------------------------
    private const string TenantId = "<Tenant_ID>";
    private const string ClientId = "<Client_ID>";
    private const string ClientSecret = "<Client_Secret>";

    private const string PurviewName = "<Your Purview Name>";   // e.g. "markm-purview"
    private const string PurviewResource = "https://purview.azure.net";
    private static readonly Uri PurviewBaseUri = new($"https://{PurviewName}.purview.azure.com/");

    // Pick a concrete type you expect to exist in your collection
    private const string AssetTypeToSearch = "azure_sql_table";
    private const int SearchLimit = 1000;
    private const int LineageDepth = 5;

    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNameCaseInsensitive = true,
        WriteIndented = true
    };

    public static async Task Main()
    {
        // Acquire token (client credentials) using Azure.Identity
        var token = await GetPurviewAccessTokenAsync();
        Console.WriteLine("Access token acquired. (not printing token for safety)");

        using var http = new HttpClient { BaseAddress = PurviewBaseUri, Timeout = TimeSpan.FromSeconds(60) };
        http.DefaultRequestHeaders.Accept.Add(new MediaTypeWithQualityHeaderValue("application/json"));
        http.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1) Get typedefs
        var typedefs = await InvokePurviewApiAsync<JsonElement>(
            http,
            HttpMethod.Get,
            "datamap/api/atlas/v2/types/typedefs");

        // 2) Find DataSet-derived types
        var dataSetTypes = GetDataSetDerivedTypes(typedefs);
        Console.WriteLine($"Found {dataSetTypes.Count} DataSet-derived types.");
        // Console.WriteLine(JsonSerializer.Serialize(dataSetTypes, JsonOpts));

        // 3) Search assets (Atlas search/basic) for a concrete type
        var searchBody = new
        {
            typeName = AssetTypeToSearch,
            limit = SearchLimit
        };

        var searchResult = await InvokePurviewApiAsync<JsonElement>(
            http,
            HttpMethod.Post,
            "datamap/api/atlas/v2/search/basic",
            body: searchBody);

        var entities = ExtractEntities(searchResult);
        Console.WriteLine($"Search returned {entities.Count} entities for typeName='{AssetTypeToSearch}'.");

        // Print minimal view (first 25)
        var preview = entities.Take(25).Select(e => new
        {
            guid = e.Guid,
            typeName = e.TypeName,
            displayText = e.DisplayText
        });
        Console.WriteLine(JsonSerializer.Serialize(preview, JsonOpts));

        // 4) Lineage loop (first N or all)
        var lineageResults = new List<JsonElement>();

        foreach (var e in entities)
        {
            if (string.IsNullOrWhiteSpace(e.Guid)) continue;

            // IMPORTANT: use literal '&' not '&amp;'
            var lineagePath = $"datamap/api/atlas/v2/lineage/{e.Guid}?direction=BOTH&depth={LineageDepth}";

            var lineage = await InvokePurviewApiAsync<JsonElement>(
                http,
                HttpMethod.Get,
                lineagePath);

            lineageResults.Add(lineage);
        }

        Console.WriteLine($"Lineage calls completed for {lineageResults.Count} entities.");
        Console.WriteLine(JsonSerializer.Serialize(lineageResults.Take(5), JsonOpts)); // show first 5
    }

    /// <summary>
    /// Gets an Entra ID access token for Purview using client credentials.
    /// Tokens are time-bound and typically ~1 hour TTL in most environments.
    /// </summary>
    private static async Task<string> GetPurviewAccessTokenAsync()
    {
        var cred = new ClientSecretCredential(TenantId, ClientId, ClientSecret);
        var ctx = new TokenRequestContext(new[] { $"{PurviewResource}/.default" });

        AccessToken token = await cred.GetTokenAsync(ctx, CancellationToken.None);
        return token.Token;
    }

    /// <summary>
    /// Generic Purview REST caller that prints helpful diagnostics on 401/403/404.
    /// </summary>
    private static async Task<T> InvokePurviewApiAsync<T>(
        HttpClient http,
        HttpMethod method,
        string relativePath,
        object? body = null)
    {
        using var req = new HttpRequestMessage(method, relativePath);

        if (body is not null)
        {
            var json = JsonSerializer.Serialize(body, JsonOpts);
            req.Content = new StringContent(json, Encoding.UTF8, "application/json");
        }

        using var resp = await http.SendAsync(req);

        var respText = await resp.Content.ReadAsStringAsync();

        if (!resp.IsSuccessStatusCode)
        {
            Console.Error.WriteLine($"Purview API call failed: HTTP {(int)resp.StatusCode} {resp.ReasonPhrase}");
            if (!string.IsNullOrWhiteSpace(respText))
                Console.Error.WriteLine($"Response body: {respText}");

            resp.EnsureSuccessStatusCode();
        }

        if (typeof(T) == typeof(string))
            return (T)(object)respText;

        return JsonSerializer.Deserialize<T>(respText, JsonOpts)
               ?? throw new InvalidOperationException("Failed to deserialize response JSON.");
    }

    private static List<string> GetDataSetDerivedTypes(JsonElement typedefsRoot)
    {
        // typedefsRoot.entityDefs[].superTypes contains "DataSet"
        var results = new List<string>();

        if (!typedefsRoot.TryGetProperty("entityDefs", out var entityDefs) || entityDefs.ValueKind != JsonValueKind.Array)
            return results;

        foreach (var ed in entityDefs.EnumerateArray())
        {
            var name = ed.TryGetProperty("name", out var n) ? n.GetString() : null;
            if (string.IsNullOrWhiteSpace(name) || name == "DataSet") continue;

            if (ed.TryGetProperty("superTypes", out var st) && st.ValueKind == JsonValueKind.Array)
            {
                foreach (var s in st.EnumerateArray())
                {
                    if (string.Equals(s.GetString(), "DataSet", StringComparison.OrdinalIgnoreCase))
                    {
                        results.Add(name);
                        break;
                    }
                }
            }
        }

        return results;
    }

    private static List<AtlasEntity> ExtractEntities(JsonElement searchRoot)
    {
        var results = new List<AtlasEntity>();

        if (!searchRoot.TryGetProperty("entities", out var entities) || entities.ValueKind != JsonValueKind.Array)
            return results;

        foreach (var e in entities.EnumerateArray())
        {
            results.Add(new AtlasEntity
            {
                Guid = e.TryGetProperty("guid", out var g) ? g.GetString() : null,
                TypeName = e.TryGetProperty("typeName", out var t) ? t.GetString() : null,
                DisplayText = e.TryGetProperty("displayText", out var d) ? d.GetString() : null
            });
        }

        return results;
    }

    private sealed class AtlasEntity
    {
        public string? Guid { get; init; }
        public string? TypeName { get; init; }
        public string? DisplayText { get; init; }
    }
}
