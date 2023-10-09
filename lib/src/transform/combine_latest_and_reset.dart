import 'package:rxdart/rxdart.dart';

import '../_core.dart';

/// [rx-combinelatest]: http://reactivex.io/documentation/operators/combinelatest.html
OperatorFunction<T, O> combineLatestWithAndReset<T, S, O>(
        Observable<S> thatObservable,
        {required Observable<Object> resetWhen,
        CombineFunction<T, S, O>? combiner}) =>
    OperatorFunction<T, O>(
        (Observable<T> source) => Observable((Observer<O> observer) {
              T? capturedThisValue;
              var didCaptureThisValue = false;
              var didThisComplete = false;
              S? capturedThatValue;
              var didCaptureThatValue = false;
              var didThatComplete = false;
              var thisSad = SingleAssignmentDisposable();
              var thatSad = SingleAssignmentDisposable();
              var resetSad = SingleAssignmentDisposable();
              void maySendNext() {
                if (didCaptureThisValue && didCaptureThatValue) {
                  observer.sendNext((combiner == null
                      ? [capturedThisValue, capturedThatValue]
                      : combiner(capturedThisValue!, capturedThatValue!)) as O);
                }
              }

              void maySendCompleted() {
                if (didThisComplete && didThatComplete) {
                  observer.sendCompleted();
                  resetSad.dispose();
                }
              }

              resetSad.disposable = resetWhen.subscribe(
                  onNext: (_) {
                    didCaptureThisValue = false;
                    didCaptureThatValue = false;
                    // If one of the source [Observable] is completed, the new
                    // observable will not emit any new data after [resetWhen]
                    // emits data.
                    // Thus, [combineLatestWithAndReset] will complete the new
                    // source and dispose current listening subscriptions for
                    // better resource management.
                    if (didThisComplete) {
                      observer.sendCompleted();
                      thatSad.dispose();
                      resetSad.dispose();
                    } else if (didThatComplete) {
                      observer.sendCompleted();
                      thisSad.dispose();
                      resetSad.dispose();
                    }
                  },
                  onError: sendErrorAndDispose(
                      observer, CompositeDisposable([thisSad, thatSad])));
              thisSad.disposable = source.subscribe(
                  onNext: (T data) {
                    capturedThisValue = data;
                    didCaptureThisValue = true;
                    maySendNext();
                  },
                  onError: sendErrorAndDispose(
                      observer, CompositeDisposable([thatSad, resetSad])),
                  onCompleted: () {
                    didThisComplete = true;
                    maySendCompleted();
                  });
              thatSad.disposable = thatObservable.subscribe(
                  onNext: (S data) {
                    capturedThatValue = data;
                    didCaptureThatValue = true;
                    maySendNext();
                  },
                  onError: sendErrorAndDispose(
                      observer, CompositeDisposable([thisSad, resetSad])),
                  onCompleted: () {
                    didThatComplete = true;
                    maySendCompleted();
                  });
              return CompositeDisposable([thisSad, thatSad]);
            }));

/// [rx-combinelatest]: http://reactivex.io/documentation/operators/combinelatest.html
// Observable<List<T>> combineLatestAndReset<T>(
//     Iterable<Observable<T>> observables, Observable<Object> resetWhen) {
//   // [reset] has to be multicast so that each pair of sources could reset
//   // when reset emits an event.
//   final reset = resetWhen.shareReplay();
//   return observables.skip(1).fold(
//     observables.isEmpty
//         ? Observable<List<T>>.just([])
//         : observables.first.map((item) => [item]),
//         (Observable<List<T>> prevValue, Observable<T> element) =>
//         prevValue.apply(combineLatestWithAndReset<List<T>, T, List<T>>(
//           element,
//           combiner: (combined, element) =>
//           List<T>.from(combined)
//             ..add(element),
//           resetWhen: reset,
//         )),
//   )
//     ..name = 'combineLatestAndReset($observables, $resetWhen)';
// }
