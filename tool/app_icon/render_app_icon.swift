// Renders the app icon source images into assets/icon/, and the Misék tab
// icon (assets/images/chalice.png with its 2x–4x variants).
//
// The chalice is drawn from geometry measured on the original 480 px
// mise.png, so the icon can be regenerated at any size. The generated PNGs
// are the input of flutter_launcher_icons; flutter_launcher_icons.yaml has the
// steps that follow.
//
// Run from the repository root (macOS only, uses CoreGraphics):
//   swift tool/app_icon/render_app_icon.swift

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// The purple of the original mise.png. Also the Android adaptive background
/// colour in flutter_launcher_icons.yaml.
let purple = CGColor(srgbRed: 91 / 255, green: 39 / 255, blue: 173 / 255, alpha: 1)
let white = CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1)

/// Design space: the original 480×480 image, whose purple circle has its
/// centre at (240, 240) and a radius of 220. The chalice fits inside it.
let designCentre = CGPoint(x: 240, y: 240)
let designCircleRadius: CGFloat = 220
/// From the top of the host to the base of the foot.
let chaliceHeight: CGFloat = 380 - 102

func chalicePath() -> CGPath {
  let path = CGMutablePath()
  // Host above the cup.
  path.addEllipse(in: CGRect(x: 240 - 37, y: 139 - 37, width: 74, height: 74))
  // Cup: flat rim, lower half of an ellipse.
  path.move(to: CGPoint(x: 157, y: 186))
  path.addLine(to: CGPoint(x: 323, y: 186))
  path.addArc(
    center: .zero, radius: 1, startAngle: 0, endAngle: .pi, clockwise: false,
    transform: CGAffineTransform(translationX: 240, y: 186).scaledBy(x: 83, y: 68))
  path.closeSubpath()
  // Stem, overlapping the cup and the foot.
  path.addRect(CGRect(x: 223, y: 240, width: 34, height: 126))
  // Foot: flat base, upper half of an ellipse.
  path.move(to: CGPoint(x: 298, y: 380))
  path.addLine(to: CGPoint(x: 182, y: 380))
  path.addArc(
    center: .zero, radius: 1, startAngle: .pi, endAngle: 2 * .pi, clockwise: false,
    transform: CGAffineTransform(translationX: 240, y: 380).scaledBy(x: 58, y: 27))
  path.closeSubpath()
  return path
}

/// Draws one [pixels]×[pixels] image to [path], relative to the repository
/// root. [circleRatio] is the share of the edge that the original purple
/// circle's diameter maps to; the chalice scales with it.
func render(
  _ path: String, pixels: Int, circleRatio: CGFloat, background: Bool, circle: Bool
) {
  let size = CGFloat(pixels)
  let context = CGContext(
    data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
    bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

  if background {
    context.setFillColor(purple)
    context.fill(CGRect(x: 0, y: 0, width: size, height: size))
  }

  // Design space is y-down; CoreGraphics is y-up.
  let scale = size * circleRatio / (2 * designCircleRadius)
  context.translateBy(x: size / 2, y: size / 2)
  context.scaleBy(x: scale, y: -scale)
  context.translateBy(x: -designCentre.x, y: -designCentre.y)

  if circle {
    context.setFillColor(purple)
    context.fillEllipse(
      in: CGRect(
        x: designCentre.x - designCircleRadius, y: designCentre.y - designCircleRadius,
        width: 2 * designCircleRadius, height: 2 * designCircleRadius))
  }

  context.setFillColor(white)
  context.addPath(chalicePath())
  context.fillPath(using: .winding)

  let url = URL(fileURLWithPath: path)
  let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil)!
  CGImageDestinationAddImage(destination, context.makeImage()!, nil)
  guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(url.path)")
  }
  print("Wrote \(url.path)")
}

/// Edge length of the launcher icon sources; the App Store icon needs 1024 px.
let launcherIconPixels = 1024

// iOS masks the square itself, so the purple fills it and the circle's
// diameter is the full edge.
render(
  "assets/icon/app_icon.png", pixels: launcherIconPixels, circleRatio: 1,
  background: true, circle: false)

// Android adaptive foreground: a 108 dp layer of which the launcher shows the
// middle 72 dp, so the circle's diameter maps to 72/108 of the edge. The
// launcher mask replaces the circle; the background is a colour.
render(
  "assets/icon/app_icon_foreground.png", pixels: launcherIconPixels,
  circleRatio: 72 / 108, background: false, circle: false)

// Android before API 26 shows the image unmasked: keep the round icon with the
// original margin.
render(
  "assets/icon/app_icon_android_legacy.png", pixels: launcherIconPixels,
  circleRatio: 440 / 480, background: false, circle: true)

// Misék tab icon: a white silhouette the navigation bar tints, on a 24 dp
// canvas like the Material icons beside it. Their glyphs are about 20 dp tall.
let tabIconDp = 24
let tabGlyphRatio: CGFloat = 20 / 24
for density in 1...4 {
  let variant = density == 1 ? "" : "\(density).0x/"
  render(
    "assets/images/\(variant)chalice.png", pixels: tabIconDp * density,
    circleRatio: tabGlyphRatio * 2 * designCircleRadius / chaliceHeight,
    background: false, circle: false)
}
