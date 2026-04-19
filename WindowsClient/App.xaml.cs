using System.IO;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
using System.Windows.Media;
using AiMonitorClient.Models;

namespace AiMonitorClient;

public partial class App : Application
{
    public static AppSettings Settings { get; private set; } = new();
    public static event EventHandler? ThemeChanged;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        Settings = AppSettings.Load();
        ApplyTheme(Settings.DarkMode);
    }

    public static void ApplyTheme(bool dark)
    {
        Settings.DarkMode = dark;
        var dict = new ResourceDictionary
        {
            Source = new Uri(dark ? "Themes/DarkTheme.xaml" : "Themes/LightTheme.xaml",
                             UriKind.Relative)
        };
        Current.Resources.MergedDictionaries.Clear();
        Current.Resources.MergedDictionaries.Add(dict);
        ThemeChanged?.Invoke(null, EventArgs.Empty);
    }

    // ── DWM title-bar colouring (Windows 11+; silently ignored on older OS) ─
    [DllImport("dwmapi.dll", PreserveSig = true)]
    private static extern int DwmSetWindowAttribute(nint hwnd, uint attr, ref int value, uint size);
    private const uint DWMWA_CAPTION_COLOR = 35;

    /// <summary>Tints a window's title bar to match the current WindowBg theme colour.</summary>
    public static void ApplyTitleBarColor(Window w)
    {
        try
        {
            var bg  = (SolidColorBrush)Current.Resources["WindowBg"];
            var c   = bg.Color;
            int rgb = c.R | (c.G << 8) | (c.B << 16);
            var hwnd = new WindowInteropHelper(w).Handle;
            DwmSetWindowAttribute(hwnd, DWMWA_CAPTION_COLOR, ref rgb, 4);
        }
        catch { }
    }
}
