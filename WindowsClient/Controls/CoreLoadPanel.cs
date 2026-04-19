using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Media;

namespace AiMonitorClient.Controls;

/// <summary>
/// "Load per cores" panel — shows one mini-card per CPU core with a live graph.
/// Same sky-blue palette as the macOS SystemCorePanel.
/// </summary>
public sealed class CoreLoadPanel : FrameworkElement
{
    // ── Sky-blue accent (matches macOS cpuColor: 0.55, 0.75, 1.0) ─────────
    private static readonly Color AccentColor = Color.FromRgb(0x8B, 0xBF, 0xFF);

    // ── Dependency properties ──────────────────────────────────────────────

    public static readonly DependencyProperty CoreHistoriesProperty =
        DependencyProperty.Register(nameof(CoreHistories), typeof(IReadOnlyList<double[]>),
            typeof(CoreLoadPanel),
            new FrameworkPropertyMetadata(null, OnCoreHistoriesChanged));

    public static readonly DependencyProperty GrayscaleProperty =
        DependencyProperty.Register(nameof(Grayscale), typeof(bool),
            typeof(CoreLoadPanel),
            new FrameworkPropertyMetadata(false, OnGrayscaleChanged));

    public IReadOnlyList<double[]>? CoreHistories
    {
        get => (IReadOnlyList<double[]>?)GetValue(CoreHistoriesProperty);
        set => SetValue(CoreHistoriesProperty, value);
    }

    public bool Grayscale
    {
        get => (bool)GetValue(GrayscaleProperty);
        set => SetValue(GrayscaleProperty, value);
    }

    // ── Children host ──────────────────────────────────────────────────────

    private readonly Border        _shell;
    private readonly StackPanel    _root;
    private readonly TextBlock     _header;
    private readonly Border        _sep;
    private          UniformGrid?  _grid;
    private          int           _builtForCoreCount = 0;

    private readonly List<CoreMiniCard> _cards = new();

    public CoreLoadPanel()
    {
        _shell = new Border
        {
            CornerRadius    = new CornerRadius(14),
            BorderThickness = new Thickness(1),
            Padding         = new Thickness(10),
        };

        _root = new StackPanel { Orientation = Orientation.Vertical };
        _shell.Child = _root;

        // Header row
        var headerGrid = new Grid();
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        headerGrid.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        var iconBadge = new Border
        {
            Width               = 28,
            Height              = 28,
            CornerRadius        = new CornerRadius(8),
            Background          = new SolidColorBrush(Color.FromArgb(38, AccentColor.R, AccentColor.G, AccentColor.B)),
            HorizontalAlignment = HorizontalAlignment.Left,
            VerticalAlignment   = VerticalAlignment.Center,
            Margin              = new Thickness(0, 0, 8, 0),
            Child = new TextBlock
            {
                Text                = "CPU",
                FontFamily          = new FontFamily("Consolas"),
                FontSize            = 9,
                FontWeight          = FontWeights.Bold,
                Foreground          = new SolidColorBrush(AccentColor),
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment   = VerticalAlignment.Center,
            },
        };

        var titleText = new TextBlock
        {
            Text              = "Load per cores",
            FontSize          = 13,
            FontWeight        = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
        };

        var titlePanel = new StackPanel { Orientation = Orientation.Horizontal, VerticalAlignment = VerticalAlignment.Center };
        titlePanel.Children.Add(iconBadge);
        titlePanel.Children.Add(titleText);
        Grid.SetColumn(titlePanel, 0);
        headerGrid.Children.Add(titlePanel);

        _header = new TextBlock
        {
            FontFamily        = new FontFamily("Consolas"),
            FontSize          = 9,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(_header, 1);
        headerGrid.Children.Add(_header);

        _root.Children.Add(headerGrid);

        _sep = new Border { Height = 1, Margin = new Thickness(0, 8, 0, 8) };
        _root.Children.Add(_sep);

        // Store refs for theme updates
        _titleText  = titleText;

        AddVisualChild(_shell);
        AddLogicalChild(_shell);

        // Subscribe to theme changes so dynamic resources update in this custom visual tree
        App.ThemeChanged += (_, _) => ApplyThemeResources();
        Loaded += (_, _) => ApplyThemeResources();
    }

    // Keep refs to elements whose brushes we update on theme change
    private readonly TextBlock _titleText;

    private void ApplyThemeResources()
    {
        _shell.SetResourceReference(Border.BackgroundProperty,    "CardBg");
        _shell.SetResourceReference(Border.BorderBrushProperty,   "CardBorder");
        _sep.SetResourceReference(Border.BackgroundProperty,      "Separator");
        _titleText.SetResourceReference(TextBlock.ForegroundProperty, "TextSecondary");
        _header.SetResourceReference(TextBlock.ForegroundProperty,    "TextSubtle");

        var effect = Application.Current.TryFindResource("CardShadow");
        if (effect is System.Windows.Media.Effects.Effect e) _shell.Effect = e;

        foreach (var c in _cards) c.ApplyThemeResources();
    }

    // ── Visual tree ────────────────────────────────────────────────────────

    protected override int VisualChildrenCount => 1;
    protected override Visual GetVisualChild(int index) => _shell;

    protected override Size MeasureOverride(Size availableSize)
    {
        _shell.Measure(availableSize);
        return _shell.DesiredSize;
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        _shell.Arrange(new Rect(finalSize));
        return finalSize;
    }

    // ── Update cores ────────────────────────────────────────────────────────

    private static void OnCoreHistoriesChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        => ((CoreLoadPanel)d).UpdateCores();

    private static void OnGrayscaleChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var panel = (CoreLoadPanel)d;
        foreach (var c in panel._cards) c.Grayscale = (bool)e.NewValue;
    }

