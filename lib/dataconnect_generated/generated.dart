library dataconnect_generated;

import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_y.dart';

part 'list_ys.dart';

part 'create_follow.dart';

part 'get_user.dart';

class ExampleConnector {
  CreateYVariablesBuilder createY({
    required String content,
    required String authorId,
    required Timestamp createdAt,
  }) {
    return CreateYVariablesBuilder(
      dataConnect,
      content: content,
      authorId: authorId,
      createdAt: createdAt,
    );
  }

  ListYsVariablesBuilder listYs() {
    return ListYsVariablesBuilder(dataConnect);
  }

  CreateFollowVariablesBuilder createFollow({
    required String followerId,
    required String followingId,
    required Timestamp createdAt,
  }) {
    return CreateFollowVariablesBuilder(
      dataConnect,
      followerId: followerId,
      followingId: followingId,
      createdAt: createdAt,
    );
  }

  GetUserVariablesBuilder getUser({required String id}) {
    return GetUserVariablesBuilder(dataConnect, id: id);
  }

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-east4',
    'example',
    'mychatolicapp',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
      dataConnect: FirebaseDataConnect.instanceFor(
        connectorConfig: connectorConfig,
        sdkType: CallerSDKType.generated,
      ),
    );
  }

  FirebaseDataConnect dataConnect;
}
