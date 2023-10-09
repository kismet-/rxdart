part of rxdart;

typedef Disposable OnSubscribeFunction<T>(Observer<T> observer);
typedef T ConvertFunction<S, T>(Observable<S> observable);

class OperatorFunction<S, T> {
  final Observable<T> Function(Observable<S>) _operator;

  OperatorFunction(this._operator);

  Observable<T> call(Observable<S> source) => _operator(source);
}

typedef O CombineFunction<T, S, O>(T thisValue, S thatValue);

/// See:
/// http://reactivex.io/documentation/observable.html
abstract class Observable<T> {
  String? name;

  @protected
  Observable.protected();

  @override
  String toString() => name!;

  factory Observable(OnSubscribeFunction<T> onSubscribe) =>
      OnSubscribeObservableFactory.currentFactory.create(onSubscribe);

  /// http://reactivex.io/documentation/contract.html
  Disposable subscribeByObserver(Observer<T> observer);

  Disposable subscribe(
          {required OnNextFunction<T> onNext,
          Function? onError,
          OnCompletedFunction? onCompleted}) =>
      subscribeByObserver(Observer.safe(
          onNext: onNext,
          onError: onError != null ? onError as Function : () => print('error'),
          onCompleted: onCompleted));

  /// Related articles:
  /// http://reactivex.io/documentation/implement-operator.html
  /// http://xgrommx.github.io/rx-book/content/getting_started_with_rxjs/implementing_your_own_operators.html
  /// http://akarnokd.blogspot.hu/2015/05/pitfalls-of-operator-implementations.html
  /// http://akarnokd.blogspot.hu/2015/05/pitfalls-of-operator-implementations_14.html
  Observable<S> apply<S>(OperatorFunction<T, S> op) =>
      op(this)..name = '$name.apply($op)';

  S convertAs<S>(ConvertFunction<T, S> convert) => convert(this);

  Disposable subscribeBySink(Sink<T> sink) => subscribe(
      onNext: sink.add,
      onError: (error, [stackTrace]) {
        sink is EventSink
            ? ((sink as EventSink)
              ..addError(error, stackTrace)
              ..close())
            : sink.close();
      },
      onCompleted: sink.close);

  S convertTo<S>(ConvertFunction<T, S> convert) => convert(this);

  Stream<T> asStream() {
    var sad = SingleAssignmentDisposable();
    StreamController<T>? streamController;
    streamController = StreamController<T>(
        onListen: () {
          sad.disposable = subscribe(
              onNext: streamController!.add,
              onError: streamController.addError,
              onCompleted: () {
                streamController!.close();
              });
        },
        onCancel: sad.dispose);
    return streamController.stream;
  }

  /// See [concat operator in ReactiveX][rx-concat] for more details.
  ///
  /// [rx-concat]: http://reactivex.io/documentation/operators/concat.html
  Observable<T> concatWith(Observable<T> that) =>
      Observable((Observer<T> observer) {
        final thatDisposable = SingleAssignmentDisposable();
        final thisDisposable = subscribe(
            onNext: observer.sendNext,
            onError: observer.sendError,
            onCompleted: () {
              thatDisposable.disposable = that.subscribeByObserver(observer);
            });
        return CompositeDisposable([thisDisposable, thatDisposable]);
      })
        ..name = '$name.concatWith($that)';

  /// [rx-concat]: http://reactivex.io/documentation/operators/concat.html
  factory Observable.concat(List<Observable<T>> observables) =>
      observables.fold(
          Observable<T>.empty(),
          (Observable<T> prevValue, Observable<T> element) =>
              prevValue.concatWith(element))
        ..name = 'concat($observables)';

