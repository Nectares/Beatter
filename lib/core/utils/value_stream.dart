import 'dart:async';

/// Builds a stream that, per listener, emits the current value and then all
/// subsequent [updates] — without the lost-event window an
/// `async* { yield snapshot; yield* updates; }` implementation has (broadcast
/// events fired between listen() and the `yield*` subscription are dropped,
/// which lets a stale snapshot overwrite newer optimistic state).
///
/// [updates] must be a broadcast stream; every emission must carry the full
/// current state (so a queued older event followed by the snapshot still
/// converges to the latest value).
Stream<T> valueThenUpdates<T>({
  Future<void> Function()? ensureLoaded,
  required T Function() snapshot,
  required Stream<T> updates,
}) {
  late StreamController<T> out;
  StreamSubscription<T>? sub;
  out = StreamController<T>(
    onListen: () async {
      // Subscribe first: nothing emitted after this point can be missed.
      sub = updates.listen(out.add, onError: out.addError);
      try {
        await ensureLoaded?.call();
        out.add(snapshot());
      } catch (e, s) {
        out.addError(e, s);
      }
    },
    onPause: () => sub?.pause(),
    onResume: () => sub?.resume(),
    onCancel: () => sub?.cancel(),
  );
  return out.stream;
}
