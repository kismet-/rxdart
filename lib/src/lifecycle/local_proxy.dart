import 'package:rxdart/rxdart.dart';

OperatorFunction<T, T> localProxy<T>(CompositeDisposable localDisposable) =>
    OperatorFunction<T, T>(
      (Observable<T> src) => Observable((Observer<T> observer) {
        final subscriptionDisposable = src.subscribeByObserver(observer);
        localDisposable.add(subscriptionDisposable);
        final completeObserverDisposable =
            Disposable(() => observer.sendCompleted());
        localDisposable.add(completeObserverDisposable);
        return CompositeDisposable([
          subscriptionDisposable,
          Disposable(() => localDisposable.remove(subscriptionDisposable)),
          Disposable(() => localDisposable.remove(completeObserverDisposable)),
        ]);
      }),
    );