  /// See [combineLatest operator in ReactiveX][rx-combinelatest]
  /// for more details.
  ///
  /// [rx-combinelatest]: http://reactivex.io/documentation/operators/combinelatest.html
  Observable<O> combineLatestWith<S, O>(Observable<S> thatObservable,
      [CombineFunction<T, S, O>? combiner]) {
    return Observable((Observer<O> observer) {
      T? capturedThisValue;
      var didCaptureThisValue = false;
      var didThisComplete = false;
      S? capturedThatValue;
      var didCaptureThatValue = false;
      var didThatComplete = false;
      void maySendNext() {
        if (didCaptureThisValue && didCaptureThatValue) {
          observer.sendNext((combiner == null
              ? [capturedThisValue, capturedThatValue]
              : combiner(capturedThisValue as T, capturedThatValue as S)) as O);
        }
      }

      void maySendCompleted() {
        if (didThisComplete && didThatComplete) {
          observer.sendCompleted();
        }
      }

      var thisSad = SingleAssignmentDisposable();
      var thatSad = SingleAssignmentDisposable();
      thisSad.disposable = subscribe(onNext: (T data) {
        capturedThisValue = data;
        didCaptureThisValue = true;
        maySendNext();
      },
          //onError: _sendErrorAndDispose(observer, thatSad),
          onCompleted: () {
        didThisComplete = true;
        maySendCompleted();
      });
      thatSad.disposable = thatObservable.subscribe(onNext: (S data) {
        capturedThatValue = data;
        didCaptureThatValue = true;
        maySendNext();
      },
          //onError: _sendErrorAndDispose(observer, thisSad),
          onCompleted: () {
        didThatComplete = true;
        maySendCompleted();
      });
      return CompositeDisposable([thisSad, thatSad]);
    })
      ..name = '$name.combineLatestWith($thatObservable)';
  }

  /// [rx-combinelatest]: http://reactivex.io/documentation/operators/combinelatest.html
  static Observable<List<T>> combineLatest<T>(
          Iterable<Observable<T>> observables) =>
      observables.fold(
          Observable<List<T>>.just([]),
          (Observable<List<T>> prevValue, Observable<T> element) =>
              prevValue.combineLatestWith<T, List<T>>(element,
                  (combined, element) => List.from(combined)..add(element)))
        ..name = 'combineLatest($observables)';

  /// [rx-merge]: http://reactivex.io/documentation/operators/merge.html
  Observable<T> mergeWith(Observable<T> that) =>
      Observable((Observer<T> observer) {
        var didThisComplete = false;
        var didThatComplete = false;
        var thisDisposable = SingleAssignmentDisposable();
        var thatDisposable = SingleAssignmentDisposable();
        void maySendCompleted() {
          if (didThisComplete && didThatComplete) {
            observer.sendCompleted();
          }
        }

        thisDisposable.disposable = subscribe(
            onNext: observer.sendNext,
            onError: () {
              print('ERRRRRORRR');
            },
            onCompleted: () {
              didThisComplete = true;
              maySendCompleted();
            });
        thatDisposable.disposable = that.subscribe(
            onNext: observer.sendNext,
            onError: () {
              print('ERRRRRORRR');
            },
            onCompleted: () {
              didThatComplete = true;
              maySendCompleted();
            });
        return CompositeDisposable([thisDisposable, thatDisposable]);
      })
        ..name = '$name.mergeWith($that)';

  /// [rx-merge]: http://reactivex.io/documentation/operators/merge.html
  factory Observable.merge(List<Observable<T>> observables) => observables.fold(
      Observable<T>.empty(),
      (Observable<T> prevValue, Observable<T> element) =>
          prevValue.mergeWith(element))
    ..name = 'merge($observables)';

  /// [rx-startwith]: http://reactivex.io/documentation/operators/startwith.html
  Observable<T> startWith(List<T> values) =>
      Observable.fromValues(values).concatWith(this)
        ..name = '$name.startWith($values)';

  /// [rx-startwith]: http://reactivex.io/documentation/operators/startwith.html
  Observable<T> startWithSingle(T value) =>
      Observable.fromValues([value]).concatWith(this)
        ..name = '$name.startWithSingle($value)';

  /// [rx-switch]: http://reactivex.io/documentation/operators/switch.html
  Observable<S> switchLatest<S>() => Observable((Observer<S> observer) {
        var outerCompleted = false;
        var isLastInnerAlive = false;
        void maySendCompleted() {
          if (outerCompleted && !isLastInnerAlive) {
            observer.sendCompleted();
          }
        }

        SerialDisposable innerSd = SerialDisposable();
        var outerSad = SingleAssignmentDisposable();
        outerSad.disposable = subscribe(onNext: (T data) {
          //_checkIsObservable('switchLatest', data);
          isLastInnerAlive = false;
          innerSd.disposable = (data as Observable<S>).subscribe(
              onNext: observer.sendNext,
              //onError: _sendErrorAndDispose(observer, outerSad),
              onCompleted: () {
                isLastInnerAlive = false;
                maySendCompleted();
              });
          isLastInnerAlive = true;
        },
            //onError: _sendErrorAndDispose(observer, innerSd),
            onCompleted: () {
          outerCompleted = true;
          maySendCompleted();
        });
        return CompositeDisposable([outerSad, innerSd]);
      })
        ..name = '$name.switchLatest()';

