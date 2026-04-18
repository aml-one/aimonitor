#!/usr/bin/env swift
/// Run from the project root:  swift scripts/generate_icon.swift
import AppKit

let outputDir = "AiMonitor/Assets.xcassets/AppIcon.appiconset"
let fm = FileManager.default
try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let _ = NSApplication.shared   // so SF symbols resolve

// Each entry: (exactPixelSize, filename)
let specs: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func makePNG(pixels: Int) -> Data? {
    let s     = CGFloat(pixels)
    let cs    = CGColorSpaceCreateDeviceRGB()
    let flags = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: flags.rawValue) else { return nil }

    // Flip coordinate system to top-left origin (easier maths)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let all = CGRect(x: 0, y: 0, width: s, height: s)
    let cr  = s * 0.22   // corner radius

    // ── 1. Rounded-rect clip + dark fill ──
    let bgPath = CGPath(roundedRect: all, cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(bgPath); ctx.clip()
    ctx.setFillColor(CGColor(red: 0.038, green: 0.038, blue: 0.082, alpha: 1))
    ctx.fill(all)

    // ── 2. Ambient glow blobs ──
    func radial(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat,
                r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let grad = CGGradient(
            colorsSpace: cs,
            colors: [CGColor(red: r, green: g, blue: b, alpha: a),
                     CGColor(red: r, green: g, blue: b, alpha: 0)] as CFArray,
            locations: [0, 1]) else { return }
        ctx.drawRadialGradient(grad,
            startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
            endCenter:   CGPoint(x: cx, y: cy), endRadius: rad, options: [])
    }
    radial(s*0.26, s*0.70, s*0.55, r: 0.55, g: 0.75, b: 1.00, a: 0.32)
    radial(s*0.78, s*0.34, s*0.48, r: 0.77, g: 0.58, b: 1.00, a: 0.26)
    radial(s*0.52, s*0.50, s*0.35, r: 0.52, g: 1.00, b: 0.76, a: 0.12)

    // ── 3. SF Symbol via NSImage → CGImage, drawn at exact pixels ──
    let ptSize  = s * 0.50
    let symCfg  = NSImage.SymbolConfiguration(pointSize: ptSize, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0),
        ]))
    if let sym  = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil)?
           .withSymbolConfiguration(symCfg) {
        // Render symbol into its own exact-pixel CGContext
        let sw  = Int(sym.size.width  * 2)   // render at 2x to avoid blur
        let sh  = Int(sym.size.height * 2)
        if sw > 0 && sh > 0,
           let symCtx = CGContext(data: nil, width: sw, height: sh,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: flags.rawValue) {
            let nsCtx = NSGraphicsContext(cgContext: symCtx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            sym.draw(in: CGRect(x: 0, y: 0, width: CGFloat(sw), height: CGFloat(sh)))
            NSGraphicsContext.restoreGraphicsState()

            if let symImg = symCtx.makeImage() {
                let dx = (s - CGFloat(sw) / 2) / 2
                let dy = (s - CGFloat(sh) / 2) / 2
                ctx.draw(symImg, in: CGRect(x: dx, y: dy,
                                            width:  CGFloat(sw) / 2,
                                            height: CGFloat(sh) / 2))
            }
        }
    }

    // ── 4. Glass shimmer at top ──
    if let grad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red:1,green:1,blue:1,alpha:0.14),
                 CGColor(red:1,green:1,blue:1,alpha:0.0)] as CFArray,
        locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: s/2, y: 0),
            end:   CGPoint(x: s/2, y: s * 0.48), options: [])
    }

    // ── 5. Inner border ──
    ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.14))
    ctx.setLineWidth(max(s * 0.012, 1))
    ctx.addPath(CGPath(roundedRect: all.insetBy(dx: max(s*0.006,0.5),
                                                 dy: max(s*0.006,0.5)),
                       cornerWidth: cr, cornerHeight: cr, transform: nil))
    ctx.strokePath()

    // ── 6. Encode to PNG ──
    guard let cgImg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])
}

for (pixels, name) in specs {
    let path = "\(outputDir)/\(name)"
    if let data = makePNG(pixels: pixels) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("✓  \(name)  (\(pixels)×\(pixels) px)")
        } catch { print("✗  \(name): \(error)") }
    } else {
        print("⚠️  Failed to render \(name)")
    }
}
print("Done.")

try? fm.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
let _ = NSApplication.shared   // so SF symbols resolve

// Each entry: (exactPixelSize, filename)
let specs: [(Int, String)] = [
    (16,   "icon_16x16.png"),
    (32,   "icon_16x16@2x.png"),
    (32,   "icon_32x32.png"),
    (64,   "icon_32x32@2x.png"),
    (128,  "icon_128x128.png"),
    (256,  "icon_128x128@2x.png"),
    (256,  "icon_256x256.png"),
    (512,  "icon_256x256@2x.png"),
    (512,  "icon_512x512.png"),
    (1024, "icon_512x512@2x.png"),
]

