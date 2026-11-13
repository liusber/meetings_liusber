import AppKit

func render(_ path: String, mac: Bool, layer: Int = 0) {  // layer: 0 completo, 1 solo fondo, 2 solo figura
  let S: CGFloat = 1024
  let img = NSImage(size: NSSize(width: S, height: S))
  img.lockFocus()
  let ctx = NSGraphicsContext.current!.cgContext
  // Área del fondo: a sangre (iOS/Android/Windows) o placa redondeada con margen (macOS).
  let inset: CGFloat = mac ? 100 : 0
  let plate = CGRect(x: inset, y: inset, width: S - 2*inset, height: S - 2*inset)
  let k = plate.width / S
  if mac {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 30, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill()
    NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185).fill()
    ctx.restoreGState()
    NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185).addClip()
  }
  let grad = NSGradient(colors: [NSColor(srgbRed: 0.24, green: 0.18, blue: 0.78, alpha: 1),
                                 NSColor(srgbRed: 0.05, green: 0.62, blue: 0.86, alpha: 1)])!
  if layer != 2 { grad.draw(in: plate, angle: -50) }
  if layer == 1 { img.unlockFocus(); save(img, path, S); return }
  if layer == 2 { ctx.translateBy(x: S/2, y: S/2); ctx.scaleBy(x: 0.62, y: 0.62); ctx.translateBy(x: -S/2, y: -S/2) }

  func P(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: plate.minX + x*k, y: plate.minY + y*k) }
  func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(origin: P(x, y), size: NSSize(width: w*k, height: h*k)) }

  // Globo de diálogo blanco con cola abajo a la izquierda.
  ctx.saveGState()
  ctx.setShadow(offset: CGSize(width: 0, height: -14*k), blur: 40*k, color: NSColor.black.withAlphaComponent(0.25).cgColor)
  let bubble = NSBezierPath(roundedRect: R(190, 330, 644, 440), xRadius: 130*k, yRadius: 130*k)
  let tail = NSBezierPath()
  tail.move(to: P(290, 360)); tail.line(to: P(250, 215)); tail.line(to: P(430, 340)); tail.close()
  bubble.append(tail)
  NSColor.white.setFill()
  bubble.fill()
  ctx.restoreGState()

  // Ondas de voz dentro del globo.
  let heights: [CGFloat] = [90, 190, 280, 190, 120]
  let bw: CGFloat = 56, gap: CGFloat = 40
  let total = CGFloat(heights.count)*bw + CGFloat(heights.count-1)*gap
  var x = 512 - total/2
  let cy: CGFloat = 550
  let wave = NSGradient(colors: [NSColor(srgbRed: 0.24, green: 0.18, blue: 0.78, alpha: 1),
                                 NSColor(srgbRed: 0.05, green: 0.55, blue: 0.82, alpha: 1)])!
  for h in heights {
    wave.draw(in: NSBezierPath(roundedRect: R(x, cy - h/2, bw, h), xRadius: bw/2*k, yRadius: bw/2*k), angle: -90)
    x += bw + gap
  }

  // Destello de IA arriba a la derecha.
  func sparkle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let s = NSBezierPath()
    let c = P(cx, cy), q = r*k*0.22
    s.move(to: NSPoint(x: c.x, y: c.y + r*k))
    s.curve(to: NSPoint(x: c.x + r*k, y: c.y), controlPoint1: NSPoint(x: c.x + q, y: c.y + q), controlPoint2: NSPoint(x: c.x + q, y: c.y + q))
    s.curve(to: NSPoint(x: c.x, y: c.y - r*k), controlPoint1: NSPoint(x: c.x + q, y: c.y - q), controlPoint2: NSPoint(x: c.x + q, y: c.y - q))
    s.curve(to: NSPoint(x: c.x - r*k, y: c.y), controlPoint1: NSPoint(x: c.x - q, y: c.y - q), controlPoint2: NSPoint(x: c.x - q, y: c.y - q))
    s.curve(to: NSPoint(x: c.x, y: c.y + r*k), controlPoint1: NSPoint(x: c.x - q, y: c.y + q), controlPoint2: NSPoint(x: c.x - q, y: c.y + q))
    NSColor(srgbRed: 1.0, green: 0.78, blue: 0.24, alpha: 1).setFill()
    s.fill()
  }
  sparkle(820, 800, 95)
  sparkle(905, 655, 42)

  img.unlockFocus()
  save(img, path, S)
}

func save(_ img: NSImage, _ path: String, _ S: CGFloat) {
  let rep = NSBitmapImageRep(cgImage: img.cgImage(forProposedRect: nil, context: nil, hints: nil)!)
  rep.size = NSSize(width: S, height: S)
  try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

let dir = CommandLine.arguments[1]
render(dir + "/icon_full.png", mac: false)
render(dir + "/icon_mac.png", mac: true)
render(dir + "/icon_bg.png", mac: false, layer: 1)
render(dir + "/icon_fg.png", mac: false, layer: 2)