  /// [rxjs-withlatestfrom]: https://github.com/Reactive-Extensions/RxJS/blob/master/doc/api/core/operators/withlatestfrom.md
  Observable<O> withLatestFrom<S, O>(Observable<S> observable,
          [O reducer(T thisValue, S thatValue)?]) =>
      Observable((Observer<O> observer) {
        var didCaptureThat = false;
        S? capturedThat;
        var thisSad = SingleAssignmentDisposable();
        var thatSad = SingleAssignmentDisposable();
        void onNextThis(T data) {
          observer.sendNext((reducer == null
              ? [data, capturedThat]
              : reducer(data, capturedThat!)) as O);
        }

        thatSad.disposable = observable.subscribe(onNext: (S data) {
          didCaptureThat = true;
          capturedThat = data;
        },
            //onError: clearSendErrorThenDispose(thisSad),
            onCompleted: () {
          if (!didCaptureThat) {
            // Optimization: if observable has not fired anything,
            // dispose this observable as well since the returned
            // observable will never fire anything.
            thisSad.dispose();
            observer.sendCompleted();
          }
        });
        thisSad.disposable = filter((_) => didCaptureThat).subscribe(
            onNext: onNextThis,
            //onError: clearSendErrorThenDispose(thatSad),
            onCompleted: () {
              capturedThat = null;
              thatSad.dispose();
              observer.sendCompleted();
            });
        return CompositeDisposable([thisSad, thatSad]);
      })
        ..name = '$name.withLatestFrom($observable, $reducer)';

  /// [rx-publish]: http://reactivex.io/documentation/operators/publish.html
  Connectable<T> multicast(Subject<T> subject) =>
      Connectable._(this, subject)..name = '$name.multicast($subject)';

  /// [rx-publish]: http://reactivex.io/documentation/operators/publish.html
  Connectable<T> publish() => multicast(Subject<T>())..name = '$name.publish()';

  /// [rx-publish]: http://reactivex.io/documentation/operators/publish.html
  /// [rx-replay]: http://reactivex.io/documentation/operators/replay.html
  Connectable<T> publishReplay(
          {bool shouldReplayAll = false,
          int bufferSize = 1,
          Iterable<T> initValues = const []}) =>
      multicast(Subject<T>.replay(
          shouldReplayAll: shouldReplayAll,
          bufferSize: bufferSize,
          initValues: initValues))
        ..name = '$name.publishReplay(shouldReplayAll: $shouldReplayAll, '
            'bufferSize: $bufferSize, initValues: $initValues)';

  // TODO(kismet):
  // Revisits this opeartor to decide whether it should depend on the
  // reference count. See
  // [the RxJs5 shareReplay issue][rxjs-5-share-replay-issue] for more details.
  //
  // [rxjs-5-share-replay-issue]: https://github.com/ReactiveX/rxjs/issues/3127
  Observable<T> share() => publish().refCount()..name = '$name.share()';

  Observable<T> shareReplay(
          {bool shouldReplayAll = false,
          int bufferSize = 1,
          Iterable<T> initValues = const []}) =>
      publishReplay(
              shouldReplayAll: shouldReplayAll,
              bufferSize: bufferSize,
              initValues: initValues)
          .refCount()
        ..name = '$name.shareReplay('
            'shouldReplayAll: $shouldReplayAll, '
            'bufferSize: $bufferSize, initValues: $initValues)';

  /// [rx-defer]: http://reactivex.io/documentation/operators/defer.html
  factory Observable.defer(Observable<T> observableCreator()) =>
      Observable((Observer<T> observer) =>
          observableCreator().subscribeByObserver(observer))
        ..name = 'defer($observableCreator)';

  /// http://reactivex.io/documentation/operators/empty-never-throw.html
  factory Observable.empty() => Observable((Observer<T> observer) {
        observer.sendCompleted();
        return Disposable.noop;
      })
        ..name = 'empty()';

