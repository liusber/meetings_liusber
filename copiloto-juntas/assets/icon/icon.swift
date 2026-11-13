// Ícono de Auren: "A" de listón doblado sobre azul marino.
// Uso: swift icon.swift <carpeta>  → icon_full, icon_mac, icon_bg, icon_fg (2048 px; reducir a 1024).
import AppKit

func c(_ r: Int, _ g: Int, _ b: Int, _ a: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat(r)/255, green: CGFloat(g)/255, blue: CGFloat(b)/255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!
func linear(_ ctx: CGContext, _ cols: [CGColor], _ from: CGPoint, _ to: CGPoint) {
  ctx.drawLinearGradient(CGGradient(colorsSpace: space, colors: cols as CFArray, locations: nil)!,
                         start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

/// layer: 0 completo, 1 solo fondo, 2 solo la A (sin fondo, reducida para Android adaptable).
func render(_ path: String, mac: Bool, layer: Int = 0) {
  let S: CGFloat = 2048
  let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
  ctx.scaleBy(x: 2, y: 2)  // dibujo en coordenadas de 1024
  let inset: CGFloat = mac ? 100 : 0
  let plate = CGRect(x: inset, y: inset, width: 1024 - 2*inset, height: 1024 - 2*inset)
  let platePath = CGPath(roundedRect: plate, cornerWidth: mac ? 185 : 0, cornerHeight: mac ? 185 : 0, transform: nil)

  if layer != 2 {
    if mac {
      ctx.saveGState()
      ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: c(0, 0, 0, 0.4))
      ctx.addPath(platePath); ctx.setFillColor(c(8, 11, 30)); ctx.fillPath()
      ctx.restoreGState()
    }
    ctx.saveGState()
    ctx.addPath(platePath); ctx.clip()
    linear(ctx, [c(17, 21, 52), c(5, 7, 20)], CGPoint(x: 300, y: 1024), CGPoint(x: 700, y: 0))
    // Resplandor suave detrás de la A.
    ctx.drawRadialGradient(CGGradient(colorsSpace: space, colors: [c(92, 96, 235, 0.28), c(92, 96, 235, 0)] as CFArray, locations: nil)!,
                           startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
                           endCenter: CGPoint(x: 512, y: 560), endRadius: 420, options: [])
    ctx.restoreGState()
    if layer == 1 { save(ctx, path); return }
  }

  ctx.saveGState()
  if mac { ctx.addPath(platePath); ctx.clip() }
  // La A ocupa el centro; en macOS se ajusta a la placa, en Android cabe en la zona segura.
  let k: CGFloat = layer == 2 ? 0.66 : (mac ? 0.86 : 1)
  ctx.translateBy(x: 512, y: 512); ctx.scaleBy(x: k, y: k); ctx.translateBy(x: -512, y: -493)

  let base: CGFloat = 290
  // Contorno del listón: piernas paralelas, cima redonda por fuera y arco redondo por dentro.
  let ribbon = CGMutablePath()
  ribbon.move(to: CGPoint(x: 200, y: base))
  ribbon.addLine(to: CGPoint(x: 392, y: 600))
  ribbon.addCurve(to: CGPoint(x: 632, y: 600), control1: CGPoint(x: 473, y: 730), control2: CGPoint(x: 551, y: 730))
  ribbon.addLine(to: CGPoint(x: 824, y: base))
  ribbon.addLine(to: CGPoint(x: 664, y: base))
  ribbon.addLine(to: CGPoint(x: 571, y: 440))
  ribbon.addCurve(to: CGPoint(x: 453, y: 440), control1: CGPoint(x: 521, y: 520), control2: CGPoint(x: 503, y: 520))
  ribbon.addLine(to: CGPoint(x: 360, y: base))
  ribbon.closeSubpath()
  let floor = CGRect(x: 0, y: base, width: 1024, height: 1024)

  ctx.saveGState()
  ctx.clip(to: floor)
  // Resplandor del listón.
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 44, color: c(80, 90, 240, 0.6))
  ctx.addPath(ribbon); ctx.setFillColor(c(110, 105, 235)); ctx.fillPath()
  ctx.restoreGState()
  ctx.addPath(ribbon); ctx.clip()

  // Cara de atrás: la pierna derecha, lila clara.
  linear(ctx, [c(206, 198, 252), c(150, 134, 246), c(104, 92, 230)], CGPoint(x: 600, y: 680), CGPoint(x: 850, y: base))

  // Doblez: la cara de enfrente cubre la pierna izquierda y la cima, cortada por una curva.
  let fold = CGMutablePath()
  fold.move(to: CGPoint(x: 0, y: 0))
  fold.addLine(to: CGPoint(x: 548, y: 0))
  fold.addLine(to: CGPoint(x: 552, y: 440))
  fold.addCurve(to: CGPoint(x: 670, y: 750), control1: CGPoint(x: 562, y: 540), control2: CGPoint(x: 600, y: 660))
  fold.addLine(to: CGPoint(x: 0, y: 1024))
  fold.closeSubpath()
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 18, height: -4), blur: 30, color: c(28, 26, 100, 0.6))
  ctx.addPath(fold); ctx.setFillColor(c(84, 96, 236)); ctx.fillPath()
  ctx.restoreGState()
  ctx.addPath(fold); ctx.clip()
  linear(ctx, [c(118, 140, 252), c(92, 102, 238), c(112, 104, 240)], CGPoint(x: 220, y: base), CGPoint(x: 560, y: 760))
  // Brillo en la cima.
  ctx.drawRadialGradient(CGGradient(colorsSpace: space, colors: [c(255, 255, 255, 0.28), c(255, 255, 255, 0)] as CFArray, locations: nil)!,
                         startCenter: CGPoint(x: 500, y: 660), startRadius: 0,
                         endCenter: CGPoint(x: 500, y: 660), endRadius: 160, options: [])
  ctx.restoreGState()
  ctx.restoreGState()
  save(ctx, path)
}

func save(_ ctx: CGContext, _ path: String) {
  let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments[1]
render(dir + "/icon_full.png", mac: false)
render(dir + "/icon_mac.png", mac: true)
render(dir + "/icon_bg.png", mac: false, layer: 1)
render(dir + "/icon_fg.png", mac: false, layer: 2)
