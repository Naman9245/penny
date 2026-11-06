package com.naman9245.penny

import android.content.Context
import android.os.SystemClock
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest

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

    // Fingerprints of what was queued lately, read or not, so a
    // notification still showing isn't queued again each time Penny looks.
    private const val SEEN = "captures_seen.txt"
    private const val SEEN_MAX = 500

    /** A reader that never drops what it took lets go after this long. */
    private const val HOLD_MS = 60_000L

    private var takenBy: String? = null
    private var takenSince = 0L

    private fun file(context: Context) = File(context.filesDir, NAME)

    /**
     * Queues [capture], unless it was queued lately: a conversation's
     * notification repeats its earlier messages, and a notification still
     * showing is looked at again. Whether it was new.
     */
    @Synchronized
    fun add(context: Context, capture: JSONObject): Boolean {
        val line = capture.toString()
        val seenFile = File(context.filesDir, SEEN)
        val seen = read(seenFile)
        val print = fingerprint(line)
        if (print in seen) return false
        val file = file(context)
        val lines = read(file)
        if (line in lines) return false
        lines.add(line)
        write(file, lines.takeLast(MAX))
        seen.add(print)
        write(seenFile, seen.takeLast(SEEN_MAX))
        return true
    }

    private fun fingerprint(line: String): String =
        MessageDigest.getInstance("SHA-256")
            .digest(line.toByteArray())
            .joinToString("") { "%02x".format(it) }

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