  factory Observable.fromStream(Stream<T> stream) {
    var broadcastStream =
        stream.isBroadcast ? stream : stream.asBroadcastStream();
    return Observable((Observer<T> observer) => Disposable(broadcastStream
        .listen(observer.sendNext,
            onError: observer.sendError, onDone: observer.sendCompleted)
        .cancel))
      ..name = 'fromStream($stream)';
  }

  /// http://reactivex.io/documentation/operators/from.html
  factory Observable.fromValues(Iterable<T> values) {
    var copied = values.toList(growable: false);
    return Observable((Observer<T> observer) {
      copied.forEach(observer.sendNext);
      observer.sendCompleted();
      return Disposable.noop;
    })
      ..name = 'fromValues($values)';
  }

  /// http://reactivex.io/documentation/operators/just.html
  factory Observable.just(T value) =>
      Observable.fromValues([value])..name = 'just($value)';

  /// http://reactivex.io/documentation/operators/empty-never-throw.html
  factory Observable.never() =>
      Observable((_) => Disposable.noop)..name = 'never()';

  /// [rx-retry]: http://reactivex.io/documentation/operators/retry.html
  //
  // TODO(kismet): implements [retryWhen] operator so that we don't need the
  // [shouldRetry] and [delay] parameter. But also need to either implement
  // the [zip] operator or change [scan] operator (to try/catch exception) to
  // simulate the [maxAttempts] behavior.
  Observable<T> retry(
          {int maxAttempts = 1,
          bool shouldRetry(Object object, [StackTrace stackTrace])?,
          Duration? delay(int attempted, Object error,
              [StackTrace stackTrace])?,
          Scheduler? scheduler}) =>
      Observable((Observer<T> observer) {
        var attempts = 0;
        scheduler ??= Scheduler.defaultScheduler;
        final cd = CompositeDisposable();
        final scheduleSad = SingleAssignmentDisposable();
        cd.add(scheduleSad);
        scheduleSad.disposable =
            scheduler?.scheduleRecursiveDelay((reschedule) {
          final sad = SingleAssignmentDisposable();
          cd.add(sad);
          sad.disposable = subscribe(
              onNext: observer.sendNext,
              onError: (error, [stackTrace]) {
                void close() {
                  observer.sendError(error, stackTrace);
                  cd.dispose();
                }

                if (maxAttempts >= 0 && attempts == maxAttempts) {
                  close();
                } else {
                  if (shouldRetry == null || shouldRetry(error, stackTrace)) {
                    ++attempts;
                    final delayDuration = delay == null
                        ? null
                        : delay(attempts, error, stackTrace);
                    cd.remove(sad);
                    reschedule(delayDuration!);
                  } else {
                    close();
                  }
                }
              },
              onCompleted: () {
                observer.sendCompleted();
                cd.dispose();
              });
        });
        return cd;
      })
        ..name = '$name.retry(maxAttempts: $maxAttempts, '
            'shouldRetry: $shouldRetry, delay: $delay, '
            'scheduler: $scheduler)';

  // TODO(kismet): implement [retryWhen] operator.
  // Observable<T> retryWhen(
  //         Observable Function(Observable<Object>) errorTriggerFactory);

  /// [rx-debounce]: http://reactivex.io/documentation/operators/debounce.html
  Observable<T> debounce(Duration duration, {Scheduler? scheduler}) =>
      Observable((Observer<T> observer) {
        scheduler ??= Scheduler.defaultScheduler;
        var hasLastValue = false;
        T? lastData;
        var delaySd = SerialDisposable();
        var disposable = subscribe(onNext: (T data) {
          hasLastValue = true;
          lastData = data;
          delaySd.disposable = scheduler!.scheduleDelay(duration, () {
            observer.sendNext(data);
            hasLastValue = false;
          });
        },
            //onError: _sendErrorAndDispose(observer, delaySd),
            onCompleted: () {
          // Cancel delayed 'sendNext' and emit the last data immediately.
          delaySd.dispose();
          // TODO(kismet): revisit potential threading issue.
          if (hasLastValue) observer.sendNext(lastData!);
          observer.sendCompleted();
        });
        return CompositeDisposable([disposable, delaySd]);
      })
        ..name = '$name.debounce($duration, scheduler: $scheduler)';

