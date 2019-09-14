//
// Copyright (C) 2019 Muhammad Tayyab Akram
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import UIKit

public enum RenderingStyle {
    /// Glyphs drawn with this style will be filled, ignoring all stroke-related settings in the
    /// renderer.
    case fill
    /// Glyphs drawn with this style will be both filled and stroked at the same time, respecting
    /// the stroke-related settings in the renderer.
    case fillStroke
    /// Glyphs drawn with this style will be stroked, respecting the stroke-related settings in the
    /// the renderer.
    case stroke
}

/// Specifies the treatment for the beginning and ending of stroked lines and paths.
public enum StrokeCap: Int {
    /// The stroke ends with the path, and does not project beyond it.
    case butt = 0
    /// The stroke projects out as a semicircle, with the center at the end of the
    case round = 1
    /// The stroke projects out as a square, with the center at the end of the path.
    case square = 2
}

/// Specifies the treatment where lines and curve segments join on a stroked path.
public enum StrokeJoin : Int {
    /// The outer edges of a join meet with a straight line.
    case bevel = 1
    /// The outer edges of a join meet at a sharp angle.
    case miter = 2
    /// The outer edges of a join meet in a circular arc.
    case round = 0
}

public class Renderer {
    private var glyphStrike: GlyphStrike = GlyphStrike()
    private var glyphLineRadius: Int = 32
    private var glyphMiterLimit: Int = 0x10000
    private var shouldRender: Bool = false

    init() {
        updatePixelSizes()
    }

    /// The fill color for glyphs. Its default value is `.black`.
    public var fillColor: UIColor = .black

    /// The style, used for controlling how glyphs should appear while drawing. Its default value is
    /// `.fill`.
    public var renderingStyle: RenderingStyle = .fill

    /// The direction in which the pen will advance after drawing a glyph. Its default value is
    /// `.leftToRight`.
    public var writingDirection: WritingDirection = .leftToRight

    /// The typeface, used for drawing glyphs.
    public var typeface: Typeface! = nil {
        didSet {
            glyphStrike.typeface = typeface
        }
    }

    /// The type size, applied on glyphs while drawing.
    public var typeSize: CGFloat = 16.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The slant angle for glyphs. Its default value is 0.
    public var slantAngle: CGFloat = 0.0 {
        didSet {
            updateTransform()
        }
    }

    public var renderScale: CGFloat = 1.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The horizontal scale factor for drawing/measuring glyphs. Its default value is 1.0. Values
    /// greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the glyphs
    /// narrower.
    public var scaleX: CGFloat = 1.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The vertical scale factor for drawing/measuring glyphs. Its default value is 1.0. Values
    /// greater than 1.0 will stretch the glyphs wider. Values less than 1.0 will stretch the glyphs
    /// narrower.
    public var scaleY: CGFloat = 1.0 {
        didSet {
            updatePixelSizes()
        }
    }

    /// The stroke color for glyphs. Its default value is `.black`.
    public var strokeColor: UIColor = .black

    /// The width, in pixels, for stroking glyphs.
    public var strokeWidth: CGFloat = 1.0 {
        didSet {
            glyphLineRadius = Int((strokeWidth * 64.0 / 2.0) + 0.5)
        }
    }

    /// The stroke cap style which controls how the start and end of stroked lines and paths are
    /// treated. Its default value is `.butt`.
    public var strokeCap: StrokeCap = .butt

    /// The stroke join type. Its default value is `.round`.
    public var strokeJoin: StrokeJoin = .round

    /// The stroke miter limit in pixels. This is used to control the behavior of miter joins when
    /// the joins angle is sharp.
    public var strokeMiter: CGFloat = 1.0 {
        didSet {
            glyphMiterLimit = Int((strokeMiter * 0x10000) + 0.5)
        }
    }

    /// The shadow radius, in pixels, used when drawing glyphs. Its default value is
    /// zero. The shadow would be disabled if the value is set to zero.
    public var shadowRadius: CGFloat = 0.0

    /// The horizontal shadow offset, in pixels.
    public var shadowDx: CGFloat = 0.0

    /// The vertical shadow offset in pixels.
    public var shadowDy: CGFloat = 0.0

    /// The shadow color.
    public var shadowColor: UIColor = .black

    private func updatePixelSizes() {
        let pixelWidth = Int((typeSize * scaleX * renderScale * 64.0) + 0.5)
        let pixelHeight = Int((typeSize * scaleY * renderScale * 64.0) + 0.5)

        // Minimum size supported by Freetype is 64x64.
        shouldRender = (pixelWidth >= 64 && pixelHeight >= 64)
        glyphStrike.pixelWidth = pixelWidth
        glyphStrike.pixelHeight = pixelHeight
    }

    private func updateTransform() {
        glyphStrike.skewX = Int((slantAngle * 0x10000) + 0.5)
    }

    private func cachedGlyphPath(for glyphID: UInt16) -> CGPath? {
        return GlyphCache.instance.glyphPath(with: glyphStrike, for: glyphID)
    }

    /// Generates the path of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose path is generated.
    /// - Returns: The path of the glyph specified by `glyphID`.
    public func makePath(glyphID: UInt16) -> UIBezierPath? {
        if let glyphPath = cachedGlyphPath(for: glyphID) {
            return UIBezierPath(cgPath: glyphPath)
        }

        return nil
    }

