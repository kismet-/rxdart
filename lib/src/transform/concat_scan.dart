import 'package:rxdart/rxdart.dart';

import '../_core.dart';

/// [rxjs-mergescan]: http://reactivex.io/rxjs/class/es6/Observable.js~Observable.html#instance-method-mergeScan.
OperatorFunction<T, S> concatScan<T, S>(
        Observable<S> accumulator(S currentValue, T operand),
        {S? seed}) =>
    NamedOperatorFunction<T, S>(
        'concatScan($accumulator, seed: $seed)',
        (Observable<T> source) => Observable((Observer<S> observer) {
              final bufferedSourceData = <T>[];
              final accumulatedSd = SerialDisposable();
              final sourceSad = SingleAssignmentDisposable();
              var accumulatedCompleted = false;
              var accumulatedActive = false;
              var currentValue = seed;
              void maySendCompleted() {
                if (accumulatedCompleted && !accumulatedActive) {
                  currentValue = null;
                  observer.sendCompleted();
                }
              }

              void onNextSource(sourceData) {
                if (!accumulatedActive) {
                  final accumulatedObservable =
                      accumulator(currentValue as S, sourceData);
                  final sad = SingleAssignmentDisposable();
                  accumulatedActive = true;
                  accumulatedSd.disposable = sad;
                  sad.disposable = accumulatedObservable.subscribe(
                      onNext: (accumulatedData) {
                        currentValue = accumulatedData;
                        observer.sendNext(currentValue as S);
                      },
                      onError: sendErrorAndDispose(observer, () {
                        accumulatedActive = false;
                        accumulatedSd.disposable = null;
                        sourceSad.dispose();
                        currentValue = null;
                      }),
                      onCompleted: () {
                        accumulatedActive = false;
                        accumulatedSd.disposable = null;
                        if (bufferedSourceData.isNotEmpty) {
                          onNextSource(bufferedSourceData.removeAt(0));
                        } else {
                          maySendCompleted();
                        }
                      });
                } else {
                  bufferedSourceData.add(sourceData);
                }
              }

              sourceSad.disposable = source.subscribe(
                  onNext: onNextSource,
                  onError: sendErrorAndDispose(observer, () {
                    accumulatedSd.dispose();
                    currentValue = null;
                  }),
                  onCompleted: () {
                    accumulatedCompleted = true;
                    maySendCompleted();
                  });
              return CompositeDisposable([sourceSad, accumulatedSd]);
            }));
