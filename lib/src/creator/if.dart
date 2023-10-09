import 'package:quiver/check.dart';
import 'package:rxdart/rxdart.dart';

import '../_core.dart';

Observable<T> observableIf<T>(Observable<bool> condition,
    {required Observable<T> then, required Observable<T> orElse}) {
  checkArgument(condition != null, message: 'The condition can not be null');
  checkArgument(then != null || orElse != null,
      message: 'Then and OrElse can not be both null');
  then = then ?? Observable.empty();
  orElse = orElse ?? Observable.empty();
  return Observable((Observer<T> observer) {
    var conditionCompleted = false;
    var lastStatementCompleted = false;
    void sendCompletedIfPossible() {
      if (conditionCompleted && lastStatementCompleted) {
        observer.sendCompleted();
      }
    }

    final statementSD = SerialDisposable();
    Disposable? conditionDisposable;
    conditionDisposable = condition.distinctUntilChanged().subscribe(
        onNext: (condition) {
          final next = condition ? then : orElse;
          lastStatementCompleted = false;
          statementSD.disposable = next.subscribe(
              onNext: observer.sendNext,
              onError: sendErrorAndDispose(
                  observer, conditionDisposable as DisposeFunction?),
              onCompleted: () {
                lastStatementCompleted = true;
                sendCompletedIfPossible();
              });
        },
        onError: sendErrorAndDispose(observer, statementSD),
        onCompleted: () {
          conditionCompleted = true;
          sendCompletedIfPossible();
        });
    return CompositeDisposable([conditionDisposable, statementSD]);
  })
    ..name = 'if($condition, then: $then, else: $orElse)';
}