  /// [rx-distinct]: http://reactivex.io/documentation/operators/distinct.html
  /// [rx-distinctUntilChanged]: http://rxmarbles.com/#distinctUntilChanged
  Observable<T> distinctUntilChanged([Comparator<T>? comparator]) {
    isEqual(T a, T b) => comparator == null ? a == b : comparator(a, b) == 0;
    return Observable((Observer<T> observer) {
      T? prevEvent;
      var isFirstEvent = true;
      return subscribe(
          onNext: (T data) {
            if (isFirstEvent || !isEqual(data, prevEvent as T)) {
              isFirstEvent = false;
              prevEvent = data;
              observer.sendNext(data);
            }
          },
          onError: observer.sendError,
          onCompleted: observer.sendCompleted);
    })
      ..name = '$name.distinctUntilChanged($comparator)';
  }

  /// [rx-first]: http://reactivex.io/documentation/operators/first.html
  Observable<T> first() => take(1)..name = '$name.first()';

  /// [rx-take]: http://reactivex.io/documentation/operators/take.html
  Observable<T> take(int n) {
    return n == 0
        ? Observable.empty()
        : Observable((Observer<T> observer) {
            final sad = SingleAssignmentDisposable();
            var localN = n;
            sad.disposable = subscribe(
                onNext: (T data) {
                  if (localN-- > 0) observer.sendNext(data);
                  if (localN <= 0) {
                    observer.sendCompleted();
                    sad.dispose();
                  }
                },
                onError: observer.sendError,
                onCompleted: observer.sendCompleted);
            return sad;
          })
      ..name = '$name.take($n)';
  }

  /// [rx-take-last]: http://reactivex.io/documentation/operators/takelast.html
  Observable<T> takeLast(int n) {
    return n == 0
        ? Observable.empty()
        : Observable((Observer<T> observer) {
            var pool = Queue<T>();
            return subscribe(onNext: (T data) {
              if (pool.length == n) pool.removeFirst();
              pool.addLast(data);
            },
                //onError: _sendErrorAndDispose(observer, pool.clear),
                onCompleted: () {
              pool.forEach(observer.sendNext);
              pool.clear();
              observer.sendCompleted();
            });
          })
      ..name = '$name.takeLast($n)';
  }

  /// [rx-filter]: http://reactivex.io/documentation/operators/filter.html
  Observable<T> filter(bool predicate(T data)) =>
      Observable((Observer<T> observer) => subscribe(
          onNext: (T data) {
            if (predicate(data)) observer.sendNext(data);
          },
          onError: observer.sendError,
          onCompleted: observer.sendCompleted))
        ..name = '$name.filter($predicate)';

  /// [rx-skip]: http://http://reactivex.io/documentation/operators/skip.html
  Observable<T> skip(int n) {
    return n == 0
        ? this
        : Observable((Observer<T> observer) {
            final sad = SingleAssignmentDisposable();
            var localN = n;
            sad.disposable = subscribe(
                onNext: (T data) {
                  if (localN == 0) {
                    observer.sendNext(data);
                  } else {
                    localN--;
                  }
                },
                onError: observer.sendError,
                onCompleted: observer.sendCompleted);
            return sad;
          })
      ..name = '$name.skip($n)';
  }

  /// [rx-buffer]: http://reactivex.io/documentation/operators/buffer.html
  Observable<List<T>> buffer(int bufferSize, {bool drainOnCompleted = true}) {
    assert(bufferSize > 1);
    return Observable((Observer<List<T>> observer) {
      List<T>? buffer = <T>[];
      return subscribe(onNext: (T data) {
        buffer?.add(data);
        if (buffer?.length == bufferSize) {
          var tempBuffer = buffer;
          buffer = <T>[];
          observer.sendNext(tempBuffer!);
        }
      }, onError: (error, [stackTrace]) {
        buffer = null;
        observer.sendError(error, stackTrace);
      }, onCompleted: () {
        if (drainOnCompleted && buffer!.isNotEmpty) {
          var tempBuffer = buffer;
          buffer = null;
          observer.sendNext(tempBuffer!);
        }
        observer.sendCompleted();
      });
    })
      ..name = '$name.buffer($bufferSize, drainOnCompleted: $drainOnCompleted)';
  }

  /// [rx-flatmap]: http://reactivex.io/documentation/operators/flatmap.html
  Observable<S> flatMap<S>(Observable<S> convert(T data)) =>
      (map<Observable<S>>(convert).flatten<S>()
        ..name = '$name.flatMap($convert)');

