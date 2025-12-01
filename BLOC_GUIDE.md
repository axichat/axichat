# BLoC & Flutter_BLoC Library Guide for Sonnet 4

NEVER DO ANY OF THIS:
```dart
final homeSearchCubit = BlocProvider.maybeOf<HomeSearchCubit>(context);
final searchProvider = context.findAncestorWidgetOfExactType<BlocProvider<HomeSearchCubit>>();
if (searchProvider == null) {
  return _BlocklistListBody(items: items);
}
final homeSearchCubit = context.read<HomeSearchCubit>();
```
- Finding BLoCs with any method other than `BlocBuilder`, `BlocSelector`, `BlocListener`, or `BlocConsumer` is STRICTLY FORBIDDEN.
- The ONLY EXCEPTION is you MUST use `context.watch()` when listening to the `SettingsCubit` outside of settings related UI, i.e., outside of the app.dart file, or the `ProfileScreen` and its descendants you must use `context.watch()`.
- NEVER store BloCs in variables. If you use `context.read()` or `context.watch()` you must call them EVERY TIME you want to access their state. Do NOT store BLoC state in variables.

## Core Concepts

### What is BLoC?

BLoC (Business Logic Component) is a state management pattern that separates business logic from UI
presentation. The bloc library provides tools to implement this pattern in Flutter apps.

**Key Principles:**

- Predictable state management through unidirectional data flow
- Complete separation of business logic from UI
- Excellent testability and reusability
- Event-driven architecture (for Bloc) or method-driven (for Cubit)

## Package Structure

### Required Dependencies

```yaml
dependencies:
  flutter_bloc: ^8.1.0  # Flutter widgets for bloc
  bloc: ^8.1.0         # Core bloc logic (optional if using flutter_bloc)
```

### Import Statements

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

// This includes both bloc and flutter_bloc functionality
```

## Critical: Understanding BuildContext & Provider Gotchas

### The BuildContext Hierarchy Problem

**THE MOST COMMON ERROR:**

```
ProviderNotFoundException: Error: Could not find the correct Provider<MyBloc> above this Widget
```

This happens because:

1. **Wrong Context**: You're using a BuildContext that doesn't have the provider above it
2. **Same Widget Context**: Trying to access a provider in the same widget that creates it
3. **Route Scoping**: Provider is in a different route and not accessible
4. **Async Gaps**: Context became invalid after async operation

### Critical Provider Rules

#### Rule 1: Provider Must Be Above Consumer

```dart
// ❌ WRONG - Will throw ProviderNotFoundException
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyBloc(),
      // This context doesn't have MyBloc above it!
      child: Text('${context
          .read<MyBloc>()
          .state}'),
    );
  }
}

// ✅ CORRECT - Use Builder to get new context
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyBloc(),
      child: Builder(
        builder: (context) {
          // This context has MyBloc above it
          return Text('${context
              .read<MyBloc>()
              .state}');
        },
      ),
    );
  }
}
```

#### Rule 2: Context.read vs Context.watch

```dart
// ❌ NEVER use context.read in build methods
@override
Widget build(BuildContext context) {
  final bloc = context.read<MyBloc>(); // Will throw error!
  return Text(bloc.state.toString());
}

// ✅ Use context.watch in build methods
@override
Widget build(BuildContext context) {
  final bloc = context.watch<MyBloc>(); // Rebuilds on state change
  return Text(bloc.state.toString());
}

// ✅ Use context.read in callbacks
ElevatedButton
(
onPressed: () {
context.read<MyBloc>().add(MyEvent()); // Correct for one-time access
},
child: Text('Click'),
)
```

#### Rule 3: Routes & Navigation Scoping

```dart
// ❌ WRONG - Bloc won't be accessible in new route
Navigator.push
(
context,
MaterialPageRoute(
builder: (context) => SecondScreen(), // Can't access bloc here!
),
);

// ✅ SOLUTION 1: Wrap route in BlocProvider.value
Navigator.push(
context,
MaterialPageRoute(
builder: (_) => BlocProvider.value(
value: context.read<MyBloc>(),
child: SecondScreen(),
),
),
);

