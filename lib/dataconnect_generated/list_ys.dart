part of 'generated.dart';

class ListYsVariablesBuilder {
  final FirebaseDataConnect _dataConnect;
  ListYsVariablesBuilder(this._dataConnect);
  Deserializer<ListYsData> dataDeserializer = (dynamic json) =>
      ListYsData.fromJson(jsonDecode(json));

  Future<QueryResult<ListYsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListYsData, void> ref() {
    return _dataConnect.query(
      "ListYs",
      dataDeserializer,
      emptySerializer,
      null,
    );
  }
}

@immutable
class ListYsYs {
  final String id;
  final String content;
  final ListYsYsAuthor author;
  ListYsYs.fromJson(dynamic json)
    : id = nativeFromJson<String>(json['id']),
      content = nativeFromJson<String>(json['content']),
      author = ListYsYsAuthor.fromJson(json['author']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ListYsYs otherTyped = other as ListYsYs;
    return id == otherTyped.id &&
        content == otherTyped.content &&
        author == otherTyped.author;
  }

  @override
  int get hashCode =>
      Object.hashAll([id.hashCode, content.hashCode, author.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['content'] = nativeToJson<String>(content);
    json['author'] = author.toJson();
    return json;
  }

  ListYsYs({required this.id, required this.content, required this.author});
}

@immutable
class ListYsYsAuthor {
  final String id;
  final String username;
  ListYsYsAuthor.fromJson(dynamic json)
    : id = nativeFromJson<String>(json['id']),
      username = nativeFromJson<String>(json['username']);
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ListYsYsAuthor otherTyped = other as ListYsYsAuthor;
    return id == otherTyped.id && username == otherTyped.username;
  }

  @override
  int get hashCode => Object.hashAll([id.hashCode, username.hashCode]);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['username'] = nativeToJson<String>(username);
    return json;
  }

  ListYsYsAuthor({required this.id, required this.username});
}

@immutable
class ListYsData {
  final List<ListYsYs> ys;
  ListYsData.fromJson(dynamic json)
    : ys = (json['ys'] as List<dynamic>)
          .map((e) => ListYsYs.fromJson(e))
          .toList();
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }

    final ListYsData otherTyped = other as ListYsData;
    return ys == otherTyped.ys;
  }

  @override
  int get hashCode => ys.hashCode;

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['ys'] = ys.map((e) => e.toJson()).toList();
    return json;
  }

  ListYsData({required this.ys});
}
