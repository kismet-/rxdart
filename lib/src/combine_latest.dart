import 'package:rxdart/rxdart.dart';

Observable<T> combineLatest<A, T>(
  Observable<A> o1,
  T Function(
    A,
  ) combiner,
) =>
    Observable.combineLatest(<Observable<dynamic>>[
      o1,
    ]).map((list) => combiner(
          list[0] as A,
        ));

/// See combineLatest operator in ReactiveX:
/// http://reactivex.io/documentation/operators/combinelatest.html
/// Takes the latest events from the two provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest2<A, B, T>(
  Observable<A> o1,
  Observable<B> o2,
  T Function(A, B) combiner,
) =>
    o1.combineLatestWith(o2, combiner);

/// Takes the latest events from the three provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest3<A, B, C, T>(
  Observable<A> o1,
  Observable<B> o2,
  Observable<C> o3,
  T Function(A, B, C) combiner,
) =>
    Observable.combineLatest(<Observable<dynamic>>[o1, o2, o3])
        .map((list) => combiner(
              list[0] as A,
              list[1] as B,
              list[2] as C,
            ));

/// Takes the latest events from the four provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest4<A, B, C, D, T>(Observable<A> o1, Observable<B> o2,
        Observable<C> o3, Observable<D> o4, T Function(A, B, C, D) combiner) =>
    Observable.combineLatest(<Observable<dynamic>>[o1, o2, o3, o4])
        .map((list) => combiner(
              list[0] as A,
              list[1] as B,
              list[2] as C,
              list[3] as D,
            ));

/// Takes the latest events from the five provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest5<A, B, C, D, E, T>(
        Observable<A> o1,
        Observable<B> o2,
        Observable<C> o3,
        Observable<D> o4,
        Observable<E> o5,
        T Function(A, B, C, D, E) combiner) =>
    Observable.combineLatest(<Observable<dynamic>>[o1, o2, o3, o4, o5])
        .map((list) => combiner(
              list[0] as A,
              list[1] as B,
              list[2] as C,
              list[3] as D,
              list[4] as E,
            ));

/// Takes the latest events from the six provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest6<A, B, C, D, E, F, T>(
    Observable<A> o1,
    Observable<B> o2,
    Observable<C> o3,
    Observable<D> o4,
    Observable<E> o5,
    Observable<F> o6,
    T Function(A, B, C, D, E, F) combiner) {
  return Observable.combineLatest(
    <Observable<dynamic>>[o1, o2, o3, o4, o5, o6],
  ).map((list) => combiner(
        list[0] as A,
        list[1] as B,
        list[2] as C,
        list[3] as D,
        list[4] as E,
        list[5] as F,
      ));
}

/// Takes the latest events from the seven provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest7<A, B, C, D, E, F, G, T>(
    Observable<A> o1,
    Observable<B> o2,
    Observable<C> o3,
    Observable<D> o4,
    Observable<E> o5,
    Observable<F> o6,
    Observable<G> o7,
    T Function(A, B, C, D, E, F, G) combiner) {
  return Observable.combineLatest(
    <Observable<dynamic>>[o1, o2, o3, o4, o5, o6, o7],
  ).map((list) => combiner(
        list[0] as A,
        list[1] as B,
        list[2] as C,
        list[3] as D,
        list[4] as E,
        list[5] as F,
        list[6] as G,
      ));
}

/// Takes the latest events from the eight provided [Observable]s, then combines
/// them using the provided [combiner].
Observable<T> combineLatest8<A, B, C, D, E, F, G, H, T>(
    Observable<A> o1,
    Observable<B> o2,
    Observable<C> o3,
    Observable<D> o4,
    Observable<E> o5,
    Observable<F> o6,
    Observable<G> o7,
    Observable<H> o8,
    T Function(A, B, C, D, E, F, G, H) combiner) {
  return Observable.combineLatest(
    <Observable<dynamic>>[o1, o2, o3, o4, o5, o6, o7, o8],
  ).map((list) => combiner(
        list[0] as A,
        list[1] as B,
        list[2] as C,
        list[3] as D,
        list[4] as E,
        list[5] as F,
        list[6] as G,
        list[7] as H,
      ));
}
