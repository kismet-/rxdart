import 'package:rxdart/rxdart.dart';

T? lastEvent<T>(Observable<T> observable) {
  T? lastEvent;
  observable?.subscribe(onNext: (event) {
    lastEvent = event;
  })?.dispose();
  return lastEvent;
}

T? lastEventFromSource<T>(Source<T> source) {
  T? lastEvent;
  source.subscribe((event) {
    lastEvent = event;
  })();

  return lastEvent;
}