    private void UpdateCores()
    {
        var histories = CoreHistories;
        if (histories == null || histories.Count == 0) return;

        var count = histories.Count;
        _header.Text = $"{count} cores";

        if (_grid == null || _builtForCoreCount != count)
        {
            if (_grid != null) _root.Children.Remove(_grid);
            _cards.Clear();

            _grid = new UniformGrid
            {
                Rows    = (count + 3) / 4,
                Columns = Math.Min(count, 4),
            };

            for (int i = 0; i < count; i++)
            {
                var card = new CoreMiniCard
                {
                    CoreIndex = i,
                    Grayscale = Grayscale,
                    Margin    = new Thickness(
                        i % 4 == 0 ? 0 : 4,
                        i < 4      ? 0 : 4,
                        i % 4 == 3 || i == count - 1 ? 0 : 4,
                        0),
                };
                card.ApplyThemeResources();
                _cards.Add(card);
                _grid.Children.Add(card);
            }

            _root.Children.Add(_grid);
            _builtForCoreCount = count;
        }

        for (int i = 0; i < count && i < _cards.Count; i++)
            _cards[i].HistoryValues = histories[i];
    }
}

// ══════════════════════════════════════════════════════════════════════════════
// CoreMiniCard
// ══════════════════════════════════════════════════════════════════════════════

public sealed class CoreMiniCard : FrameworkElement
{
    private static readonly Color AccentColor = Color.FromRgb(0x8B, 0xBF, 0xFF);
    private static readonly Color RedColor    = Color.FromRgb(0xFF, 0x60, 0x60);

    // ── DPs ────────────────────────────────────────────────────────────────

    public static readonly DependencyProperty CoreIndexProperty =
        DependencyProperty.Register(nameof(CoreIndex), typeof(int), typeof(CoreMiniCard),
            new FrameworkPropertyMetadata(0, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty HistoryValuesProperty =
        DependencyProperty.Register(nameof(HistoryValues), typeof(double[]), typeof(CoreMiniCard),
            new FrameworkPropertyMetadata(null, OnHistoryChanged));

    public static readonly DependencyProperty GrayscaleProperty =
        DependencyProperty.Register(nameof(Grayscale), typeof(bool), typeof(CoreMiniCard),
            new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));

    public int CoreIndex
    {
        get => (int)GetValue(CoreIndexProperty);
        set => SetValue(CoreIndexProperty, value);
    }

    public double[]? HistoryValues
    {
        get => (double[]?)GetValue(HistoryValuesProperty);
        set => SetValue(HistoryValuesProperty, value);
    }

    public bool Grayscale
    {
        get => (bool)GetValue(GrayscaleProperty);
        set => SetValue(GrayscaleProperty, value);
    }

    private static void OnHistoryChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var card = (CoreMiniCard)d;
        card._graph.Values      = (double[]?)e.NewValue;
        card._graph.AccentColor = card.EffectiveAccent;
        card.InvalidateVisual();
    }

