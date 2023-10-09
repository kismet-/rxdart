/// Rx lib aimed to implement ReactiveX (http://reactivex.io/) equivalent
/// data structures in dart for reactive functional programming.
library rxdart;

import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:math';

import "package:collection/collection.dart";
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

export 'src/behavior_subject.dart';
export 'src/behavior_subject_map.dart';
export 'src/bloc_with_rx.dart';
export 'src/blocking.dart';
export 'src/combine_latest.dart';
export 'src/conditional.dart';
export 'src/connectable.dart';
export 'src/creator.dart';
export 'src/last_event.dart';
export 'src/lifecycle.dart';
export 'src/map_to_optional.dart';
export 'src/rx_util.dart';
export 'src/transform.dart';

part 'src/disposable.dart';
part 'src/notification.dart';
part 'src/observable.dart';
part 'src/observer.dart';
part 'src/scheduler.dart';
part 'src/subject.dart';

Logger _defaultLogger = Logger('rxdart');
Logger _logger = _defaultLogger;

void setRxLogger(Logger logger) {
  _logger = logger ?? _defaultLogger;
}
