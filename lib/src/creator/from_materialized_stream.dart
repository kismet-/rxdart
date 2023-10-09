import 'package:rxdart/rxdart.dart';

Observable<Notification<T>> observableFromMaterializedStream<T>(
    Stream<T> stream,
    {bool completeOnError = true}) {
  final broadcastStream =
      stream.isBroadcast ? stream : stream.asBroadcastStream();
  return Observable((Observer<Notification<T>> observer) => Disposable(
          broadcastStream
              .listen((T data) => observer.sendNext(Notification.onNext(data)),
                  onError: (error, [stackTrace]) {
        observer.sendNext(Notification.onError(error, stackTrace));
        if (completeOnError) observer.sendCompleted();
      }, onDone: () {
        observer
          ..sendNext(Notification.onCompleted())
          ..sendCompleted();
      }).cancel))
    ..name = 'observableFromMaterializedStream($stream)';
}