  /// [rx-flatmap]: http://reactivex.io/documentation/operators/flatmap.html
  Observable<S> flatten<S>() => Observable((Observer<S> observer) {
        var cd = CompositeDisposable();
        var sad = SingleAssignmentDisposable();
        var outerCompleted = false;
        var innerAliveCount = 0;
        void maySendCompleted() {
          if (outerCompleted && innerAliveCount == 0) {
            observer.sendCompleted();
          }
        }

        sad.disposable = subscribe(onNext: (T data) {
          //_checkIsObservable('flatten', data);
          var innerObservable = data as Observable<S>;
          ++innerAliveCount;
          var innerSad = SingleAssignmentDisposable();
          cd.add(innerSad);
          innerSad.disposable = innerObservable.subscribe(
              onNext: observer.sendNext,
//                  onError: _sendErrorAndDispose(observer, () {
//                    sad.dispose();
//                    (cd..remove(innerSad)).dispose();
//                  }),
              onCompleted: () {
                cd.remove(innerSad);
                --innerAliveCount;
                maySendCompleted();
              });
        },
            //onError: _sendErrorAndDispose(observer, cd),
            onCompleted: () {
          outerCompleted = true;
          maySendCompleted();
        });
        return CompositeDisposable([sad, cd]);
      })
        ..name = '$name.flatten()';

  /// [rx-map]: http://reactivex.io/documentation/operators/map.html
  Observable<S> map<S>(S convert(T data)) =>
      Observable((Observer<S> observer) => subscribe(
          onNext: (T data) {
            observer.sendNext(convert(data));
          },
          onError: observer.sendError,
          onCompleted: observer.sendCompleted))
        ..name = '$name.map($convert)';

  Observable<List<T>> nGram(int count) {
    return Observable((Observer<List<T>> observer) {
      final buffer = Queue<T>()..addAll(List<T>.empty(growable: true));
      return subscribe(
          onNext: (T data) {
            buffer.addLast(data);
            buffer.removeFirst();
            observer.sendNext(buffer.toList());
          },
          onError: observer.sendError,
          onCompleted: observer.sendCompleted);
    })
      ..name = '$name.nGram($count)';
  }

  /// [rx-scan]: http://reactivex.io/documentation/operators/scan.html
  Observable<S> scan<S>(S accumulator(S? a, T b), [S? seed]) =>
      Observable((Observer<S> observer) {
        var accumulated = seed;
        return this.subscribe(onNext: (T data) {
          accumulated = accumulator(accumulated, data);
          observer.sendNext(accumulated!);
        },
//            onError: _sendErrorAndDispose(observer, () {
//              accumulated = null;
//            }),
            onCompleted: () {
          observer.sendCompleted();
          accumulated = null;
        });
      })
        ..name = '$name.scan()';

  /// [rx-delay]: http://reactivex.io/documentation/operators/delay.html
  Observable<T> delay(Duration duration, {required Scheduler scheduler}) =>
      Observable((Observer<T> observer) {
        scheduler ??= Scheduler.defaultScheduler;
        final delayCd = CompositeDisposable();
        void scheduleAction(void action()) {
          final scheduledSad = SingleAssignmentDisposable();
          scheduledSad.disposable = scheduler.scheduleDelay(duration, () {
            delayCd.remove(scheduledSad);
            action();
          });
          delayCd.add(scheduledSad);
        }

        final disposable = subscribe(onNext: (T data) {
          scheduleAction(() {
            observer.sendNext(data);
          });
        },
            //onError: _sendErrorAndDispose(observer, delayCd),
            onCompleted: () {
          // TODO(kismet): revisit potential threading issue.
          scheduleAction(() {
            observer.sendCompleted();
            delayCd.dispose();
          });
        });
        return CompositeDisposable([disposable, delayCd]);
      })
        ..name = '$name.delay($duration, scheduler: $scheduler)';

  /// [rx-interval]: http://reactivex.io/documentation/operators/interval.html
  static Observable<int> interval(Duration period,
          {required Scheduler scheduler}) =>
      Observable.timer(period: period, scheduler: scheduler)
          .map((_) => 1)
          .scan((a, b) => (a ?? -1) + b)
        ..name = 'interval($period, scheduler: $scheduler)';