// ✅ SOLUTION 2: Use MultiBlocProvider at root
class MyApp extends StatelessWidget {
@override
Widget build(BuildContext context) {
return MultiBlocProvider(
providers: [
BlocProvider(create: (_) => AppBloc()),
],
child: MaterialApp(...), // All routes can access AppBloc
);
}
}
```

### InheritedWidget Fundamentals (What BlocProvider Uses)

#### How InheritedWidget Works

```dart
// BlocProvider internally uses InheritedWidget
// Understanding this helps debug context issues

// 1. InheritedWidget propagates data down the tree
class MyInheritedWidget extends InheritedWidget {
  final int data;

  MyInheritedWidget({required this.data, required Widget child})
      : super(child: child);

  // Called when widget rebuilds to check if dependents should rebuild
  @override
  bool updateShouldNotify(MyInheritedWidget old) => data != old.data;

  // Helper to access the widget
  static MyInheritedWidget? of(BuildContext context) {
    // This registers the context as a dependency!
    return context.dependOnInheritedWidgetOfExactType<MyInheritedWidget>();
  }
}
```

#### Context Lifecycle Gotchas

```dart
// ❌ WRONG - Using context after async gap
class MyWidget extends StatelessWidget {
  void fetchData(BuildContext context) async {
    await Future.delayed(Duration(seconds: 2));
    // Context might be invalid now!
    context.read<MyBloc>().add(DataLoaded()); // May crash
  }
}

// ✅ CORRECT - Check mounted for StatefulWidget
class MyStatefulWidget extends State<MyWidget> {
  void fetchData() async {
    await Future.delayed(Duration(seconds: 2));
    if (mounted) { // Check if widget is still in tree
      context.read<MyBloc>().add(DataLoaded());
    }
  }
}

// ✅ CORRECT - Store reference before async
class MyWidget extends StatelessWidget {
  void fetchData(BuildContext context) async {
    final bloc = context.read<MyBloc>(); // Get reference first
    await Future.delayed(Duration(seconds: 2));
    bloc.add(DataLoaded()); // Use stored reference
  }
}
```

### Dialog & Modal Context Issues

#### The Dialog Problem

```dart
// ❌ WRONG - Dialog has different context tree
showDialog
(
context: context,
builder: (dialogContext) {
// This dialogContext doesn't have access to blocs!
return ElevatedButton(
onPressed: () {
dialogContext.read<MyBloc>().add(MyEvent()); // Will crash!
},
child: Text('Click'),
);
},
);

// ✅ SOLUTION 1: Use BlocProvider.value
showDialog(
context: context,
builder: (dialogContext) {
return BlocProvider.value(
value: context.read<MyBloc>(), // Pass bloc to dialog
child: Builder(
builder: (context) {
return ElevatedButton(
onPressed: () {
context.read<MyBloc>().add(MyEvent()); // Works!
},
child: Text('Click'),
);
},
),
);
},
);

// ✅ SOLUTION 2: Capture bloc reference
final bloc = context.read<MyBloc>();
showDialog(
context: context,
builder: (_) {
return ElevatedButton(
onPressed: () {
bloc.add(MyEvent()); // Use captured reference
},
child: Text('Click'),
);
},
);
```

## Cubit (Simplified State Management)

### When to Use Cubit

- Simple state changes triggered by method calls
- Synchronous or basic async operations
- When you don't need event transformation
- Smaller features or simpler UI components

### Basic Cubit Structure

```dart
// 1. Define State Class
class CounterState {
  final int count;

  CounterState(this.count);
}

// 2. Create Cubit
class CounterCubit extends Cubit<CounterState> {
  CounterCubit() : super(CounterState(0)); // Initial state

  void increment() {
    emit(CounterState(state.count + 1)); // Emit new state
  }

  void decrement() {
    emit(CounterState(state.count - 1));
  }
}
```

## Bloc (Advanced State Management)

### When to Use Bloc

- Complex state logic requiring events
- Need to track event-state transitions
- Event transformations (debounce, throttle)
- Multiple sources triggering state changes
- Better debugging with event tracking

### Basic Bloc Structure

```dart
// 1. Define Events
abstract class CounterEvent {}

class Increment extends CounterEvent {}

