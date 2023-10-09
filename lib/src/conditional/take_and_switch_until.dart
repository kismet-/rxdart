import 'package:rxdart/rxdart.dart';

import '../_core.dart';

/// [rx-amb]: http://reactivex.io/documentation/operators/amb.html
/// [rx-take-until]: http://reactivex.io/documentation/operators/takeuntil.html
OperatorFunction<T, T> takeAndSwitchUntil<T>(Observable<T> until) =>
    NamedOperatorFunction<T, T>(
        'takeAndSwitchUntil(${until.name})',
        (Observable<T> source) => Observable((Observer<T> observer) {
              final sourceSad = SingleAssignmentDisposable();
              final untilSad = SingleAssignmentDisposable();
              sourceSad.disposable = source.subscribe(
                  onNext: observer.sendNext,
                  onError: sendErrorAndDispose(observer, untilSad));
              untilSad.disposable = until.subscribe(
                  onNext: (data) {
                    sourceSad.disposable!();
                    observer.sendNext(data);
                  },
                  onError: sendErrorAndDispose(observer, sourceSad),
                  onCompleted: () {
                    sourceSad.disposable!();
                    observer.sendCompleted();
                  });
              return CompositeDisposable([sourceSad, untilSad]);
            }));
