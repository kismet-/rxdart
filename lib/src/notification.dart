part of rxdart;

/// http://www.introtorx.com/Content/v1.0.10621.0/08_Transformation.html#MaterializeAndDematerialize
class Notification<T> {
  final T? value;
  final NotificationType type;
  final Object? error;
  final StackTrace? stackTrace;

  Notification._(this.value, this.type, this.error, this.stackTrace);

  factory Notification.onNext(T value) =>
      Notification._(value, NotificationType.OnNext, null, null);

  factory Notification.onCompleted() =>
      Notification._(null, NotificationType.OnCompleted, null, null);

  factory Notification.onError(Object error, StackTrace stackTrace) =>
      Notification._(null, NotificationType.OnError, error, stackTrace);
}

enum NotificationType { OnNext, OnError, OnCompleted }
