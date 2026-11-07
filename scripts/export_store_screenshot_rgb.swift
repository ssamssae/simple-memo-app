import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let args=CommandLine.arguments
precondition(args.count==3)
let source=CGImageSourceCreateWithURL(URL(fileURLWithPath:args[1]) as CFURL,nil)!
let im=CGImageSourceCreateImageAtIndex(source,0,nil)!
let w=im.width,h=im.height,space=CGColorSpace(name:CGColorSpace.sRGB)!
let ctx=CGContext(data:nil,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(im,in:CGRect(x:0,y:0,width:w,height:h))
let p=ctx.data!.assumingMemoryBound(to:UInt8.self)
var rgb=Data(count:w*h*3)
rgb.withUnsafeMutableBytes { (buffer:UnsafeMutableRawBufferPointer) in
    let dst=buffer.baseAddress!.assumingMemoryBound(to:UInt8.self)
    for i in 0..<(w*h) {
        precondition(p[i*4+3]==255,"Screenshot has transparent pixels")
        for c in 0..<3 {dst[i*3+c]=p[i*4+c]}
    }
}
let provider=CGDataProvider(data:rgb as CFData)!
let out=CGImage(width:w,height:h,bitsPerComponent:8,bitsPerPixel:24,bytesPerRow:w*3,space:space,bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.none.rawValue),provider:provider,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
let dest=CGImageDestinationCreateWithURL(URL(fileURLWithPath:args[2]) as CFURL,UTType.png.identifier as CFString,1,nil)!
CGImageDestinationAddImage(dest,out,nil);precondition(CGImageDestinationFinalize(dest))