    // ── Children ───────────────────────────────────────────────────────────

    private readonly Border           _shell;
    private readonly TextBlock        _labelTb;
    private readonly TextBlock        _valueTb;
    private readonly LiveGraphControl _graph;

    public CoreMiniCard()
    {
        _shell = new Border
        {
            CornerRadius    = new CornerRadius(10),
            BorderThickness = new Thickness(1),
            MinHeight       = 70,
        };

        var inner = new Grid();
        inner.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        inner.RowDefinitions.Add(new RowDefinition { Height = new GridLength(1, GridUnitType.Star) });

        var topRow = new Grid { Margin = new Thickness(8, 7, 8, 3) };
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = new GridLength(1, GridUnitType.Star) });
        topRow.ColumnDefinitions.Add(new ColumnDefinition { Width = GridLength.Auto });

        _labelTb = new TextBlock
        {
            FontFamily        = new FontFamily("Consolas"),
            FontSize          = 8,
            FontWeight        = FontWeights.SemiBold,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(_labelTb, 0);

        _valueTb = new TextBlock
        {
            FontFamily        = new FontFamily("Consolas"),
            FontSize          = 11,
            FontWeight        = FontWeights.Bold,
            MinWidth          = 34,
            TextAlignment     = TextAlignment.Right,
            VerticalAlignment = VerticalAlignment.Center,
        };
        Grid.SetColumn(_valueTb, 1);

        topRow.Children.Add(_labelTb);
        topRow.Children.Add(_valueTb);
        Grid.SetRow(topRow, 0);

        _graph = new LiveGraphControl
        {
            Margin      = new Thickness(0, 0, 0, 3),
            MinHeight   = 38,
            AccentColor = AccentColor,
        };
        Grid.SetRow(_graph, 1);

        inner.Children.Add(topRow);
        inner.Children.Add(_graph);
        _shell.Child = inner;

        AddVisualChild(_shell);
        AddLogicalChild(_shell);
    }

    /// <summary>Called by CoreLoadPanel whenever the theme changes or a card is first created.</summary>
    internal void ApplyThemeResources()
    {
        _shell.SetResourceReference(Border.BackgroundProperty,   "CardBg");
        _shell.SetResourceReference(Border.BorderBrushProperty,  "CardBorder");
        _labelTb.SetResourceReference(TextBlock.ForegroundProperty, "TextSubtle");
        // Value foreground is also refreshed in OnRender, but set a safe default here
        _valueTb.SetResourceReference(TextBlock.ForegroundProperty, "TextPrimary");
    }

    private Color EffectiveAccent
    {
        get
        {
            if (Grayscale) return Color.FromArgb(180, 120, 120, 120);
            var pct = HistoryValues?.LastOrDefault() ?? 0;
            return pct > 93 ? RedColor : AccentColor;
        }
    }

    // ── Visual tree ────────────────────────────────────────────────────────

    protected override int VisualChildrenCount => 1;
    protected override Visual GetVisualChild(int index) => _shell;

    protected override Size MeasureOverride(Size availableSize)
    {
        _shell.Measure(availableSize);
        return _shell.DesiredSize;
    }

    protected override Size ArrangeOverride(Size finalSize)
    {
        _shell.Arrange(new Rect(finalSize));
        return finalSize;
    }

    // ── Render pass ────────────────────────────────────────────────────────

    protected override void OnRender(DrawingContext dc)
    {
        base.OnRender(dc);

        _labelTb.Text = $"Core {CoreIndex + 1}";

        var pct = HistoryValues?.LastOrDefault() ?? 0;
        _valueTb.Text = pct < 4 ? "idle" : $"{(int)Math.Round(pct)}%";
        _valueTb.SetResourceReference(TextBlock.ForegroundProperty, pct < 4 ? "TextSubtle" : "TextPrimary");

        _graph.AccentColor = EffectiveAccent;
        _graph.Grayscale   = Grayscale;
    }
}