class Decrement extends CounterEvent {}

// 2. Define State
class CounterState {
  final int count;

  CounterState(this.count);
}

// 3. Create Bloc
class CounterBloc extends Bloc<CounterEvent, CounterState> {
  CounterBloc() : super(CounterState(0)) {
    // Register event handlers
    on<Increment>((event, emit) {
      emit(CounterState(state.count + 1));
    });

    on<Decrement>((event, emit) {
      emit(CounterState(state.count - 1));
    });
  }
}
```

## Flutter Widgets Deep Dive

### BlocProvider

Provides a bloc/cubit to the widget tree with automatic lifecycle management.

```dart
// GOTCHA: lazy parameter (default: true)
BlocProvider
(
// By default, bloc is created when first accessed
lazy: true, // Default
create: (context) => ExpensiveBloc(), // Created on first read
)

// Force immediate creation
BlocProvider(
lazy: false,
create: (context) => ExpensiveBloc(), // Created immediately
)

// Providing existing bloc (won't auto-dispose)
BlocProvider.value(
value: existingBloc, // Won't call close() automatically
child:
MyWidget
(
)
,
)
```

### BlocBuilder

Rebuilds UI in response to state changes.

```dart
// GOTCHA: buildWhen optimization
BlocBuilder<CounterCubit, CounterState>
(
// Only rebuild when count is even
buildWhen: (previous, current) => current.count % 2 == 0,

builder: (context, state) {
return Text('Count: ${state.count}');
},
)

// GOTCHA: Providing external bloc
final myBloc = MyBloc(); // External bloc instance

BlocBuilder<MyBloc, MyState>(
bloc: myBloc, // Use external bloc, not from context
builder: (context, state) {
return Text(state.toString());
},
)
```

### BlocListener

Performs side effects without rebuilding.

```dart
// GOTCHA: Listener is called once per state
BlocListener<AuthBloc, AuthState>
(
// Only listen when logged out
listenWhen: (previous, current) =>
previous is LoggedIn && current is LoggedOut,

listener: (context, state) {
// Side effects only, no rebuilds
Navigator.pushReplacementNamed(context, '/login');
},
child: Container(),
)

// GOTCHA: Multiple listeners pattern
MultiBlocListener(
listeners: [
BlocListener<AuthBloc, AuthState>(...),
BlocListener<CartBloc, CartState>(...),
],
child: MyWidget(),
)
```

### BlocConsumer

Combines BlocBuilder and BlocListener.

```dart
BlocConsumer<CounterCubit, CounterState>
(
// Different conditions for listening vs building
listenWhen: (previous, current) => current.count == 10,
buildWhen: (previous, current) => current.count < 10,

listener: (context, state) {
if (state.count == 10) {
showDialog(...); // Show only at 10
}
},
builder: (context, state) {
// Rebuilds until count reaches 10
return Text('${state.count}');
},
)
```

### BlocSelector (Performance Optimization)

```dart
// Only rebuilds when specific field changes
BlocSelector<UserBloc, UserState, String>
(
selector: (state) => state.user.name, // Select specific field
builder: (context, name) {
// Only rebuilds when name changes
return Text('Hello $name');
},
)
```

## Advanced Context Patterns

### The Builder Pattern

```dart
// When you need a new context with provider above it
BlocProvider
(
create: (_) => MyBloc(),
child: Builder( // Creates new BuildContext
builder: (context) {
// This context has MyBloc above it
return BlocBuilder<MyBloc, MyState>(...);
},
)
,
)
```

### Context Extension Methods

```dart
// context.read<T>() - One-time access, no rebuilds
// ✅ Use in: callbacks, onPressed, initState (with caution)
// ❌ Don't use in: build methods

// context.watch<T>() - Rebuilds on changes
// ✅ Use in: build methods
// ❌ Don't use in: callbacks, async functions