  /// [rx-timer]: http://reactivex.io/documentation/operators/timer.html
  static Observable<Duration> timer({
    Duration? delay,
    required Duration period,
    Duration? until,
    Scheduler? scheduler,
  }) =>
      Observable<Duration>((Observer<Duration> observer) {
        scheduler = scheduler ?? Scheduler.defaultScheduler;
        final subscribedTimestampMillis = scheduler!.now;
        return scheduler!.scheduleTimer(
          () => observer.sendNext(Duration(
              milliseconds: scheduler!.now - subscribedTimestampMillis)),
          delay: delay,
          period: period,
          until: until,
          timeoutCallback: observer.sendCompleted,
        );
      })
        ..name = 'timer(delay: $delay, period: $period, until: $until, '
            'scheduler: $scheduler)';

  /// [rx-observeon]: http://reactivex.io/documentation/operators/observeon.html
  Observable<T> observeOn(Scheduler scheduler) =>
      Observable((Observer<T> observer) {
        var nextCd = CompositeDisposable();
        var errorSad = SingleAssignmentDisposable();
        var completedSad = SingleAssignmentDisposable();
        // TODO(kismet): revisit potential threading issue.
        var thisDisposable = subscribe(onNext: (T data) {
          var localSad = SingleAssignmentDisposable();
          nextCd.add(localSad);
          localSad.disposable = scheduler.schedule(() {
            observer.sendNext(data);
            nextCd.remove(localSad);
          });
        }, onError: (error, [stackTrace]) {
          errorSad.disposable = scheduler.schedule(() {
            observer.sendError(error, stackTrace);
            nextCd.dispose();
            completedSad.dispose();
          });
        }, onCompleted: () {
          completedSad.disposable = scheduler.schedule(() {
            observer.sendCompleted();
            // TODO(kismet): assert the nextCd is empty.
            nextCd.dispose();
            errorSad.dispose();
          });
        });
        return CompositeDisposable([
          thisDisposable,
          nextCd,
          errorSad,
          completedSad,
        ]);
      })
        ..name = '$name.observeOn($scheduler)';

  /// [rx-subscribeon]: http://reactivex.io/documentation/operators/subscribeon.html
  Observable<T> subscribeOn(Scheduler scheduler) =>
      // TODO(kismet): revisit potential threading issue.
      Observable((Observer<T> observer) {
        var subscriptionSad = SingleAssignmentDisposable();
        var scheduleDisposable = scheduler.schedule(() {
          subscriptionSad.disposable = subscribeByObserver(observer);
        });
        return CompositeDisposable([scheduleDisposable, subscriptionSad]);
      })
        ..name = '$name.subscribeOn($scheduler)';

  /// [rx-do]: http://reactivex.io/documentation/operators/do.html
  Observable<T> tap(
          {required OnNextFunction<T> onNext,
          Function? onError,
          required OnCompletedFunction onCompleted,
          required void Function() onSubscribed,
          required void Function() onDisposed}) =>
      Observable((Observer<T> observer) {
        if (onSubscribed != null) onSubscribed();
        return CompositeDisposable([
          subscribe(onNext: (data) {
            if (onNext != null) onNext(data);
            observer.sendNext(data);
          }, onError: (error, [stackTrace]) {
            if (onError != null) onError(error, stackTrace);
            observer.sendError(error, stackTrace);
          }, onCompleted: () {
            if (onCompleted != null) onCompleted();
            observer.sendCompleted();
          }),
          Disposable(() {
            if (onDisposed != null) onDisposed();
          }),
        ]);
      })
        ..name = '$name.tap(onNext: $onNext, onError: $onError, '
            'onCompleted: $onCompleted, '
            'onSubscribed: $onSubscribed, onDisposed: $onDisposed)';

  /// [rx-materialize]: http://reactivex.io/documentation/operators/materialize-dematerialize.html
  Observable<Notification<T>> materialize() =>
      Observable((Observer<Notification<T>> observer) {
        return subscribe(
            onNext: (T value) => observer.sendNext(Notification.onNext(value)),
            onError: (error, [stackTrace]) {
              observer.sendNext(Notification.onError(error, stackTrace));
              observer.sendCompleted();
            },
            onCompleted: () {
              observer.sendNext(Notification.onCompleted());
              observer.sendCompleted();
            });
      })
        ..name = '$name.materialize()';

