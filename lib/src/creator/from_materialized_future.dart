// Observable<Notification<T>> observableFromMaterializedFuture<T>(
//     Future<T> future) =>
//     Observable((Observer<Notification<T>> observer) {
//       // Note, we need the CheckableDisposable since we are not able to stop
//       // the computation in the closure of 'Future.then', so we need to check
//       // the status of disposable to decide whether we should feed the observer.
//       final disposable = CheckableDisposable();
//       future.then((T data) {
//         if (!disposable.disposed) {
//           observer
//             ..sendNext(Notification.onNext(data))
//             ..sendNext(Notification.onCompleted())
//             ..sendCompleted();
//         }
//       }, onError: (error, [stackTrace]) {
//         if (!disposable.disposed) {
//           observer
//             ..sendNext(Notification.onError(error, stackTrace))
//             ..sendCompleted();
//         }
//       });
//       return disposable;
//     })
//       ..name = 'observableFromMaterializedFuture($future)';