func makePNG(pixels: Int) -> Data? {
    let s     = CGFloat(pixels)
    let cs    = CGColorSpaceCreateDeviceRGB()
    let flags = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
    guard let ctx = CGContext(data: nil, width: pixels, height: pixels,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: cs, bitmapInfo: flags.rawValue) else { return nil }

    // Flip coordinate system to top-left origin (easier maths)
    ctx.translateBy(x: 0, y: s)
    ctx.scaleBy(x: 1, y: -1)

    let all = CGRect(x: 0, y: 0, width: s, height: s)
    let cr  = s * 0.22   // corner radius

    // ── 1. Rounded-rect clip + dark fill ──
    let bgPath = CGPath(roundedRect: all, cornerWidth: cr, cornerHeight: cr, transform: nil)
    ctx.addPath(bgPath); ctx.clip()
    ctx.setFillColor(CGColor(red: 0.038, green: 0.038, blue: 0.082, alpha: 1))
    ctx.fill(all)

    // ── 2. Ambient glow blobs ──
    func radial(_ cx: CGFloat, _ cy: CGFloat, _ rad: CGFloat,
                r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        guard let grad = CGGradient(
            colorsSpace: cs,
            colors: [CGColor(red: r, green: g, blue: b, alpha: a),
                     CGColor(red: r, green: g, blue: b, alpha: 0)] as CFArray,
            locations: [0, 1]) else { return }
        ctx.drawRadialGradient(grad,
            startCenter: CGPoint(x: cx, y: cy), startRadius: 0,
            endCenter:   CGPoint(x: cx, y: cy), endRadius: rad, options: [])
    }
    radial(s*0.26, s*0.70, s*0.55, r: 0.55, g: 0.75, b: 1.00, a: 0.32)
    radial(s*0.78, s*0.34, s*0.48, r: 0.77, g: 0.58, b: 1.00, a: 0.26)
    radial(s*0.52, s*0.50, s*0.35, r: 0.52, g: 1.00, b: 0.76, a: 0.12)

    // ── 3. SF Symbol via NSImage → CGImage, drawn at exact pixels ──
    let ptSize  = s * 0.50
    let symCfg  = NSImage.SymbolConfiguration(pointSize: ptSize, weight: .bold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [
            NSColor(red: 0.55, green: 0.75, blue: 1.0, alpha: 1.0),
        ]))
    if let sym  = NSImage(systemSymbolName: "waveform.path.ecg", accessibilityDescription: nil)?
           .withSymbolConfiguration(symCfg) {
        // Render symbol into its own exact-pixel CGContext
        let sw  = Int(sym.size.width  * 2)   // render at 2x to avoid blur
        let sh  = Int(sym.size.height * 2)
        if sw > 0 && sh > 0,
           let symCtx = CGContext(data: nil, width: sw, height: sh,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: cs, bitmapInfo: flags.rawValue) {
            let nsCtx = NSGraphicsContext(cgContext: symCtx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsCtx
            sym.draw(in: CGRect(x: 0, y: 0, width: CGFloat(sw), height: CGFloat(sh)))
            NSGraphicsContext.restoreGraphicsState()

            if let symImg = symCtx.makeImage() {
                let dx = (s - CGFloat(sw) / 2) / 2
                let dy = (s - CGFloat(sh) / 2) / 2
                ctx.draw(symImg, in: CGRect(x: dx, y: dy,
                                            width:  CGFloat(sw) / 2,
                                            height: CGFloat(sh) / 2))
            }
        }
    }

    // ── 4. Glass shimmer at top ──
    if let grad = CGGradient(
        colorsSpace: cs,
        colors: [CGColor(red:1,green:1,blue:1,alpha:0.14),
                 CGColor(red:1,green:1,blue:1,alpha:0.0)] as CFArray,
        locations: [0, 1]) {
        ctx.drawLinearGradient(grad,
            start: CGPoint(x: s/2, y: 0),
            end:   CGPoint(x: s/2, y: s * 0.48), options: [])
    }

    // ── 5. Inner border ──
    ctx.setStrokeColor(CGColor(red:1,green:1,blue:1,alpha:0.14))
    ctx.setLineWidth(max(s * 0.012, 1))
    ctx.addPath(CGPath(roundedRect: all.insetBy(dx: max(s*0.006,0.5),
                                                 dy: max(s*0.006,0.5)),
                       cornerWidth: cr, cornerHeight: cr, transform: nil))
    ctx.strokePath()

    // ── 6. Encode to PNG ──
    guard let cgImg = ctx.makeImage() else { return nil }
    let rep = NSBitmapImageRep(cgImage: cgImg)
    return rep.representation(using: .png, properties: [:])
}

for (pixels, name) in specs {
    let path = "\(outputDir)/\(name)"
    if let data = makePNG(pixels: pixels) {
        do {
            try data.write(to: URL(fileURLWithPath: path))
            print("✓  \(name)  (\(pixels)×\(pixels) px)")
        } catch { print("✗  \(name): \(error)") }
    } else {
        print("⚠️  Failed to render \(name)")
    }
}
print("Done.")
