package com.inouiw.audesiq

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Flutter method channel plugin that decodes a compressed audio file (MP3, AAC,
 * OGG…) to raw PCM-16 LE mono at 16 kHz using Android's MediaExtractor +
 * MediaCodec pipeline — identical in approach to AudioDecoder.kt in the reference
 * Android project.
 *
 * Channel: com.inouiw.audesiq/audio_decoder
 * Method:  decodeToPcm(inputPath: String, outputPath: String) → void
 */
class AudioDecoderPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var methodChannel: MethodChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    companion object {
        const val CHANNEL = "com.inouiw.audesiq/audio_decoder"
        private const val TARGET_SAMPLE_RATE = 16_000
        private const val DECODE_TIMEOUT_US = 5_000L
        // 30 seconds worth of output-rate samples per batch
        private const val BATCH_OUTPUT_SAMPLES = TARGET_SAMPLE_RATE * 30
        /** AudioFormat.ENCODING_PCM_FLOAT = 4 */
        private const val ENCODING_PCM_FLOAT = 4
    }

    // ── FlutterPlugin ─────────────────────────────────────────────────────────

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL)
        methodChannel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        scope.cancel()
    }

    // ── MethodCallHandler ─────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: Result) {
        if (call.method != "decodeToPcm") {
            result.notImplemented()
            return
        }
        val inputPath = call.argument<String>("inputPath")
            ?: return result.error("ARG_ERROR", "inputPath is required", null)
        val outputPath = call.argument<String>("outputPath")
            ?: return result.error("ARG_ERROR", "outputPath is required", null)

        scope.launch {
            try {
                decodeToRawPcm16(inputPath, outputPath)
                withContext(Dispatchers.Main) { result.success(null) }
            } catch (e: Exception) {
                withContext(Dispatchers.Main) {
                    result.error("DECODE_FAILED", e.message ?: "Unknown error", null)
                }
            }
        }
    }

    // ── Decoder ───────────────────────────────────────────────────────────────

    /**
     * Decode [inputPath] to raw PCM-16 LE mono at [TARGET_SAMPLE_RATE] and write
     * the result to [outputPath].  Streams internally in 30-second batches so
     * heap usage is O(batch) regardless of file length.
     */
    private fun decodeToRawPcm16(inputPath: String, outputPath: String) {
        require(File(inputPath).exists()) { "Audio file not found: $inputPath" }

        val extractor = MediaExtractor()
        extractor.setDataSource(inputPath)

        // Find first audio track
        val trackIdx = (0 until extractor.trackCount).firstOrNull { i ->
            extractor.getTrackFormat(i)
                .getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
        } ?: throw IllegalStateException("No audio track in: $inputPath")

        extractor.selectTrack(trackIdx)
        val inputFmt = extractor.getTrackFormat(trackIdx)
        val mime = inputFmt.getString(MediaFormat.KEY_MIME)!!
        val nativeChannels = inputFmt.getIntOrDefault(MediaFormat.KEY_CHANNEL_COUNT, 1)
        val nativeSampleRate = inputFmt.getInteger(MediaFormat.KEY_SAMPLE_RATE)

        // How many native-rate mono samples fill one 30 s output batch
        val batchNativeSamples =
            (BATCH_OUTPUT_SAMPLES.toLong() * nativeSampleRate / TARGET_SAMPLE_RATE).toInt()

        val codec = MediaCodec.createDecoderByType(mime)
        codec.configure(inputFmt, null, null, 0)
        codec.start()

        val outStream = BufferedOutputStream(FileOutputStream(outputPath))
        var currentChannels = nativeChannels
        var currentEncoding = 2 // PCM_16
        var inputDone = false
        var outputDone = false
        val bufInfo = MediaCodec.BufferInfo()

        // Accumulator: downmixed float samples at the native codec rate
        val accumulator = ArrayList<Float>(batchNativeSamples + 8192)
        var accStart = 0

        try {
            while (!outputDone) {

                // ── Feed input ────────────────────────────────────────────────
                if (!inputDone) {
                    val inputId = codec.dequeueInputBuffer(DECODE_TIMEOUT_US)
                    if (inputId >= 0) {
                        val inputBuf = codec.getInputBuffer(inputId)!!
                        val n = extractor.readSampleData(inputBuf, 0)
                        if (n < 0) {
                            codec.queueInputBuffer(
                                inputId, 0, 0, 0L,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM
                            )
                            inputDone = true
                        } else {
                            codec.queueInputBuffer(
                                inputId, 0, n, extractor.sampleTime, 0
                            )
                            extractor.advance()
                        }
                    }
                }

                // ── Drain output ──────────────────────────────────────────────
                val outId = codec.dequeueOutputBuffer(bufInfo, DECODE_TIMEOUT_US)
                when {
                    outId == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val newFmt = codec.outputFormat
                        currentChannels = newFmt.getIntOrDefault(
                            MediaFormat.KEY_CHANNEL_COUNT, currentChannels
                        )
                        currentEncoding = newFmt.getIntOrDefault(
                            MediaFormat.KEY_PCM_ENCODING, currentEncoding
                        )
                    }
                    outId >= 0 -> {
                        if (bufInfo.size > 0) {
                            val buf = codec.getOutputBuffer(outId)!!
                            buf.position(bufInfo.offset)
                            buf.limit(bufInfo.offset + bufInfo.size)
                            buf.order(ByteOrder.LITTLE_ENDIAN)
                            appendMono(accumulator, buf, currentChannels, currentEncoding)
                        }
                        codec.releaseOutputBuffer(outId, false)
                        if (bufInfo.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) {
                            outputDone = true
                        }

                        // Flush complete 30-second batches
                        while ((accumulator.size - accStart) >= batchNativeSamples) {
                            val slice = FloatArray(batchNativeSamples) { accumulator[accStart + it] }
                            writeResampled(outStream, slice, nativeSampleRate)
                            accStart += batchNativeSamples
                            // Compact accumulator to prevent unbounded growth
                            if (accStart >= batchNativeSamples) {
                                val tail = accumulator.subList(accStart, accumulator.size).toList()
                                accumulator.clear()
                                accumulator.addAll(tail)
                                accStart = 0
                            }
                        }
                    }
                }
            }

            // Flush remaining samples after EOS
            val remaining = accumulator.size - accStart
            if (remaining > 0) {
                val tail = FloatArray(remaining) { accumulator[accStart + it] }
                writeResampled(outStream, tail, nativeSampleRate)
            }
        } finally {
            runCatching { codec.stop() }
            codec.release()
            extractor.release()
            outStream.close()
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    /** Downmix codec output buffer to mono floats and append to [acc]. */
    private fun appendMono(
        acc: ArrayList<Float>,
        buf: ByteBuffer,
        channels: Int,
        encoding: Int
    ) {
        if (encoding == ENCODING_PCM_FLOAT) {
            val floatBuf = buf.asFloatBuffer()
            val monoSamples = floatBuf.remaining() / channels
            repeat(monoSamples) {
                var sum = 0f
                repeat(channels) { sum += floatBuf.get() }
                acc.add(sum / channels)
            }
        } else {
            val shortBuf = buf.asShortBuffer()
            val monoSamples = shortBuf.remaining() / channels
            repeat(monoSamples) {
                var sum = 0f
                repeat(channels) { sum += shortBuf.get() / 32768f }
                acc.add(sum / channels)
            }
        }
    }

    /** Resample [samples] from [nativeSampleRate] → [TARGET_SAMPLE_RATE] and
     *  write as PCM-16 LE to [out]. */
    private fun writeResampled(
        out: BufferedOutputStream,
        samples: FloatArray,
        nativeSampleRate: Int
    ) {
        val resampled = resample(samples, nativeSampleRate, TARGET_SAMPLE_RATE)
        val bytes = ByteArray(resampled.size * 2)
        val byteBuf = ByteBuffer.wrap(bytes).order(ByteOrder.LITTLE_ENDIAN)
        for (s in resampled) {
            byteBuf.putShort((s.coerceIn(-1f, 1f) * 32767f).toInt().toShort())
        }
        out.write(bytes)
    }

    /** Linear interpolation resampler — sufficient quality for fingerprinting. */
    private fun resample(input: FloatArray, inRate: Int, outRate: Int): FloatArray {
        if (inRate == outRate || input.isEmpty()) return input
        val ratio = inRate.toDouble() / outRate
        val outputSize = maxOf(1, (input.size / ratio).toInt())
        return FloatArray(outputSize) { i ->
            val srcPos = i * ratio
            val srcIdx = srcPos.toInt().coerceIn(0, input.size - 1)
            val frac = (srcPos - srcIdx).toFloat()
            val a = input[srcIdx]
            val b = if (srcIdx + 1 < input.size) input[srcIdx + 1] else a
            a + frac * (b - a)
        }
    }

    private fun MediaFormat.getIntOrDefault(key: String, default: Int): Int =
        if (containsKey(key)) getInteger(key) else default
}
