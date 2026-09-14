package com.whuppi.device_io

import android.app.Activity
import android.content.ContentResolver
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.system.Os
import android.system.OsConstants
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.FileNotFoundException

/**
 * The Android half of device_io's links door.
 *
 * Five jobs, all Storage Access Framework: run the document and tree
 * pickers asking for PERSISTABLE grants, keep the grant ledger
 * (take / release / list / cap), list a tree's children, open a
 * document to a detached descriptor the Dart side reads through
 * `/proc/self/fd`, and read/write/list/delete objects inside a linked
 * tree by a relative path (`folderRead` / `folderWrite` / `folderList` /
 * `folderDelete`). Every verdict a caller needs — is this a regular file,
 * is the grant persistable — is measured here, not guessed in Dart.
 *
 * The method names and payload keys mirror `LinksChannel` on the Dart
 * side, which is the one contract.
 */
class DeviceIoPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL = "device_io/links"
        private const val REQUEST_FILES = 0x4c4e4b31 // "LNK1"
        private const val REQUEST_FOLDER = 0x4c4e4b32 // "LNK2"
        private const val PERSIST_FLAGS =
            Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION

        // A tree grant needs write access too, so folderWrite/folderDelete
        // can create and remove documents under it. A single file's own
        // grant stays read-only — nothing on the file-links door writes.
        private const val TREE_FLAGS = PERSIST_FLAGS or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
    }

    private var channel: MethodChannel? = null
    private var binding: FlutterPlugin.FlutterPluginBinding? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var pendingCode = 0
    private var tempCounter = 0

    private val resolver: ContentResolver
        get() = binding!!.applicationContext.contentResolver

    // ── Plugin lifecycle ──

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        this.binding = binding
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        this.binding = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detachActivity()

    private fun detachActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    // ── Dispatch ──

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "mode" -> result.success("android")
                "pickFiles" -> pickFiles(call.argument<List<String>>("extensions"), result)
                "pickFolder" -> pickFolder(result)
                "children" -> result.success(
                    children(
                        Uri.parse(call.argument<String>("folder")!!),
                        call.argument<List<String>>("extensions"),
                        call.argument<Boolean>("recursive") ?: false,
                    )
                )
                "takeGrant" -> {
                    resolver.takePersistableUriPermission(
                        Uri.parse(call.argument<String>("id")!!),
                        Intent.FLAG_GRANT_READ_URI_PERMISSION,
                    )
                    result.success(null)
                }
                "releaseGrant" -> {
                    releaseGrant(Uri.parse(call.argument<String>("id")!!))
                    result.success(null)
                }
                "grants" -> result.success(
                    resolver.persistedUriPermissions.map {
                        mapOf("id" to it.uri.toString(), "persistedAt" to it.persistedTime)
                    }
                )
                "grantCapacity" -> result.success(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) 512 else 128
                )
                "open" -> result.success(open(Uri.parse(call.argument<String>("id")!!)))
                "close" -> {
                    ParcelFileDescriptor.adoptFd(call.argument<Int>("handle")!!).close()
                    result.success(null)
                }
                "startDownload" -> result.success(null) // Android providers fetch on open.
                "folderRead" -> result.success(
                    folderRead(
                        Uri.parse(call.argument<String>("tree")!!),
                        call.argument<String>("relativePath")!!,
                    )
                )
                "folderWrite" -> {
                    folderWrite(
                        Uri.parse(call.argument<String>("tree")!!),
                        call.argument<String>("relativePath")!!,
                        call.argument<ByteArray>("bytes")!!,
                    )
                    result.success(null)
                }
                "folderList" -> result.success(
                    folderList(
                        Uri.parse(call.argument<String>("tree")!!),
                        call.argument<String>("prefix") ?: "",
                    )
                )
                "folderDelete" -> {
                    folderDelete(
                        Uri.parse(call.argument<String>("tree")!!),
                        call.argument<String>("relativePath")!!,
                    )
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (e: SecurityException) {
            result.error("permission", e.message ?: "Access to the document was refused", null)
        } catch (e: FileNotFoundException) {
            result.error("missing", e.message ?: "The document is no longer there", null)
        } catch (e: IllegalArgumentException) {
            result.error("missing", e.message ?: "Not a document this app can reach", null)
        } catch (e: Exception) {
            result.error("failed", e.message ?: e.javaClass.simpleName, null)
        }
    }

    // ── Picking ──

    private fun pickFiles(extensions: List<String>?, result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
            addFlags(PERSIST_FLAGS)
            // SAF filters by MIME, never by extension; a type the map knows
            // narrows the picker, one it does not leaves every file offered.
            val mimes = mimesFor(extensions)
            if (mimes.isNotEmpty()) putExtra(Intent.EXTRA_MIME_TYPES, mimes.toTypedArray())
        }
        launch(intent, REQUEST_FILES, result)
    }

    private fun pickFolder(result: MethodChannel.Result) {
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply { addFlags(TREE_FLAGS) }
        launch(intent, REQUEST_FOLDER, result)
    }

    private fun launch(intent: Intent, code: Int, result: MethodChannel.Result) {
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("failed", "No activity to show a picker from", null)
            return
        }
        if (pendingResult != null) {
            result.error("failed", "A picker is already open", null)
            return
        }
        pendingResult = result
        pendingCode = code
        activity.startActivityForResult(intent, code)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != pendingCode) return false
        val result = pendingResult ?: return false
        pendingResult = null
        try {
            if (resultCode != Activity.RESULT_OK || data == null) {
                result.success(if (requestCode == REQUEST_FILES) emptyList<Any>() else null)
                return true
            }
            when (requestCode) {
                REQUEST_FILES -> {
                    val persistable = data.flags and Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION != 0
                    val uris = mutableListOf<Uri>()
                    data.clipData?.let { clip -> for (i in 0 until clip.itemCount) uris += clip.getItemAt(i).uri }
                    if (uris.isEmpty()) data.data?.let { uris += it }
                    result.success(uris.map { describe(it, persistable) })
                }
                REQUEST_FOLDER -> {
                    val tree = data.data!!
                    // The folder's grant is taken here, atomically with the
                    // pick — a tree the Dart side holds is always one it can
                    // reopen after a reboot. Read AND write: folderWrite and
                    // folderDelete need the write half of the grant.
                    resolver.takePersistableUriPermission(
                        tree,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                    val docUri = DocumentsContract.buildDocumentUriUsingTree(
                        tree, DocumentsContract.getTreeDocumentId(tree)
                    )
                    result.success(mapOf("id" to tree.toString(), "name" to displayName(docUri)))
                }
            }
        } catch (e: Exception) {
            result.error("failed", e.message ?: e.javaClass.simpleName, null)
        }
        return true
    }

    // ── Describing ──

    /** `{id, name, size, regular, persistable}` for one picked document. */
    private fun describe(uri: Uri, persistable: Boolean): Map<String, Any?> {
        var name: String? = null
        var size: Long? = null
        query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)) { c ->
            if (c.moveToFirst()) {
                name = c.getString(0)
                if (!c.isNull(1)) size = c.getLong(1)
            }
        }
        return mapOf(
            "id" to uri.toString(),
            "name" to (name ?: uri.lastPathSegment ?: "file"),
            "size" to size,
            "regular" to isRegularFile(uri),
            "persistable" to persistable,
        )
    }

    /**
     * Whether the provider hands out a real, seekable file for [uri].
     * A cloud provider that streams answers with a pipe — readable, but
     * nothing an engine can mmap. Measured by opening once and asking
     * the kernel, because the provider's authority is only a hint.
     */
    private fun isRegularFile(uri: Uri): Boolean {
        val pfd = try {
            resolver.openFileDescriptor(uri, "r") ?: return false
        } catch (_: Exception) {
            return false
        }
        pfd.use {
            return try {
                OsConstants.S_ISREG(Os.fstat(it.fileDescriptor).st_mode)
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun displayName(docUri: Uri): String {
        var name: String? = null
        query(docUri, arrayOf(DocumentsContract.Document.COLUMN_DISPLAY_NAME)) { c ->
            if (c.moveToFirst()) name = c.getString(0)
        }
        return name ?: "Folder"
    }

    private fun children(
        tree: Uri, extensions: List<String>?, recursive: Boolean,
    ): List<Map<String, Any?>> {
        val wanted = extensions?.map { it.lowercase() }?.toSet()
        val out = mutableListOf<Map<String, Any?>>()
        // Walks one directory of the tree; descends into its folders only
        // when asked. Every file carries its path under the linked folder.
        fun walk(documentId: String, prefix: String) {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
            val folders = mutableListOf<Pair<String, String>>()
            query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
            ) { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    if (c.getString(3) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        if (recursive) folders += c.getString(0) to "$prefix$name/"
                        continue
                    }
                    if (wanted != null && name.substringAfterLast('.', "").lowercase() !in wanted) continue
                    val doc = DocumentsContract.buildDocumentUriUsingTree(tree, c.getString(0))
                    out += mapOf(
                        "id" to doc.toString(),
                        "name" to name,
                        "relative" to "$prefix$name",
                        "size" to if (c.isNull(2)) null else c.getLong(2),
                        // A document listed through a tree is opened through the
                        // tree's grant; the file's own shape is measured on open.
                        "regular" to true,
                    )
                }
            }
            for ((id, path) in folders) walk(id, path)
        }
        walk(DocumentsContract.getTreeDocumentId(tree), "")
        out.sortBy { it["name"] as String }
        return out
    }

    // ── Opening ──

    /**
     * Opens [uri] and hands the descriptor to Dart, detached: this side
     * forgets it, the Dart side owns it until `close`. A pipe is refused
     * with `pipe` — the caller was told at pick time and asked anyway.
     */
    private fun open(uri: Uri): Map<String, Any?> {
        val pfd = resolver.openFileDescriptor(uri, "r")
            ?: throw FileNotFoundException("The provider returned no descriptor")
        val stat = Os.fstat(pfd.fileDescriptor)
        if (!OsConstants.S_ISREG(stat.st_mode)) {
            pfd.close()
            throw IllegalStateException("pipe")
        }
        return mapOf("fd" to pfd.detachFd(), "size" to stat.st_size)
    }

    private fun releaseGrant(uri: Uri) {
        try {
            resolver.releasePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (_: SecurityException) {
            // Already released — the outcome the caller wanted.
        }
    }

    // ── Folder IO ──

    /** Bytes of the document at [relativePath] under [tree]; null when absent. */
    private fun folderRead(tree: Uri, relativePath: String): ByteArray? {
        val (dirs, name) = splitRelativePath(relativePath)
        val dirId = resolveDirectoryId(tree, dirs, createDirs = false) ?: return null
        val fileId = findChildId(tree, dirId, name, wantDir = false) ?: return null
        val doc = DocumentsContract.buildDocumentUriUsingTree(tree, fileId)
        return resolver.openInputStream(doc)?.use { it.readBytes() }
    }

    /**
     * Writes [bytes] at [relativePath] under [tree], creating missing parent
     * directories. Not atomic the way a filesystem rename is — the provider
     * has no rename-over — so the new bytes land at a temporary sibling
     * document first, any existing document at [relativePath] is deleted,
     * and only then is the temporary document renamed into place. A crash
     * between the delete and the rename leaves the document absent, never
     * torn; the Dart doc comment on `FolderIo.write` states this.
     */
    private fun folderWrite(tree: Uri, relativePath: String, bytes: ByteArray) {
        val (dirs, name) = splitRelativePath(relativePath)
        val dirId = resolveDirectoryId(tree, dirs, createDirs = true)!!
        val parentDoc = DocumentsContract.buildDocumentUriUsingTree(tree, dirId)
        val mime = MimeTypeMap.getSingleton()
            .getMimeTypeFromExtension(name.substringAfterLast('.', ""))
            ?: "application/octet-stream"
        val tmpName = "$name.tmp-${System.currentTimeMillis()}-${tempCounter++}"
        val tmpDoc = DocumentsContract.createDocument(resolver, parentDoc, mime, tmpName)
            ?: throw IllegalStateException("Could not create a document under the folder")
        resolver.openOutputStream(tmpDoc)?.use { it.write(bytes) }
            ?: throw FileNotFoundException("The provider returned no output stream")
        val existingId = findChildId(tree, dirId, name, wantDir = false)
        if (existingId != null) {
            DocumentsContract.deleteDocument(
                resolver,
                DocumentsContract.buildDocumentUriUsingTree(tree, existingId),
            )
        }
        DocumentsContract.renameDocument(resolver, tmpDoc, name)
    }

    /** Relative paths of every document under [tree] starting with [prefix]. */
    private fun folderList(tree: Uri, prefix: String): List<String> {
        val out = mutableListOf<String>()
        fun walk(documentId: String, path: String) {
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, documentId)
            val folders = mutableListOf<Pair<String, String>>()
            query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                ),
            ) { c ->
                while (c.moveToNext()) {
                    val name = c.getString(1) ?: continue
                    if (c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        folders += c.getString(0) to "$path$name/"
                        continue
                    }
                    val relative = "$path$name"
                    if (relative.startsWith(prefix)) out += relative
                }
            }
            for ((id, next) in folders) walk(id, next)
        }
        walk(DocumentsContract.getTreeDocumentId(tree), "")
        out.sort()
        return out
    }

    /** Deletes the document at [relativePath] under [tree]. A missing document is not an error. */
    private fun folderDelete(tree: Uri, relativePath: String) {
        val (dirs, name) = splitRelativePath(relativePath)
        val dirId = resolveDirectoryId(tree, dirs, createDirs = false) ?: return
        val fileId = findChildId(tree, dirId, name, wantDir = false) ?: return
        DocumentsContract.deleteDocument(
            resolver,
            DocumentsContract.buildDocumentUriUsingTree(tree, fileId),
        )
    }

    /**
     * Walks [segments] from [tree]'s root, one Storage Access Framework
     * child lookup per segment. Missing directories are created only when
     * [createDirs]; otherwise a missing segment answers null. Returns the
     * resolved directory's document id.
     */
    private fun resolveDirectoryId(
        tree: Uri,
        segments: List<String>,
        createDirs: Boolean,
    ): String? {
        var docId = DocumentsContract.getTreeDocumentId(tree)
        for (segment in segments) {
            if (segment.isEmpty()) continue
            val childId = findChildId(tree, docId, segment, wantDir = true)
            docId = if (childId != null) {
                childId
            } else if (createDirs) {
                val parentDoc = DocumentsContract.buildDocumentUriUsingTree(tree, docId)
                val created = DocumentsContract.createDocument(
                    resolver, parentDoc, DocumentsContract.Document.MIME_TYPE_DIR, segment,
                ) ?: throw IllegalStateException("Could not create a folder under the tree")
                DocumentsContract.getDocumentId(created)
            } else {
                return null
            }
        }
        return docId
    }

    /** The document id of [name] under [parentDocId] in [tree]; null when no child matches. */
    private fun findChildId(tree: Uri, parentDocId: String, name: String, wantDir: Boolean): String? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parentDocId)
        var found: String? = null
        query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE,
            ),
        ) { c ->
            while (c.moveToNext()) {
                if (c.getString(1) != name) continue
                val isDir = c.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR
                if (isDir != wantDir) continue
                found = c.getString(0)
                break
            }
        }
        return found
    }

    /** Splits `a/b/c.txt` into its directory segments and its final name. */
    private fun splitRelativePath(relativePath: String): Pair<List<String>, String> {
        val segments = relativePath.split('/')
        return segments.dropLast(1) to segments.last()
    }

    // ── Helpers ──

    private inline fun query(uri: Uri, projection: Array<String>, body: (Cursor) -> Unit) {
        resolver.query(uri, projection, null, null, null)?.use(body)
    }

    private fun mimesFor(extensions: List<String>?): List<String> {
        if (extensions == null) return emptyList()
        val map = MimeTypeMap.getSingleton()
        val mimes = extensions.mapNotNull { map.getMimeTypeFromExtension(it.lowercase()) }
        // One unknown extension would silently hide those files; offer
        // everything instead of a partial filter.
        return if (mimes.size == extensions.size) mimes.distinct() else emptyList()
    }
}
