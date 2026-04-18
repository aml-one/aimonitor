# Ai Monitor API — Developer Reference

**Ai Monitor by AmL** exposes a live HTTP/JSON API on your Mac so any other computer, app, or script on your network can read real-time CPU, Memory, GPU, Ollama and ComfyUI data.

---

## Quick Start

1. Launch **Ai Monitor** on your Mac.
2. The API starts automatically. Look for the blue **`API : 9876`** badge in the top-right of the window.
3. From any device on the same network, replace `<mac-ip>` with your Mac's local IP address (e.g. `192.168.1.42`):

```
http://<mac-ip>:9876/stats
```

> To find your Mac's IP: **System Settings → Network → Wi-Fi / Ethernet → IP Address**

---

## Base URL

```
http://<mac-ip>:9876
```

The server listens on **all interfaces**, so it's reachable from other machines on the same LAN.

All responses are:
- `Content-Type: application/json; charset=utf-8`
- `Access-Control-Allow-Origin: *` (full CORS support — usable from browsers/web apps)
- `Access-Control-Allow-Methods: GET, POST, OPTIONS`
- `Cache-Control: no-cache`

GET endpoints return live data. POST endpoints trigger actions on the Mac.

---

## Endpoints

| Method | Path                             | Description                              |
|--------|----------------------------------|------------------------------------------|
| GET    | `/`                              | Alias for `/stats` — full snapshot       |
| GET    | `/stats`                         | System + Services combined snapshot      |
| GET    | `/system`                        | CPU, Memory, GPU only                    |
| GET    | `/services`                      | Ollama + ComfyUI only                    |
| POST   | `/actions/ollama/restart`        | Restart the Ollama service               |
| POST   | `/actions/comfy/close`           | Terminate the ComfyUI process            |
| POST   | `/actions/comfy/clear-queue`     | Clear the ComfyUI generation queue       |

---

## Action Endpoints

Action endpoints accept a POST request with an empty body (or any JSON body — it is ignored).
They respond with:

```json
{ "ok": true, "action": "<action_name>" }
```

### `POST /actions/ollama/restart`
Restarts the Ollama service via `launchctl` (equivalent to clicking **Restart** in the app UI).

```bash
curl -X POST http://192.168.1.42:9876/actions/ollama/restart
# → {"ok":true,"action":"ollama_restart"}
```

### `POST /actions/comfy/close`
Terminates the ComfyUI Python process.

```bash
curl -X POST http://192.168.1.42:9876/actions/comfy/close
# → {"ok":true,"action":"comfy_close"}
```

### `POST /actions/comfy/clear-queue`
Clears all pending jobs from the ComfyUI generation queue.

```bash
curl -X POST http://192.168.1.42:9876/actions/comfy/clear-queue
# → {"ok":true,"action":"comfy_clear_queue"}
```

---

## Response Schemas

### `GET /stats` — Full Snapshot

Returns both the `system` and `services` objects in one call. Ideal for dashboards.

```json
{
  "timestamp": "2026-04-18T14:00:01Z",
  "system": { ... },
  "services": { ... }
}
```

---

### `GET /system` — System Resources

```json
{
  "timestamp": "2026-04-18T14:00:01Z",
  "cpu": {
    "usage_pct": 12.4,
    "core_count": 12,
    "history_pct": [8.1, 9.2, 12.4, ...]
  },
  "memory": {
    "used_gb": 18.2,
    "total_gb": 36.0,
    "usage_pct": 50.5,
    "history_pct": [48.2, 49.1, 50.5, ...]
  },
  "gpu": {
    "available": true,
    "usage_pct": 34.0,
    "history_pct": [28.0, 31.5, 34.0, ...]
  }
}
```

| Field | Type | Description |
|---|---|---|
| `cpu.usage_pct` | `number` | Average CPU usage across all cores (0–100) |
| `cpu.core_count` | `integer` | Number of logical CPU cores |
| `cpu.history_pct` | `number[]` | Last 60 samples, ~1 per second |
| `memory.used_gb` | `number` | Active + wired + compressed memory in GB |
| `memory.total_gb` | `number` | Total physical RAM in GB |
| `memory.usage_pct` | `number` | Percentage of RAM in use (0–100) |
| `memory.history_pct` | `number[]` | Last 60 samples |
| `gpu.available` | `boolean` | `true` if GPU stats could be read via IOKit |
| `gpu.usage_pct` | `number \| null` | GPU utilisation (0–100), or `null` if unavailable |
| `gpu.history_pct` | `number[]` | Last 60 samples |

---

### `GET /services` — AI Services

