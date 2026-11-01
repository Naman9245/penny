// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TxnsTable extends Txns with TableInfo<$TxnsTable, Txn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
    check: () => ComparableExpr(amountPaise).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxnType, String> type =
      GeneratedColumn<String>(
        'type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxnType>($TxnsTable.$convertertype);
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _merchantMeta = const VerificationMeta(
    'merchant',
  );
  @override
  late final GeneratedColumn<String> merchant = GeneratedColumn<String>(
    'merchant',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxnSource, String> source =
      GeneratedColumn<String>(
        'source',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxnSource>($TxnsTable.$convertersource);
  @override
  late final GeneratedColumnWithTypeConverter<TxnTag?, String> tag =
      GeneratedColumn<String>(
        'tag',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      ).withConverter<TxnTag?>($TxnsTable.$convertertagn);
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    amountPaise,
    type,
    categoryId,
    merchant,
    occurredAt,
    source,
    tag,
    createdAt,
    updatedAt,
    deletedAt,
    dedupeKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'txns';
  @override
  VerificationContext validateIntegrity(
    Insertable<Txn> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('amount_paise')) {
      context.handle(
        _amountPaiseMeta,
        amountPaise.isAcceptableOrUnknown(
          data['amount_paise']!,
          _amountPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_amountPaiseMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('merchant')) {
      context.handle(
        _merchantMeta,
        merchant.isAcceptableOrUnknown(data['merchant']!, _merchantMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Txn map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Txn(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      type: $TxnsTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      )!,
      merchant: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}merchant'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      source: $TxnsTable.$convertersource.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}source'],
        )!,
      ),
      tag: $TxnsTable.$convertertagn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tag'],
        ),
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      ),
    );
  }

  @override
  $TxnsTable createAlias(String alias) {
    return $TxnsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxnType, String, String> $convertertype =
      const EnumNameConverter<TxnType>(TxnType.values);
  static JsonTypeConverter2<TxnSource, String, String> $convertersource =
      const EnumNameConverter<TxnSource>(TxnSource.values);
  static JsonTypeConverter2<TxnTag, String, String> $convertertag =
      const EnumNameConverter<TxnTag>(TxnTag.values);
  static JsonTypeConverter2<TxnTag?, String?, String?> $convertertagn =
      JsonTypeConverter2.asNullable($convertertag);
}

