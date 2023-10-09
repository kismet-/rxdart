import 'package:rxdart/rxdart.dart';

typedef void SourceDisposeFunction();
typedef void SourceOnDataFunction<T>(T data);

abstract class Source<T> {
  SourceDisposeFunction subscribe(SourceOnDataFunction<T> onData);
}

/// Converts the [observable] to a Source.
/// The [observable] will be [shareReplay]ed to meet the contracts
/// of Source.
Source<T> toSource<T>(Observable<T> observable) =>
    _ObservableSource(observable);

// Source<T> toSource<T>(Stream<T> observable) => _ObservableSource(observable);

/// A Source that wraps an observable.
class _ObservableSource<T> implements Source<T> {
  final Observable<T> _replayed;

  _ObservableSource(Observable<T> observable)
      : _replayed = observable.shareReplay();

  @override
  SourceDisposeFunction subscribe(SourceOnDataFunction<T> onData) =>
      _replayed.subscribe(
          onNext: onData,
          onError: () {
            print("error");
          });
}
