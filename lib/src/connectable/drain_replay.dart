import 'package:rxdart/rxdart.dart';

OperatorFunction<T, T> drainReplay<T>() => OperatorFunction<T, T>(
      (observable) => Observable((observer) {
        final subject = Subject<T>();
        final terminatingSubject = Subject<T>.replay();
        // Drain all replayed events.
        final sourceDisposable = observable.subscribe(
            onNext: subject.sendNext,
            onCompleted: terminatingSubject.sendCompleted,
            onError: terminatingSubject.sendError);
        // Pass later events and preexisting failures.
        final subjectDisposable = subject.subscribeByObserver(observer);
        terminatingSubject.subscribe(
            onError: (_, [__]) => subjectDisposable.dispose(),
            onCompleted: subjectDisposable.dispose,
            onNext: (T data) {});
        final terminatingSubjectDisposable =
            terminatingSubject.subscribeByObserver(observer);
        return CompositeDisposable([
          sourceDisposable,
          subjectDisposable,
          terminatingSubjectDisposable
        ]);
      }),
    );
