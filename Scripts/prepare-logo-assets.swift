import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count == 4 else {
    fputs("Usage: prepare-logo-assets.swift app-logo-image menu-bar-logo-image output-directory\n", stderr)
    exit(2)
}

let appLogoURL = URL(fileURLWithPath: CommandLine.arguments[1])
let menuLogoURL = URL(fileURLWithPath: CommandLine.arguments[2])
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[3], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

let colorSpace = CGColorSpaceCreateDeviceRGB()
let sourceBitmapInfo = CGBitmapInfo.byteOrder32Big.union(
    CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
)

func decodeImage(_ url: URL) -> (image: CGImage, pixels: [UInt8], width: Int, height: Int) {
    guard let sourceImage = NSImage(contentsOf: url) else {
        fatalError("Could not read logo image at \(url.path)")
    }
    var proposedRect = NSRect(origin: .zero, size: sourceImage.size)
    guard let image = sourceImage.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
        fatalError("Could not decode logo image at \(url.path)")
    }
    let width = image.width
    let height = image.height
    let rowBytes = width * 4
    var pixels = [UInt8](repeating: 0, count: rowBytes * height)
    pixels.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: rowBytes,
            space: colorSpace,
            bitmapInfo: sourceBitmapInfo.rawValue
        ) else { fatalError("Could not decode logo image") }
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    return (image, pixels, width, height)
}

let (_, sourcePixels, sourceWidth, sourceHeight) = decodeImage(appLogoURL)
func rgbaIndex(x: Int, y: Int) -> Int { (y * sourceWidth + x) * 4 }

func makeImage(_ pixels: [UInt8], width: Int, height: Int) -> CGImage {
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: sourceBitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: true,
        intent: .defaultIntent
    )!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else { fatalError("Could not create PNG at \(url.path)") }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        fatalError("Could not write PNG at \(url.path)")
    }
}

func contentBounds(_ pixels: [UInt8], width: Int, height: Int, threshold: UInt8 = 8) -> CGRect {
    var minX = width
    var minY = height
    var maxX = -1
    var maxY = -1
    for y in 0..<height {
        for x in 0..<width where pixels[(y * width + x) * 4 + 3] > threshold {
            minX = min(minX, x)
            minY = min(minY, y)
            maxX = max(maxX, x)
            maxY = max(maxY, y)
        }
    }
    guard maxX >= minX, maxY >= minY else { fatalError("Logo has no visible pixels") }
    return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
}

func squareCanvas(from pixels: [UInt8], width: Int, height: Int, outputSize: Int, fillRatio: CGFloat) -> CGImage {
    let source = makeImage(pixels, width: width, height: height)
    let bounds = contentBounds(pixels, width: width, height: height)
    let scale = min(
        CGFloat(outputSize) * fillRatio / bounds.width,
        CGFloat(outputSize) * fillRatio / bounds.height
    )
    let drawWidth = bounds.width * scale
    let drawHeight = bounds.height * scale
    let destinationRect = CGRect(
        x: (CGFloat(outputSize) - drawWidth) / 2,
        y: (CGFloat(outputSize) - drawHeight) / 2,
        width: drawWidth,
        height: drawHeight
    )
    var output = [UInt8](repeating: 0, count: outputSize * outputSize * 4)
    output.withUnsafeMutableBytes { bytes in
        guard let context = CGContext(
            data: bytes.baseAddress,
            width: outputSize,
            height: outputSize,
            bitsPerComponent: 8,
            bytesPerRow: outputSize * 4,
            space: colorSpace,
            bitmapInfo: sourceBitmapInfo.rawValue
        ) else { fatalError("Could not create output logo") }
        context.interpolationQuality = .high
        context.translateBy(x: 0, y: CGFloat(outputSize))
        context.scaleBy(x: 1, y: -1)
        context.draw(source, in: destinationRect, byTiling: false)
    }
    return makeImage(output, width: outputSize, height: outputSize)
}

let leftPanelWidth = sourceWidth / 2
let panelHeight = sourceHeight

// The colorful mark has a low-saturation background around the blue app tile.
// Remove only background pixels connected to the panel edge, keeping the white
// artwork inside the tile intact.
var appPixels = [UInt8](repeating: 0, count: leftPanelWidth * panelHeight * 4)
for y in 0..<panelHeight {
    for x in 0..<leftPanelWidth {
        let sourceIndex = rgbaIndex(x: x, y: y)
        let targetIndex = (y * leftPanelWidth + x) * 4
        appPixels[targetIndex] = sourcePixels[sourceIndex]
        appPixels[targetIndex + 1] = sourcePixels[sourceIndex + 1]
        appPixels[targetIndex + 2] = sourcePixels[sourceIndex + 2]
        appPixels[targetIndex + 3] = 255
    }
}

var visited = [Bool](repeating: false, count: leftPanelWidth * panelHeight)
var queue: [Int] = []
func isNeutralBackground(_ index: Int) -> Bool {
    let pixel = index * 4
    let red = Int(appPixels[pixel])
    let green = Int(appPixels[pixel + 1])
    let blue = Int(appPixels[pixel + 2])
    return max(red, green, blue) - min(red, green, blue) < 42
}
func enqueueIfBackground(_ x: Int, _ y: Int) {
    guard x >= 0, x < leftPanelWidth, y >= 0, y < panelHeight else { return }
    let index = y * leftPanelWidth + x
    guard !visited[index], isNeutralBackground(index) else { return }
    visited[index] = true
    queue.append(index)
}
for x in 0..<leftPanelWidth {
    enqueueIfBackground(x, 0)
    enqueueIfBackground(x, panelHeight - 1)
}
for y in 0..<panelHeight {
    enqueueIfBackground(0, y)
    enqueueIfBackground(leftPanelWidth - 1, y)
}
var queueIndex = 0
while queueIndex < queue.count {
    let index = queue[queueIndex]
    queueIndex += 1
    let x = index % leftPanelWidth
    let y = index / leftPanelWidth
    appPixels[index * 4 + 3] = 0
    enqueueIfBackground(x - 1, y)
    enqueueIfBackground(x + 1, y)
    enqueueIfBackground(x, y - 1)
    enqueueIfBackground(x, y + 1)
}

let appIcon = squareCanvas(from: appPixels, width: leftPanelWidth, height: panelHeight, outputSize: 1024, fillRatio: 0.9)
try writePNG(appIcon, to: outputDirectory.appendingPathComponent("AppIcon.png"))

// This monochrome artwork is already a transparent black badge with the logo
// cut out of it. Use its alpha directly as a template mask so AppKit can tint
// the supplied design for light and dark menu bars.
let (_, menuSourcePixels, menuWidth, menuHeight) = decodeImage(menuLogoURL)
var menuPixels = [UInt8](repeating: 0, count: menuWidth * menuHeight * 4)
for y in 0..<menuHeight {
    for x in 0..<menuWidth {
        let sourceIndex = (y * menuWidth + x) * 4
        let targetIndex = sourceIndex
        menuPixels[targetIndex] = 0
        menuPixels[targetIndex + 1] = 0
        menuPixels[targetIndex + 2] = 0
        menuPixels[targetIndex + 3] = menuSourcePixels[sourceIndex + 3]
    }
}

let menuIcon = squareCanvas(from: menuPixels, width: menuWidth, height: menuHeight, outputSize: 512, fillRatio: 0.86)
try writePNG(menuIcon, to: outputDirectory.appendingPathComponent("MenuBarIcon.png"))
