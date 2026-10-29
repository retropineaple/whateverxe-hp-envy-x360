import CoreGraphics
let d=CGMainDisplayID()
let opts=[kCGDisplayShowDuplicateLowResolutionModes:true] as CFDictionary
let modes=CGDisplayCopyAllDisplayModes(d,opts) as! [CGDisplayMode]
guard let m=modes.first(where:{$0.width==1440 && $0.height==900 && $0.pixelWidth==2880 && $0.isUsableForDesktopGUI()}) else {print("no mode");exit(1)}
var c:CGDisplayConfigRef?
CGBeginDisplayConfiguration(&c)
CGConfigureDisplayWithDisplayMode(c,d,m,nil)
print(CGCompleteDisplayConfiguration(c,.permanently).rawValue)
