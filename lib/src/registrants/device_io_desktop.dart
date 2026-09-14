/// The Linux and Windows registrant. Those platforms have no native half:
/// the links door runs in its `paths` world, where the file picker hands
/// out paths and a path is its own durable link. Declaring the platforms
/// with this class is what tells pub.dev, and the tooling, that they are
/// supported.
class DeviceIoDesktop {
  /// Called by the generated plugin registrant. Nothing to wire.
  static void registerWith() {}
}
