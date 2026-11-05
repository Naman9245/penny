package com.naman9245.penny

import android.content.Context
import android.os.SystemClock
import org.json.JSONObject
import java.io.File

/**
 * Notifications waiting for Penny to read them, one JSON object a line, in
 * the app's private files. The listener adds to it; a reader (the open
 * Penny, or her hidden copy) takes what's there, keeps what it read, then
 * drops that many. Only the newest few hundred are kept.
 *
 * One reader at a time: while one is taking, another gets nothing, so a
 * payment is never taken twice.
 */
object CaptureQueue {
    private const val NAME = "captures.jsonl"
    private const val MAX = 300

    /** A reader that never drops what it took lets go after this long. */
    private const val HOLD_MS = 60_000L

    private var takenBy: String? = null
    private var takenSince = 0L

    private fun file(context: Context) = File(context.filesDir, NAME)

    @Synchronized
    fun add(context: Context, capture: JSONObject) {
        val file = file(context)
        val lines = read(file)
        val line = capture.toString()
        // A conversation's notification repeats its earlier messages.
        if (line in lines) return
        lines.add(line)
        write(file, lines.takeLast(MAX))
    }

    /**
     * Everything waiting, oldest first, as a JSON array, for [reader] to
     * take: it's theirs until they drop it. Nothing while another reader is
     * taking.
     */
    @Synchronized
    fun take(context: Context, reader: String): String {
        val now = SystemClock.elapsedRealtime()
        val other = takenBy
        if (other != null && other != reader && now - takenSince < HOLD_MS) return "[]"
        val lines = read(file(context))
        takenBy = if (lines.isEmpty()) null else reader
        takenSince = now
        return lines.joinToString(",", "[", "]")
    }

    /** Forgets the oldest [count], once [reader] has kept them. */
    @Synchronized
    fun drop(context: Context, reader: String, count: Int) {
        val file = file(context)
        val rest = read(file).drop(count)
        if (rest.isEmpty()) file.delete() else write(file, rest)
        release(reader)
    }

    /** Lets another reader take, if [reader] was taking. */
    @Synchronized
    fun release(reader: String) {
        if (takenBy == reader) takenBy = null
    }

    private fun read(file: File): MutableList<String> =
        if (file.exists()) {
            file.readLines().filter { it.isNotBlank() }.toMutableList()
        } else {
            mutableListOf()
        }

    private fun write(file: File, lines: List<String>) =
        file.writeText(lines.joinToString("\n", postfix = "\n"))
}
