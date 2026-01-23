# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListYs
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listYs().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListYsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listYs();
ListYsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listYs().ref();
ref.execute();

ref.subscribe(...);
```


### GetUser
#### Required Arguments
```dart
String id = ...;
ExampleConnector.instance.getUser(
  id: id,
).execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetUserData, GetUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getUser(
  id: id,
);
GetUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String id = ...;

final ref = ExampleConnector.instance.getUser(
  id: id,
).ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### CreateY
#### Required Arguments
```dart
String content = ...;
String authorId = ...;
Timestamp createdAt = ...;
ExampleConnector.instance.createY(
  content: content,
  authorId: authorId,
  createdAt: createdAt,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateYData, CreateYVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createY(
  content: content,
  authorId: authorId,
  createdAt: createdAt,
);
CreateYData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String content = ...;
String authorId = ...;
Timestamp createdAt = ...;

final ref = ExampleConnector.instance.createY(
  content: content,
  authorId: authorId,
  createdAt: createdAt,
).ref();
ref.execute();
```


### CreateFollow
#### Required Arguments
```dart
String followerId = ...;
String followingId = ...;
Timestamp createdAt = ...;
ExampleConnector.instance.createFollow(
  followerId: followerId,
  followingId: followingId,
  createdAt: createdAt,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateFollowData, CreateFollowVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createFollow(
  followerId: followerId,
  followingId: followingId,
  createdAt: createdAt,
);
CreateFollowData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String followerId = ...;
String followingId = ...;
Timestamp createdAt = ...;

final ref = ExampleConnector.instance.createFollow(
  followerId: followerId,
  followingId: followingId,
  createdAt: createdAt,
).ref();
ref.execute();
```

