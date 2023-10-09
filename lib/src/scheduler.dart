part of rxdart;

typedef void RunnableFunction();

typedef void RescheduleFunction();

typedef void RecursiveRunnableFunction(RescheduleFunction reschedule);

typedef void RescheduleDelayFunction(Duration? delay);

typedef void RecursiveDelayRunnableFunction(
    RescheduleDelayFunction rescheduleDelay);
typedef void TimeoutCallbackFunction();
typedef int NowTimestampMillisecondsFunction();

/// http://reactivex.io/documentation/scheduler.html
abstract class Scheduler {
  static final Scheduler defaultScheduler = Scheduler.immediate()
    ..name = 'DefaultImmediateScheduler';

  static final Scheduler microtaskScheduler = Scheduler.microtask()
    ..name = 'DefaultMicrotaskScheduler';

  late String name;

  @protected
  Scheduler.protected();

  factory Scheduler.immediate([NowTimestampMillisecondsFunction? nowFn]) =>
      _ImmediateScheduler(nowFn!);

  factory Scheduler.microtask([NowTimestampMillisecondsFunction? nowFn]) =>
      _MicrotaskScheduler(nowFn!);

  @override
  String toString() => name;

  /// TODO(kismet): change the type from 'int' to 'Duration'.
  int get now;

  Disposable schedule(RunnableFunction runnable);

  Disposable scheduleDelay(Duration delay, RunnableFunction runnable);

  Disposable scheduleRecursive(RecursiveRunnableFunction runnable) =>
      scheduleRecursiveDelay((RescheduleDelayFunction rescheduleDelay) {
        runnable(() {
          rescheduleDelay(null);
        });
      });

  Disposable scheduleRecursiveDelay(RecursiveDelayRunnableFunction runnable) {
    var sd = SerialDisposable();
    void scheduleNext() {
      runnable((Duration? delay) {
        sd.disposable = scheduleDelay(delay!, scheduleNext);
      });
    }

    return CompositeDisposable([schedule(scheduleNext), sd]);
  }

  Disposable scheduleTimer(
    RunnableFunction runnable, {
    Duration? delay,
    Duration? period,
    Duration? until,
    TimeoutCallbackFunction? timeoutCallback,
  }) {
    schedulePeriodicTask(Duration? until) => period == null
        ? Disposable.noop
        : schedulePeriodic(period, runnable,
            until: until, timeoutCallback: timeoutCallback!);
    if (delay == null) return schedulePeriodicTask(until!);
    var sd = SerialDisposable();
    sd.disposable = scheduleDelay(delay, () {
      runnable();
      sd.disposable =
          schedulePeriodicTask(until == null ? null : until - delay);
    });
    return sd;
  }

  Disposable schedulePeriodic(Duration period, RunnableFunction runnable,
      {Duration? until, TimeoutCallbackFunction? timeoutCallback}) {
    var scheduledTimestamp = now;
    var localRunnable;
    return scheduleRecursiveDelay((RescheduleDelayFunction rescheduleDelay) {
      if (until != null && until.inMilliseconds <= now - scheduledTimestamp) {
        if (timeoutCallback != null) timeoutCallback();
      } else {
        if (localRunnable == null) {
          localRunnable = runnable;
        } else {
          localRunnable();
        }
        rescheduleDelay(period);
      }
    });
  }
}

abstract class _BaseTimerScheduler extends Scheduler {
  static int _nowSinceEpoch() => DateTime.now().millisecondsSinceEpoch;

  final int _creationTimestamp;
  final NowTimestampMillisecondsFunction _nowFn;

  _BaseTimerScheduler(NowTimestampMillisecondsFunction nowFn)
      : _nowFn = nowFn ?? _nowSinceEpoch,
        _creationTimestamp = (nowFn ?? _nowSinceEpoch)(),
        super.protected();

  @override
  int get now => _nowFn() - _creationTimestamp;

  @override
  Disposable scheduleDelay(Duration delay, RunnableFunction runnable) =>
      delay == null
          ? schedule(runnable)
          : Disposable(Timer(delay, runnable).cancel);

