/// How durable a link to a picked file can be — the verdict a caller
/// reads BEFORE deciding to link or to copy.
///
/// The verdict is the platform layer's, made from facts the app cannot
/// see: whether the picker handed out a name the process can keep (a
/// path, a bookmark, a persistable grant), and whether what it hands back
/// is a real seekable file or a pipe from a cloud provider.
enum LinkStrength {
  /// A link survives restarts: a path the app can name, a bookmark, or a
  /// persistable grant on a regular file. Link it — nothing needs
  /// copying.
  durable,

  /// Readable now, gone at process end — a grant the budget refused, or a
  /// provider that offers no persistable access. Copy it, or use it for
  /// this session only.
  session,

  /// Cannot be linked at all: a cloud provider that streams through a
  /// pipe (no seek, no mmap), a browser blob. Copying is the only honest
  /// option; `LinkCandidate.readStream` is how.
  none,
}
