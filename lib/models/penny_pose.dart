/// Faces Penny pulls for a moment rather than a mood. They never stand for
/// how the money is going, so Home and the mood calendar never show them.
enum PennyPose {
  /// While the chat waits for her reply.
  thinking('thinking'),

  /// With her glasses on, while a report or a goal plan is worked out.
  analyzing('analyzing'),

  /// Beside her tips.
  idea('with an idea'),

  /// Where there's nothing logged yet.
  sleepy('sleepy');

  const PennyPose(this.label);

  /// How a screen reader names her: "Penny, thinking".
  final String label;
}