// context.select<T, R>() - Selective rebuilds
// ✅ Use when: only part of state matters
final userName = context.select<UserBloc, String>(
        (bloc) => bloc.state.user.name
);
```

### Testing Context Issues

```dart
// GOTCHA: Test widgets need proper provider setup
testWidgets
('test with bloc
'
, (tester) async {
final bloc = MockBloc();

await tester.pumpWidget(
MaterialApp(
home: BlocProvider.value(
value: bloc,
child: MyWidget(),
),
),
);

// Widget can now access bloc
});
```

## Common Mistakes & Solutions

### Mistake 1: Using Wrong Context

```dart
// ❌ WRONG
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyBloc(),
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // This context is from MyScreen, not below BlocProvider!
            context.read<MyBloc>().add(MyEvent()); // Crashes!
          },
        ),
      ),
    );
  }
}

// ✅ CORRECT
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyBloc(),
      child: Builder(
        builder: (context) =>
            Scaffold(
              floatingActionButton: FloatingActionButton(
                onPressed: () {
                  context.read<MyBloc>().add(MyEvent()); // Works!
                },
              ),
            ),
      ),
    );
  }
}
```

### Mistake 2: Accessing Provider in initState

```dart
// ❌ WRONG
@override
void initState() {
  super.initState();
  final bloc = context.read<MyBloc>(); // May not work!
}

// ✅ CORRECT
@override
void initState() {
  super.initState();
  // Defer to after build
  WidgetsBinding.instance.addPostFrameCallback((_) {
    context.read<MyBloc>().add(InitEvent());
  });
}

// ✅ OR use didChangeDependencies
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  context.read<MyBloc>().add(InitEvent());
}
```

### Mistake 3: Not Handling Async Context

```dart
// ❌ WRONG
void _onButtonPressed(BuildContext context) async {
  final data = await fetchData();
  context.read<MyBloc>().add(DataEvent(data)); // Context may be invalid!
}

// ✅ CORRECT - StatefulWidget
void _onButtonPressed() async {
  final data = await fetchData();
  if (mounted) {
    context.read<MyBloc>().add(DataEvent(data));
  }
}

// ✅ CORRECT - Store reference
void _onButtonPressed(BuildContext context) async {
  final bloc = context.read<MyBloc>();
  final data = await fetchData();
  bloc.add(DataEvent(data)); // Safe to use
}
```

### Mistake 4: Shell Routes with go_router

```dart
// GOTCHA: go_router nested routes aren't truly nested in widget tree!

// ❌ WRONG - Child routes can't access bloc
GoRoute
(
path: '/home',
builder: (context, state) => BlocProvider(
create: (_) => HomeBloc(),
child: HomeScreen(),
),
routes: [
GoRoute(
path: 'details',
builder: (context, state) => DetailsScreen(), // Can't access HomeBloc!
),
],
)

// ✅ CORRECT - Use ShellRoute for shared context
ShellRoute(
builder: (context, state, child) {
return BlocProvider(
create: (_) => HomeBloc(),
child: child, // All nested routes can access
);
},
routes: [
GoRoute(path: '/home', builder: (_, __) => HomeScreen()),
GoRoute(path: '/details', builder: (_, __) =>
DetailsScreen
(
)
)
,
]
,
)
```

## State Classes Best Practices

### Using Sealed Classes (Recommended)

```dart
sealed class WeatherState {}

class WeatherInitial extends WeatherState {}

class WeatherLoading extends WeatherState {}

class WeatherSuccess extends WeatherState {
  final Weather weather;

  WeatherSuccess(this.weather);
}

class WeatherError extends WeatherState {
  final String message;

  WeatherError(this.message);
}
```

### Using Equatable for State Comparison

```dart
import 'package:equatable/equatable.dart';

class TodoState extends Equatable {
  final List<Todo> todos;
  final bool isLoading;

  TodoState({required this.todos, required this.isLoading});

  @override
  List<Object> get props => [todos, isLoading];

