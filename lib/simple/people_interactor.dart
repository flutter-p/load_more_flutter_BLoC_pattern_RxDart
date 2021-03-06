import 'dart:async';

import 'package:built_collection/built_collection.dart';
import 'package:load_more_flutter/data/people_data_source.dart';
import 'package:load_more_flutter/model/person.dart';
import 'package:load_more_flutter/simple/people_state.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tuple/tuple.dart';

const int pageSize = 10;

class PeopleInteractor {
  final PeopleDataSource _peopleDataSource;

  const PeopleInteractor(this._peopleDataSource)
      : assert(_peopleDataSource != null);

  Observable<PeopleListState> fetchData(
      Tuple3<PeopleListState, bool, Completer<void>> tuple,
      Sink<Message> messageSink) {
    ///
    /// Destruct variables from [tuple]
    ///
    final currentState = tuple.item1;
    final refreshList = tuple.item2;
    final completer = tuple.item3;

    ///
    /// Get people from [peopleDataSource]
    ///
    final getPeople = _peopleDataSource.getPeople(
      field: 'name',
      limit: pageSize,
      startAfter: refreshList ? null : lastOrNull(currentState.people),
    );

    ///
    ///
    ///
    toListState(BuiltList<Person> people) => PeopleListState((b) {
          final listBuilder = currentState.people.toBuilder()
            ..update((b) {
              if (refreshList) {
                b.clear();
              }
              b.addAll(people);
            });

          return b
            ..error = null
            ..isLoading = false
            ..people = listBuilder
            ..getAllPeople = people.isEmpty;
        });

    toErrorState(dynamic e) => currentState.rebuild((b) => b
      ..error = e
      ..getAllPeople = false
      ..isLoading = false);

    final loadingState = currentState.rebuild((b) => b
      ..isLoading = true
      ..getAllPeople = false
      ..error = null);

    ///
    /// Perform side affects:
    ///
    /// - Add [LoadAllPeopleMessage] or [ErrorMessage] to [messageSink]
    /// - Complete [completer] if [completer] is not null
    ///
    addLoadAllPeopleMessageIfLoadedAll(PeopleListState state) {
      if (state.getAllPeople) {
        messageSink.add(const LoadAllPeopleMessage());
      }
    }

    addErrorMessage(dynamic error, StackTrace _) =>
        messageSink.add(ErrorMessage(error));

    completeCompleter() => completer?.complete();

    ///
    /// Return state [Stream]
    ///
    return Observable.fromFuture(getPeople)
        .map(toListState)
        .doOnData(addLoadAllPeopleMessageIfLoadedAll)
        .doOnError(addErrorMessage)
        .startWith(loadingState)
        .onErrorReturnWith(toErrorState)
        .doOnDone(completeCompleter);
  }
}

///
/// Returns the last element if [list] is not empty, otherwise return null
///
T lastOrNull<T>(Iterable<T> list) => list.isNotEmpty ? list.last : null;
