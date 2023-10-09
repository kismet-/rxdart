import 'dart:async';

import 'package:rxdart/rxdart.dart';

export 'blocking_latest.dart';

Future<T>? blockingLatest<T>(Observable<T> observable, {bool sync = true}) {
  final completer = sync ? Completer<T>.sync() : Completer<T>();
  final sad = SingleAssignmentDisposable();
  var hasData = false;
  var hasError = false;
  var drainReplayed = false;
  T? capturedData;
  sad.disposable = observable.subscribe(onNext: (data) {
    if (drainReplayed && !hasData) {
      completer.complete(data);
      sad.dispose();
    } else {
      capturedData = data;
    }
    hasData = true;
  }, onError: (error, [stackTrace]) {
    hasError = true;
    capturedData = null;
    completer.completeError(error, stackTrace);
    sad.dispose();
  }, onCompleted: () {
    if (!hasData) {
      completer.completeError(
          StateError('Observable [$observable] completes without emission'));
    }
    sad.dispose();
  });
  drainReplayed = true;
  if (hasData && !hasError) {
    completer.complete(capturedData);
    sad.dispose();
    return completer.future;
  }
  return null;
}
