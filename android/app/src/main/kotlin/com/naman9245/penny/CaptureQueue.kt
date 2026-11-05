package com.naman9245.penny

import android.content.Context
import org.json.JSONObject
import java.io.File

/**
 * Notifications waiting for Penny to read them, one JSON object a line, in
 * the app's private files. The listener adds to it; Penny peeks, keeps what
 * it read, then drops that many. Only the newest few hundred are kept.
 */
object CaptureQueue {
    private const val NAME = "captures.jsonl"
    private const val MAX = 300

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

    /** Everything waiting, oldest first, as a JSON array. */
    @Synchronized
    fun peek(context: Context): String =
        read(file(context)).joinToString(",", "[", "]")

    /** Forgets the oldest [count], once Penny has kept them. */
    @Synchronized
    fun drop(context: Context, count: Int) {
        val file = file(context)
        val rest = read(file).drop(count)
        if (rest.isEmpty()) file.delete() else write(file, rest)
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
