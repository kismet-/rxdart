import 'package:rxdart/rxdart.dart';

/// Creates a Function which will to pass error and stackTrace
/// to [observer], and then call the [dispose] function.
Function sendErrorAndDispose<T>(
        Observer<T> observer, DisposeFunction? dispose) =>
    (error, [stackTrace]) {
      observer.sendError(error, stackTrace);
      dispose!();
    };

/// An override of [OperatorFunction] which takes a name to print.
class NamedOperatorFunction<S, T> extends OperatorFunction<S, T> {
  final String _name;

  NamedOperatorFunction(
      this._name, Observable<T> Function(Observable<S>) operator)
      : super(operator);

  @override
  String toString() => _name;
}
