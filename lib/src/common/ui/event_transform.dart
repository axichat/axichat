import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:stream_transform/stream_transform.dart';

const downTime = Duration(milliseconds: 100);

EventTransformer<E> blocThrottle<E>(Duration duration) =>
    (events, mapper) => droppable<E>().call(events.throttle(duration), mapper);