```json
{
  "timestamp": "2026-04-18T14:00:01Z",
  "ollama": {
    "installed": true,
    "online": true,
    "models": [
      { "name": "llama3:8b", "size_gb": 4.661 },
      { "name": "mistral:7b", "size_gb": 4.108 }
    ],
    "cpu_pct": 5.2,
    "mem_gb": 6.12,
    "cpu_history_pct": [3.1, 4.8, 5.2, ...]
  },
  "comfyui": {
    "installed": true,
    "online": false,
    "queue_running": 0,
    "queue_pending": 3,
    "cpu_pct": 0.0,
    "mem_gb": 0.0,
    "cpu_history_pct": [0.0, 0.0, ...]
  }
}
```

| Field | Type | Description |
|---|---|---|
| `ollama.installed` | `boolean` | `true` if Ollama binary or app was found on this Mac |
| `ollama.online` | `boolean` | `true` if `localhost:11434` is responding |
| `ollama.models` | `object[]` | Currently loaded/cached models |
| `ollama.models[].name` | `string` | Model identifier (e.g. `"llama3:8b"`) |
| `ollama.models[].size_gb` | `number` | Model size in GB |
| `ollama.cpu_pct` | `number` | Ollama process CPU % (sum of all ollama threads) |
| `ollama.mem_gb` | `number` | Ollama process resident memory in GB |
| `ollama.cpu_history_pct` | `number[]` | Last 60 samples |
| `comfyui.installed` | `boolean` | `true` if ComfyUI directory or app was found |
| `comfyui.online` | `boolean` | `true` if `localhost:8188` is responding |
| `comfyui.queue_running` | `integer` | Number of jobs actively generating |
| `comfyui.queue_pending` | `integer` | Number of jobs waiting in queue |
| `comfyui.cpu_pct` | `number` | ComfyUI Python process CPU % |
| `comfyui.mem_gb` | `number` | ComfyUI process resident memory in GB |
| `comfyui.cpu_history_pct` | `number[]` | Last 60 samples |

---

## Examples

### cURL

```bash
# Full snapshot
curl http://192.168.1.42:9876/stats

# Just system resources, pretty-printed
curl -s http://192.168.1.42:9876/system | python3 -m json.tool

# Just services
curl http://192.168.1.42:9876/services
```

### Python

```python
import requests

r = requests.get("http://192.168.1.42:9876/stats")
data = r.json()

print(f"CPU:    {data['system']['cpu']['usage_pct']}%")
print(f"Memory: {data['system']['memory']['used_gb']:.1f} / {data['system']['memory']['total_gb']:.0f} GB")

if data['services']['ollama']['online']:
    models = [m['name'] for m in data['services']['ollama']['models']]
    print(f"Ollama models loaded: {models}")

if data['services']['comfyui']['online']:
    q = data['services']['comfyui']
    print(f"ComfyUI queue: {q['queue_running']} running, {q['queue_pending']} pending")
```

### JavaScript / Browser

```js
const res  = await fetch("http://192.168.1.42:9876/stats");
const data = await res.json();

console.log("GPU:", data.system.gpu.usage_pct, "%");
console.log("Ollama online:", data.services.ollama.online);
```

### Node.js polling loop

```js
const BASE = "http://192.168.1.42:9876";

async function poll() {
  try {
    const { system } = await (await fetch(`${BASE}/system`)).json();
    process.stdout.write(
      `\r CPU ${system.cpu.usage_pct.toFixed(1)}%  ` +
      `MEM ${system.memory.usage_pct.toFixed(1)}%  ` +
      `GPU ${system.gpu.usage_pct ?? "N/A"}%`
    );
  } catch { /* mac might be asleep */ }
}

setInterval(poll, 1000);
```

---

## Error Responses

All errors return JSON with an `"error"` key:

```json
{ "error": "Not found", "endpoints": ["/stats", "/system", "/services"] }
```

| HTTP Status | Meaning |
|---|---|
| `200 OK` | Success |
| `404 Not Found` | Unknown path |
| `405 Method Not Allowed` | Not GET or POST on a known path |

---

## Controlling the Server

- **Toggle on/off** — tap the `API : 9876` badge in the app header
- **Restart** — Help menu → *Restart API Server*
- **Default port** — `9876` (hardcoded; to change it, modify `apiServer.start(port:)` in `AiMonitorApp.swift`)

---

## Network / Firewall Notes

- macOS may ask for permission the first time the server starts. Click **Allow**.
- If unreachable from another machine, check **System Settings → Network → Firewall** and ensure the app is allowed.
- The API binds to all interfaces (`0.0.0.0`) — it is accessible from any device on the same LAN.
- There is **no authentication**. Do not expose port `9876` to the public internet; use a VPN or SSH tunnel if you need remote access outside your LAN.

---

## Data Update Rate

| Source | Refresh interval |
|---|---|
| CPU / Memory / GPU | Every **1 second** |
| Ollama / ComfyUI poll | Every **2 seconds** |
| History arrays | 60 data points (~60s window for system, ~120s for services) |