  TodoState copyWith({List<Todo>? todos, bool? isLoading}) {
    return TodoState(
      todos: todos ?? this.todos,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}
```

## Memory & Performance Gotchas

### Bloc Disposal

```dart
// BlocProvider auto-disposes when removed from tree
BlocProvider
(
create: (_) => MyBloc(), // Will call close() when removed
child: MyWidget(),
)

// BlocProvider.value does NOT auto-dispose
BlocProvider.value(
value: existingBloc, // You must manually close this
child: MyWidget(),
)

// Manual disposal pattern
class MyStatefulWidget extends StatefulWidget {
@override
_MyStatefulWidgetState createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget> {
late final MyBloc _bloc;

@override
void initState() {
super.initState();
_bloc = MyBloc();
}

@override
void dispose() {
_bloc.close(); // Manual cleanup
super.dispose();
}

@override
Widget build(BuildContext context) {
return BlocProvider.value(
value: _bloc,
child: MyContent(),
);
}
}
```

### Preventing Unnecessary Rebuilds

```dart
// Use buildWhen to optimize
BlocBuilder<MyBloc, MyState>
(
buildWhen: (previous, current) {
// Only rebuild if specific field changed
return previous.importantField != current.importantField;
},
builder: (context, state) => ExpensiveWidget(state),
)

// Use BlocSelector for field-specific rebuilds
BlocSelector<MyBloc, MyState, String>(
selector: (state) => state.specificField,
builder: (context, field)
=>
Text
(
field
)
,
)
```

## BlocObserver for Debugging

```dart
class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    print('${bloc.runtimeType} $change');
  }

  @override
  void onTransition(Bloc bloc, Transition transition) {
    super.onTransition(bloc, transition);
    print('${bloc.runtimeType} $transition');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    print('${bloc.runtimeType} $error $stackTrace');
    super.onError(bloc, error, stackTrace);
  }
}

void main() {
  Bloc.observer = AppBlocObserver();
  runApp(MyApp());
}
```

## Quick Decision Guide

### Choose Cubit when:

- Simple state management needs
- Direct method calls suffice
- No need for event tracking
- Learning bloc pattern
- Rapid prototyping

### Choose Bloc when:

- Complex state transitions
- Need event tracking/replay
- Multiple event sources
- Event transformations needed
- Better debugging required

## Provider Package Integration

flutter_bloc uses provider package internally. Understanding this helps with:

### Null-Safe Provider Access

```dart
// Check if provider exists without crashing
final bloc = context.watch<MyBloc?>(); // Returns null if not found
if (
bloc != null) {
// Use bloc
}

// vs standard (throws if not found)
final bloc = context.watch<MyBloc>(); // Throws ProviderNotFoundException
```

### Custom Provider Extensions

```dart
// flutter_bloc exports these from provider
extension ReadContext on BuildContext {
  T read<T>() => Provider.of<T>(this, listen: false);
}

extension WatchContext on BuildContext {
  T watch<T>() => Provider.of<T>(this);
}

extension SelectContext on BuildContext {
  R select<T, R>(R Function(T) selector) =>
      Provider.of<T>(this).select(selector);
}
```

## Essential Testing Patterns

```dart
import 'package:bloc_test/bloc_test.dart';

// Test Cubit
blocTest<CounterCubit, int>
('emits [1] when increment is called
'
,build: () => CounterCubit(),
act: (cubit) => cubit.increment(),
expect: () => [1],
);

// Test Bloc with events
blocTest<CounterBloc, int>(
'emits [1] when Increment is added',
build: () => CounterBloc(),
act: (bloc) => bloc.add(Increment()),
expect: () => [1],
);

// Test with mock dependencies
class MockRepository extends Mock implements Repository {}

blocTest<MyBloc, MyState>(
'emits [Loading, Success] when data is fetched',
build: () {
final repository = MockRepository();
when(() => repository.getData()).thenAnswer((_) async => 'data');
return MyBloc(repository);
},
act: (bloc) => bloc.add(FetchData()),
expect: () => [Loading(), Success('data'
)
]
,
);
```

## Migration Path

Start with Cubit for simpler features, migrate to Bloc when complexity demands it. Both are
interoperable and use the same widget ecosystem.

## Key Takeaways

1. **Context is Everything**: Most errors come from using wrong BuildContext
2. **Provider Scope**: Providers only work below where they're created in the tree
3. **Route Boundaries**: Navigation creates new context trees - plan accordingly
4. **Async Safety**: Always handle context validity after async operations
5. **Read vs Watch**: Use read for events, watch for builds
6. **Builder Pattern**: Your friend for context issues
7. **Test Everything**: Especially context-dependent code