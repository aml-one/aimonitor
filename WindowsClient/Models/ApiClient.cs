using System.Net.Http;
using System.Net.Http.Json;
using System.Text;

namespace AiMonitorClient.Models;

public sealed class ApiClient : IDisposable
{
    private readonly HttpClient _http = new() { Timeout = Timeout.InfiniteTimeSpan }; // per-request CTS controls timeout
    private string _baseUrl;

    public ApiClient(string host, int port) =>
        _baseUrl = BuildUrl(host, port);

    public void UpdateEndpoint(string host, int port) =>
        _baseUrl = BuildUrl(host, port);

    public async Task<StatsResponse?> GetStatsAsync(CancellationToken ct = default)
    {
        var response = await _http.GetAsync($"{_baseUrl}/stats", ct);
        response.EnsureSuccessStatusCode();
        return await response.Content.ReadFromJsonAsync<StatsResponse>(ct);
    }

    /// <summary>POST /actions/{action}</summary>
    public async Task PostActionAsync(string action, CancellationToken ct = default)
    {
        var content = new StringContent("{}", Encoding.UTF8, "application/json");
        await _http.PostAsync($"{_baseUrl}/actions/{action}", content, ct);
    }

    public void Dispose() => _http.Dispose();

    private static string BuildUrl(string host, int port) => $"http://{host}:{port}";
}
