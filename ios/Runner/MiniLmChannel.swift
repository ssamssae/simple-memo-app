import Flutter
import Foundation
import UIKit
import onnxruntime_objc

/// `memoyo/minilm` MethodChannel 의 iOS 구현.
///
/// Android `MainActivity.kt` 의 대칭 포팅이다. 두 가지가 계약이라 임의로 바꾸면 안 된다:
///
/// 1. **에러코드 문자열** — `mini_lm_embedding_engine.dart:82-132` 가 `PlatformException.code`
///    를 문자열로 분기한다(`OUT_OF_MEMORY` 만 outOfMemory, 나머지는 loadFailed).
///    Android 가 내는 `INVALID_ARGUMENT` / `LOAD_FAILED` / `INFERENCE_FAILED` /
///    `CLOSE_FAILED` / `OUT_OF_MEMORY` 를 자 단위로 동일하게 낸다.
/// 2. **pooling 알고리즘** — `poolAndNormalize` 가 플랫폼 간 다르면 같은 `engineId` 로
///    저장된 임베딩이 조용히 오염된다(`staleMemos()` 가 engineId·차원만 보므로 재색인이
///    트리거되지 않는다). mean-pool(mask=0 제외) + L2 정규화를 Android 와 동치로 구현한다.
final class MiniLmChannel {
  static let channelName = "memoyo/minilm"

  /// iOS 는 ABI 로 자를 수 없다 — 15.1 지원 기기는 전부 arm64 다.
  /// 대신 메모리로 자른다: 118.4MB qint8 모델을 2GB 기기(A9/A10)에 올리면 jetsam kill
  /// 위험이 크고, iOS 에는 Android 의 `OutOfMemoryError` catch 에 해당하는 경로가 없다
  /// (프로세스가 그냥 죽는다). A11(iPhone 8/X) 이상만 통과시키는 선.
  ///
  /// ⚠️ 임계값 3GB 는 초기 권고치다 — **실기기 실측 후 확정**한다(설계 §3/§4.4).
  /// 시뮬레이터는 호스트 메모리를 보므로 이 게이트가 항상 통과한다 = 시뮬로는 검증 불가.
  private static let minimumPhysicalMemoryBytes: UInt64 = 3 * 1024 * 1024 * 1024

