#if os(iOS)
import Flutter
#else
import FlutterMacOS
#endif
import AVFoundation
import Speech

/// Dictado continuo para juntas largas.
///
/// El AVAudioEngine se crea una vez y queda corriendo toda la junta. Lo que se
/// renueva es solo la tarea de reconocimiento (Apple la corta tras silencios o
/// ~1 minuto). Re-crear el motor de audio en cada corte es lo que tumbaba la
/// app con el plugin speech_to_text.
public class DictationPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var sink: FlutterEventSink?
  private let engine = AVAudioEngine()
  private var recognizer: SFSpeechRecognizer?
  private var request: SFSpeechAudioBufferRecognitionRequest?
  private var task: SFSpeechRecognitionTask?
  private let requestLock = NSLock()
  private var running = false
  private var tapInstalled = false
  private var rotateTimer: Timer?
  private var lastText = ""

  public static func register(with registrar: FlutterPluginRegistrar) {
    #if os(iOS)
    let messenger = registrar.messenger()
    #else
    let messenger = registrar.messenger
    #endif
    let instance = DictationPlugin()
    let methods = FlutterMethodChannel(name: "copiloto/dictation", binaryMessenger: messenger)
    registrar.addMethodCallDelegate(instance, channel: methods)
    FlutterEventChannel(name: "copiloto/dictation/events", binaryMessenger: messenger)
      .setStreamHandler(instance)
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "authorize":
      authorize { ok in DispatchQueue.main.async { result(ok) } }
    case "start":
      let locale = (call.arguments as? [String: Any])?["locale"] as? String ?? "es_MX"
      do {
        try start(locale)
        result(nil)
      } catch {
        stopAll(emitLast: false)
        result(FlutterError(code: "start", message: error.localizedDescription, details: nil))
      }
    case "stop":
      stopAll(emitLast: true)
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func authorize(_ done: @escaping (Bool) -> Void) {
    SFSpeechRecognizer.requestAuthorization { status in
      guard status == .authorized else { return done(false) }
      AVCaptureDevice.requestAccess(for: .audio) { granted in done(granted) }
    }
  }

  // MARK: - Arranque y paro

  private func start(_ localeId: String) throws {
    stopAll(emitLast: false)
    let locale = Locale(identifier: localeId.replacingOccurrences(of: "_", with: "-"))
    guard let r = SFSpeechRecognizer(locale: locale) else {
      throw err("El reconocimiento de voz no está disponible para \(localeId).")
    }
    recognizer = r
    #if os(iOS)
    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement, options: [])
    try session.setActive(true, options: .notifyOthersOnDeactivation)
    #endif
    running = true
    try startEngine()
    newTask()
    // Apple corta cada tarea en ~1 min: la renovamos antes, sin tocar el micrófono.
    rotateTimer = Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { [weak self] _ in
      self?.rotate()
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(audioConfigChanged),
      name: .AVAudioEngineConfigurationChange, object: engine)
  }

  private func startEngine() throws {
    let input = engine.inputNode
    let format = input.outputFormat(forBus: 0)
    guard format.channelCount > 0, format.sampleRate > 0 else {
      throw err("No encontré un micrófono disponible.")
    }
    if tapInstalled { input.removeTap(onBus: 0) }
    input.installTap(onBus: 0, bufferSize: 2048, format: format) { [weak self] buffer, _ in
      guard let self else { return }
      self.requestLock.lock()
      let req = self.request
      self.requestLock.unlock()
      req?.append(buffer)
    }
    tapInstalled = true
    engine.prepare()
    try engine.start()
  }

  private func stopAll(emitLast: Bool) {
    running = false
    rotateTimer?.invalidate()
    rotateTimer = nil
    NotificationCenter.default.removeObserver(self, name: .AVAudioEngineConfigurationChange, object: engine)
    if engine.isRunning { engine.stop() }
    if tapInstalled {
      engine.inputNode.removeTap(onBus: 0)
      tapInstalled = false
    }
    finishCurrent(emitLast: emitLast)
    #if os(iOS)
    try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    #endif
  }

  // MARK: - Tareas de reconocimiento

  private func newTask() {
    guard running, let r = recognizer else { return }
    let req = SFSpeechAudioBufferRecognitionRequest()
    req.shouldReportPartialResults = true
    req.taskHint = .dictation
    if #available(iOS 16.0, macOS 13.0, *) { req.addsPunctuation = true }
    requestLock.lock()
    request = req
    requestLock.unlock()
    lastText = ""
    task = r.recognitionTask(with: req) { [weak self] result, error in
      DispatchQueue.main.async { self?.onRecognition(req, result, error) }
    }
  }

  /// Cierra la tarea actual entregando lo último que se oyó.
  private func finishCurrent(emitLast: Bool) {
    requestLock.lock()
    request = nil
    requestLock.unlock()
    task?.cancel()
    task = nil
    if emitLast, !lastText.isEmpty { emit("final", lastText) }
    lastText = ""
  }

  private func rotate() {
    guard running else { return }
    finishCurrent(emitLast: true)
    newTask()
  }

  private func onRecognition(_ req: SFSpeechAudioBufferRecognitionRequest,
                             _ result: SFSpeechRecognitionResult?, _ error: Error?) {
    // Avisos de una tarea ya renovada: lo suyo ya se entregó.
    guard running, req === request else { return }
    if let result {
      let text = result.bestTranscription.formattedString
      if result.isFinal {
        lastText = text
        rotate()
        return
      }
      lastText = text
      emit("partial", text)
    }
    if error != nil {
      // Silencio largo o corte de Apple: entrega lo oído y sigue escuchando.
      finishCurrent(emitLast: true)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.newTask() }
    }
  }

  /// Cambió el micrófono (AirPods, despertar de reposo, etc.): re-conecta la entrada.
  @objc private func audioConfigChanged(_ note: Notification) {
    DispatchQueue.main.async { [weak self] in
      guard let self, self.running else { return }
      self.reconnect(attempt: 0)
    }
  }

  private func reconnect(attempt: Int) {
    guard running else { return }
    if engine.isRunning { engine.stop() }
    do {
      try startEngine()
      rotate()
    } catch {
      if attempt < 5 {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
          self?.reconnect(attempt: attempt + 1)
        }
      } else {
        emit("error", "Se perdió el micrófono: \(error.localizedDescription)")
      }
    }
  }

  private func emit(_ type: String, _ text: String) {
    sink?(["type": type, "text": text])
  }

  private func err(_ message: String) -> NSError {
    NSError(domain: "dictation", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