  @override
  Disposable schedulePeriodic(Duration period, RunnableFunction runnable,
      {Duration? until, TimeoutCallbackFunction? timeoutCallback}) {
    var scheduledTimestamp = now;
    Timer? periodicTimer;
    periodicTimer = Timer.periodic(period, (_) {
      if (until != null && until.inMilliseconds <= now - scheduledTimestamp) {
        periodicTimer?.cancel();
        if (timeoutCallback != null) timeoutCallback();
      } else {
        runnable();
      }
    });
    return Disposable(periodicTimer.cancel);
  }
}

class _ImmediateScheduler extends _BaseTimerScheduler {
  static int _count = 0;

  _ImmediateScheduler(NowTimestampMillisecondsFunction nowFn) : super(nowFn) {
    name = 'ImmediateScheduler_${_count++}';
  }
  @override
  Disposable schedule(RunnableFunction runnable) {
    runnable();
    return Disposable.noop;
  }
}

class _MicrotaskScheduler extends _BaseTimerScheduler {
  static int _count = 0;

  _MicrotaskScheduler(NowTimestampMillisecondsFunction nowFn) : super(nowFn) {
    name = 'MicrotaskScheduler_${_count++}';
  }
  @override
  Disposable schedule(RunnableFunction runnable) {
    var disposable = CheckableDisposable();
    scheduleMicrotask(() {
      if (!disposable.disposed) {
        runnable();
      }
    });
    return disposable;
  }
}

class VirtualTimeScheduler extends Scheduler {
  static int _count = 0;
  int _virtualTimestamp = 0;
  bool _running = false;
  PriorityQueue<_VTTask> _tasks = PriorityQueue();

  VirtualTimeScheduler() : super.protected() {
    name = 'VirtualTimeScheduler_${_count++}';
  }
  @override
  int get now => _virtualTimestamp;

  Disposable _scheduleRunableAtTick(RunnableFunction runnable, int tick) {
    var task = _VTTask(runnable, tick);
    _tasks.add(task);
    return Disposable(task.dispose);
  }

  @override
  Disposable schedule(RunnableFunction runnable) =>
      _scheduleRunableAtTick(runnable, _virtualTimestamp);
  @override
  Disposable scheduleDelay(Duration delay, RunnableFunction runnable) =>
      delay == null
          ? schedule(runnable)
          : _scheduleRunableAtTick(
              runnable, _virtualTimestamp + delay.inMilliseconds);

  _VTTask? _nextTask() {
    while (_tasks.isNotEmpty) {
      _VTTask task = _tasks.removeFirst();
      if (!task.disposed) {
        return task;
      }
    }
    return null;
  }

  _VTTask? _peekAtNextTask() {
    while (_tasks.isNotEmpty) {
      if (_tasks.first.disposed) {
        _tasks.removeFirst();
      } else {
        return _tasks.first;
      }
    }
    return null;
  }

  void advanceTimeTo(Duration timestamp) {
    var nextTask = _peekAtNextTask();
    while (nextTask != null &&
        nextTask.scheduledTimestamp <= timestamp.inMilliseconds) {
      nextTask = _nextTask();
      _virtualTimestamp = nextTask!.scheduledTimestamp;
      nextTask.runnable();
      nextTask = _peekAtNextTask();
    }
    _virtualTimestamp = timestamp.inMilliseconds;
  }

  void advanceTimeBy(Duration duration) {
    advanceTimeTo(duration + Duration(milliseconds: _virtualTimestamp));
  }

  void start() {
    if (!_running) {
      _running = true;
      while (_running) {
        var nextTask = _nextTask();
        if (nextTask != null) {
          if (nextTask.scheduledTimestamp > _virtualTimestamp) {
            _virtualTimestamp = nextTask.scheduledTimestamp;
          }
          nextTask.runnable();
        } else {
          _running = false;
        }
      }
    }
  }

  void stop() {
    _running = false;
  }
}

class _VTTask implements Comparable<_VTTask> {
  final RunnableFunction runnable;

  final int scheduledTimestamp;
  bool _disposed = false;

  _VTTask(this.runnable, this.scheduledTimestamp);

  void dispose() {
    _disposed = true;
  }

  bool get disposed => _disposed;

  @override
  int compareTo(_VTTask other) {
    return scheduledTimestamp - other.scheduledTimestamp;
  }
}
