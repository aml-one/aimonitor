using System.IO;
using System.Windows;
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
}
