import 'package:rxdart/rxdart.dart';

import '../_core.dart';

OperatorFunction<T, T> completeOnError<T>(
        {void Function(Object, [StackTrace])? handleError}) =>
    NamedOperatorFunction<T, T>(
      'completeOnError($handleError: handleError)',
      (Observable<T> src) => Observable((Observer<T> observer) {
        return src.subscribe(
            onNext: observer.sendNext,
            onCompleted: observer.sendCompleted,
            onError: (error, [stackTrace]) {
              observer.sendCompleted();
              if (handleError != null) handleError(error, stackTrace);
            });
      }),
    );
