import 'package:rxdart/rxdart.dart';

import '../_core.dart';

OperatorFunction<T, T> accumulateWith<T, O>(
        Observable<O> operand, T accumulator(T value, O operand)) =>
    OperatorFunction<T, T>((Observable<T> source) =>
        Observable((Observer<T> observer) {
          var sourceComplete = false;
          var operandComplete = false;
          var subscribedToOperand = false;
          T? accumulated;
          final sourceDisposable = SingleAssignmentDisposable();
          final operandDisposable = SingleAssignmentDisposable();
          void maySendCompleted() {
            if (sourceComplete && (operandComplete || !subscribedToOperand)) {
              observer.sendCompleted();
            }
          }

          void onOperandEmission(O op) {
            accumulated = accumulator(accumulated!, op);
            observer.sendNext(accumulated!);
          }

          void onSourceEmission(T data) {
            accumulated = data;
            observer.sendNext(accumulated!);
            // Subscribe to operand on first emission of source.
            if (!subscribedToOperand) {
              operandDisposable.disposable = operand.subscribe(
                  onNext: onOperandEmission,
                  onError: sendErrorAndDispose(observer, sourceDisposable),
                  onCompleted: () {
                    operandComplete = true;
                    maySendCompleted();
                  });
              subscribedToOperand = true;
            }
          }

          sourceDisposable.disposable = source.subscribe(
              onNext: onSourceEmission,
              onError: sendErrorAndDispose(observer, operandDisposable),
              onCompleted: () {
                sourceComplete = true;
                maySendCompleted();
              });
          return CompositeDisposable([sourceDisposable, operandDisposable]);
        }));

/// Compared with [accumulateWith], this function returns a [OperatorFunction]
/// which accumulates the [source] Observable with
/// [List] of [operand] Observable and [accumulator].
/// When [source] emits a value, this value is emitted directly by the
/// transformed Observable. When [operand] emits a value, it's accumulated
/// to the previously emitted value to produce the next emission.
/// # Example
/// src: -----------------2|------------------------------------
/// op1: -------------1--------3--------5--------7--------|----
/// op2: --------------------------1--------2------ 1---1----|-
/// [          src.accumulateWith([{op1, (x, y) => x + y)},
///                                 op2, (x, y) => x - y)}]
/// out: -----------------2----5---4----9---7---14--13-12----|----
// OperatorFunction<T, T> accumulateWithMulti<T, O>(
//     Map<Observable<O>, T Function(T, O)> operandAccumulators) {
//   final highOrderObservable = operandAccumulators.entries
//       .map((entry) =>
//       entry.key
//           .map((operand) => (current) => entry.value(current, operand)))
//       .toList();
//   return accumulateWith(
//       Observable.merge(highOrderObservable), (current, hoOp) => hoOp!(current));
// }
