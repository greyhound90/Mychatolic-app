part of 'generated.dart';

class CreateYVariablesBuilder {
  String content;
  String authorId;
  Timestamp createdAt;

  final FirebaseDataConnect _dataConnect;
  CreateYVariablesBuilder(this._dataConnect, {required  this.content,required  this.authorId,required  this.createdAt,});
  Deserializer<CreateYData> dataDeserializer = (dynamic json)  => CreateYData.fromJson(jsonDecode(json));
  Serializer<CreateYVariables> varsSerializer = (CreateYVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateYData, CreateYVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateYData, CreateYVariables> ref() {
    CreateYVariables vars= CreateYVariables(content: content,authorId: authorId,createdAt: createdAt,);
    return _dataConnect.mutation("CreateY", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateYYInsert {
  final String id;
  CreateYYInsert.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateYYInsert otherTyped = other as CreateYYInsert;
    return id == otherTyped.id;
    
  }
  @override
  int get hashCode => id.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    return json;
  }

  CreateYYInsert({
    required this.id,
  });
}

@immutable
class CreateYData {
  final CreateYYInsert y_insert;
  CreateYData.fromJson(dynamic json):
  
  y_insert = CreateYYInsert.fromJson(json['y_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateYData otherTyped = other as CreateYData;
    return y_insert == otherTyped.y_insert;
    
  }
  @override
  int get hashCode => y_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['y_insert'] = y_insert.toJson();
    return json;
  }

  CreateYData({
    required this.y_insert,
  });
}

@immutable
class CreateYVariables {
  final String content;
  final String authorId;
  final Timestamp createdAt;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateYVariables.fromJson(Map<String, dynamic> json):
  
  content = nativeFromJson<String>(json['content']),
  authorId = nativeFromJson<String>(json['authorId']),
  createdAt = Timestamp.fromJson(json['createdAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateYVariables otherTyped = other as CreateYVariables;
    return content == otherTyped.content && 
    authorId == otherTyped.authorId && 
    createdAt == otherTyped.createdAt;
    
  }
  @override
  int get hashCode => Object.hashAll([content.hashCode, authorId.hashCode, createdAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['content'] = nativeToJson<String>(content);
    json['authorId'] = nativeToJson<String>(authorId);
    json['createdAt'] = createdAt.toJson();
    return json;
  }

  CreateYVariables({
    required this.content,
    required this.authorId,
    required this.createdAt,
  });
}

