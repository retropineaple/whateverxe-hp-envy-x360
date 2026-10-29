import CoreGraphics
let d=CGMainDisplayID()
let opts=[kCGDisplayShowDuplicateLowResolutionModes:true] as CFDictionary
for m in CGDisplayCopyAllDisplayModes(d,opts) as! [CGDisplayMode] {
  print(m.width,"x",m.height,"px",m.pixelWidth,"x",m.pixelHeight,"gui",m.isUsableForDesktopGUI(),"flags",String(m.ioFlags,radix:16),"id",m.ioDisplayModeID)
}