  /// [rx-dematerialize]: http://reactivex.io/documentation/operators/materialize-dematerialize.html
  Observable<S> dematerialize<S>() => Observable((Observer<S> observer) {
        return subscribe(
            onNext: (T t) {
              Notification<S> notification = t as Notification<S>;
              switch (notification.type) {
                case NotificationType.OnNext:
                  observer.sendNext(notification.value as S);
                  break;
                case NotificationType.OnError:
                  observer.sendError(
                      notification.error!, notification.stackTrace!);
                  break;
                case NotificationType.OnCompleted:
                  observer.sendCompleted();
                  break;
              }
            },
            onError: (error, [stackTrace]) =>
                observer.sendError(error, stackTrace),
            onCompleted: () => observer.sendCompleted());
      })
        ..name = '$name.dematerialize()';
}

class _OnSubscribeFunctionObservable<T> extends Observable<T> {
  final OnSubscribeFunction<T> _onSubscribe;

  _OnSubscribeFunctionObservable(this._onSubscribe) : super.protected();

  @override
  Disposable subscribeByObserver(Observer<T> observer) =>
      _onSubscribe(Observer.makeSafe(observer));
}

/// [rx-operators]: http://reactivex.io/documentation/operators.html
class Connectable<T> {
  String? name;
  final Observable<T> _source;
  final Subject<T> _subject;
  SingleAssignmentDisposable? _connectedDisposable;

  int _autoConnectCount = 0;

  bool _manuallyConnected = false;

  bool _willBeAutoConnected = false;
  Connectable._(this._source, this._subject);

  /// TODO(kismet): wrap _subject into Observable to avoid caller downcast
  /// it to Subject instance.
  Observable<T> get observable => _subject;

  /// [rx-connect]: http://reactivex.io/documentation/operators/connect.html
  Disposable connect() {
    _manuallyConnected = true;
    return _connect();
  }

  Disposable _connect() {
    if (_connectedDisposable != null) return _connectedDisposable!;
    _connectedDisposable = SingleAssignmentDisposable();
    _connectedDisposable!.disposable = CompositeDisposable([
      _source.subscribeByObserver(_subject),
      Disposable(() {
        _connectedDisposable = null;
      }),
    ]);
    return _connectedDisposable!;
  }

  /// [rxjava-autoconnect]: http://reactivex.io/RxJava/javadoc/rx/observables/ConnectableObservable.html
  Observable<T> autoConnect([int subscriptionCount = 1]) {
    _willBeAutoConnected = true;
    // This is desired side effect out of onSubscribe function.
    var subscribedCount = 0;
    return Observable((Observer<T> observer) {
      var disposable = observable.subscribeByObserver(observer);
      if (subscribedCount == 0) ++_autoConnectCount;
      ++subscribedCount;
      if (subscribedCount >= subscriptionCount) _connect();
      return CompositeDisposable([
        disposable,
        Disposable(() {
          subscribedCount = max(0, subscribedCount - 1);
          if (subscribedCount == 0) {
            _autoConnectCount = max(0, _autoConnectCount - 1);
          }
          if (_autoConnectCount == 0) _connectedDisposable?.dispose();
        })
      ]);
    })
      ..name = '$name.autoConnect($subscriptionCount)';
  }

  /// [rx-refcount]: http://reactivex.io/documentation/operators/refcount.html
  Observable<T> refCount() => autoConnect()..name = '$name.refCount()';
}

class OnSubscribeObservableFactory {
  /// The default factory.
  static final OnSubscribeObservableFactory defaultFactory =
      OnSubscribeObservableFactory._();
  static OnSubscribeObservableFactory? _currenctFactory;

  /// Current factory.
  static OnSubscribeObservableFactory get currentFactory =>
      _currenctFactory ?? defaultFactory;

  static set currentFactory(OnSubscribeObservableFactory currenctFactory) {
    _currenctFactory = currenctFactory;
  }

  OnSubscribeObservableFactory._();

  Observable<T> create<T>(OnSubscribeFunction<T> onSubscribe) =>
      _OnSubscribeFunctionObservable(onSubscribe)
        ..name = 'observable($onSubscribe)';

  Function _sendErrorAndDispose<T>(
          Observer<T> observer, DisposeFunction dispose) =>
      (error, [stackTrace]) {
        observer.sendError(error, stackTrace);
        dispose();
      };

  /// Checks whether the [object] is an Observable for [op]erator.
  void _checkIsObservable<T>(String op, T event) {}
}