  /// Android 의 `Executors.newSingleThreadExecutor()` 대응 — 세션 접근을 직렬화한다.
  private let queue = DispatchQueue(label: "memoyo.minilm", qos: .userInitiated)
  private var environment: ORTEnv?
  private var session: ORTSession?

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleMemoryWarning),
      name: UIApplication.didReceiveMemoryWarningNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleTermination),
      name: UIApplication.willTerminateNotification,
      object: nil
    )
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(Self.isSupported())
    case "availableBytes":
      guard let path = call.arguments(named: "directoryPath") as String? else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "directoryPath is required", details: nil))
        return
      }
      do {
        result(try Self.availableBytes(at: path))
      } catch {
        result(FlutterError(code: "INVALID_ARGUMENT", message: error.localizedDescription, details: nil))
      }
    case "load":
      runInBackground(result: result, errorCode: "LOAD_FAILED") { [weak self] in
        guard let modelPath = call.arguments(named: "modelPath") as String? else {
          throw MiniLmError.invalidArgument("modelPath is required")
        }
        try self?.loadModel(at: modelPath)
        return nil
      }
    case "embed":
      runInBackground(result: result, errorCode: "INFERENCE_FAILED") { [weak self] in
        let inputIds = try call.int64Array(named: "inputIds")
        let attentionMask = try call.int64Array(named: "attentionMask")
        let tokenTypeIds = try call.int64Array(named: "tokenTypeIds")
        return try self?.embed(
          inputIds: inputIds,
          attentionMask: attentionMask,
          tokenTypeIds: tokenTypeIds
        )
      }
    case "close":
      runInBackground(result: result, errorCode: "CLOSE_FAILED") { [weak self] in
        self?.closeSession()
        return nil
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Android `runInBackground` 대응. 실패는 지정 errorCode 로 감싸고, 인자 오류만
  /// `INVALID_ARGUMENT` 로 승격한다(Android 도 argument 검증은 별도 코드로 낸다).
  private func runInBackground(
    result: @escaping FlutterResult,
    errorCode: String,
    action: @escaping () throws -> Any?
  ) {
    queue.async {
      do {
        let value = try action()
        DispatchQueue.main.async { result(value) }
      } catch let MiniLmError.invalidArgument(message) {
        DispatchQueue.main.async {
          result(FlutterError(code: "INVALID_ARGUMENT", message: message, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: errorCode, message: error.localizedDescription, details: nil))
        }
      }
    }
  }

  // MARK: - capability

  private static func isSupported() -> Bool {
    ProcessInfo.processInfo.physicalMemory >= minimumPhysicalMemoryBytes
  }

  /// Android `StatFs(path).availableBytes` 대응.
  private static func availableBytes(at path: String) throws -> Int64 {
    let attributes = try FileManager.default.attributesOfFileSystem(forPath: path)
    guard let free = attributes[.systemFreeSize] as? NSNumber else {
      throw MiniLmError.invalidArgument("systemFreeSize is unavailable for \(path)")
    }
    return free.int64Value
  }

  // MARK: - session

  private func loadModel(at modelPath: String) throws {
    guard Self.isSupported() else {
      throw MiniLmError.failure("MiniLM is unsupported on this device tier")
    }
    guard FileManager.default.fileExists(atPath: modelPath) else {
      throw MiniLmError.failure("MiniLM model file is missing")
    }
    closeSession()
    let env = try resolveEnvironment()
    let options = try ORTSessionOptions()
    // Android: intraOp 2 / ALL_OPT. (interOp 는 ORT Objective-C API 에 노출되지 않아 생략)
    try options.setIntraOpNumThreads(2)
    try options.setGraphOptimizationLevel(.all)
    session = try ORTSession(env: env, modelPath: modelPath, sessionOptions: options)
  }

  private func resolveEnvironment() throws -> ORTEnv {
    if let environment { return environment }
    let created = try ORTEnv(loggingLevel: .warning)
    environment = created
    return created
  }

  private func embed(
    inputIds: [Int64],
    attentionMask: [Int64],
    tokenTypeIds: [Int64]
  ) throws -> [Double] {
    guard let session else {
      throw MiniLmError.failure("MiniLM model is not loaded")
    }
    guard !inputIds.isEmpty else {
      throw MiniLmError.invalidArgument("inputIds must not be empty")
    }
    guard inputIds.count == attentionMask.count, inputIds.count == tokenTypeIds.count else {
      throw MiniLmError.invalidArgument("MiniLM input lengths must match")
    }

    let shape: [NSNumber] = [1, NSNumber(value: inputIds.count)]
    let candidates: [String: [Int64]] = [
      "input_ids": inputIds,
      "attention_mask": attentionMask,
      "token_type_ids": tokenTypeIds,
    ]

    // Android 와 동일하게 "세션이 요구하는 입력만" 채운다.
    var inputs: [String: ORTValue] = [:]
    for name in try session.inputNames() {
      guard let values = candidates[name] else {
        throw MiniLmError.failure("Unsupported MiniLM input: \(name)")
      }
      inputs[name] = try Self.makeInt64Tensor(values, shape: shape)
    }

    let outputNames = try session.outputNames()
    let outputs = try session.run(
      withInputs: inputs,
      outputNames: Set(outputNames),
      runOptions: nil
    )

    // Android 우선순위와 동일. 셋 다 없으면 0번 출력.
    let preferred = ["sentence_embedding", "last_hidden_state", "token_embeddings"]
      .first(where: outputNames.contains)
    guard let value = preferred.flatMap({ outputs[$0] }) ?? outputNames.first.flatMap({ outputs[$0] }) else {
      throw MiniLmError.failure("MiniLM produced no output tensor")
    }

    let info = try value.tensorTypeAndShapeInfo()
    let outputShape = info.shape.map { $0.int64Value }
    let data = try value.tensorData() as Data
    let flattened = data.withUnsafeBytes { raw -> [Float] in
      Array(raw.bindMemory(to: Float.self))
    }
    return try Self.poolAndNormalize(
      flattened: flattened,
      shape: outputShape,
      attentionMask: attentionMask
    ).map(Double.init)
  }

  private static func makeInt64Tensor(_ values: [Int64], shape: [NSNumber]) throws -> ORTValue {
    let data = values.withUnsafeBufferPointer { buffer in
      NSMutableData(bytes: buffer.baseAddress, length: buffer.count * MemoryLayout<Int64>.stride)
    }
    return try ORTValue(tensorData: data, elementType: .int64, shape: shape)
  }

  /// Android `poolAndNormalize` 의 알고리즘 동치 포팅.
  /// (a) rank-2 `[1, D]` 는 그대로, (b) rank-3 `[1, S, D]` 는 mask=0 토큰을 제외한
  /// mean-pool, (c) L2 정규화.
  static func poolAndNormalize(
    flattened: [Float],
    shape: [Int64],
    attentionMask: [Int64]
  ) throws -> [Float] {
    var pooled: [Float]
    if shape.count == 2, shape[0] == 1 {
      guard flattened.count == Int(shape[1]) else {
        throw MiniLmError.failure("Unexpected rank-2 MiniLM output size")
      }
      pooled = flattened
    } else if shape.count == 3, shape[0] == 1 {
      let sequenceLength = Int(shape[1])
      let dimensions = Int(shape[2])
      guard sequenceLength == attentionMask.count else {
        throw MiniLmError.failure("MiniLM output and attention mask disagree")
      }
      guard flattened.count == sequenceLength * dimensions else {
        throw MiniLmError.failure("Unexpected rank-3 MiniLM output size")
      }
      var result = [Float](repeating: 0, count: dimensions)
      var tokenCount = 0
      for token in 0..<sequenceLength {
        if attentionMask[token] == 0 { continue }
        tokenCount += 1
        let offset = token * dimensions
        for dimension in 0..<dimensions {
          result[dimension] += flattened[offset + dimension]
        }
      }
      guard tokenCount > 0 else {
        throw MiniLmError.failure("Cannot pool an empty attention mask")
      }
      let divisor = Float(tokenCount)
      for dimension in result.indices { result[dimension] /= divisor }
      pooled = result
    } else {
      throw MiniLmError.failure("Unsupported MiniLM output shape: \(shape)")
    }

    var squaredNorm = 0.0
    for value in pooled { squaredNorm += Double(value) * Double(value) }
    guard squaredNorm > 0, squaredNorm.isFinite else {
      throw MiniLmError.failure("MiniLM embedding norm must be finite and non-zero")
    }
    let norm = Float(squaredNorm.squareRoot())
    for index in pooled.indices { pooled[index] /= norm }
    return pooled
  }

  private func closeSession() {
    session = nil
  }

  // MARK: - lifecycle

  /// iOS 는 OOM 을 catch 할 수 없으므로(jetsam), 경고 시점에 선제적으로 세션을 놓는다.
  @objc private func handleMemoryWarning() {
    queue.async { [weak self] in self?.closeSession() }
  }

  /// Android `onDestroy` 대응.
  @objc private func handleTermination() {
    queue.sync { closeSession() }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

enum MiniLmError: Error, LocalizedError {
  case invalidArgument(String)
  case failure(String)

  var errorDescription: String? {
    switch self {
    case let .invalidArgument(message): return message
    case let .failure(message): return message
    }
  }
}

private extension FlutterMethodCall {
  func arguments<T>(named name: String) -> T? {
    (arguments as? [String: Any])?[name] as? T
  }

  /// Dart 는 `List<int>` 를 보내지만 플랫폼 채널에서 NSNumber 배열로 도착한다.
  func int64Array(named name: String) throws -> [Int64] {
    guard let values: [NSNumber] = arguments(named: name) else {
      throw MiniLmError.invalidArgument("\(name) is required")
    }
    return values.map { $0.int64Value }
  }
}