class Txn extends DataClass implements Insertable<Txn> {
  final String id;
  final int amountPaise;
  final TxnType type;
  final String categoryId;
  final String? merchant;
  final DateTime occurredAt;
  final TxnSource source;
  final TxnTag? tag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Fingerprint of the SMS this entry came from, if any. Stays on the
  /// phone: sync must never upload it.
  final String? dedupeKey;
  const Txn({
    required this.id,
    required this.amountPaise,
    required this.type,
    required this.categoryId,
    this.merchant,
    required this.occurredAt,
    required this.source,
    this.tag,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.dedupeKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['amount_paise'] = Variable<int>(amountPaise);
    {
      map['type'] = Variable<String>($TxnsTable.$convertertype.toSql(type));
    }
    map['category_id'] = Variable<String>(categoryId);
    if (!nullToAbsent || merchant != null) {
      map['merchant'] = Variable<String>(merchant);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    {
      map['source'] = Variable<String>(
        $TxnsTable.$convertersource.toSql(source),
      );
    }
    if (!nullToAbsent || tag != null) {
      map['tag'] = Variable<String>($TxnsTable.$convertertagn.toSql(tag));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    if (!nullToAbsent || dedupeKey != null) {
      map['dedupe_key'] = Variable<String>(dedupeKey);
    }
    return map;
  }

  TxnsCompanion toCompanion(bool nullToAbsent) {
    return TxnsCompanion(
      id: Value(id),
      amountPaise: Value(amountPaise),
      type: Value(type),
      categoryId: Value(categoryId),
      merchant: merchant == null && nullToAbsent
          ? const Value.absent()
          : Value(merchant),
      occurredAt: Value(occurredAt),
      source: Value(source),
      tag: tag == null && nullToAbsent ? const Value.absent() : Value(tag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      dedupeKey: dedupeKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dedupeKey),
    );
  }

  factory Txn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Txn(
      id: serializer.fromJson<String>(json['id']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      type: $TxnsTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      categoryId: serializer.fromJson<String>(json['categoryId']),
      merchant: serializer.fromJson<String?>(json['merchant']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      source: $TxnsTable.$convertersource.fromJson(
        serializer.fromJson<String>(json['source']),
      ),
      tag: $TxnsTable.$convertertagn.fromJson(
        serializer.fromJson<String?>(json['tag']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      dedupeKey: serializer.fromJson<String?>(json['dedupeKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'type': serializer.toJson<String>($TxnsTable.$convertertype.toJson(type)),
      'categoryId': serializer.toJson<String>(categoryId),
      'merchant': serializer.toJson<String?>(merchant),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'source': serializer.toJson<String>(
        $TxnsTable.$convertersource.toJson(source),
      ),
      'tag': serializer.toJson<String?>($TxnsTable.$convertertagn.toJson(tag)),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'dedupeKey': serializer.toJson<String?>(dedupeKey),
    };
  }

  Txn copyWith({
    String? id,
    int? amountPaise,
    TxnType? type,
    String? categoryId,
    Value<String?> merchant = const Value.absent(),
    DateTime? occurredAt,
    TxnSource? source,
    Value<TxnTag?> tag = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    Value<String?> dedupeKey = const Value.absent(),
  }) => Txn(
    id: id ?? this.id,
    amountPaise: amountPaise ?? this.amountPaise,
    type: type ?? this.type,
    categoryId: categoryId ?? this.categoryId,
    merchant: merchant.present ? merchant.value : this.merchant,
    occurredAt: occurredAt ?? this.occurredAt,
    source: source ?? this.source,
    tag: tag.present ? tag.value : this.tag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    dedupeKey: dedupeKey.present ? dedupeKey.value : this.dedupeKey,
  );
  Txn copyWithCompanion(TxnsCompanion data) {
    return Txn(
      id: data.id.present ? data.id.value : this.id,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      type: data.type.present ? data.type.value : this.type,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      merchant: data.merchant.present ? data.merchant.value : this.merchant,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      source: data.source.present ? data.source.value : this.source,
      tag: data.tag.present ? data.tag.value : this.tag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Txn(')
          ..write('id: $id, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('tag: $tag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dedupeKey: $dedupeKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    amountPaise,
    type,
    categoryId,
    merchant,
    occurredAt,
    source,
    tag,
    createdAt,
    updatedAt,
    deletedAt,
    dedupeKey,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Txn &&
          other.id == this.id &&
          other.amountPaise == this.amountPaise &&
          other.type == this.type &&
          other.categoryId == this.categoryId &&
          other.merchant == this.merchant &&
          other.occurredAt == this.occurredAt &&
          other.source == this.source &&
          other.tag == this.tag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.dedupeKey == this.dedupeKey);
}

class TxnsCompanion extends UpdateCompanion<Txn> {
  final Value<String> id;
  final Value<int> amountPaise;
  final Value<TxnType> type;
  final Value<String> categoryId;
  final Value<String?> merchant;
  final Value<DateTime> occurredAt;
  final Value<TxnSource> source;
  final Value<TxnTag?> tag;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<String?> dedupeKey;
  final Value<int> rowid;
  const TxnsCompanion({
    this.id = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.type = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.merchant = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.source = const Value.absent(),
    this.tag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TxnsCompanion.insert({
    required String id,
    required int amountPaise,
    required TxnType type,
    required String categoryId,
    this.merchant = const Value.absent(),
    required DateTime occurredAt,
    required TxnSource source,
    this.tag = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       amountPaise = Value(amountPaise),
       type = Value(type),
       categoryId = Value(categoryId),
       occurredAt = Value(occurredAt),
       source = Value(source),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Txn> custom({
    Expression<String>? id,
    Expression<int>? amountPaise,
    Expression<String>? type,
    Expression<String>? categoryId,
    Expression<String>? merchant,
    Expression<DateTime>? occurredAt,
    Expression<String>? source,
    Expression<String>? tag,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<String>? dedupeKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (type != null) 'type': type,
      if (categoryId != null) 'category_id': categoryId,
      if (merchant != null) 'merchant': merchant,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (source != null) 'source': source,
      if (tag != null) 'tag': tag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TxnsCompanion copyWith({
    Value<String>? id,
    Value<int>? amountPaise,
    Value<TxnType>? type,
    Value<String>? categoryId,
    Value<String?>? merchant,
    Value<DateTime>? occurredAt,
    Value<TxnSource>? source,
    Value<TxnTag?>? tag,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<String?>? dedupeKey,
    Value<int>? rowid,
  }) {
    return TxnsCompanion(
      id: id ?? this.id,
      amountPaise: amountPaise ?? this.amountPaise,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      merchant: merchant ?? this.merchant,
      occurredAt: occurredAt ?? this.occurredAt,
      source: source ?? this.source,
      tag: tag ?? this.tag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $TxnsTable.$convertertype.toSql(type.value),
      );
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (merchant.present) {
      map['merchant'] = Variable<String>(merchant.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(
        $TxnsTable.$convertersource.toSql(source.value),
      );
    }
    if (tag.present) {
      map['tag'] = Variable<String>($TxnsTable.$convertertagn.toSql(tag.value));
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TxnsCompanion(')
          ..write('id: $id, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('type: $type, ')
          ..write('categoryId: $categoryId, ')
          ..write('merchant: $merchant, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('source: $source, ')
          ..write('tag: $tag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TxnsTable txns = $TxnsTable(this);
  late final Index txnsOccurredAt = Index(
    'txns_occurred_at',
    'CREATE INDEX txns_occurred_at ON txns (occurred_at)',
  );
  late final Index txnsDedupeKey = Index(
    'txns_dedupe_key',
    'CREATE UNIQUE INDEX txns_dedupe_key ON txns (dedupe_key) WHERE deleted_at IS NULL',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    txns,
    txnsOccurredAt,
    txnsDedupeKey,
  ];
}

typedef $$TxnsTableCreateCompanionBuilder = TxnsCompanion Function({
  required String id,
  required int amountPaise,
  required TxnType type,
  required String categoryId,
  Value<String?> merchant,
  required DateTime occurredAt,
  required TxnSource source,
  Value<TxnTag?> tag,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> dedupeKey,
  Value<int> rowid,
});
typedef $$TxnsTableUpdateCompanionBuilder = TxnsCompanion Function({
  Value<String> id,
  Value<int> amountPaise,
  Value<TxnType> type,
  Value<String> categoryId,
  Value<String?> merchant,
  Value<DateTime> occurredAt,
  Value<TxnSource> source,
  Value<TxnTag?> tag,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<String?> dedupeKey,
  Value<int> rowid,
});

class $$TxnsTableFilterComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxnType, TxnType, String> get type =>
      $composableBuilder(
        column: $table.type,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxnSource, TxnSource, String> get source =>
      $composableBuilder(
        column: $table.source,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnWithTypeConverterFilters<TxnTag?, TxnTag, String> get tag =>
      $composableBuilder(
        column: $table.tag,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TxnsTableOrderingComposer extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get merchant => $composableBuilder(
    column: $table.merchant,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TxnsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TxnsTable> {
  $$TxnsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TxnType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get merchant =>
      $composableBuilder(column: $table.merchant, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TxnSource, String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxnTag?, String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);
}

class $$TxnsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TxnsTable,
          Txn,
          $$TxnsTableFilterComposer,
          $$TxnsTableOrderingComposer,
          $$TxnsTableAnnotationComposer,
          $$TxnsTableCreateCompanionBuilder,
          $$TxnsTableUpdateCompanionBuilder,
          (Txn, BaseReferences<_$AppDatabase, $TxnsTable, Txn>),
          Txn,
          PrefetchHooks Function()
        > {
  $$TxnsTableTableManager(_$AppDatabase db, $TxnsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TxnsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TxnsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TxnsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<TxnType> type = const Value.absent(),
                Value<String> categoryId = const Value.absent(),
                Value<String?> merchant = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<TxnSource> source = const Value.absent(),
                Value<TxnTag?> tag = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TxnsCompanion(
                id: id,
                amountPaise: amountPaise,
                type: type,
                categoryId: categoryId,
                merchant: merchant,
                occurredAt: occurredAt,
                source: source,
                tag: tag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dedupeKey: dedupeKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int amountPaise,
                required TxnType type,
                required String categoryId,
                Value<String?> merchant = const Value.absent(),
                required DateTime occurredAt,
                required TxnSource source,
                Value<TxnTag?> tag = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<String?> dedupeKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TxnsCompanion.insert(
                id: id,
                amountPaise: amountPaise,
                type: type,
                categoryId: categoryId,
                merchant: merchant,
                occurredAt: occurredAt,
                source: source,
                tag: tag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                dedupeKey: dedupeKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TxnsTable, Txn>(table),
                  BaseReferences<_$AppDatabase, $TxnsTable, Txn>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TxnsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TxnsTable,
      Txn,
      $$TxnsTableFilterComposer,
      $$TxnsTableOrderingComposer,
      $$TxnsTableAnnotationComposer,
      $$TxnsTableCreateCompanionBuilder,
      $$TxnsTableUpdateCompanionBuilder,
      (Txn, BaseReferences<_$AppDatabase, $TxnsTable, Txn>),
      Txn,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TxnsTableTableManager get txns => $$TxnsTableTableManager(_db, _db.txns);
}
