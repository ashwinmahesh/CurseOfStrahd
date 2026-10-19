// veo_frames.swift <video> <out dir>: every frame of a video as PNG (macOS AVFoundation, no ffmpeg; tools/art/veo_anims.py).
import AVFoundation
import ImageIO
import CoreImage
import UniformTypeIdentifiers
let a = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: a[1]))
let track = asset.tracks(withMediaType: .video)[0]
let reader = try AVAssetReader(asset: asset)
let out = AVAssetReaderTrackOutput(track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
reader.add(out)
reader.startReading()
try? FileManager.default.createDirectory(atPath: a[2], withIntermediateDirectories: true)
var i = 0
let ctx = CIContext()
while let sb = out.copyNextSampleBuffer() {
	guard let pb = CMSampleBufferGetImageBuffer(sb) else { continue }
	let ci = CIImage(cvPixelBuffer: pb)
	let cg = ctx.createCGImage(ci, from: ci.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
	let url = URL(fileURLWithPath: a[2] + String(format: "/%04d.png", i))
	let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
	CGImageDestinationAddImage(dst, cg, nil); CGImageDestinationFinalize(dst)
	i += 1
}
print("frames \(i), fps \(track.nominalFrameRate), size \(track.naturalSize)")
