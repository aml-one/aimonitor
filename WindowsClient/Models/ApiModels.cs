using System.Text.Json.Serialization;

namespace AiMonitorClient.Models;

// ── Top-level response ──────────────────────────────────────────────────────

public record StatsResponse(
    [property: JsonPropertyName("timestamp")] string Timestamp,
    [property: JsonPropertyName("system")]    SystemData? System,
    [property: JsonPropertyName("services")]  ServicesData? Services);

// ── System ──────────────────────────────────────────────────────────────────

public record SystemData(
    [property: JsonPropertyName("cpu")]    CpuData    Cpu,
    [property: JsonPropertyName("memory")] MemoryData Memory,
    [property: JsonPropertyName("gpu")]    GpuData    Gpu);

public record CpuData(
    [property: JsonPropertyName("usage_pct")]    double   UsagePct,
    [property: JsonPropertyName("core_count")]   int      CoreCount,
    [property: JsonPropertyName("history_pct")]  double[] HistoryPct);

public record MemoryData(
    [property: JsonPropertyName("used_gb")]      double   UsedGb,
    [property: JsonPropertyName("total_gb")]     double   TotalGb,
    [property: JsonPropertyName("usage_pct")]    double   UsagePct,
    [property: JsonPropertyName("history_pct")]  double[] HistoryPct);

public record GpuData(
    [property: JsonPropertyName("available")]    bool     Available,
    [property: JsonPropertyName("usage_pct")]    double?  UsagePct,
    [property: JsonPropertyName("history_pct")]  double[] HistoryPct);

// ── Services ────────────────────────────────────────────────────────────────

public record ServicesData(
    [property: JsonPropertyName("ollama")]  OllamaData OllamaData,
    [property: JsonPropertyName("comfyui")] ComfyData  ComfyData);

public record OllamaData(
    [property: JsonPropertyName("installed")]       bool           Installed,
    [property: JsonPropertyName("online")]          bool           Online,
    [property: JsonPropertyName("models")]          OllamaModel[]  Models,
    [property: JsonPropertyName("cpu_pct")]         double         CpuPct,
    [property: JsonPropertyName("mem_gb")]          double         MemGb,
    [property: JsonPropertyName("cpu_history_pct")] double[]       CpuHistoryPct);

public record OllamaModel(
    [property: JsonPropertyName("name")]    string Name,
    [property: JsonPropertyName("size_gb")] double SizeGb);

public record ComfyData(
    [property: JsonPropertyName("installed")]           bool     Installed,
    [property: JsonPropertyName("online")]              bool     Online,
    [property: JsonPropertyName("queue_running")]       int      QueueRunning,
    [property: JsonPropertyName("queue_pending")]       int      QueuePending,
    [property: JsonPropertyName("is_generating")]       bool     IsGenerating,
    [property: JsonPropertyName("generation_progress")] double   GenerationProgress,
    [property: JsonPropertyName("cpu_pct")]             double   CpuPct,
    [property: JsonPropertyName("mem_gb")]              double   MemGb,
    [property: JsonPropertyName("cpu_history_pct")]     double[] CpuHistoryPct);
