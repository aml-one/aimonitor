using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace AiMonitorClient.Controls;

public partial class MetricCard : UserControl, INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Notify(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    // ── Dependency Properties ──────────────────────────────────────────────

    public static readonly DependencyProperty TitleProperty =
        DP<string>(nameof(Title), "");

    public static readonly DependencyProperty IconLabelProperty =
        DP<string>(nameof(IconLabel), "CPU");

    public static readonly DependencyProperty ValueTextProperty =
        DP<string>(nameof(ValueText), "—");

    public static readonly DependencyProperty SubtitleTextProperty =
        DP<string>(nameof(SubtitleText), "");

    public static readonly DependencyProperty HistoryValuesProperty =
        DP<IReadOnlyList<double>?>(nameof(HistoryValues), null);

    public static readonly DependencyProperty AccentColorProperty =
        DP<Color>(nameof(AccentColor), Colors.White,
            (d, _) => ((MetricCard)d).OnAccentChanged());

    // ── Public properties ──────────────────────────────────────────────────

    public string                 Title         { get => (string)GetValue(TitleProperty);         set => SetValue(TitleProperty, value); }
    public string                 IconLabel     { get => (string)GetValue(IconLabelProperty);     set => SetValue(IconLabelProperty, value); }
    public string                 ValueText     { get => (string)GetValue(ValueTextProperty);     set => SetValue(ValueTextProperty, value); }
    public string                 SubtitleText  { get => (string)GetValue(SubtitleTextProperty);  set => SetValue(SubtitleTextProperty, value); }
    public IReadOnlyList<double>? HistoryValues { get => (IReadOnlyList<double>?)GetValue(HistoryValuesProperty); set => SetValue(HistoryValuesProperty, value); }
    public Color                  AccentColor   { get => (Color)GetValue(AccentColorProperty);    set => SetValue(AccentColorProperty, value); }

    // Computed brushes exposed for XAML binding — backed with INPC
    private SolidColorBrush _accentBrush    = Brushes.White;
    private SolidColorBrush _iconBadgeBrush = new(Color.FromArgb(38, 255, 255, 255));

    public SolidColorBrush AccentBrush    { get => _accentBrush;    private set { _accentBrush    = value; Notify(nameof(AccentBrush)); } }
    public SolidColorBrush IconBadgeBrush { get => _iconBadgeBrush; private set { _iconBadgeBrush = value; Notify(nameof(IconBadgeBrush)); } }

    public MetricCard()
    {
        InitializeComponent();
        OnAccentChanged();
    }

    private void OnAccentChanged()
    {
        var c = AccentColor;
        AccentBrush    = Frozen(new SolidColorBrush(c));
        IconBadgeBrush = Frozen(new SolidColorBrush(Color.FromArgb(38, c.R, c.G, c.B)));
    }

    // ── Helper ────────────────────────────────────────────────────────────

    private static SolidColorBrush Frozen(SolidColorBrush b) { b.Freeze(); return b; }

    private static DependencyProperty DP<T>(string name, T defaultValue,
        PropertyChangedCallback? changed = null) =>
        DependencyProperty.Register(name, typeof(T), typeof(MetricCard),
            new PropertyMetadata(defaultValue, changed));
}
