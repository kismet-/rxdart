import 'package:rxdart/rxdart.dart';

/// Creates a behavior [Subject] with an optional initial value:
/// http://reactivex.io/documentation/subject.html
Subject<T> createBehaviorSubject<T>({T? initial}) =>
    Subject.replay(initValues: initial != null ? [initial] : []);
