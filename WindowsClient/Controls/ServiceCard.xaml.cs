using System.ComponentModel;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;

namespace AiMonitorClient.Controls;

public enum ServiceCardType { Ollama, ComfyUI }

public partial class ServiceCard : UserControl, INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;
    private void Notify(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
    private void SetProp<T>(ref T field, T value, string name)
        { if (!Equals(field, value)) { field = value; Notify(name); } }

    // ── Dependency Properties ──────────────────────────────────────────────

    public static readonly DependencyProperty ServiceTypeProperty =
        DependencyProperty.Register(nameof(ServiceType), typeof(ServiceCardType),
            typeof(ServiceCard), new PropertyMetadata(ServiceCardType.Ollama));

    public static readonly DependencyProperty ServiceNameProperty =
        DP<string>(nameof(ServiceName), "");
    public static readonly DependencyProperty ServiceUrlProperty =
        DP<string>(nameof(ServiceUrl), "");
    public static readonly DependencyProperty IconLabelProperty =
        DP<string>(nameof(IconLabel), "SVC");
    public static readonly DependencyProperty IsOnlineProperty =
        DP<bool>(nameof(IsOnline), false,
            (d, _) => ((ServiceCard)d).OnOnlineChanged());
    public static readonly DependencyProperty CpuTextProperty =
        DP<string>(nameof(CpuText), "0%",
            (d, _) => ((ServiceCard)d).OnCpuTextChanged());
    public static readonly DependencyProperty MemTextProperty =
        DP<string>(nameof(MemText), "0 GB");
    public static readonly DependencyProperty ExtraLabelProperty =
        DP<string>(nameof(ExtraLabel), "");
    public static readonly DependencyProperty ExtraTextProperty =
        DP<string>(nameof(ExtraText), "");
    public static readonly DependencyProperty ModelNamesProperty =
        DP<IReadOnlyList<string>?>(nameof(ModelNames), null);
    public static readonly DependencyProperty HistoryValuesProperty =
        DP<IReadOnlyList<double>?>(nameof(HistoryValues), null);
    public static readonly DependencyProperty AccentColorProperty =
        DP<Color>(nameof(AccentColor), Colors.White,
            (d, _) => ((ServiceCard)d).OnAccentChanged());
    public static readonly DependencyProperty Btn1LabelProperty =
        DP<string>(nameof(Btn1Label), "");
    public static readonly DependencyProperty Btn2LabelProperty =
        DP<string>(nameof(Btn2Label), "");
    public static readonly DependencyProperty Btn2VisibilityProperty =
        DP<Visibility>(nameof(Btn2Visibility), Visibility.Collapsed);
    public static readonly DependencyProperty ModelsVisibilityProperty =
        DP<Visibility>(nameof(ModelsVisibility), Visibility.Collapsed);
    public static readonly DependencyProperty QueueSectionVisibilityProperty =
        DP<Visibility>(nameof(QueueSectionVisibility), Visibility.Collapsed);
    public static readonly DependencyProperty QueueRunningProperty =
        DP<int>(nameof(QueueRunning), 0);
    public static readonly DependencyProperty QueuePendingProperty =
        DP<int>(nameof(QueuePending), 0);
    public static readonly DependencyProperty IsGeneratingProperty =
        DP<bool>(nameof(IsGenerating), false,
            (d, _) => ((ServiceCard)d).OnIsGeneratingChanged());
    public static readonly DependencyProperty GenerationProgressProperty =
        DP<double>(nameof(GenerationProgress), 0.0);
    public static readonly DependencyProperty GrayscaleProperty =
        DP<bool>(nameof(Grayscale), false);

    // ── Events ────────────────────────────────────────────────────────────

    public event RoutedEventHandler? Btn1Clicked;
    public event RoutedEventHandler? Btn2Clicked;

    // ── Public Properties ──────────────────────────────────────────────────

    public ServiceCardType        ServiceType           { get => (ServiceCardType)GetValue(ServiceTypeProperty);           set => SetValue(ServiceTypeProperty, value); }
    public string                 ServiceName           { get => (string)GetValue(ServiceNameProperty);                   set => SetValue(ServiceNameProperty, value); }
    public string                 ServiceUrl            { get => (string)GetValue(ServiceUrlProperty);                    set => SetValue(ServiceUrlProperty, value); }
    public string                 IconLabel             { get => (string)GetValue(IconLabelProperty);                     set => SetValue(IconLabelProperty, value); }
    public bool                   IsOnline              { get => (bool)GetValue(IsOnlineProperty);                        set => SetValue(IsOnlineProperty, value); }
    public string                 CpuText               { get => (string)GetValue(CpuTextProperty);                       set => SetValue(CpuTextProperty, value); }
    public string                 MemText               { get => (string)GetValue(MemTextProperty);                       set => SetValue(MemTextProperty, value); }
    public string                 ExtraLabel            { get => (string)GetValue(ExtraLabelProperty);                    set => SetValue(ExtraLabelProperty, value); }
    public string                 ExtraText             { get => (string)GetValue(ExtraTextProperty);                     set => SetValue(ExtraTextProperty, value); }
    public IReadOnlyList<string>? ModelNames            { get => (IReadOnlyList<string>?)GetValue(ModelNamesProperty);    set => SetValue(ModelNamesProperty, value); }
    public IReadOnlyList<double>? HistoryValues         { get => (IReadOnlyList<double>?)GetValue(HistoryValuesProperty); set => SetValue(HistoryValuesProperty, value); }
    public Color                  AccentColor           { get => (Color)GetValue(AccentColorProperty);                    set => SetValue(AccentColorProperty, value); }
    public string                 Btn1Label             { get => (string)GetValue(Btn1LabelProperty);                     set => SetValue(Btn1LabelProperty, value); }
    public string                 Btn2Label             { get => (string)GetValue(Btn2LabelProperty);                     set => SetValue(Btn2LabelProperty, value); }
    public Visibility             Btn2Visibility        { get => (Visibility)GetValue(Btn2VisibilityProperty);            set => SetValue(Btn2VisibilityProperty, value); }
    public Visibility             ModelsVisibility      { get => (Visibility)GetValue(ModelsVisibilityProperty);          set => SetValue(ModelsVisibilityProperty, value); }
    public Visibility             QueueSectionVisibility{ get => (Visibility)GetValue(QueueSectionVisibilityProperty);   set => SetValue(QueueSectionVisibilityProperty, value); }
    public int                    QueueRunning          { get => (int)GetValue(QueueRunningProperty);                     set => SetValue(QueueRunningProperty, value); }
    public int                    QueuePending          { get => (int)GetValue(QueuePendingProperty);                     set => SetValue(QueuePendingProperty, value); }
    public bool                   IsGenerating          { get => (bool)GetValue(IsGeneratingProperty);                    set => SetValue(IsGeneratingProperty, value); }
    public double                 GenerationProgress    { get => (double)GetValue(GenerationProgressProperty);            set => SetValue(GenerationProgressProperty, value); }
    public bool                   Grayscale             { get => (bool)GetValue(GrayscaleProperty);                       set => SetValue(GrayscaleProperty, value); }

    // Computed brushes — backed with INPC fields so bindings update
    private SolidColorBrush _accentBrush       = Brushes.White;
    private SolidColorBrush _iconBadgeBrush    = Brushes.Transparent;
    private SolidColorBrush _actionBtnBg       = Brushes.Transparent;
    private SolidColorBrush _actionBtnBorder   = Brushes.Transparent;
    private SolidColorBrush _modelBadgeBg      = Brushes.Transparent;
    private SolidColorBrush _modelBadgeBorder  = Brushes.Transparent;
    private SolidColorBrush _statusDotBrush    = Brushes.Gray;
    private SolidColorBrush _statusBadgeBg     = Brushes.Transparent;
    private SolidColorBrush _statusBadgeBorder = Brushes.Transparent;
    private string           _statusText       = "OFFLINE";
    private Visibility        _generatingBarVisibility = Visibility.Collapsed;

    public SolidColorBrush AccentBrush      { get => _accentBrush;       private set => SetProp(ref _accentBrush,       value, nameof(AccentBrush)); }
    public SolidColorBrush IconBadgeBrush   { get => _iconBadgeBrush;    private set => SetProp(ref _iconBadgeBrush,    value, nameof(IconBadgeBrush)); }
    public SolidColorBrush ActionBtnBg      { get => _actionBtnBg;       private set => SetProp(ref _actionBtnBg,       value, nameof(ActionBtnBg)); }
    public SolidColorBrush ActionBtnBorder  { get => _actionBtnBorder;   private set => SetProp(ref _actionBtnBorder,   value, nameof(ActionBtnBorder)); }
    public SolidColorBrush ModelBadgeBg     { get => _modelBadgeBg;      private set => SetProp(ref _modelBadgeBg,      value, nameof(ModelBadgeBg)); }
    public SolidColorBrush ModelBadgeBorder { get => _modelBadgeBorder;  private set => SetProp(ref _modelBadgeBorder,  value, nameof(ModelBadgeBorder)); }
    public SolidColorBrush StatusDotBrush   { get => _statusDotBrush;    private set => SetProp(ref _statusDotBrush,    value, nameof(StatusDotBrush)); }
    public SolidColorBrush StatusBadgeBg    { get => _statusBadgeBg;     private set => SetProp(ref _statusBadgeBg,     value, nameof(StatusBadgeBg)); }
    public SolidColorBrush StatusBadgeBorder{ get => _statusBadgeBorder; private set => SetProp(ref _statusBadgeBorder, value, nameof(StatusBadgeBorder)); }
    public string           StatusText      { get => _statusText;        private set => SetProp(ref _statusText,        value, nameof(StatusText)); }
    public Visibility GeneratingBarVisibility { get => _generatingBarVisibility; private set => SetProp(ref _generatingBarVisibility, value, nameof(GeneratingBarVisibility)); }

    public ServiceCard()
    {
        InitializeComponent();
        OnAccentChanged();
        OnOnlineChanged();

        App.ThemeChanged += OnThemeChanged;
        Unloaded += (s, e) => App.ThemeChanged -= OnThemeChanged;
    }

    private void OnThemeChanged(object? sender, EventArgs e)
    {
        Dispatcher.InvokeAsync(() => OnOnlineChanged(), System.Windows.Threading.DispatcherPriority.Background);
    }

    private void OnIsGeneratingChanged()
    {
        GeneratingBarVisibility = IsGenerating ? Visibility.Visible : Visibility.Hidden;
    }


    private void OnCpuTextChanged()
    {
        if (CpuValueText != null)
        {
            var isIdle = CpuText == "idle";
            CpuValueText.Foreground = isIdle ? (SolidColorBrush?)TryFindResource("OnlineBrush") : (SolidColorBrush?)TryFindResource("TextPrimary");
        }
    }

    private void OnAccentChanged()
    {
        var c = AccentColor;
        AccentBrush      = Frozen(new SolidColorBrush(c));
        IconBadgeBrush   = Frozen(new SolidColorBrush(Color.FromArgb(38, c.R, c.G, c.B)));
        ActionBtnBg      = Frozen(new SolidColorBrush(Color.FromArgb(30, c.R, c.G, c.B)));
        ActionBtnBorder  = Frozen(new SolidColorBrush(Color.FromArgb(70, c.R, c.G, c.B)));
        ModelBadgeBg     = Frozen(new SolidColorBrush(Color.FromArgb(30, c.R, c.G, c.B)));
        ModelBadgeBorder = Frozen(new SolidColorBrush(Color.FromArgb(55, c.R, c.G, c.B)));

        Dispatcher.InvokeAsync(() => OnOnlineChanged(), System.Windows.Threading.DispatcherPriority.Loaded);
    }

    private void OnOnlineChanged()
    {
        if (IsOnline)
        {
            StatusText = "ONLINE";
            var brush = (SolidColorBrush?)TryFindResource("OnlineBrush");
            if (brush != null)
            {
                var c = brush.Color;
                StatusDotBrush    = Frozen(new SolidColorBrush(c));
                StatusBadgeBg     = Frozen(new SolidColorBrush(Color.FromArgb(25, c.R, c.G, c.B)));
                StatusBadgeBorder = Frozen(new SolidColorBrush(Color.FromArgb(64, c.R, c.G, c.B)));
            }
        }
        else
        {
            StatusText = "OFFLINE";
            var brush = (SolidColorBrush?)TryFindResource("OfflineBrush");
            if (brush != null)
            {
                var c = brush.Color;
                StatusDotBrush    = Frozen(new SolidColorBrush(c));
                StatusBadgeBg     = Frozen(new SolidColorBrush(Color.FromArgb(25, c.R, c.G, c.B)));
                StatusBadgeBorder = Frozen(new SolidColorBrush(Color.FromArgb(64, c.R, c.G, c.B)));
            }
        }
    }

    private void Btn1_Click(object sender, RoutedEventArgs e) => Btn1Clicked?.Invoke(this, e);
    private void Btn2_Click(object sender, RoutedEventArgs e) => Btn2Clicked?.Invoke(this, e);

    private static DependencyProperty DP<T>(string name, T def,
        PropertyChangedCallback? cb = null) =>
        DependencyProperty.Register(name, typeof(T), typeof(ServiceCard),
            new PropertyMetadata(def, cb));

    private static SolidColorBrush Frozen(SolidColorBrush b) { b.Freeze(); return b; }
}




