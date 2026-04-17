import 'package:drift/drift.dart';

@DataClassName('AiConversationRow')
class AiConversations extends Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get context => text().nullable()();
  TextColumn get messages => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}
