using System.Windows;
using System.Windows.Controls;

namespace AiMonitorClient;

public partial class SettingsWindow : Window
{
    public SettingsWindow()
    {
        InitializeComponent();
        var s = App.Settings;
        HostBox.Text = s.Host;
        PortBox.Text = s.Port.ToString();

        // Select the matching poll interval in the ComboBox
        foreach (ComboBoxItem item in PollBox.Items)
        {
            if (item.Tag is string tag && int.TryParse(tag, out int ms) && ms == s.PollIntervalMs)
            {
                PollBox.SelectedItem = item;
                break;
            }
        }
        if (PollBox.SelectedItem is null) PollBox.SelectedIndex = 0;
    }

    protected override void OnSourceInitialized(EventArgs e)
    {
        base.OnSourceInitialized(e);
        App.ApplyTitleBarColor(this);
        App.ThemeChanged += OnThemeChanged;
    }

    private void OnThemeChanged(object? sender, EventArgs e)
        => App.ApplyTitleBarColor(this);

    protected override void OnClosed(EventArgs e)
    {
        App.ThemeChanged -= OnThemeChanged;
        base.OnClosed(e);
    }

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var host = HostBox.Text.Trim();
        if (string.IsNullOrEmpty(host))
        {
            MessageBox.Show("Please enter a host name or IP address.",
                            "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        if (!int.TryParse(PortBox.Text.Trim(), out var port) || port < 1 || port > 65535)
        {
            MessageBox.Show("Port must be a number between 1 and 65535.",
                            "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        int pollMs = 300;
        if (PollBox.SelectedItem is ComboBoxItem ci && ci.Tag is string tag)
            int.TryParse(tag, out pollMs);

        App.Settings.Host          = host;
        App.Settings.Port          = port;
        App.Settings.PollIntervalMs= pollMs;
        App.Settings.Save();

        DialogResult = true;
        Close();
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }
}
