package com.daejongkang.simple_memo_app

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import ai.onnxruntime.TensorInfo
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.LongBuffer
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.sqrt

class MainActivity : FlutterActivity() {
    private val environment: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private var session: OrtSession? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler(
            ::handleMethodCall,
        )
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "availableBytes" -> {
                val path = call.argument<String>("directoryPath")
                if (path == null) {
                    result.error("INVALID_ARGUMENT", "directoryPath is required", null)
                } else {
                    result.success(StatFs(path).availableBytes)
                }
            }
            "load" -> runInBackground(result, "LOAD_FAILED") {
                val modelPath = call.argument<String>("modelPath")
                    ?: throw IllegalArgumentException("modelPath is required")
                loadModel(modelPath)
                null
            }
            "embed" -> runInBackground(result, "INFERENCE_FAILED") {
                embed(
                    inputIds = call.longArray("inputIds"),
                    attentionMask = call.longArray("attentionMask"),
                    tokenTypeIds = call.longArray("tokenTypeIds"),
                ).map(Float::toDouble)
            }
            "close" -> runInBackground(result, "CLOSE_FAILED") {
                closeSession()
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun runInBackground(
        result: MethodChannel.Result,
        errorCode: String,
        action: () -> Any?,
    ) {
        executor.execute {
            try {
                result.success(action())
            } catch (error: OutOfMemoryError) {
                closeSession()
                result.error("OUT_OF_MEMORY", "MiniLM runtime exhausted memory", null)
            } catch (error: Throwable) {
                result.error(errorCode, error.message ?: error.javaClass.simpleName, null)
            }
        }
    }

    private fun loadModel(modelPath: String) {
        check(isSupported()) { "MiniLM arm64 model is unsupported on this ABI" }
        val model = File(modelPath)
        require(model.isFile) { "MiniLM model file is missing" }
        closeSession()
        OrtSession.SessionOptions().use { options ->
            options.setIntraOpNumThreads(2)
            options.setInterOpNumThreads(1)
            options.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT)
            session = environment.createSession(model.absolutePath, options)
        }
    }

    private fun embed(
        inputIds: LongArray,
        attentionMask: LongArray,
        tokenTypeIds: LongArray,
    ): FloatArray {
        val activeSession = session ?: error("MiniLM model is not loaded")
        require(inputIds.isNotEmpty()) { "inputIds must not be empty" }
        require(inputIds.size == attentionMask.size && inputIds.size == tokenTypeIds.size) {
            "MiniLM input lengths must match"
        }
        val shape = longArrayOf(1, inputIds.size.toLong())
        val tensors = mutableMapOf<String, OnnxTensor>()
        try {
            val values = mapOf(
                "input_ids" to inputIds,
                "attention_mask" to attentionMask,
                "token_type_ids" to tokenTypeIds,
            )
            for (name in activeSession.inputNames) {
                val value = values[name] ?: error("Unsupported MiniLM input: $name")
                tensors[name] = OnnxTensor.createTensor(
                    environment,
                    LongBuffer.wrap(value),
                    shape,
                )
            }
            activeSession.run(tensors).use { outputs ->
                val preferredName = listOf(
                    "sentence_embedding",
                    "last_hidden_state",
                    "token_embeddings",
                ).firstOrNull(activeSession.outputNames::contains)
                val output = preferredName
                    ?.let { outputs.get(it).orElse(null) }
                    ?: outputs.get(0)
                val tensor = output as? OnnxTensor
                    ?: error("MiniLM output is not a tensor")
                val info = tensor.info as TensorInfo
                val outputShape = info.shape
                val valuesBuffer = tensor.floatBuffer
                    ?: error("MiniLM output is not a float tensor")
                val flattened = FloatArray(valuesBuffer.remaining())
                valuesBuffer.get(flattened)
                return poolAndNormalize(flattened, outputShape, attentionMask)
            }
        } finally {
            tensors.values.forEach(OnnxTensor::close)
        }
    }

    private fun poolAndNormalize(
        flattened: FloatArray,
        shape: LongArray,
        attentionMask: LongArray,
    ): FloatArray {
        val pooled = when {
            shape.size == 2 && shape[0] == 1L -> {
                require(flattened.size == shape[1].toInt()) {
                    "Unexpected rank-2 MiniLM output size"
                }
                flattened.copyOf()
            }
            shape.size == 3 && shape[0] == 1L -> {
                val sequenceLength = shape[1].toInt()
                val dimensions = shape[2].toInt()
                require(sequenceLength == attentionMask.size) {
                    "MiniLM output and attention mask disagree"
                }
                require(flattened.size == sequenceLength * dimensions) {
                    "Unexpected rank-3 MiniLM output size"
                }
                val result = FloatArray(dimensions)
                var tokenCount = 0
                for (token in 0 until sequenceLength) {
                    if (attentionMask[token] == 0L) continue
                    tokenCount++
                    val offset = token * dimensions
                    for (dimension in 0 until dimensions) {
                        result[dimension] += flattened[offset + dimension]
                    }
                }
                require(tokenCount > 0) { "Cannot pool an empty attention mask" }
                for (dimension in result.indices) result[dimension] /= tokenCount.toFloat()
                result
            }
            else -> error("Unsupported MiniLM output shape: ${shape.contentToString()}")
        }
        var squaredNorm = 0.0
        for (value in pooled) squaredNorm += value * value
        require(squaredNorm > 0 && squaredNorm.isFinite()) {
            "MiniLM embedding norm must be finite and non-zero"
        }
        val norm = sqrt(squaredNorm).toFloat()
        for (index in pooled.indices) pooled[index] /= norm
        return pooled
    }

    private fun MethodCall.longArray(name: String): LongArray {
        val values = argument<List<Number>>(name)
            ?: throw IllegalArgumentException("$name is required")
        return values.map(Number::toLong).toLongArray()
    }

    private fun closeSession() {
        session?.close()
        session = null
    }

    /// iOS `MiniLmChannel.isSupported()` 와 동형 판정.
    ///
    /// arm64 ABI 만 보면 RAM 2GB 급 arm64 기기가 게이트를 통과한 뒤
    /// 118MB 모델을 적재하다 프로세스째 죽는다 (T-260723-009).
    /// iOS 는 `physicalMemory >= 3GB` 로 이미 막고 있어 Android 만 구멍이었다.
    ///
    /// ⚠️ 임계값 3GB 는 초기 권고치다 — **실기기 실측 후 확정**한다.
    ///    iOS `MiniLmChannel.minimumPhysicalMemoryBytes` 주석과 같은 잠정 상태이며,
    ///    한쪽만 바꾸면 플랫폼 간 판정이 어긋나므로 **양쪽을 함께** 조정한다.
    private fun isSupported(): Boolean =
        Build.SUPPORTED_ABIS.contains("arm64-v8a") &&
            totalMemoryBytes() >= MINIMUM_TOTAL_MEMORY_BYTES

    /// iOS `ProcessInfo.processInfo.physicalMemory` 대응.
    private fun totalMemoryBytes(): Long {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        activityManager.getMemoryInfo(info)
        return info.totalMem
    }

    override fun onDestroy() {
        executor.execute(::closeSession)
        executor.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "memoyo/minilm"

        /// iOS `MiniLmChannel.minimumPhysicalMemoryBytes` (3GB) 와 동일 임계 — 함께 조정할 것.
        private const val MINIMUM_TOTAL_MEMORY_BYTES = 3L * 1024 * 1024 * 1024
    }
}
