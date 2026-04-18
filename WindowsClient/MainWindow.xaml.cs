using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Threading;
using AiMonitorClient.Controls;
using AiMonitorClient.Models;

namespace AiMonitorClient;

public partial class MainWindow : Window
{
    // DWM caption-color API (Windows 11+; silently ignored on older OS)
    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(nint hwnd, uint attr, ref int attrValue, uint attrSize);
    private const uint DWMWA_CAPTION_COLOR = 35;

    private ApiClient        _api;
    private DispatcherTimer  _timer;
    private CancellationTokenSource _cts = new();
    private bool             _connected;
    private bool             _polling;          // guard: skip tick if previous poll still running
    private int              _failStreak;       // consecutive failures before showing offline
    private const int        FailThreshold = 3; // tolerate up to 3 missed polls before marking offline

    // ── CPU/Mem/GPU rolling history kept client-side as fallback ──────────
    // (the Mac sends history[], but we store it here too for display)

    public MainWindow()
    {
        InitializeComponent();

        var s = App.Settings;
        _api  = new ApiClient(s.Host, s.Port);
        UpdateConnectionLabel();

        // Wire service-card action buttons
        OllamaCard.Btn1Clicked += async (_, _) =>
            await SafePostAction("ollama/restart");

        ComfyCard.Btn1Clicked += async (_, _) =>
            await SafePostAction("comfy/close");

        ComfyCard.Btn2Clicked += async (_, _) =>
            await SafePostAction("comfy/clear-queue");

        // Load window icon from Assets/AppIcon.png if present
        LoadWindowIcon();

        // Start polling timer using saved interval
        _timer = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(App.Settings.PollIntervalMs) };
        _timer.Tick += async (_, _) => await PollAsync();
        _timer.Start();
    }

    // ── Titlebar colour ───────────────────────────────────────────────────

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        ApplyTitleBarColor();
    }

    internal void ApplyTitleBarColor()
    {
        try
        {
            // WindowBg in dark mode = #0D0D17, light = #F2F2F7 — read from resources
            var bg = (SolidColorBrush)Application.Current.Resources["WindowBg"];
            var c  = bg.Color;
            // DWMWA_CAPTION_COLOR expects 0x00BBGGRR
            int rgb = c.R | (c.G << 8) | (c.B << 16);
            var hwnd = new WindowInteropHelper(this).Handle;
            DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, ref rgb, 4);
        }
        catch { }
    }

    // ── Polling ───────────────────────────────────────────────────────────

    private async Task PollAsync()
    {
        if (_polling) return;   // skip if previous request still in flight
        _polling = true;
        try
        {
            // Timeout = 1.5× the poll interval, min 800ms, max 3s
            var ms  = Math.Clamp(App.Settings.PollIntervalMs * 3 / 2, 800, 3000);
            using var cts = CancellationTokenSource.CreateLinkedTokenSource(_cts.Token);
            cts.CancelAfter(ms);

            var data = await _api.GetStatsAsync(cts.Token);
            if (data is null) return;

            _failStreak = 0;
            SetConnected(true);
            ApplySystem(data.System);
            ApplyServices(data.Services);
            UpdateFooter(data.Timestamp);
        }
        catch (Exception ex) when (ex is OperationCanceledException or TaskCanceledException
                                       or System.Net.Http.HttpRequestException
                                       or System.Net.Sockets.SocketException)
        {
            if (++_failStreak >= FailThreshold) SetConnected(false);
        }
        catch (Exception)
        {
            if (++_failStreak >= FailThreshold) SetConnected(false);
        }
        finally
        {
            _polling = false;
        }
    }

    // ── System section ────────────────────────────────────────────────────

    private void ApplySystem(SystemData? sys)
    {
        if (sys is null) return;

        // CPU
        CpuCard.ValueText     = $"{sys.Cpu.UsagePct:F0}%";
        CpuCard.SubtitleText  = $"{sys.Cpu.CoreCount} logical cores";
        CpuCard.HistoryValues = sys.Cpu.HistoryPct;

        // Memory
        MemCard.ValueText     = $"{sys.Memory.UsedGb:F1} GB";
        MemCard.SubtitleText  = $"of {sys.Memory.TotalGb:F0} GB total";
        MemCard.HistoryValues = sys.Memory.HistoryPct;

        // GPU
        if (sys.Gpu.Available && sys.Gpu.UsagePct.HasValue)
        {
            GpuCard.ValueText    = $"{sys.Gpu.UsagePct.Value:F0}%";
            GpuCard.SubtitleText = "Apple Silicon";
        }
        else
        {
            GpuCard.ValueText    = "—";
            GpuCard.SubtitleText = "unavailable";
        }
        GpuCard.HistoryValues = sys.Gpu.HistoryPct;

        // Summary capsule
        SumCpuVal.Text = $"{sys.Cpu.UsagePct:F0}%";
        SumMemVal.Text = $"{sys.Memory.UsagePct:F0}%";
        SumGpuVal.Text = sys.Gpu.Available && sys.Gpu.UsagePct.HasValue
                            ? $"{sys.Gpu.UsagePct.Value:F0}%"
                            : "N/A";
    }

    // ── Services section ──────────────────────────────────────────────────

    private void ApplyServices(ServicesData? svc)
    {
        if (svc is null) return;

        bool showOllama = svc.OllamaData.Installed;
        bool showComfy  = svc.ComfyData.Installed;

        ServicesSection.Visibility  = (showOllama || showComfy) ? Visibility.Visible : Visibility.Collapsed;
        OllamaCard.Visibility       = showOllama ? Visibility.Visible : Visibility.Collapsed;
        ComfyCard.Visibility        = showComfy  ? Visibility.Visible : Visibility.Collapsed;

        if (showOllama)
        {
            var o = svc.OllamaData;
            OllamaCard.IsOnline      = o.Online;
            OllamaCard.CpuText       = $"{o.CpuPct:F1}%";
            OllamaCard.MemText       = $"{o.MemGb:F2} GB";
            OllamaCard.ExtraText     = $"{o.Models.Length}";
            OllamaCard.HistoryValues = o.CpuHistoryPct;
            OllamaCard.ModelsVisibility = o.Online ? Visibility.Visible : Visibility.Hidden;
            OllamaCard.ModelNames    = o.Online
                ? (IReadOnlyList<string>)o.Models.Select(m => m.Name).ToArray()
                : Array.Empty<string>();
        }

        if (showComfy)
        {
            var c = svc.ComfyData;
            ComfyCard.IsOnline              = c.Online;
            ComfyCard.CpuText               = $"{c.CpuPct:F1}%";
            ComfyCard.MemText               = $"{c.MemGb:F2} GB";
            ComfyCard.ExtraText             = $"{c.QueueRunning} / {c.QueuePending}";
            ComfyCard.QueueRunning          = c.QueueRunning;
            ComfyCard.QueuePending          = c.QueuePending;
            ComfyCard.QueueSectionVisibility= c.Online ? Visibility.Visible : Visibility.Hidden;
            ComfyCard.HistoryValues         = c.CpuHistoryPct;
        }
    }

    // ── Connection state ──────────────────────────────────────────────────

    private void SetConnected(bool connected)
    {
        if (_connected == connected) return;
        _connected = connected;

        var ms  = App.Settings.PollIntervalMs;
        var lbl = ms >= 1000 ? $"{ms / 1000}s" : $"{ms}ms";
        ConnDot.Fill = new SolidColorBrush(connected
            ? Color.FromRgb(0x80, 0xFF, 0xAA)
            : Color.FromRgb(0xFF, 0x60, 0x60));
        ConnStatusText.Text = connected ? $"connected · {lbl}" : "unreachable";
    }

    private void UpdateConnectionLabel()
    {
        var s = App.Settings;
        ConnHostText.Text = $"{s.Host}:{s.Port}";
    }

    private void UpdateFooter(string timestamp)
    {
        var ms  = App.Settings.PollIntervalMs;
        var lbl = ms >= 1000 ? $"{ms / 1000}s" : $"{ms}ms";
        FooterText.Text = $"Last update: {timestamp}  ·  {lbl}  ·  AI Monitor Client by AmL";
    }

    // ── Actions ───────────────────────────────────────────────────────────

    private async Task SafePostAction(string action)
    {
        try { await _api.PostActionAsync(action); }
        catch { /* silently ignore — Mac may be unreachable */ }
    }

    // ── Buttons ───────────────────────────────────────────────────────────

    private void SettingsBtn_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new SettingsWindow { Owner = this };
        if (dlg.ShowDialog() != true) return;

        var s = App.Settings;
        _api.UpdateEndpoint(s.Host, s.Port);
        _timer.Interval = TimeSpan.FromMilliseconds(s.PollIntervalMs);
        _failStreak = 0;
        _connected  = false;  // force badge refresh on next poll
        UpdateConnectionLabel();
        ConnDot.Fill = new SolidColorBrush(Color.FromRgb(0xFF, 0x60, 0x60));
        ConnStatusText.Text = "connecting…";
    }

    private void ThemeBtn_Click(object sender, RoutedEventArgs e)
    {
        App.ApplyTheme(!App.Settings.DarkMode);
        App.Settings.Save();
        ApplyTitleBarColor();
    }

    // ── Icon ──────────────────────────────────────────────────────────────

    private void LoadWindowIcon()
    {
        try
        {
            var png = Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                                   "Assets", "AppIcon.png");
            if (File.Exists(png))
            {
                var img = new System.Windows.Media.Imaging.BitmapImage(new Uri(png));
                Icon = img;
            }
        }
        catch { }
    }

    // ── Cleanup ───────────────────────────────────────────────────────────

    protected override void OnClosed(EventArgs e)
    {
        _cts.Cancel();
        _timer.Stop();
        _api.Dispose();
        base.OnClosed(e);
    }
}
