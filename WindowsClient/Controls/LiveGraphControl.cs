using System.Windows;
using System.Windows.Media;

namespace AiMonitorClient.Controls;

/// <summary>
/// Full-bleed area + line graph drawn via OnRender.
/// Values are in the 0–100 range (percentage).
/// </summary>
public sealed class LiveGraphControl : FrameworkElement
{
    // ── Dependency properties ──────────────────────────────────────────────

    public static readonly DependencyProperty ValuesProperty =
        DependencyProperty.Register(nameof(Values), typeof(IReadOnlyList<double>),
            typeof(LiveGraphControl),
            new FrameworkPropertyMetadata(null, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty AccentColorProperty =
        DependencyProperty.Register(nameof(AccentColor), typeof(Color),
            typeof(LiveGraphControl),
            new FrameworkPropertyMetadata(Colors.White, FrameworkPropertyMetadataOptions.AffectsRender));

    public static readonly DependencyProperty GrayscaleProperty =
        DependencyProperty.Register(nameof(Grayscale), typeof(bool),
            typeof(LiveGraphControl),
            new FrameworkPropertyMetadata(false, FrameworkPropertyMetadataOptions.AffectsRender));

    public IReadOnlyList<double>? Values
    {
        get => (IReadOnlyList<double>?)GetValue(ValuesProperty);
        set => SetValue(ValuesProperty, value);
    }

    public Color AccentColor
    {
        get => (Color)GetValue(AccentColorProperty);
        set => SetValue(AccentColorProperty, value);
    }

    public bool Grayscale
    {
        get => (bool)GetValue(GrayscaleProperty);
        set => SetValue(GrayscaleProperty, value);
    }

    // ── Render ─────────────────────────────────────────────────────────────

    protected override void OnRender(DrawingContext dc)
    {
        var values = Values;
        if (values == null || values.Count < 2 || ActualWidth <= 0 || ActualHeight <= 0)
            return;

        var w     = ActualWidth;
        var h     = ActualHeight;
        var count = values.Count;
        var step  = w / (count - 1);

        // Compute screen points (WPF y=0 is top)
        var pts = new Point[count];
        for (int i = 0; i < count; i++)
            pts[i] = new Point(i * step, h - Math.Clamp(values[i] / 100.0, 0, 1) * h);

        var accent = Grayscale ? Color.FromArgb(180, 120, 120, 120) : AccentColor;

        // Filled gradient area
        var fillFigure = new PathFigure
        {
            StartPoint = new Point(0, h),
            IsFilled   = true,
            IsClosed   = true
        };
        fillFigure.Segments.Add(new LineSegment(pts[0], false));
        for (int i = 1; i < count; i++)
            fillFigure.Segments.Add(new LineSegment(pts[i], true));
        fillFigure.Segments.Add(new LineSegment(new Point(w, h), false));

        var fillGeom = new PathGeometry([fillFigure]);
        var fillBrush = new LinearGradientBrush(
            Color.FromArgb(110, accent.R, accent.G, accent.B),
            Color.FromArgb(18,  accent.R, accent.G, accent.B),
            new Point(0, 0), new Point(0, 1));
        fillBrush.Freeze();
        fillGeom.Freeze();
        dc.DrawGeometry(fillBrush, null, fillGeom);

        // Line with glow effect
        var lineFigure = new PathFigure { StartPoint = pts[0] };
        for (int i = 1; i < count; i++)
            lineFigure.Segments.Add(new LineSegment(pts[i], true));
        var lineGeom = new PathGeometry([lineFigure]);
        lineGeom.Freeze();
        var lineBrush = new SolidColorBrush(accent);
        lineBrush.Freeze();
        var pen = new Pen(lineBrush, 1.5);
        pen.Freeze();
        dc.DrawGeometry(null, pen, lineGeom);
    }
}
