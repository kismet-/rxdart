import 'package:rxdart/rxdart.dart';

/// [hot-vs-cold-observable]: https://github.com/Reactive-Extensions/RxJS/blob/master/doc/gettingstarted/creating.md#cold-vs-hot-observables
OperatorFunction<T, T> _makeHot<T>(
        Connectable<T> toConnectable(Observable<T> observable),
        CompositeDisposable cd) =>
    OperatorFunction<T, T>((Observable<T> src) {
      final connectable = toConnectable(src);
      cd.add(connectable.connect());
      return connectable.observable;
    });

/// [hot-vs-cold-observable]: https://github.com/Reactive-Extensions/RxJS/blob/master/doc/gettingstarted/creating.md#cold-vs-hot-observables
OperatorFunction<T, T> hotShareReplay<T>(CompositeDisposable cd) =>
    _makeHot<T>((ob) => ob.publishReplay(), cd);
