part of 'generated.dart';

class CreateFollowVariablesBuilder {
  String followerId;
  String followingId;
  Timestamp createdAt;

  final FirebaseDataConnect _dataConnect;
  CreateFollowVariablesBuilder(this._dataConnect, {required  this.followerId,required  this.followingId,required  this.createdAt,});
  Deserializer<CreateFollowData> dataDeserializer = (dynamic json)  => CreateFollowData.fromJson(jsonDecode(json));
  Serializer<CreateFollowVariables> varsSerializer = (CreateFollowVariables vars) => jsonEncode(vars.toJson());
  Future<OperationResult<CreateFollowData, CreateFollowVariables>> execute() {
    return ref().execute();
  }

  MutationRef<CreateFollowData, CreateFollowVariables> ref() {
    CreateFollowVariables vars= CreateFollowVariables(followerId: followerId,followingId: followingId,createdAt: createdAt,);
    return _dataConnect.mutation("CreateFollow", dataDeserializer, varsSerializer, vars);
  }
}

@immutable
class CreateFollowFollowInsert {
  final String followerId;
  final String followingId;
  CreateFollowFollowInsert.fromJson(dynamic json):
  
  followerId = nativeFromJson<String>(json['followerId']),
  followingId = nativeFromJson<String>(json['followingId']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateFollowFollowInsert otherTyped = other as CreateFollowFollowInsert;
    return followerId == otherTyped.followerId && 
    followingId == otherTyped.followingId;
    
  }
  @override
  int get hashCode => Object.hashAll([followerId.hashCode, followingId.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['followerId'] = nativeToJson<String>(followerId);
    json['followingId'] = nativeToJson<String>(followingId);
    return json;
  }

  CreateFollowFollowInsert({
    required this.followerId,
    required this.followingId,
  });
}

@immutable
class CreateFollowData {
  final CreateFollowFollowInsert follow_insert;
  CreateFollowData.fromJson(dynamic json):
  
  follow_insert = CreateFollowFollowInsert.fromJson(json['follow_insert']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateFollowData otherTyped = other as CreateFollowData;
    return follow_insert == otherTyped.follow_insert;
    
  }
  @override
  int get hashCode => follow_insert.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['follow_insert'] = follow_insert.toJson();
    return json;
  }

  CreateFollowData({
    required this.follow_insert,
  });
}

@immutable
class CreateFollowVariables {
  final String followerId;
  final String followingId;
  final Timestamp createdAt;
  @Deprecated('fromJson is deprecated for Variable classes as they are no longer required for deserialization.')
  CreateFollowVariables.fromJson(Map<String, dynamic> json):
  
  followerId = nativeFromJson<String>(json['followerId']),
  followingId = nativeFromJson<String>(json['followingId']),
  createdAt = Timestamp.fromJson(json['createdAt']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final CreateFollowVariables otherTyped = other as CreateFollowVariables;
    return followerId == otherTyped.followerId && 
    followingId == otherTyped.followingId && 
    createdAt == otherTyped.createdAt;
    
  }
  @override
  int get hashCode => Object.hashAll([followerId.hashCode, followingId.hashCode, createdAt.hashCode]);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['followerId'] = nativeToJson<String>(followerId);
    json['followingId'] = nativeToJson<String>(followingId);
    json['createdAt'] = createdAt.toJson();
    return json;
  }

  CreateFollowVariables({
    required this.followerId,
    required this.followingId,
    required this.createdAt,
  });
}

