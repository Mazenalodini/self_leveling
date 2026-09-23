package com.selfleveling.self_leveling

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.util.Log

/**
 * Shared native SQLite access helper.
 *
 * This keeps native DB access aligned with Flutter's sqflite configuration:
 * - writable connections opt into WAL
 * - all native connections use a busy timeout
 * - synchronous mode is relaxed for app-owned local data
 */
object NativeDatabaseAccess {
    private const val TAG = "SL.NativeDb"
    private const val DB_NAME = "self_leveling.db"

    fun openReadable(context: Context): SQLiteDatabase? {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(
                dbFile.path,
                null,
                SQLiteDatabase.OPEN_READWRITE or
                    SQLiteDatabase.NO_LOCALIZED_COLLATORS or
                    SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING,
            ).also { configureShared(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Readable DB open failed", e)
            null
        }
    }

    fun openWritable(context: Context): SQLiteDatabase? {
        val dbFile = context.getDatabasePath(DB_NAME)
        if (!dbFile.exists()) return null
        return try {
            SQLiteDatabase.openDatabase(
                dbFile.path,
                null,
                SQLiteDatabase.OPEN_READWRITE or
                    SQLiteDatabase.NO_LOCALIZED_COLLATORS or
                    SQLiteDatabase.ENABLE_WRITE_AHEAD_LOGGING,
            ).also { configureShared(it) }
        } catch (e: Exception) {
            Log.w(TAG, "Writable DB open failed", e)
            null
        }
    }

    private fun configureShared(db: SQLiteDatabase) {
        try {
            db.enableWriteAheadLogging()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to enable WAL on native DB", e)
        }

        try {
            applyPragma(db, "PRAGMA synchronous = NORMAL")
            applyPragma(db, "PRAGMA busy_timeout = 3000")
        } catch (e: Exception) {
            Log.w(TAG, "Failed to configure native DB", e)
        }
    }

    private fun applyPragma(db: SQLiteDatabase, statement: String) {
        db.rawQuery(statement, null).use { /* force evaluation then close */ }
    }
}