    /// Generates a cumulative path of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIds: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    /// - Returns: The cumulative path of specified glyphs.
    public func makePath<GS, OS, AS>(glyphIDs: GS, offsets: OS, advances: AS) -> UIBezierPath
        where GS : Sequence, GS.Element == UInt16,
              OS : Sequence, OS.Element == CGPoint,
              AS : Sequence, AS.Element == CGFloat {
        let comulativePath = CGMutablePath()
        var penX: CGFloat = 0.0

        var offsetIter = offsets.makeIterator()
        var advanceIter = advances.makeIterator()

        for glyphID in glyphIDs {
            let offset = offsetIter.next()!
            let advance = advanceIter.next()!

            if let path = cachedGlyphPath(for: glyphID) {
                let position = CGAffineTransform(scaleX: penX + offset.x, y: offset.y)
                comulativePath.addPath(path, transform: position)
            }

            penX += advance
        }

        return UIBezierPath(cgPath: comulativePath)
    }

    private func cachedBoundingBox(for glyphID: UInt16) -> CGRect {
        let glyph = GlyphCache.instance.maskGlyph(with: glyphStrike, for: glyphID)
        return CGRect(x: glyph.lsb,
                      y: glyph.tsb,
                      width: glyph.image?.width ?? 0,
                      height: glyph.image?.height ?? 0)
    }

    /// Calculates the bounding box of specified glyph.
    ///
    /// - Parameter glyphID: The ID of glyph whose bounding box is calculated.
    /// - Returns: A rectangle that tightly encloses the path of the specified glyph.
    public func computeBoundingBox(for glyphID: UInt16) -> CGRect {
        return cachedBoundingBox(for: glyphID)
    }

    /// Calculates the bounding box of specified glyphs.
    ///
    /// - Parameters:
    ///   - glyphIDs: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    /// - Returns: A rectangle that tightly encloses the paths of specified glyphs.
    public func computeBoundingBox<GS, OS, AS>(glyphIDs: GS, offsets: OS, advances: AS) -> CGRect
        where GS: Sequence, GS.Element == UInt16,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        var comulativeBox = CGRect()
        var penX: CGFloat = 0.0

        var offsetIter = offsets.makeIterator()
        var advanceIter = advances.makeIterator()

        for glyphID in glyphIDs {
            let offset = offsetIter.next()!
            let advance = advanceIter.next()!

            var glyphBox = cachedBoundingBox(for: glyphID)
            glyphBox = glyphBox.offsetBy(dx: penX + offset.x, dy: offset.y)

            comulativeBox = comulativeBox.union(glyphBox)

            penX += advance
        }

        return comulativeBox
    }

    private func drawGlyphs<GS, OS, AS>(on context: CGContext, glyphIDs: GS, offsets: OS, advances: AS, strokeMode: Bool)
        where GS: Sequence, GS.Element == UInt16,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        let cache = GlyphCache.instance
        let reverseMode = (writingDirection == .rightToLeft)
        var penX: CGFloat = 0.0

        var offsetIter = offsets.makeIterator()
        var advanceIter = advances.makeIterator()

        for glyphID in glyphIDs {
            let offset = offsetIter.next()!
            let advance = advanceIter.next()!

            if reverseMode {
                penX -= advance
            }

            let maskGlyph: Glyph

            if !strokeMode {
                maskGlyph = cache.maskGlyph(with: glyphStrike, for: glyphID)
            } else {
                maskGlyph = cache.maskGlyph(
                    with: glyphStrike,
                    for: glyphID,
                    lineRadius: glyphLineRadius,
                    lineCap: FT_Stroker_LineCap(UInt32(strokeCap.rawValue)),
                    lineJoin: FT_Stroker_LineJoin(UInt32(strokeJoin.rawValue)),
                    miterLimit: glyphMiterLimit)
            }

            if let maskImage = maskGlyph.image {
                let rect = CGRect(
                    x: round(penX + offset.x + (CGFloat(maskGlyph.lsb) / renderScale)),
                    y: round(-offset.y - (CGFloat(maskGlyph.tsb) / renderScale)),
                    width: CGFloat(maskImage.width) / renderScale,
                    height: CGFloat(maskImage.height) / renderScale)

                context.translateBy(x: rect.minX, y: rect.maxY)
                context.scaleBy(x: 1.0, y: -1.0)

                context.draw(maskImage, in: CGRect(origin: .zero, size: rect.size))

                context.scaleBy(x: 1.0, y: -1.0)
                context.translateBy(x: -rect.minX, y: -rect.maxY)
            }

            if !reverseMode {
                penX += advance
            }
        }
    }

    /// Draws specified glyphs onto the given context.
    ///
    /// - Parameters:
    ///   - context: The context onto which to draw the glyphs.
    ///   - glyphIDs: A sequence of glyph IDs.
    ///   - offsets: A sequence of glyph offsets.
    ///   - advances: A sequence of glyph advances.
    public func drawGlyphs<GS, OS, AS>(on context: CGContext, glyphIDs: GS, offsets: OS, advances: AS)
        where GS: Sequence, GS.Element == UInt16,
              OS: Sequence, OS.Element == CGPoint,
              AS: Sequence, AS.Element == CGFloat {
        if shouldRender {
            context.setShadow(offset: CGSize(width: shadowDx, height: shadowDy),
                              blur: shadowRadius,
                              color: shadowColor.cgColor)
        }

        if renderingStyle == .fill || renderingStyle == .fillStroke {
            context.setFillColor(fillColor.cgColor)
            drawGlyphs(on: context, glyphIDs: glyphIDs, offsets: offsets, advances: advances, strokeMode: false)
        }

        if renderingStyle == .stroke || renderingStyle == .fillStroke {
            context.setFillColor(strokeColor.cgColor)
            drawGlyphs(on: context, glyphIDs: glyphIDs, offsets: offsets, advances: advances, strokeMode: true)
        }
    }
}