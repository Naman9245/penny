// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TxnsTable extends Txns with TableInfo<$TxnsTable, Txn> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TxnsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
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
  static const VerificationMeta _payeeIsPersonMeta = const VerificationMeta(
    'payeeIsPerson',
  );
  @override
  late final GeneratedColumn<bool> payeeIsPerson = GeneratedColumn<bool>(
    'payee_is_person',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("payee_is_person" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    dirty,
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
    payeeIsPerson,
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
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
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
    if (data.containsKey('payee_is_person')) {
      context.handle(
        _payeeIsPersonMeta,
        payeeIsPerson.isAcceptableOrUnknown(
          data['payee_is_person']!,
          _payeeIsPersonMeta,
        ),
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
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
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
      payeeIsPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}payee_is_person'],
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
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String id;
  final int amountPaise;
  final TxnType type;
  final String categoryId;
  final String? merchant;
  final DateTime occurredAt;
  final TxnSource source;

  /// The user's own call on a spend: necessary or wasteful. Penny's picks
  /// live in the month's insight, so a new report never overwrites this.
  final TxnTag? tag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  /// Fingerprint of the SMS this entry came from, if any. Stays on the
  /// phone: sync must never upload it.
  final String? dedupeKey;

  /// Whether the SMS showed the payee is a person rather than a shop. Null
  /// for typed entries and older imports, where Penny can only guess.
  /// People's names never reach the AI either way.
  final bool? payeeIsPerson;
  const Txn({
    required this.dirty,
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
    this.payeeIsPerson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
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
    if (!nullToAbsent || payeeIsPerson != null) {
      map['payee_is_person'] = Variable<bool>(payeeIsPerson);
    }
    return map;
  }

  TxnsCompanion toCompanion(bool nullToAbsent) {
    return TxnsCompanion(
      dirty: Value(dirty),
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
      payeeIsPerson: payeeIsPerson == null && nullToAbsent
          ? const Value.absent()
          : Value(payeeIsPerson),
    );
  }

  factory Txn.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Txn(
      dirty: serializer.fromJson<bool>(json['dirty']),
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
      payeeIsPerson: serializer.fromJson<bool?>(json['payeeIsPerson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
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
      'payeeIsPerson': serializer.toJson<bool?>(payeeIsPerson),
    };
  }

  Txn copyWith({
    bool? dirty,
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
    Value<bool?> payeeIsPerson = const Value.absent(),
  }) => Txn(
    dirty: dirty ?? this.dirty,
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
    payeeIsPerson: payeeIsPerson.present
        ? payeeIsPerson.value
        : this.payeeIsPerson,
  );
  Txn copyWithCompanion(TxnsCompanion data) {
    return Txn(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
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
      payeeIsPerson: data.payeeIsPerson.present
          ? data.payeeIsPerson.value
          : this.payeeIsPerson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Txn(')
          ..write('dirty: $dirty, ')
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
          ..write('payeeIsPerson: $payeeIsPerson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dirty,
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
    payeeIsPerson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Txn &&
          other.dirty == this.dirty &&
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
          other.dedupeKey == this.dedupeKey &&
          other.payeeIsPerson == this.payeeIsPerson);
}

class TxnsCompanion extends UpdateCompanion<Txn> {
  final Value<bool> dirty;
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
  final Value<bool?> payeeIsPerson;
  final Value<int> rowid;
  const TxnsCompanion({
    this.dirty = const Value.absent(),
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
    this.payeeIsPerson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TxnsCompanion.insert({
    this.dirty = const Value.absent(),
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
    this.payeeIsPerson = const Value.absent(),
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
    Expression<bool>? dirty,
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
    Expression<bool>? payeeIsPerson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
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
      if (payeeIsPerson != null) 'payee_is_person': payeeIsPerson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TxnsCompanion copyWith({
    Value<bool>? dirty,
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
    Value<bool?>? payeeIsPerson,
    Value<int>? rowid,
  }) {
    return TxnsCompanion(
      dirty: dirty ?? this.dirty,
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
      payeeIsPerson: payeeIsPerson ?? this.payeeIsPerson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
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
    if (payeeIsPerson.present) {
      map['payee_is_person'] = Variable<bool>(payeeIsPerson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TxnsCompanion(')
          ..write('dirty: $dirty, ')
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
          ..write('payeeIsPerson: $payeeIsPerson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, BudgetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _budgetKeyMeta = const VerificationMeta(
    'budgetKey',
  );
  @override
  late final GeneratedColumn<String> budgetKey = GeneratedColumn<String>(
    'budget_key',
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
  @override
  List<GeneratedColumn> get $columns => [
    dirty,
    id,
    budgetKey,
    amountPaise,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BudgetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('budget_key')) {
      context.handle(
        _budgetKeyMeta,
        budgetKey.isAcceptableOrUnknown(data['budget_key']!, _budgetKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_budgetKeyMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BudgetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BudgetRow(
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      budgetKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}budget_key'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
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
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class BudgetRow extends DataClass implements Insertable<BudgetRow> {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String id;

  /// "everyday", or a spend category's id.
  final String budgetKey;
  final int amountPaise;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const BudgetRow({
    required this.dirty,
    required this.id,
    required this.budgetKey,
    required this.amountPaise,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['budget_key'] = Variable<String>(budgetKey);
    map['amount_paise'] = Variable<int>(amountPaise);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      dirty: Value(dirty),
      id: Value(id),
      budgetKey: Value(budgetKey),
      amountPaise: Value(amountPaise),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory BudgetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BudgetRow(
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      budgetKey: serializer.fromJson<String>(json['budgetKey']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'budgetKey': serializer.toJson<String>(budgetKey),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  BudgetRow copyWith({
    bool? dirty,
    String? id,
    String? budgetKey,
    int? amountPaise,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => BudgetRow(
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    budgetKey: budgetKey ?? this.budgetKey,
    amountPaise: amountPaise ?? this.amountPaise,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  BudgetRow copyWithCompanion(BudgetsCompanion data) {
    return BudgetRow(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      budgetKey: data.budgetKey.present ? data.budgetKey.value : this.budgetKey,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BudgetRow(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('budgetKey: $budgetKey, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dirty,
    id,
    budgetKey,
    amountPaise,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BudgetRow &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.budgetKey == this.budgetKey &&
          other.amountPaise == this.amountPaise &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class BudgetsCompanion extends UpdateCompanion<BudgetRow> {
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> budgetKey;
  final Value<int> amountPaise;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const BudgetsCompanion({
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.budgetKey = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.dirty = const Value.absent(),
    required String id,
    required String budgetKey,
    required int amountPaise,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       budgetKey = Value(budgetKey),
       amountPaise = Value(amountPaise),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<BudgetRow> custom({
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? budgetKey,
    Expression<int>? amountPaise,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (budgetKey != null) 'budget_key': budgetKey,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BudgetsCompanion copyWith({
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? budgetKey,
    Value<int>? amountPaise,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return BudgetsCompanion(
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      budgetKey: budgetKey ?? this.budgetKey,
      amountPaise: amountPaise ?? this.amountPaise,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (budgetKey.present) {
      map['budget_key'] = Variable<String>(budgetKey.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('budgetKey: $budgetKey, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetPaiseMeta = const VerificationMeta(
    'targetPaise',
  );
  @override
  late final GeneratedColumn<int> targetPaise = GeneratedColumn<int>(
    'target_paise',
    aliasedName,
    false,
    check: () => ComparableExpr(targetPaise).isBiggerThanValue(0),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deadlineMeta = const VerificationMeta(
    'deadline',
  );
  @override
  late final GeneratedColumn<DateTime> deadline = GeneratedColumn<DateTime>(
    'deadline',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
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
  @override
  List<GeneratedColumn> get $columns => [
    dirty,
    id,
    title,
    targetPaise,
    deadline,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target_paise')) {
      context.handle(
        _targetPaiseMeta,
        targetPaise.isAcceptableOrUnknown(
          data['target_paise']!,
          _targetPaiseMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetPaiseMeta);
    }
    if (data.containsKey('deadline')) {
      context.handle(
        _deadlineMeta,
        deadline.isAcceptableOrUnknown(data['deadline']!, _deadlineMeta),
      );
    } else if (isInserting) {
      context.missing(_deadlineMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      targetPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}target_paise'],
      )!,
      deadline: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deadline'],
      )!,
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
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String id;
  final String title;
  final int targetPaise;

  /// The day it's due, at midnight.
  final DateTime deadline;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Goal({
    required this.dirty,
    required this.id,
    required this.title,
    required this.targetPaise,
    required this.deadline,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['target_paise'] = Variable<int>(targetPaise);
    map['deadline'] = Variable<DateTime>(deadline);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      dirty: Value(dirty),
      id: Value(id),
      title: Value(title),
      targetPaise: Value(targetPaise),
      deadline: Value(deadline),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      targetPaise: serializer.fromJson<int>(json['targetPaise']),
      deadline: serializer.fromJson<DateTime>(json['deadline']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'targetPaise': serializer.toJson<int>(targetPaise),
      'deadline': serializer.toJson<DateTime>(deadline),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Goal copyWith({
    bool? dirty,
    String? id,
    String? title,
    int? targetPaise,
    DateTime? deadline,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => Goal(
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    title: title ?? this.title,
    targetPaise: targetPaise ?? this.targetPaise,
    deadline: deadline ?? this.deadline,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      targetPaise: data.targetPaise.present
          ? data.targetPaise.value
          : this.targetPaise,
      deadline: data.deadline.present ? data.deadline.value : this.deadline,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetPaise: $targetPaise, ')
          ..write('deadline: $deadline, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dirty,
    id,
    title,
    targetPaise,
    deadline,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.title == this.title &&
          other.targetPaise == this.targetPaise &&
          other.deadline == this.deadline &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> title;
  final Value<int> targetPaise;
  final Value<DateTime> deadline;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const GoalsCompanion({
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.targetPaise = const Value.absent(),
    this.deadline = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.dirty = const Value.absent(),
    required String id,
    required String title,
    required int targetPaise,
    required DateTime deadline,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       targetPaise = Value(targetPaise),
       deadline = Value(deadline),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<Goal> custom({
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? title,
    Expression<int>? targetPaise,
    Expression<DateTime>? deadline,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (targetPaise != null) 'target_paise': targetPaise,
      if (deadline != null) 'deadline': deadline,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalsCompanion copyWith({
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? title,
    Value<int>? targetPaise,
    Value<DateTime>? deadline,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return GoalsCompanion(
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      title: title ?? this.title,
      targetPaise: targetPaise ?? this.targetPaise,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (targetPaise.present) {
      map['target_paise'] = Variable<int>(targetPaise.value);
    }
    if (deadline.present) {
      map['deadline'] = Variable<DateTime>(deadline.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetPaise: $targetPaise, ')
          ..write('deadline: $deadline, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalDepositsTable extends GoalDeposits
    with TableInfo<$GoalDepositsTable, GoalDeposit> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalDepositsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
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
    check: () => BooleanExpressionOperators(amountPaise.equals(0)).not(),
    type: DriftSqlType.int,
    requiredDuringInsert: true,
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
  @override
  List<GeneratedColumn> get $columns => [
    dirty,
    id,
    goalId,
    amountPaise,
    occurredAt,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_deposits';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalDeposit> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GoalDeposit map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalDeposit(
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
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
    );
  }

  @override
  $GoalDepositsTable createAlias(String alias) {
    return $GoalDepositsTable(attachedDatabase, alias);
  }
}

class GoalDeposit extends DataClass implements Insertable<GoalDeposit> {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String id;
  final String goalId;
  final int amountPaise;
  final DateTime occurredAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const GoalDeposit({
    required this.dirty,
    required this.id,
    required this.goalId,
    required this.amountPaise,
    required this.occurredAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    map['goal_id'] = Variable<String>(goalId);
    map['amount_paise'] = Variable<int>(amountPaise);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  GoalDepositsCompanion toCompanion(bool nullToAbsent) {
    return GoalDepositsCompanion(
      dirty: Value(dirty),
      id: Value(id),
      goalId: Value(goalId),
      amountPaise: Value(amountPaise),
      occurredAt: Value(occurredAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory GoalDeposit.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalDeposit(
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      goalId: serializer.fromJson<String>(json['goalId']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'goalId': serializer.toJson<String>(goalId),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  GoalDeposit copyWith({
    bool? dirty,
    String? id,
    String? goalId,
    int? amountPaise,
    DateTime? occurredAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => GoalDeposit(
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    goalId: goalId ?? this.goalId,
    amountPaise: amountPaise ?? this.amountPaise,
    occurredAt: occurredAt ?? this.occurredAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  GoalDeposit copyWithCompanion(GoalDepositsCompanion data) {
    return GoalDeposit(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalDeposit(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dirty,
    id,
    goalId,
    amountPaise,
    occurredAt,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalDeposit &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.goalId == this.goalId &&
          other.amountPaise == this.amountPaise &&
          other.occurredAt == this.occurredAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class GoalDepositsCompanion extends UpdateCompanion<GoalDeposit> {
  final Value<bool> dirty;
  final Value<String> id;
  final Value<String> goalId;
  final Value<int> amountPaise;
  final Value<DateTime> occurredAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const GoalDepositsCompanion({
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.goalId = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalDepositsCompanion.insert({
    this.dirty = const Value.absent(),
    required String id,
    required String goalId,
    required int amountPaise,
    required DateTime occurredAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       goalId = Value(goalId),
       amountPaise = Value(amountPaise),
       occurredAt = Value(occurredAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<GoalDeposit> custom({
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? goalId,
    Expression<int>? amountPaise,
    Expression<DateTime>? occurredAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (goalId != null) 'goal_id': goalId,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalDepositsCompanion copyWith({
    Value<bool>? dirty,
    Value<String>? id,
    Value<String>? goalId,
    Value<int>? amountPaise,
    Value<DateTime>? occurredAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return GoalDepositsCompanion(
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      goalId: goalId ?? this.goalId,
      amountPaise: amountPaise ?? this.amountPaise,
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalDepositsCompanion(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('goalId: $goalId, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TagRulesTable extends TagRules with TableInfo<$TagRulesTable, TagRule> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagRulesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<RuleKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<RuleKind>($TagRulesTable.$converterkind);
  static const VerificationMeta _ruleKeyMeta = const VerificationMeta(
    'ruleKey',
  );
  @override
  late final GeneratedColumn<String> ruleKey = GeneratedColumn<String>(
    'rule_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TxnTag, String> tag =
      GeneratedColumn<String>(
        'tag',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TxnTag>($TagRulesTable.$convertertag);
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
  @override
  List<GeneratedColumn> get $columns => [
    dirty,
    id,
    kind,
    ruleKey,
    tag,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tag_rules';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagRule> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('rule_key')) {
      context.handle(
        _ruleKeyMeta,
        ruleKey.isAcceptableOrUnknown(data['rule_key']!, _ruleKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_ruleKeyMeta);
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TagRule map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagRule(
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $TagRulesTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      ruleKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rule_key'],
      )!,
      tag: $TagRulesTable.$convertertag.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}tag'],
        )!,
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
    );
  }

  @override
  $TagRulesTable createAlias(String alias) {
    return $TagRulesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<RuleKind, String, String> $converterkind =
      const EnumNameConverter<RuleKind>(RuleKind.values);
  static JsonTypeConverter2<TxnTag, String, String> $convertertag =
      const EnumNameConverter<TxnTag>(TxnTag.values);
}

class TagRule extends DataClass implements Insertable<TagRule> {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String id;
  final RuleKind kind;

  /// A category id, or a shop name as `shopKey` writes it.
  final String ruleKey;
  final TxnTag tag;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const TagRule({
    required this.dirty,
    required this.id,
    required this.kind,
    required this.ruleKey,
    required this.tag,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>($TagRulesTable.$converterkind.toSql(kind));
    }
    map['rule_key'] = Variable<String>(ruleKey);
    {
      map['tag'] = Variable<String>($TagRulesTable.$convertertag.toSql(tag));
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TagRulesCompanion toCompanion(bool nullToAbsent) {
    return TagRulesCompanion(
      dirty: Value(dirty),
      id: Value(id),
      kind: Value(kind),
      ruleKey: Value(ruleKey),
      tag: Value(tag),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory TagRule.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagRule(
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<String>(json['id']),
      kind: $TagRulesTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      ruleKey: serializer.fromJson<String>(json['ruleKey']),
      tag: $TagRulesTable.$convertertag.fromJson(
        serializer.fromJson<String>(json['tag']),
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $TagRulesTable.$converterkind.toJson(kind),
      ),
      'ruleKey': serializer.toJson<String>(ruleKey),
      'tag': serializer.toJson<String>(
        $TagRulesTable.$convertertag.toJson(tag),
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  TagRule copyWith({
    bool? dirty,
    String? id,
    RuleKind? kind,
    String? ruleKey,
    TxnTag? tag,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => TagRule(
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    kind: kind ?? this.kind,
    ruleKey: ruleKey ?? this.ruleKey,
    tag: tag ?? this.tag,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  TagRule copyWithCompanion(TagRulesCompanion data) {
    return TagRule(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      ruleKey: data.ruleKey.present ? data.ruleKey.value : this.ruleKey,
      tag: data.tag.present ? data.tag.value : this.tag,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagRule(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ruleKey: $ruleKey, ')
          ..write('tag: $tag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dirty,
    id,
    kind,
    ruleKey,
    tag,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagRule &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.ruleKey == this.ruleKey &&
          other.tag == this.tag &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TagRulesCompanion extends UpdateCompanion<TagRule> {
  final Value<bool> dirty;
  final Value<String> id;
  final Value<RuleKind> kind;
  final Value<String> ruleKey;
  final Value<TxnTag> tag;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const TagRulesCompanion({
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.ruleKey = const Value.absent(),
    this.tag = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagRulesCompanion.insert({
    this.dirty = const Value.absent(),
    required String id,
    required RuleKind kind,
    required String ruleKey,
    required TxnTag tag,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       ruleKey = Value(ruleKey),
       tag = Value(tag),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<TagRule> custom({
    Expression<bool>? dirty,
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? ruleKey,
    Expression<String>? tag,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (ruleKey != null) 'rule_key': ruleKey,
      if (tag != null) 'tag': tag,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagRulesCompanion copyWith({
    Value<bool>? dirty,
    Value<String>? id,
    Value<RuleKind>? kind,
    Value<String>? ruleKey,
    Value<TxnTag>? tag,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return TagRulesCompanion(
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      kind: kind ?? this.kind,
      ruleKey: ruleKey ?? this.ruleKey,
      tag: tag ?? this.tag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $TagRulesTable.$converterkind.toSql(kind.value),
      );
    }
    if (ruleKey.present) {
      map['rule_key'] = Variable<String>(ruleKey.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(
        $TagRulesTable.$convertertag.toSql(tag.value),
      );
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
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagRulesCompanion(')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('ruleKey: $ruleKey, ')
          ..write('tag: $tag, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PrefsTable extends Prefs with TableInfo<$PrefsTable, Pref> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrefsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
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
  @override
  List<GeneratedColumn> get $columns => [dirty, name, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prefs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Pref> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {name};
  @override
  Pref map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Pref(
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PrefsTable createAlias(String alias) {
    return $PrefsTable(attachedDatabase, alias);
  }
}

class Pref extends DataClass implements Insertable<Pref> {
  /// Changed on this phone since it was last sent to the account's copy.
  /// New rows are; rows that came from the copy aren't. Every save sets it.
  final bool dirty;
  final String name;
  final String value;
  final DateTime updatedAt;
  const Pref({
    required this.dirty,
    required this.name,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dirty'] = Variable<bool>(dirty);
    map['name'] = Variable<String>(name);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PrefsCompanion toCompanion(bool nullToAbsent) {
    return PrefsCompanion(
      dirty: Value(dirty),
      name: Value(name),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Pref.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Pref(
      dirty: serializer.fromJson<bool>(json['dirty']),
      name: serializer.fromJson<String>(json['name']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dirty': serializer.toJson<bool>(dirty),
      'name': serializer.toJson<String>(name),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Pref copyWith({
    bool? dirty,
    String? name,
    String? value,
    DateTime? updatedAt,
  }) => Pref(
    dirty: dirty ?? this.dirty,
    name: name ?? this.name,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Pref copyWithCompanion(PrefsCompanion data) {
    return Pref(
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      name: data.name.present ? data.name.value : this.name,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Pref(')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dirty, name, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Pref &&
          other.dirty == this.dirty &&
          other.name == this.name &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class PrefsCompanion extends UpdateCompanion<Pref> {
  final Value<bool> dirty;
  final Value<String> name;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PrefsCompanion({
    this.dirty = const Value.absent(),
    this.name = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PrefsCompanion.insert({
    this.dirty = const Value.absent(),
    required String name,
    required String value,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : name = Value(name),
       value = Value(value),
       updatedAt = Value(updatedAt);
  static Insertable<Pref> custom({
    Expression<bool>? dirty,
    Expression<String>? name,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dirty != null) 'dirty': dirty,
      if (name != null) 'name': name,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PrefsCompanion copyWith({
    Value<bool>? dirty,
    Value<String>? name,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PrefsCompanion(
      dirty: dirty ?? this.dirty,
      name: name ?? this.name,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrefsCompanion(')
          ..write('dirty: $dirty, ')
          ..write('name: $name, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InsightsTable extends Insights
    with TableInfo<$InsightsTable, InsightRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InsightsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputHashMeta = const VerificationMeta(
    'inputHash',
  );
  @override
  late final GeneratedColumn<String> inputHash = GeneratedColumn<String>(
    'input_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupKeysMeta = const VerificationMeta(
    'groupKeys',
  );
  @override
  late final GeneratedColumn<String> groupKeys = GeneratedColumn<String>(
    'group_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  @override
  List<GeneratedColumn> get $columns => [
    month,
    inputHash,
    groupKeys,
    answer,
    model,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'insights';
  @override
  VerificationContext validateIntegrity(
    Insertable<InsightRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('input_hash')) {
      context.handle(
        _inputHashMeta,
        inputHash.isAcceptableOrUnknown(data['input_hash']!, _inputHashMeta),
      );
    } else if (isInserting) {
      context.missing(_inputHashMeta);
    }
    if (data.containsKey('group_keys')) {
      context.handle(
        _groupKeysMeta,
        groupKeys.isAcceptableOrUnknown(data['group_keys']!, _groupKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_groupKeysMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {month};
  @override
  InsightRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InsightRow(
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      inputHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_hash'],
      )!,
      groupKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_keys'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $InsightsTable createAlias(String alias) {
    return $InsightsTable(attachedDatabase, alias);
  }
}

class InsightRow extends DataClass implements Insertable<InsightRow> {
  /// The month, as "2026-10".
  final String month;

  /// Fingerprint of the money data that was sent. A different one now means
  /// entries have changed since Penny looked.
  final String inputHash;

  /// JSON object from the group ids Penny saw ("s1", "i1"…) to this phone's
  /// group keys, which turn the answer back into entries.
  final String groupKeys;

  /// The cleaned answer, as JSON.
  final String answer;
  final String model;
  final DateTime createdAt;
  const InsightRow({
    required this.month,
    required this.inputHash,
    required this.groupKeys,
    required this.answer,
    required this.model,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['month'] = Variable<String>(month);
    map['input_hash'] = Variable<String>(inputHash);
    map['group_keys'] = Variable<String>(groupKeys);
    map['answer'] = Variable<String>(answer);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  InsightsCompanion toCompanion(bool nullToAbsent) {
    return InsightsCompanion(
      month: Value(month),
      inputHash: Value(inputHash),
      groupKeys: Value(groupKeys),
      answer: Value(answer),
      model: Value(model),
      createdAt: Value(createdAt),
    );
  }

  factory InsightRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InsightRow(
      month: serializer.fromJson<String>(json['month']),
      inputHash: serializer.fromJson<String>(json['inputHash']),
      groupKeys: serializer.fromJson<String>(json['groupKeys']),
      answer: serializer.fromJson<String>(json['answer']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'month': serializer.toJson<String>(month),
      'inputHash': serializer.toJson<String>(inputHash),
      'groupKeys': serializer.toJson<String>(groupKeys),
      'answer': serializer.toJson<String>(answer),
      'model': serializer.toJson<String>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  InsightRow copyWith({
    String? month,
    String? inputHash,
    String? groupKeys,
    String? answer,
    String? model,
    DateTime? createdAt,
  }) => InsightRow(
    month: month ?? this.month,
    inputHash: inputHash ?? this.inputHash,
    groupKeys: groupKeys ?? this.groupKeys,
    answer: answer ?? this.answer,
    model: model ?? this.model,
    createdAt: createdAt ?? this.createdAt,
  );
  InsightRow copyWithCompanion(InsightsCompanion data) {
    return InsightRow(
      month: data.month.present ? data.month.value : this.month,
      inputHash: data.inputHash.present ? data.inputHash.value : this.inputHash,
      groupKeys: data.groupKeys.present ? data.groupKeys.value : this.groupKeys,
      answer: data.answer.present ? data.answer.value : this.answer,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InsightRow(')
          ..write('month: $month, ')
          ..write('inputHash: $inputHash, ')
          ..write('groupKeys: $groupKeys, ')
          ..write('answer: $answer, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(month, inputHash, groupKeys, answer, model, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsightRow &&
          other.month == this.month &&
          other.inputHash == this.inputHash &&
          other.groupKeys == this.groupKeys &&
          other.answer == this.answer &&
          other.model == this.model &&
          other.createdAt == this.createdAt);
}

class InsightsCompanion extends UpdateCompanion<InsightRow> {
  final Value<String> month;
  final Value<String> inputHash;
  final Value<String> groupKeys;
  final Value<String> answer;
  final Value<String> model;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const InsightsCompanion({
    this.month = const Value.absent(),
    this.inputHash = const Value.absent(),
    this.groupKeys = const Value.absent(),
    this.answer = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InsightsCompanion.insert({
    required String month,
    required String inputHash,
    required String groupKeys,
    required String answer,
    required String model,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : month = Value(month),
       inputHash = Value(inputHash),
       groupKeys = Value(groupKeys),
       answer = Value(answer),
       model = Value(model),
       createdAt = Value(createdAt);
  static Insertable<InsightRow> custom({
    Expression<String>? month,
    Expression<String>? inputHash,
    Expression<String>? groupKeys,
    Expression<String>? answer,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (month != null) 'month': month,
      if (inputHash != null) 'input_hash': inputHash,
      if (groupKeys != null) 'group_keys': groupKeys,
      if (answer != null) 'answer': answer,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InsightsCompanion copyWith({
    Value<String>? month,
    Value<String>? inputHash,
    Value<String>? groupKeys,
    Value<String>? answer,
    Value<String>? model,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return InsightsCompanion(
      month: month ?? this.month,
      inputHash: inputHash ?? this.inputHash,
      groupKeys: groupKeys ?? this.groupKeys,
      answer: answer ?? this.answer,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (inputHash.present) {
      map['input_hash'] = Variable<String>(inputHash.value);
    }
    if (groupKeys.present) {
      map['group_keys'] = Variable<String>(groupKeys.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InsightsCompanion(')
          ..write('month: $month, ')
          ..write('inputHash: $inputHash, ')
          ..write('groupKeys: $groupKeys, ')
          ..write('answer: $answer, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ChatMessagesTable extends ChatMessages
    with TableInfo<$ChatMessagesTable, ChatMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChatMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ChatRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ChatRole>($ChatMessagesTable.$converterrole);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
    'body',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  @override
  List<GeneratedColumn> get $columns => [id, role, body, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'chat_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<ChatMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
        _bodyMeta,
        body.isAcceptableOrUnknown(data['body']!, _bodyMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChatMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChatMessage(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      role: $ChatMessagesTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      body: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ChatMessagesTable createAlias(String alias) {
    return $ChatMessagesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ChatRole, String, String> $converterrole =
      const EnumNameConverter<ChatRole>(ChatRole.values);
}

class ChatMessage extends DataClass implements Insertable<ChatMessage> {
  final String id;
  final ChatRole role;
  final String body;
  final DateTime createdAt;
  const ChatMessage({
    required this.id,
    required this.role,
    required this.body,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['role'] = Variable<String>(
        $ChatMessagesTable.$converterrole.toSql(role),
      );
    }
    map['body'] = Variable<String>(body);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChatMessagesCompanion toCompanion(bool nullToAbsent) {
    return ChatMessagesCompanion(
      id: Value(id),
      role: Value(role),
      body: Value(body),
      createdAt: Value(createdAt),
    );
  }

  factory ChatMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChatMessage(
      id: serializer.fromJson<String>(json['id']),
      role: $ChatMessagesTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      body: serializer.fromJson<String>(json['body']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'role': serializer.toJson<String>(
        $ChatMessagesTable.$converterrole.toJson(role),
      ),
      'body': serializer.toJson<String>(body),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChatMessage copyWith({
    String? id,
    ChatRole? role,
    String? body,
    DateTime? createdAt,
  }) => ChatMessage(
    id: id ?? this.id,
    role: role ?? this.role,
    body: body ?? this.body,
    createdAt: createdAt ?? this.createdAt,
  );
  ChatMessage copyWithCompanion(ChatMessagesCompanion data) {
    return ChatMessage(
      id: data.id.present ? data.id.value : this.id,
      role: data.role.present ? data.role.value : this.role,
      body: data.body.present ? data.body.value : this.body,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessage(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, role, body, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChatMessage &&
          other.id == this.id &&
          other.role == this.role &&
          other.body == this.body &&
          other.createdAt == this.createdAt);
}

class ChatMessagesCompanion extends UpdateCompanion<ChatMessage> {
  final Value<String> id;
  final Value<ChatRole> role;
  final Value<String> body;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChatMessagesCompanion({
    this.id = const Value.absent(),
    this.role = const Value.absent(),
    this.body = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChatMessagesCompanion.insert({
    required String id,
    required ChatRole role,
    required String body,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       role = Value(role),
       body = Value(body),
       createdAt = Value(createdAt);
  static Insertable<ChatMessage> custom({
    Expression<String>? id,
    Expression<String>? role,
    Expression<String>? body,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (role != null) 'role': role,
      if (body != null) 'body': body,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChatMessagesCompanion copyWith({
    Value<String>? id,
    Value<ChatRole>? role,
    Value<String>? body,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return ChatMessagesCompanion(
      id: id ?? this.id,
      role: role ?? this.role,
      body: body ?? this.body,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $ChatMessagesTable.$converterrole.toSql(role.value),
      );
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChatMessagesCompanion(')
          ..write('id: $id, ')
          ..write('role: $role, ')
          ..write('body: $body, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GoalPlansTable extends GoalPlans
    with TableInfo<$GoalPlansTable, GoalPlanRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _goalIdMeta = const VerificationMeta('goalId');
  @override
  late final GeneratedColumn<String> goalId = GeneratedColumn<String>(
    'goal_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monthMeta = const VerificationMeta('month');
  @override
  late final GeneratedColumn<String> month = GeneratedColumn<String>(
    'month',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inputHashMeta = const VerificationMeta(
    'inputHash',
  );
  @override
  late final GeneratedColumn<String> inputHash = GeneratedColumn<String>(
    'input_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupKeysMeta = const VerificationMeta(
    'groupKeys',
  );
  @override
  late final GeneratedColumn<String> groupKeys = GeneratedColumn<String>(
    'group_keys',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerMeta = const VerificationMeta('answer');
  @override
  late final GeneratedColumn<String> answer = GeneratedColumn<String>(
    'answer',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
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
  @override
  List<GeneratedColumn> get $columns => [
    goalId,
    month,
    inputHash,
    groupKeys,
    answer,
    model,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goal_plans';
  @override
  VerificationContext validateIntegrity(
    Insertable<GoalPlanRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('goal_id')) {
      context.handle(
        _goalIdMeta,
        goalId.isAcceptableOrUnknown(data['goal_id']!, _goalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_goalIdMeta);
    }
    if (data.containsKey('month')) {
      context.handle(
        _monthMeta,
        month.isAcceptableOrUnknown(data['month']!, _monthMeta),
      );
    } else if (isInserting) {
      context.missing(_monthMeta);
    }
    if (data.containsKey('input_hash')) {
      context.handle(
        _inputHashMeta,
        inputHash.isAcceptableOrUnknown(data['input_hash']!, _inputHashMeta),
      );
    } else if (isInserting) {
      context.missing(_inputHashMeta);
    }
    if (data.containsKey('group_keys')) {
      context.handle(
        _groupKeysMeta,
        groupKeys.isAcceptableOrUnknown(data['group_keys']!, _groupKeysMeta),
      );
    } else if (isInserting) {
      context.missing(_groupKeysMeta);
    }
    if (data.containsKey('answer')) {
      context.handle(
        _answerMeta,
        answer.isAcceptableOrUnknown(data['answer']!, _answerMeta),
      );
    } else if (isInserting) {
      context.missing(_answerMeta);
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    } else if (isInserting) {
      context.missing(_modelMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {goalId};
  @override
  GoalPlanRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GoalPlanRow(
      goalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}goal_id'],
      )!,
      month: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}month'],
      )!,
      inputHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}input_hash'],
      )!,
      groupKeys: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_keys'],
      )!,
      answer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GoalPlansTable createAlias(String alias) {
    return $GoalPlansTable(attachedDatabase, alias);
  }
}

class GoalPlanRow extends DataClass implements Insertable<GoalPlanRow> {
  final String goalId;

  /// The month the plan went by, as "2026-10".
  final String month;

  /// Fingerprint of the goal as it was: a different one now means its
  /// target, deadline or money changed since Penny planned.
  final String inputHash;

  /// JSON object from the group ids Penny saw to this phone's group keys.
  final String groupKeys;

  /// The cleaned answer, as JSON.
  final String answer;
  final String model;
  final DateTime createdAt;
  const GoalPlanRow({
    required this.goalId,
    required this.month,
    required this.inputHash,
    required this.groupKeys,
    required this.answer,
    required this.model,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['goal_id'] = Variable<String>(goalId);
    map['month'] = Variable<String>(month);
    map['input_hash'] = Variable<String>(inputHash);
    map['group_keys'] = Variable<String>(groupKeys);
    map['answer'] = Variable<String>(answer);
    map['model'] = Variable<String>(model);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  GoalPlansCompanion toCompanion(bool nullToAbsent) {
    return GoalPlansCompanion(
      goalId: Value(goalId),
      month: Value(month),
      inputHash: Value(inputHash),
      groupKeys: Value(groupKeys),
      answer: Value(answer),
      model: Value(model),
      createdAt: Value(createdAt),
    );
  }

  factory GoalPlanRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GoalPlanRow(
      goalId: serializer.fromJson<String>(json['goalId']),
      month: serializer.fromJson<String>(json['month']),
      inputHash: serializer.fromJson<String>(json['inputHash']),
      groupKeys: serializer.fromJson<String>(json['groupKeys']),
      answer: serializer.fromJson<String>(json['answer']),
      model: serializer.fromJson<String>(json['model']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'goalId': serializer.toJson<String>(goalId),
      'month': serializer.toJson<String>(month),
      'inputHash': serializer.toJson<String>(inputHash),
      'groupKeys': serializer.toJson<String>(groupKeys),
      'answer': serializer.toJson<String>(answer),
      'model': serializer.toJson<String>(model),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  GoalPlanRow copyWith({
    String? goalId,
    String? month,
    String? inputHash,
    String? groupKeys,
    String? answer,
    String? model,
    DateTime? createdAt,
  }) => GoalPlanRow(
    goalId: goalId ?? this.goalId,
    month: month ?? this.month,
    inputHash: inputHash ?? this.inputHash,
    groupKeys: groupKeys ?? this.groupKeys,
    answer: answer ?? this.answer,
    model: model ?? this.model,
    createdAt: createdAt ?? this.createdAt,
  );
  GoalPlanRow copyWithCompanion(GoalPlansCompanion data) {
    return GoalPlanRow(
      goalId: data.goalId.present ? data.goalId.value : this.goalId,
      month: data.month.present ? data.month.value : this.month,
      inputHash: data.inputHash.present ? data.inputHash.value : this.inputHash,
      groupKeys: data.groupKeys.present ? data.groupKeys.value : this.groupKeys,
      answer: data.answer.present ? data.answer.value : this.answer,
      model: data.model.present ? data.model.value : this.model,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GoalPlanRow(')
          ..write('goalId: $goalId, ')
          ..write('month: $month, ')
          ..write('inputHash: $inputHash, ')
          ..write('groupKeys: $groupKeys, ')
          ..write('answer: $answer, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    goalId,
    month,
    inputHash,
    groupKeys,
    answer,
    model,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GoalPlanRow &&
          other.goalId == this.goalId &&
          other.month == this.month &&
          other.inputHash == this.inputHash &&
          other.groupKeys == this.groupKeys &&
          other.answer == this.answer &&
          other.model == this.model &&
          other.createdAt == this.createdAt);
}

class GoalPlansCompanion extends UpdateCompanion<GoalPlanRow> {
  final Value<String> goalId;
  final Value<String> month;
  final Value<String> inputHash;
  final Value<String> groupKeys;
  final Value<String> answer;
  final Value<String> model;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const GoalPlansCompanion({
    this.goalId = const Value.absent(),
    this.month = const Value.absent(),
    this.inputHash = const Value.absent(),
    this.groupKeys = const Value.absent(),
    this.answer = const Value.absent(),
    this.model = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GoalPlansCompanion.insert({
    required String goalId,
    required String month,
    required String inputHash,
    required String groupKeys,
    required String answer,
    required String model,
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : goalId = Value(goalId),
       month = Value(month),
       inputHash = Value(inputHash),
       groupKeys = Value(groupKeys),
       answer = Value(answer),
       model = Value(model),
       createdAt = Value(createdAt);
  static Insertable<GoalPlanRow> custom({
    Expression<String>? goalId,
    Expression<String>? month,
    Expression<String>? inputHash,
    Expression<String>? groupKeys,
    Expression<String>? answer,
    Expression<String>? model,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (goalId != null) 'goal_id': goalId,
      if (month != null) 'month': month,
      if (inputHash != null) 'input_hash': inputHash,
      if (groupKeys != null) 'group_keys': groupKeys,
      if (answer != null) 'answer': answer,
      if (model != null) 'model': model,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GoalPlansCompanion copyWith({
    Value<String>? goalId,
    Value<String>? month,
    Value<String>? inputHash,
    Value<String>? groupKeys,
    Value<String>? answer,
    Value<String>? model,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return GoalPlansCompanion(
      goalId: goalId ?? this.goalId,
      month: month ?? this.month,
      inputHash: inputHash ?? this.inputHash,
      groupKeys: groupKeys ?? this.groupKeys,
      answer: answer ?? this.answer,
      model: model ?? this.model,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (goalId.present) {
      map['goal_id'] = Variable<String>(goalId.value);
    }
    if (month.present) {
      map['month'] = Variable<String>(month.value);
    }
    if (inputHash.present) {
      map['input_hash'] = Variable<String>(inputHash.value);
    }
    if (groupKeys.present) {
      map['group_keys'] = Variable<String>(groupKeys.value);
    }
    if (answer.present) {
      map['answer'] = Variable<String>(answer.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalPlansCompanion(')
          ..write('goalId: $goalId, ')
          ..write('month: $month, ')
          ..write('inputHash: $inputHash, ')
          ..write('groupKeys: $groupKeys, ')
          ..write('answer: $answer, ')
          ..write('model: $model, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursor> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accountMeta = const VerificationMeta(
    'account',
  );
  @override
  late final GeneratedColumn<String> account = GeneratedColumn<String>(
    'account',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [kind, account, seq];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursor> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('account')) {
      context.handle(
        _accountMeta,
        account.isAcceptableOrUnknown(data['account']!, _accountMeta),
      );
    } else if (isInserting) {
      context.missing(_accountMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {kind};
  @override
  SyncCursor map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursor(
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      account: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursor extends DataClass implements Insertable<SyncCursor> {
  /// The synced table, by its name on the server.
  final String kind;

  /// The account whose copy it is. Another account starts again from 0.
  final String account;
  final int seq;
  const SyncCursor({
    required this.kind,
    required this.account,
    required this.seq,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['kind'] = Variable<String>(kind);
    map['account'] = Variable<String>(account);
    map['seq'] = Variable<int>(seq);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      kind: Value(kind),
      account: Value(account),
      seq: Value(seq),
    );
  }

  factory SyncCursor.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursor(
      kind: serializer.fromJson<String>(json['kind']),
      account: serializer.fromJson<String>(json['account']),
      seq: serializer.fromJson<int>(json['seq']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'kind': serializer.toJson<String>(kind),
      'account': serializer.toJson<String>(account),
      'seq': serializer.toJson<int>(seq),
    };
  }

  SyncCursor copyWith({String? kind, String? account, int? seq}) => SyncCursor(
    kind: kind ?? this.kind,
    account: account ?? this.account,
    seq: seq ?? this.seq,
  );
  SyncCursor copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursor(
      kind: data.kind.present ? data.kind.value : this.kind,
      account: data.account.present ? data.account.value : this.account,
      seq: data.seq.present ? data.seq.value : this.seq,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursor(')
          ..write('kind: $kind, ')
          ..write('account: $account, ')
          ..write('seq: $seq')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(kind, account, seq);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursor &&
          other.kind == this.kind &&
          other.account == this.account &&
          other.seq == this.seq);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursor> {
  final Value<String> kind;
  final Value<String> account;
  final Value<int> seq;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.kind = const Value.absent(),
    this.account = const Value.absent(),
    this.seq = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String kind,
    required String account,
    required int seq,
    this.rowid = const Value.absent(),
  }) : kind = Value(kind),
       account = Value(account),
       seq = Value(seq);
  static Insertable<SyncCursor> custom({
    Expression<String>? kind,
    Expression<String>? account,
    Expression<int>? seq,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (kind != null) 'kind': kind,
      if (account != null) 'account': account,
      if (seq != null) 'seq': seq,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? kind,
    Value<String>? account,
    Value<int>? seq,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      kind: kind ?? this.kind,
      account: account ?? this.account,
      seq: seq ?? this.seq,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (account.present) {
      map['account'] = Variable<String>(account.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('kind: $kind, ')
          ..write('account: $account, ')
          ..write('seq: $seq, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingCapturesTable extends PendingCaptures
    with TableInfo<$PendingCapturesTable, PendingCapture> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingCapturesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appMeta = const VerificationMeta('app');
  @override
  late final GeneratedColumn<String> app = GeneratedColumn<String>(
    'app',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderMeta = const VerificationMeta('sender');
  @override
  late final GeneratedColumn<String> sender = GeneratedColumn<String>(
    'sender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAsMeta = const VerificationMeta(
    'savedAs',
  );
  @override
  late final GeneratedColumn<String> savedAs = GeneratedColumn<String>(
    'saved_as',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _amountPaiseMeta = const VerificationMeta(
    'amountPaise',
  );
  @override
  late final GeneratedColumn<int> amountPaise = GeneratedColumn<int>(
    'amount_paise',
    aliasedName,
    false,
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
      ).withConverter<TxnType>($PendingCapturesTable.$convertertype);
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _payeeIsPersonMeta = const VerificationMeta(
    'payeeIsPerson',
  );
  @override
  late final GeneratedColumn<bool> payeeIsPerson = GeneratedColumn<bool>(
    'payee_is_person',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("payee_is_person" IN (0, 1))',
    ),
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
  static const VerificationMeta _suggestedCategoryIdMeta =
      const VerificationMeta('suggestedCategoryId');
  @override
  late final GeneratedColumn<String> suggestedCategoryId =
      GeneratedColumn<String>(
        'suggested_category_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _previewMeta = const VerificationMeta(
    'preview',
  );
  @override
  late final GeneratedColumn<String> preview = GeneratedColumn<String>(
    'preview',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _previewSpansMeta = const VerificationMeta(
    'previewSpans',
  );
  @override
  late final GeneratedColumn<String> previewSpans = GeneratedColumn<String>(
    'preview_spans',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lookalikeMeta = const VerificationMeta(
    'lookalike',
  );
  @override
  late final GeneratedColumn<String> lookalike = GeneratedColumn<String>(
    'lookalike',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _skippedAtMeta = const VerificationMeta(
    'skippedAt',
  );
  @override
  late final GeneratedColumn<DateTime> skippedAt = GeneratedColumn<DateTime>(
    'skipped_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dedupeKey,
    app,
    sender,
    savedAs,
    amountPaise,
    type,
    payee,
    payeeIsPerson,
    occurredAt,
    suggestedCategoryId,
    preview,
    previewSpans,
    lookalike,
    capturedAt,
    skippedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_captures';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingCapture> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('app')) {
      context.handle(
        _appMeta,
        app.isAcceptableOrUnknown(data['app']!, _appMeta),
      );
    } else if (isInserting) {
      context.missing(_appMeta);
    }
    if (data.containsKey('sender')) {
      context.handle(
        _senderMeta,
        sender.isAcceptableOrUnknown(data['sender']!, _senderMeta),
      );
    }
    if (data.containsKey('saved_as')) {
      context.handle(
        _savedAsMeta,
        savedAs.isAcceptableOrUnknown(data['saved_as']!, _savedAsMeta),
      );
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
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('payee_is_person')) {
      context.handle(
        _payeeIsPersonMeta,
        payeeIsPerson.isAcceptableOrUnknown(
          data['payee_is_person']!,
          _payeeIsPersonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payeeIsPersonMeta);
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('suggested_category_id')) {
      context.handle(
        _suggestedCategoryIdMeta,
        suggestedCategoryId.isAcceptableOrUnknown(
          data['suggested_category_id']!,
          _suggestedCategoryIdMeta,
        ),
      );
    }
    if (data.containsKey('preview')) {
      context.handle(
        _previewMeta,
        preview.isAcceptableOrUnknown(data['preview']!, _previewMeta),
      );
    } else if (isInserting) {
      context.missing(_previewMeta);
    }
    if (data.containsKey('preview_spans')) {
      context.handle(
        _previewSpansMeta,
        previewSpans.isAcceptableOrUnknown(
          data['preview_spans']!,
          _previewSpansMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_previewSpansMeta);
    }
    if (data.containsKey('lookalike')) {
      context.handle(
        _lookalikeMeta,
        lookalike.isAcceptableOrUnknown(data['lookalike']!, _lookalikeMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('skipped_at')) {
      context.handle(
        _skippedAtMeta,
        skippedAt.isAcceptableOrUnknown(data['skipped_at']!, _skippedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dedupeKey};
  @override
  PendingCapture map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingCapture(
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      app: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app'],
      )!,
      sender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender'],
      ),
      savedAs: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}saved_as'],
      ),
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      type: $PendingCapturesTable.$convertertype.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}type'],
        )!,
      ),
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      payeeIsPerson: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}payee_is_person'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      suggestedCategoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}suggested_category_id'],
      ),
      preview: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview'],
      )!,
      previewSpans: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preview_spans'],
      )!,
      lookalike: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lookalike'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      skippedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}skipped_at'],
      ),
    );
  }

  @override
  $PendingCapturesTable createAlias(String alias) {
    return $PendingCapturesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TxnType, String, String> $convertertype =
      const EnumNameConverter<TxnType>(TxnType.values);
}

class PendingCapture extends DataClass implements Insertable<PendingCapture> {
  /// The fingerprint of what was read, as its entry would keep it.
  final String dedupeKey;

  /// Where it was read: "sms", "gpay", "phonepe" or "paytm".
  final String app;

  /// Who sent it, for an SMS, as the Messages app names them: "JM-HDFCBK",
  /// "HDFC Bank". Tells one payment seen twice from two payments.
  final String? sender;

  /// The entry it was saved as, once saved. Kept, out of sight, so the same
  /// payment read again from another app is known.
  final String? savedAs;
  final int amountPaise;
  final TxnType type;
  final String? payee;
  final bool payeeIsPerson;
  final DateTime occurredAt;
  final String? suggestedCategoryId;

  /// What was read, with numbers hidden as on the SMS card.
  final String preview;

  /// The preview's marked stretches, as JSON: [[start, end, kind], …].
  final String previewSpans;

  /// An entry it may already be, in words, like "₹250 · Swiggy at 2:10 PM".
  final String? lookalike;
  final DateTime capturedAt;

  /// When it was skipped. A skipped one stays out of sight for a while.
  final DateTime? skippedAt;
  const PendingCapture({
    required this.dedupeKey,
    required this.app,
    this.sender,
    this.savedAs,
    required this.amountPaise,
    required this.type,
    this.payee,
    required this.payeeIsPerson,
    required this.occurredAt,
    this.suggestedCategoryId,
    required this.preview,
    required this.previewSpans,
    this.lookalike,
    required this.capturedAt,
    this.skippedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['app'] = Variable<String>(app);
    if (!nullToAbsent || sender != null) {
      map['sender'] = Variable<String>(sender);
    }
    if (!nullToAbsent || savedAs != null) {
      map['saved_as'] = Variable<String>(savedAs);
    }
    map['amount_paise'] = Variable<int>(amountPaise);
    {
      map['type'] = Variable<String>(
        $PendingCapturesTable.$convertertype.toSql(type),
      );
    }
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    map['payee_is_person'] = Variable<bool>(payeeIsPerson);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || suggestedCategoryId != null) {
      map['suggested_category_id'] = Variable<String>(suggestedCategoryId);
    }
    map['preview'] = Variable<String>(preview);
    map['preview_spans'] = Variable<String>(previewSpans);
    if (!nullToAbsent || lookalike != null) {
      map['lookalike'] = Variable<String>(lookalike);
    }
    map['captured_at'] = Variable<DateTime>(capturedAt);
    if (!nullToAbsent || skippedAt != null) {
      map['skipped_at'] = Variable<DateTime>(skippedAt);
    }
    return map;
  }

  PendingCapturesCompanion toCompanion(bool nullToAbsent) {
    return PendingCapturesCompanion(
      dedupeKey: Value(dedupeKey),
      app: Value(app),
      sender: sender == null && nullToAbsent
          ? const Value.absent()
          : Value(sender),
      savedAs: savedAs == null && nullToAbsent
          ? const Value.absent()
          : Value(savedAs),
      amountPaise: Value(amountPaise),
      type: Value(type),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      payeeIsPerson: Value(payeeIsPerson),
      occurredAt: Value(occurredAt),
      suggestedCategoryId: suggestedCategoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(suggestedCategoryId),
      preview: Value(preview),
      previewSpans: Value(previewSpans),
      lookalike: lookalike == null && nullToAbsent
          ? const Value.absent()
          : Value(lookalike),
      capturedAt: Value(capturedAt),
      skippedAt: skippedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(skippedAt),
    );
  }

  factory PendingCapture.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingCapture(
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      app: serializer.fromJson<String>(json['app']),
      sender: serializer.fromJson<String?>(json['sender']),
      savedAs: serializer.fromJson<String?>(json['savedAs']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      type: $PendingCapturesTable.$convertertype.fromJson(
        serializer.fromJson<String>(json['type']),
      ),
      payee: serializer.fromJson<String?>(json['payee']),
      payeeIsPerson: serializer.fromJson<bool>(json['payeeIsPerson']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      suggestedCategoryId: serializer.fromJson<String?>(
        json['suggestedCategoryId'],
      ),
      preview: serializer.fromJson<String>(json['preview']),
      previewSpans: serializer.fromJson<String>(json['previewSpans']),
      lookalike: serializer.fromJson<String?>(json['lookalike']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      skippedAt: serializer.fromJson<DateTime?>(json['skippedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'app': serializer.toJson<String>(app),
      'sender': serializer.toJson<String?>(sender),
      'savedAs': serializer.toJson<String?>(savedAs),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'type': serializer.toJson<String>(
        $PendingCapturesTable.$convertertype.toJson(type),
      ),
      'payee': serializer.toJson<String?>(payee),
      'payeeIsPerson': serializer.toJson<bool>(payeeIsPerson),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'suggestedCategoryId': serializer.toJson<String?>(suggestedCategoryId),
      'preview': serializer.toJson<String>(preview),
      'previewSpans': serializer.toJson<String>(previewSpans),
      'lookalike': serializer.toJson<String?>(lookalike),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'skippedAt': serializer.toJson<DateTime?>(skippedAt),
    };
  }

  PendingCapture copyWith({
    String? dedupeKey,
    String? app,
    Value<String?> sender = const Value.absent(),
    Value<String?> savedAs = const Value.absent(),
    int? amountPaise,
    TxnType? type,
    Value<String?> payee = const Value.absent(),
    bool? payeeIsPerson,
    DateTime? occurredAt,
    Value<String?> suggestedCategoryId = const Value.absent(),
    String? preview,
    String? previewSpans,
    Value<String?> lookalike = const Value.absent(),
    DateTime? capturedAt,
    Value<DateTime?> skippedAt = const Value.absent(),
  }) => PendingCapture(
    dedupeKey: dedupeKey ?? this.dedupeKey,
    app: app ?? this.app,
    sender: sender.present ? sender.value : this.sender,
    savedAs: savedAs.present ? savedAs.value : this.savedAs,
    amountPaise: amountPaise ?? this.amountPaise,
    type: type ?? this.type,
    payee: payee.present ? payee.value : this.payee,
    payeeIsPerson: payeeIsPerson ?? this.payeeIsPerson,
    occurredAt: occurredAt ?? this.occurredAt,
    suggestedCategoryId: suggestedCategoryId.present
        ? suggestedCategoryId.value
        : this.suggestedCategoryId,
    preview: preview ?? this.preview,
    previewSpans: previewSpans ?? this.previewSpans,
    lookalike: lookalike.present ? lookalike.value : this.lookalike,
    capturedAt: capturedAt ?? this.capturedAt,
    skippedAt: skippedAt.present ? skippedAt.value : this.skippedAt,
  );
  PendingCapture copyWithCompanion(PendingCapturesCompanion data) {
    return PendingCapture(
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      app: data.app.present ? data.app.value : this.app,
      sender: data.sender.present ? data.sender.value : this.sender,
      savedAs: data.savedAs.present ? data.savedAs.value : this.savedAs,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      type: data.type.present ? data.type.value : this.type,
      payee: data.payee.present ? data.payee.value : this.payee,
      payeeIsPerson: data.payeeIsPerson.present
          ? data.payeeIsPerson.value
          : this.payeeIsPerson,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      suggestedCategoryId: data.suggestedCategoryId.present
          ? data.suggestedCategoryId.value
          : this.suggestedCategoryId,
      preview: data.preview.present ? data.preview.value : this.preview,
      previewSpans: data.previewSpans.present
          ? data.previewSpans.value
          : this.previewSpans,
      lookalike: data.lookalike.present ? data.lookalike.value : this.lookalike,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      skippedAt: data.skippedAt.present ? data.skippedAt.value : this.skippedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingCapture(')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('app: $app, ')
          ..write('sender: $sender, ')
          ..write('savedAs: $savedAs, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('type: $type, ')
          ..write('payee: $payee, ')
          ..write('payeeIsPerson: $payeeIsPerson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('suggestedCategoryId: $suggestedCategoryId, ')
          ..write('preview: $preview, ')
          ..write('previewSpans: $previewSpans, ')
          ..write('lookalike: $lookalike, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('skippedAt: $skippedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dedupeKey,
    app,
    sender,
    savedAs,
    amountPaise,
    type,
    payee,
    payeeIsPerson,
    occurredAt,
    suggestedCategoryId,
    preview,
    previewSpans,
    lookalike,
    capturedAt,
    skippedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingCapture &&
          other.dedupeKey == this.dedupeKey &&
          other.app == this.app &&
          other.sender == this.sender &&
          other.savedAs == this.savedAs &&
          other.amountPaise == this.amountPaise &&
          other.type == this.type &&
          other.payee == this.payee &&
          other.payeeIsPerson == this.payeeIsPerson &&
          other.occurredAt == this.occurredAt &&
          other.suggestedCategoryId == this.suggestedCategoryId &&
          other.preview == this.preview &&
          other.previewSpans == this.previewSpans &&
          other.lookalike == this.lookalike &&
          other.capturedAt == this.capturedAt &&
          other.skippedAt == this.skippedAt);
}

class PendingCapturesCompanion extends UpdateCompanion<PendingCapture> {
  final Value<String> dedupeKey;
  final Value<String> app;
  final Value<String?> sender;
  final Value<String?> savedAs;
  final Value<int> amountPaise;
  final Value<TxnType> type;
  final Value<String?> payee;
  final Value<bool> payeeIsPerson;
  final Value<DateTime> occurredAt;
  final Value<String?> suggestedCategoryId;
  final Value<String> preview;
  final Value<String> previewSpans;
  final Value<String?> lookalike;
  final Value<DateTime> capturedAt;
  final Value<DateTime?> skippedAt;
  final Value<int> rowid;
  const PendingCapturesCompanion({
    this.dedupeKey = const Value.absent(),
    this.app = const Value.absent(),
    this.sender = const Value.absent(),
    this.savedAs = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.type = const Value.absent(),
    this.payee = const Value.absent(),
    this.payeeIsPerson = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.suggestedCategoryId = const Value.absent(),
    this.preview = const Value.absent(),
    this.previewSpans = const Value.absent(),
    this.lookalike = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.skippedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingCapturesCompanion.insert({
    required String dedupeKey,
    required String app,
    this.sender = const Value.absent(),
    this.savedAs = const Value.absent(),
    required int amountPaise,
    required TxnType type,
    this.payee = const Value.absent(),
    required bool payeeIsPerson,
    required DateTime occurredAt,
    this.suggestedCategoryId = const Value.absent(),
    required String preview,
    required String previewSpans,
    this.lookalike = const Value.absent(),
    required DateTime capturedAt,
    this.skippedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dedupeKey = Value(dedupeKey),
       app = Value(app),
       amountPaise = Value(amountPaise),
       type = Value(type),
       payeeIsPerson = Value(payeeIsPerson),
       occurredAt = Value(occurredAt),
       preview = Value(preview),
       previewSpans = Value(previewSpans),
       capturedAt = Value(capturedAt);
  static Insertable<PendingCapture> custom({
    Expression<String>? dedupeKey,
    Expression<String>? app,
    Expression<String>? sender,
    Expression<String>? savedAs,
    Expression<int>? amountPaise,
    Expression<String>? type,
    Expression<String>? payee,
    Expression<bool>? payeeIsPerson,
    Expression<DateTime>? occurredAt,
    Expression<String>? suggestedCategoryId,
    Expression<String>? preview,
    Expression<String>? previewSpans,
    Expression<String>? lookalike,
    Expression<DateTime>? capturedAt,
    Expression<DateTime>? skippedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (app != null) 'app': app,
      if (sender != null) 'sender': sender,
      if (savedAs != null) 'saved_as': savedAs,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (type != null) 'type': type,
      if (payee != null) 'payee': payee,
      if (payeeIsPerson != null) 'payee_is_person': payeeIsPerson,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (suggestedCategoryId != null)
        'suggested_category_id': suggestedCategoryId,
      if (preview != null) 'preview': preview,
      if (previewSpans != null) 'preview_spans': previewSpans,
      if (lookalike != null) 'lookalike': lookalike,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (skippedAt != null) 'skipped_at': skippedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingCapturesCompanion copyWith({
    Value<String>? dedupeKey,
    Value<String>? app,
    Value<String?>? sender,
    Value<String?>? savedAs,
    Value<int>? amountPaise,
    Value<TxnType>? type,
    Value<String?>? payee,
    Value<bool>? payeeIsPerson,
    Value<DateTime>? occurredAt,
    Value<String?>? suggestedCategoryId,
    Value<String>? preview,
    Value<String>? previewSpans,
    Value<String?>? lookalike,
    Value<DateTime>? capturedAt,
    Value<DateTime?>? skippedAt,
    Value<int>? rowid,
  }) {
    return PendingCapturesCompanion(
      dedupeKey: dedupeKey ?? this.dedupeKey,
      app: app ?? this.app,
      sender: sender ?? this.sender,
      savedAs: savedAs ?? this.savedAs,
      amountPaise: amountPaise ?? this.amountPaise,
      type: type ?? this.type,
      payee: payee ?? this.payee,
      payeeIsPerson: payeeIsPerson ?? this.payeeIsPerson,
      occurredAt: occurredAt ?? this.occurredAt,
      suggestedCategoryId: suggestedCategoryId ?? this.suggestedCategoryId,
      preview: preview ?? this.preview,
      previewSpans: previewSpans ?? this.previewSpans,
      lookalike: lookalike ?? this.lookalike,
      capturedAt: capturedAt ?? this.capturedAt,
      skippedAt: skippedAt ?? this.skippedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (app.present) {
      map['app'] = Variable<String>(app.value);
    }
    if (sender.present) {
      map['sender'] = Variable<String>(sender.value);
    }
    if (savedAs.present) {
      map['saved_as'] = Variable<String>(savedAs.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(
        $PendingCapturesTable.$convertertype.toSql(type.value),
      );
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (payeeIsPerson.present) {
      map['payee_is_person'] = Variable<bool>(payeeIsPerson.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (suggestedCategoryId.present) {
      map['suggested_category_id'] = Variable<String>(
        suggestedCategoryId.value,
      );
    }
    if (preview.present) {
      map['preview'] = Variable<String>(preview.value);
    }
    if (previewSpans.present) {
      map['preview_spans'] = Variable<String>(previewSpans.value);
    }
    if (lookalike.present) {
      map['lookalike'] = Variable<String>(lookalike.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (skippedAt.present) {
      map['skipped_at'] = Variable<DateTime>(skippedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingCapturesCompanion(')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('app: $app, ')
          ..write('sender: $sender, ')
          ..write('savedAs: $savedAs, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('type: $type, ')
          ..write('payee: $payee, ')
          ..write('payeeIsPerson: $payeeIsPerson, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('suggestedCategoryId: $suggestedCategoryId, ')
          ..write('preview: $preview, ')
          ..write('previewSpans: $previewSpans, ')
          ..write('lookalike: $lookalike, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('skippedAt: $skippedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UpcomingPaymentsTable extends UpcomingPayments
    with TableInfo<$UpcomingPaymentsTable, UpcomingPayment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpcomingPaymentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
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
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payeeMeta = const VerificationMeta('payee');
  @override
  late final GeneratedColumn<String> payee = GeneratedColumn<String>(
    'payee',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<String> categoryId = GeneratedColumn<String>(
    'category_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dueOnMeta = const VerificationMeta('dueOn');
  @override
  late final GeneratedColumn<DateTime> dueOn = GeneratedColumn<DateTime>(
    'due_on',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<DateTime> readAt = GeneratedColumn<DateTime>(
    'read_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
    'dismissed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    dedupeKey,
    amountPaise,
    payee,
    categoryId,
    dueOn,
    readAt,
    dismissedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upcoming_payments';
  @override
  VerificationContext validateIntegrity(
    Insertable<UpcomingPayment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
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
    if (data.containsKey('payee')) {
      context.handle(
        _payeeMeta,
        payee.isAcceptableOrUnknown(data['payee']!, _payeeMeta),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    }
    if (data.containsKey('due_on')) {
      context.handle(
        _dueOnMeta,
        dueOn.isAcceptableOrUnknown(data['due_on']!, _dueOnMeta),
      );
    } else if (isInserting) {
      context.missing(_dueOnMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(
        _readAtMeta,
        readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta),
      );
    } else if (isInserting) {
      context.missing(_readAtMeta);
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dedupeKey};
  @override
  UpcomingPayment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UpcomingPayment(
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      amountPaise: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_paise'],
      )!,
      payee: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payee'],
      ),
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_id'],
      ),
      dueOn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_on'],
      )!,
      readAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}read_at'],
      )!,
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dismissed_at'],
      ),
    );
  }

  @override
  $UpcomingPaymentsTable createAlias(String alias) {
    return $UpcomingPaymentsTable(attachedDatabase, alias);
  }
}

class UpcomingPayment extends DataClass implements Insertable<UpcomingPayment> {
  /// The message's fingerprint, so one read twice is kept once.
  final String dedupeKey;
  final int amountPaise;
  final String? payee;
  final String? categoryId;

  /// The day it's due.
  final DateTime dueOn;
  final DateTime readAt;

  /// When it was taken off the card.
  final DateTime? dismissedAt;
  const UpcomingPayment({
    required this.dedupeKey,
    required this.amountPaise,
    this.payee,
    this.categoryId,
    required this.dueOn,
    required this.readAt,
    this.dismissedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['amount_paise'] = Variable<int>(amountPaise);
    if (!nullToAbsent || payee != null) {
      map['payee'] = Variable<String>(payee);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<String>(categoryId);
    }
    map['due_on'] = Variable<DateTime>(dueOn);
    map['read_at'] = Variable<DateTime>(readAt);
    if (!nullToAbsent || dismissedAt != null) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    }
    return map;
  }

  UpcomingPaymentsCompanion toCompanion(bool nullToAbsent) {
    return UpcomingPaymentsCompanion(
      dedupeKey: Value(dedupeKey),
      amountPaise: Value(amountPaise),
      payee: payee == null && nullToAbsent
          ? const Value.absent()
          : Value(payee),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      dueOn: Value(dueOn),
      readAt: Value(readAt),
      dismissedAt: dismissedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(dismissedAt),
    );
  }

  factory UpcomingPayment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UpcomingPayment(
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      amountPaise: serializer.fromJson<int>(json['amountPaise']),
      payee: serializer.fromJson<String?>(json['payee']),
      categoryId: serializer.fromJson<String?>(json['categoryId']),
      dueOn: serializer.fromJson<DateTime>(json['dueOn']),
      readAt: serializer.fromJson<DateTime>(json['readAt']),
      dismissedAt: serializer.fromJson<DateTime?>(json['dismissedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'amountPaise': serializer.toJson<int>(amountPaise),
      'payee': serializer.toJson<String?>(payee),
      'categoryId': serializer.toJson<String?>(categoryId),
      'dueOn': serializer.toJson<DateTime>(dueOn),
      'readAt': serializer.toJson<DateTime>(readAt),
      'dismissedAt': serializer.toJson<DateTime?>(dismissedAt),
    };
  }

  UpcomingPayment copyWith({
    String? dedupeKey,
    int? amountPaise,
    Value<String?> payee = const Value.absent(),
    Value<String?> categoryId = const Value.absent(),
    DateTime? dueOn,
    DateTime? readAt,
    Value<DateTime?> dismissedAt = const Value.absent(),
  }) => UpcomingPayment(
    dedupeKey: dedupeKey ?? this.dedupeKey,
    amountPaise: amountPaise ?? this.amountPaise,
    payee: payee.present ? payee.value : this.payee,
    categoryId: categoryId.present ? categoryId.value : this.categoryId,
    dueOn: dueOn ?? this.dueOn,
    readAt: readAt ?? this.readAt,
    dismissedAt: dismissedAt.present ? dismissedAt.value : this.dismissedAt,
  );
  UpcomingPayment copyWithCompanion(UpcomingPaymentsCompanion data) {
    return UpcomingPayment(
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      amountPaise: data.amountPaise.present
          ? data.amountPaise.value
          : this.amountPaise,
      payee: data.payee.present ? data.payee.value : this.payee,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      dueOn: data.dueOn.present ? data.dueOn.value : this.dueOn,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingPayment(')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('payee: $payee, ')
          ..write('categoryId: $categoryId, ')
          ..write('dueOn: $dueOn, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    dedupeKey,
    amountPaise,
    payee,
    categoryId,
    dueOn,
    readAt,
    dismissedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpcomingPayment &&
          other.dedupeKey == this.dedupeKey &&
          other.amountPaise == this.amountPaise &&
          other.payee == this.payee &&
          other.categoryId == this.categoryId &&
          other.dueOn == this.dueOn &&
          other.readAt == this.readAt &&
          other.dismissedAt == this.dismissedAt);
}

class UpcomingPaymentsCompanion extends UpdateCompanion<UpcomingPayment> {
  final Value<String> dedupeKey;
  final Value<int> amountPaise;
  final Value<String?> payee;
  final Value<String?> categoryId;
  final Value<DateTime> dueOn;
  final Value<DateTime> readAt;
  final Value<DateTime?> dismissedAt;
  final Value<int> rowid;
  const UpcomingPaymentsCompanion({
    this.dedupeKey = const Value.absent(),
    this.amountPaise = const Value.absent(),
    this.payee = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.dueOn = const Value.absent(),
    this.readAt = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UpcomingPaymentsCompanion.insert({
    required String dedupeKey,
    required int amountPaise,
    this.payee = const Value.absent(),
    this.categoryId = const Value.absent(),
    required DateTime dueOn,
    required DateTime readAt,
    this.dismissedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dedupeKey = Value(dedupeKey),
       amountPaise = Value(amountPaise),
       dueOn = Value(dueOn),
       readAt = Value(readAt);
  static Insertable<UpcomingPayment> custom({
    Expression<String>? dedupeKey,
    Expression<int>? amountPaise,
    Expression<String>? payee,
    Expression<String>? categoryId,
    Expression<DateTime>? dueOn,
    Expression<DateTime>? readAt,
    Expression<DateTime>? dismissedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (amountPaise != null) 'amount_paise': amountPaise,
      if (payee != null) 'payee': payee,
      if (categoryId != null) 'category_id': categoryId,
      if (dueOn != null) 'due_on': dueOn,
      if (readAt != null) 'read_at': readAt,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UpcomingPaymentsCompanion copyWith({
    Value<String>? dedupeKey,
    Value<int>? amountPaise,
    Value<String?>? payee,
    Value<String?>? categoryId,
    Value<DateTime>? dueOn,
    Value<DateTime>? readAt,
    Value<DateTime?>? dismissedAt,
    Value<int>? rowid,
  }) {
    return UpcomingPaymentsCompanion(
      dedupeKey: dedupeKey ?? this.dedupeKey,
      amountPaise: amountPaise ?? this.amountPaise,
      payee: payee ?? this.payee,
      categoryId: categoryId ?? this.categoryId,
      dueOn: dueOn ?? this.dueOn,
      readAt: readAt ?? this.readAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (amountPaise.present) {
      map['amount_paise'] = Variable<int>(amountPaise.value);
    }
    if (payee.present) {
      map['payee'] = Variable<String>(payee.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<String>(categoryId.value);
    }
    if (dueOn.present) {
      map['due_on'] = Variable<DateTime>(dueOn.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<DateTime>(readAt.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingPaymentsCompanion(')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('amountPaise: $amountPaise, ')
          ..write('payee: $payee, ')
          ..write('categoryId: $categoryId, ')
          ..write('dueOn: $dueOn, ')
          ..write('readAt: $readAt, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TxnsTable txns = $TxnsTable(this);
  late final Trigger txnsStampForward = Trigger(
    'CREATE TRIGGER txns_stamp_forward AFTER UPDATE OF updated_at ON txns WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE txns SET updated_at = OLD.updated_at + 1 WHERE id = NEW.id;END',
    'txns_stamp_forward',
  );
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final Trigger budgetsStampForward = Trigger(
    'CREATE TRIGGER budgets_stamp_forward AFTER UPDATE OF updated_at ON budgets WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE budgets SET updated_at = OLD.updated_at + 1 WHERE id = NEW.id;END',
    'budgets_stamp_forward',
  );
  late final $GoalsTable goals = $GoalsTable(this);
  late final Trigger goalsStampForward = Trigger(
    'CREATE TRIGGER goals_stamp_forward AFTER UPDATE OF updated_at ON goals WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE goals SET updated_at = OLD.updated_at + 1 WHERE id = NEW.id;END',
    'goals_stamp_forward',
  );
  late final $GoalDepositsTable goalDeposits = $GoalDepositsTable(this);
  late final Trigger goalDepositsStampForward = Trigger(
    'CREATE TRIGGER goal_deposits_stamp_forward AFTER UPDATE OF updated_at ON goal_deposits WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE goal_deposits SET updated_at = OLD.updated_at + 1 WHERE id = NEW.id;END',
    'goal_deposits_stamp_forward',
  );
  late final $TagRulesTable tagRules = $TagRulesTable(this);
  late final Trigger tagRulesStampForward = Trigger(
    'CREATE TRIGGER tag_rules_stamp_forward AFTER UPDATE OF updated_at ON tag_rules WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE tag_rules SET updated_at = OLD.updated_at + 1 WHERE id = NEW.id;END',
    'tag_rules_stamp_forward',
  );
  late final $PrefsTable prefs = $PrefsTable(this);
  late final Trigger prefsStampForward = Trigger(
    'CREATE TRIGGER prefs_stamp_forward AFTER UPDATE OF updated_at ON prefs WHEN NEW.dirty = 1 AND NEW.updated_at <= OLD.updated_at BEGIN UPDATE prefs SET updated_at = OLD.updated_at + 1 WHERE name = NEW.name;END',
    'prefs_stamp_forward',
  );
  late final $InsightsTable insights = $InsightsTable(this);
  late final $ChatMessagesTable chatMessages = $ChatMessagesTable(this);
  late final $GoalPlansTable goalPlans = $GoalPlansTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $PendingCapturesTable pendingCaptures = $PendingCapturesTable(
    this,
  );
  late final $UpcomingPaymentsTable upcomingPayments = $UpcomingPaymentsTable(
    this,
  );
  late final Index txnsOccurredAt = Index(
    'txns_occurred_at',
    'CREATE INDEX txns_occurred_at ON txns (occurred_at)',
  );
  late final Index txnsDedupeKey = Index(
    'txns_dedupe_key',
    'CREATE UNIQUE INDEX txns_dedupe_key ON txns (dedupe_key) WHERE deleted_at IS NULL',
  );
  late final Index tagRulesKindRuleKey = Index(
    'tag_rules_kind_rule_key',
    'CREATE UNIQUE INDEX tag_rules_kind_rule_key ON tag_rules (kind, rule_key) WHERE deleted_at IS NULL',
  );
  late final Index chatMessagesCreatedAt = Index(
    'chat_messages_created_at',
    'CREATE INDEX chat_messages_created_at ON chat_messages (created_at)',
  );
  late final Index budgetsBudgetKey = Index(
    'budgets_budget_key',
    'CREATE UNIQUE INDEX budgets_budget_key ON budgets (budget_key) WHERE deleted_at IS NULL',
  );
  late final Index goalDepositsGoalId = Index(
    'goal_deposits_goal_id',
    'CREATE INDEX goal_deposits_goal_id ON goal_deposits (goal_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    txns,
    txnsStampForward,
    budgets,
    budgetsStampForward,
    goals,
    goalsStampForward,
    goalDeposits,
    goalDepositsStampForward,
    tagRules,
    tagRulesStampForward,
    prefs,
    prefsStampForward,
    insights,
    chatMessages,
    goalPlans,
    syncCursors,
    pendingCaptures,
    upcomingPayments,
    txnsOccurredAt,
    txnsDedupeKey,
    tagRulesKindRuleKey,
    chatMessagesCreatedAt,
    budgetsBudgetKey,
    goalDepositsGoalId,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'txns',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('txns', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'budgets',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('budgets', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goals',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('goals', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'goal_deposits',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('goal_deposits', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tag_rules',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('tag_rules', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'prefs',
        limitUpdateKind: UpdateKind.update,
      ),
      result: [TableUpdate('prefs', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$TxnsTableCreateCompanionBuilder = TxnsCompanion Function({
  Value<bool> dirty,
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
  Value<bool?> payeeIsPerson,
  Value<int> rowid,
});
typedef $$TxnsTableUpdateCompanionBuilder = TxnsCompanion Function({
  Value<bool> dirty,
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
  Value<bool?> payeeIsPerson,
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
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

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

  ColumnFilters<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
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
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

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

  ColumnOrderings<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
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
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

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

  GeneratedColumn<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
    builder: (column) => column,
  );
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
                Value<bool> dirty = const Value.absent(),
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
                Value<bool?> payeeIsPerson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TxnsCompanion(
                dirty: dirty,
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
                payeeIsPerson: payeeIsPerson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
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
                Value<bool?> payeeIsPerson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TxnsCompanion.insert(
                dirty: dirty,
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
                payeeIsPerson: payeeIsPerson,
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
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  Value<bool> dirty,
  required String id,
  required String budgetKey,
  required int amountPaise,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<bool> dirty,
  Value<String> id,
  Value<String> budgetKey,
  Value<int> amountPaise,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get budgetKey => $composableBuilder(
    column: $table.budgetKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
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
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get budgetKey => $composableBuilder(
    column: $table.budgetKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
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
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get budgetKey =>
      $composableBuilder(column: $table.budgetKey, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$BudgetsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BudgetsTable,
          BudgetRow,
          $$BudgetsTableFilterComposer,
          $$BudgetsTableOrderingComposer,
          $$BudgetsTableAnnotationComposer,
          $$BudgetsTableCreateCompanionBuilder,
          $$BudgetsTableUpdateCompanionBuilder,
          (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
          BudgetRow,
          PrefetchHooks Function()
        > {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> budgetKey = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion(
                dirty: dirty,
                id: id,
                budgetKey: budgetKey,
                amountPaise: amountPaise,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String budgetKey,
                required int amountPaise,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BudgetsCompanion.insert(
                dirty: dirty,
                id: id,
                budgetKey: budgetKey,
                amountPaise: amountPaise,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BudgetsTable, BudgetRow>(table),
                  BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BudgetsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BudgetsTable,
      BudgetRow,
      $$BudgetsTableFilterComposer,
      $$BudgetsTableOrderingComposer,
      $$BudgetsTableAnnotationComposer,
      $$BudgetsTableCreateCompanionBuilder,
      $$BudgetsTableUpdateCompanionBuilder,
      (BudgetRow, BaseReferences<_$AppDatabase, $BudgetsTable, BudgetRow>),
      BudgetRow,
      PrefetchHooks Function()
    >;
typedef $$GoalsTableCreateCompanionBuilder = GoalsCompanion Function({
  Value<bool> dirty,
  required String id,
  required String title,
  required int targetPaise,
  required DateTime deadline,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$GoalsTableUpdateCompanionBuilder = GoalsCompanion Function({
  Value<bool> dirty,
  Value<String> id,
  Value<String> title,
  Value<int> targetPaise,
  Value<DateTime> deadline,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get targetPaise => $composableBuilder(
    column: $table.targetPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
    builder: (column) => ColumnFilters(column),
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
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get targetPaise => $composableBuilder(
    column: $table.targetPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deadline => $composableBuilder(
    column: $table.deadline,
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
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get targetPaise => $composableBuilder(
    column: $table.targetPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deadline =>
      $composableBuilder(column: $table.deadline, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
          Goal,
          PrefetchHooks Function()
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int> targetPaise = const Value.absent(),
                Value<DateTime> deadline = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion(
                dirty: dirty,
                id: id,
                title: title,
                targetPaise: targetPaise,
                deadline: deadline,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String title,
                required int targetPaise,
                required DateTime deadline,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalsCompanion.insert(
                dirty: dirty,
                id: id,
                title: title,
                targetPaise: targetPaise,
                deadline: deadline,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalsTable, Goal>(table),
                  BaseReferences<_$AppDatabase, $GoalsTable, Goal>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, BaseReferences<_$AppDatabase, $GoalsTable, Goal>),
      Goal,
      PrefetchHooks Function()
    >;
typedef $$GoalDepositsTableCreateCompanionBuilder =
    GoalDepositsCompanion Function({
      Value<bool> dirty,
      required String id,
      required String goalId,
      required int amountPaise,
      required DateTime occurredAt,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$GoalDepositsTableUpdateCompanionBuilder =
    GoalDepositsCompanion Function({
      Value<bool> dirty,
      Value<String> id,
      Value<String> goalId,
      Value<int> amountPaise,
      Value<DateTime> occurredAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$GoalDepositsTableFilterComposer
    extends Composer<_$AppDatabase, $GoalDepositsTable> {
  $$GoalDepositsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
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
}

class $$GoalDepositsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalDepositsTable> {
  $$GoalDepositsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
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
}

class $$GoalDepositsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalDepositsTable> {
  $$GoalDepositsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$GoalDepositsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalDepositsTable,
          GoalDeposit,
          $$GoalDepositsTableFilterComposer,
          $$GoalDepositsTableOrderingComposer,
          $$GoalDepositsTableAnnotationComposer,
          $$GoalDepositsTableCreateCompanionBuilder,
          $$GoalDepositsTableUpdateCompanionBuilder,
          (
            GoalDeposit,
            BaseReferences<_$AppDatabase, $GoalDepositsTable, GoalDeposit>,
          ),
          GoalDeposit,
          PrefetchHooks Function()
        > {
  $$GoalDepositsTableTableManager(_$AppDatabase db, $GoalDepositsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalDepositsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalDepositsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalDepositsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> goalId = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalDepositsCompanion(
                dirty: dirty,
                id: id,
                goalId: goalId,
                amountPaise: amountPaise,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                required String id,
                required String goalId,
                required int amountPaise,
                required DateTime occurredAt,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalDepositsCompanion.insert(
                dirty: dirty,
                id: id,
                goalId: goalId,
                amountPaise: amountPaise,
                occurredAt: occurredAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalDepositsTable, GoalDeposit>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $GoalDepositsTable,
                    GoalDeposit
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalDepositsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalDepositsTable,
      GoalDeposit,
      $$GoalDepositsTableFilterComposer,
      $$GoalDepositsTableOrderingComposer,
      $$GoalDepositsTableAnnotationComposer,
      $$GoalDepositsTableCreateCompanionBuilder,
      $$GoalDepositsTableUpdateCompanionBuilder,
      (
        GoalDeposit,
        BaseReferences<_$AppDatabase, $GoalDepositsTable, GoalDeposit>,
      ),
      GoalDeposit,
      PrefetchHooks Function()
    >;
typedef $$TagRulesTableCreateCompanionBuilder = TagRulesCompanion Function({
  Value<bool> dirty,
  required String id,
  required RuleKind kind,
  required String ruleKey,
  required TxnTag tag,
  required DateTime createdAt,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});
typedef $$TagRulesTableUpdateCompanionBuilder = TagRulesCompanion Function({
  Value<bool> dirty,
  Value<String> id,
  Value<RuleKind> kind,
  Value<String> ruleKey,
  Value<TxnTag> tag,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
  Value<int> rowid,
});

class $$TagRulesTableFilterComposer
    extends Composer<_$AppDatabase, $TagRulesTable> {
  $$TagRulesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<RuleKind, RuleKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get ruleKey => $composableBuilder(
    column: $table.ruleKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TxnTag, TxnTag, String> get tag =>
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
}

class $$TagRulesTableOrderingComposer
    extends Composer<_$AppDatabase, $TagRulesTable> {
  $$TagRulesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ruleKey => $composableBuilder(
    column: $table.ruleKey,
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
}

class $$TagRulesTableAnnotationComposer
    extends Composer<_$AppDatabase, $TagRulesTable> {
  $$TagRulesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<RuleKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get ruleKey =>
      $composableBuilder(column: $table.ruleKey, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TxnTag, String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TagRulesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TagRulesTable,
          TagRule,
          $$TagRulesTableFilterComposer,
          $$TagRulesTableOrderingComposer,
          $$TagRulesTableAnnotationComposer,
          $$TagRulesTableCreateCompanionBuilder,
          $$TagRulesTableUpdateCompanionBuilder,
          (TagRule, BaseReferences<_$AppDatabase, $TagRulesTable, TagRule>),
          TagRule,
          PrefetchHooks Function()
        > {
  $$TagRulesTableTableManager(_$AppDatabase db, $TagRulesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagRulesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagRulesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagRulesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<RuleKind> kind = const Value.absent(),
                Value<String> ruleKey = const Value.absent(),
                Value<TxnTag> tag = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagRulesCompanion(
                dirty: dirty,
                id: id,
                kind: kind,
                ruleKey: ruleKey,
                tag: tag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                required String id,
                required RuleKind kind,
                required String ruleKey,
                required TxnTag tag,
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagRulesCompanion.insert(
                dirty: dirty,
                id: id,
                kind: kind,
                ruleKey: ruleKey,
                tag: tag,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagRulesTable, TagRule>(table),
                  BaseReferences<_$AppDatabase, $TagRulesTable, TagRule>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagRulesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TagRulesTable,
      TagRule,
      $$TagRulesTableFilterComposer,
      $$TagRulesTableOrderingComposer,
      $$TagRulesTableAnnotationComposer,
      $$TagRulesTableCreateCompanionBuilder,
      $$TagRulesTableUpdateCompanionBuilder,
      (TagRule, BaseReferences<_$AppDatabase, $TagRulesTable, TagRule>),
      TagRule,
      PrefetchHooks Function()
    >;
typedef $$PrefsTableCreateCompanionBuilder = PrefsCompanion Function({
  Value<bool> dirty,
  required String name,
  required String value,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$PrefsTableUpdateCompanionBuilder = PrefsCompanion Function({
  Value<bool> dirty,
  Value<String> name,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$PrefsTableFilterComposer extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PrefsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PrefsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrefsTable> {
  $$PrefsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PrefsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PrefsTable,
          Pref,
          $$PrefsTableFilterComposer,
          $$PrefsTableOrderingComposer,
          $$PrefsTableAnnotationComposer,
          $$PrefsTableCreateCompanionBuilder,
          $$PrefsTableUpdateCompanionBuilder,
          (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
          Pref,
          PrefetchHooks Function()
        > {
  $$PrefsTableTableManager(_$AppDatabase db, $PrefsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrefsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrefsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrefsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion(
                dirty: dirty,
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<bool> dirty = const Value.absent(),
                required String name,
                required String value,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => PrefsCompanion.insert(
                dirty: dirty,
                name: name,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PrefsTable, Pref>(table),
                  BaseReferences<_$AppDatabase, $PrefsTable, Pref>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PrefsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PrefsTable,
      Pref,
      $$PrefsTableFilterComposer,
      $$PrefsTableOrderingComposer,
      $$PrefsTableAnnotationComposer,
      $$PrefsTableCreateCompanionBuilder,
      $$PrefsTableUpdateCompanionBuilder,
      (Pref, BaseReferences<_$AppDatabase, $PrefsTable, Pref>),
      Pref,
      PrefetchHooks Function()
    >;
typedef $$InsightsTableCreateCompanionBuilder = InsightsCompanion Function({
  required String month,
  required String inputHash,
  required String groupKeys,
  required String answer,
  required String model,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$InsightsTableUpdateCompanionBuilder = InsightsCompanion Function({
  Value<String> month,
  Value<String> inputHash,
  Value<String> groupKeys,
  Value<String> answer,
  Value<String> model,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$InsightsTableFilterComposer
    extends Composer<_$AppDatabase, $InsightsTable> {
  $$InsightsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupKeys => $composableBuilder(
    column: $table.groupKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InsightsTableOrderingComposer
    extends Composer<_$AppDatabase, $InsightsTable> {
  $$InsightsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupKeys => $composableBuilder(
    column: $table.groupKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InsightsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InsightsTable> {
  $$InsightsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get inputHash =>
      $composableBuilder(column: $table.inputHash, builder: (column) => column);

  GeneratedColumn<String> get groupKeys =>
      $composableBuilder(column: $table.groupKeys, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$InsightsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InsightsTable,
          InsightRow,
          $$InsightsTableFilterComposer,
          $$InsightsTableOrderingComposer,
          $$InsightsTableAnnotationComposer,
          $$InsightsTableCreateCompanionBuilder,
          $$InsightsTableUpdateCompanionBuilder,
          (
            InsightRow,
            BaseReferences<_$AppDatabase, $InsightsTable, InsightRow>,
          ),
          InsightRow,
          PrefetchHooks Function()
        > {
  $$InsightsTableTableManager(_$AppDatabase db, $InsightsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InsightsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InsightsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InsightsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> month = const Value.absent(),
                Value<String> inputHash = const Value.absent(),
                Value<String> groupKeys = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InsightsCompanion(
                month: month,
                inputHash: inputHash,
                groupKeys: groupKeys,
                answer: answer,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String month,
                required String inputHash,
                required String groupKeys,
                required String answer,
                required String model,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => InsightsCompanion.insert(
                month: month,
                inputHash: inputHash,
                groupKeys: groupKeys,
                answer: answer,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InsightsTable, InsightRow>(table),
                  BaseReferences<_$AppDatabase, $InsightsTable, InsightRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InsightsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InsightsTable,
      InsightRow,
      $$InsightsTableFilterComposer,
      $$InsightsTableOrderingComposer,
      $$InsightsTableAnnotationComposer,
      $$InsightsTableCreateCompanionBuilder,
      $$InsightsTableUpdateCompanionBuilder,
      (InsightRow, BaseReferences<_$AppDatabase, $InsightsTable, InsightRow>),
      InsightRow,
      PrefetchHooks Function()
    >;
typedef $$ChatMessagesTableCreateCompanionBuilder =
    ChatMessagesCompanion Function({
      required String id,
      required ChatRole role,
      required String body,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$ChatMessagesTableUpdateCompanionBuilder =
    ChatMessagesCompanion Function({
      Value<String> id,
      Value<ChatRole> role,
      Value<String> body,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$ChatMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<ChatRole, ChatRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ChatMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableOrderingComposer({
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

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get body => $composableBuilder(
    column: $table.body,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ChatMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChatMessagesTable> {
  $$ChatMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ChatRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChatMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ChatMessagesTable,
          ChatMessage,
          $$ChatMessagesTableFilterComposer,
          $$ChatMessagesTableOrderingComposer,
          $$ChatMessagesTableAnnotationComposer,
          $$ChatMessagesTableCreateCompanionBuilder,
          $$ChatMessagesTableUpdateCompanionBuilder,
          (
            ChatMessage,
            BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
          ),
          ChatMessage,
          PrefetchHooks Function()
        > {
  $$ChatMessagesTableTableManager(_$AppDatabase db, $ChatMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChatMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChatMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChatMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<ChatRole> role = const Value.absent(),
                Value<String> body = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion(
                id: id,
                role: role,
                body: body,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required ChatRole role,
                required String body,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => ChatMessagesCompanion.insert(
                id: id,
                role: role,
                body: body,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ChatMessagesTable, ChatMessage>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ChatMessagesTable,
                    ChatMessage
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ChatMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ChatMessagesTable,
      ChatMessage,
      $$ChatMessagesTableFilterComposer,
      $$ChatMessagesTableOrderingComposer,
      $$ChatMessagesTableAnnotationComposer,
      $$ChatMessagesTableCreateCompanionBuilder,
      $$ChatMessagesTableUpdateCompanionBuilder,
      (
        ChatMessage,
        BaseReferences<_$AppDatabase, $ChatMessagesTable, ChatMessage>,
      ),
      ChatMessage,
      PrefetchHooks Function()
    >;
typedef $$GoalPlansTableCreateCompanionBuilder = GoalPlansCompanion Function({
  required String goalId,
  required String month,
  required String inputHash,
  required String groupKeys,
  required String answer,
  required String model,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$GoalPlansTableUpdateCompanionBuilder = GoalPlansCompanion Function({
  Value<String> goalId,
  Value<String> month,
  Value<String> inputHash,
  Value<String> groupKeys,
  Value<String> answer,
  Value<String> model,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$GoalPlansTableFilterComposer
    extends Composer<_$AppDatabase, $GoalPlansTable> {
  $$GoalPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get groupKeys => $composableBuilder(
    column: $table.groupKeys,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GoalPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalPlansTable> {
  $$GoalPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get goalId => $composableBuilder(
    column: $table.goalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get month => $composableBuilder(
    column: $table.month,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inputHash => $composableBuilder(
    column: $table.inputHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get groupKeys => $composableBuilder(
    column: $table.groupKeys,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answer => $composableBuilder(
    column: $table.answer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GoalPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalPlansTable> {
  $$GoalPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get goalId =>
      $composableBuilder(column: $table.goalId, builder: (column) => column);

  GeneratedColumn<String> get month =>
      $composableBuilder(column: $table.month, builder: (column) => column);

  GeneratedColumn<String> get inputHash =>
      $composableBuilder(column: $table.inputHash, builder: (column) => column);

  GeneratedColumn<String> get groupKeys =>
      $composableBuilder(column: $table.groupKeys, builder: (column) => column);

  GeneratedColumn<String> get answer =>
      $composableBuilder(column: $table.answer, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GoalPlansTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalPlansTable,
          GoalPlanRow,
          $$GoalPlansTableFilterComposer,
          $$GoalPlansTableOrderingComposer,
          $$GoalPlansTableAnnotationComposer,
          $$GoalPlansTableCreateCompanionBuilder,
          $$GoalPlansTableUpdateCompanionBuilder,
          (
            GoalPlanRow,
            BaseReferences<_$AppDatabase, $GoalPlansTable, GoalPlanRow>,
          ),
          GoalPlanRow,
          PrefetchHooks Function()
        > {
  $$GoalPlansTableTableManager(_$AppDatabase db, $GoalPlansTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> goalId = const Value.absent(),
                Value<String> month = const Value.absent(),
                Value<String> inputHash = const Value.absent(),
                Value<String> groupKeys = const Value.absent(),
                Value<String> answer = const Value.absent(),
                Value<String> model = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GoalPlansCompanion(
                goalId: goalId,
                month: month,
                inputHash: inputHash,
                groupKeys: groupKeys,
                answer: answer,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String goalId,
                required String month,
                required String inputHash,
                required String groupKeys,
                required String answer,
                required String model,
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => GoalPlansCompanion.insert(
                goalId: goalId,
                month: month,
                inputHash: inputHash,
                groupKeys: groupKeys,
                answer: answer,
                model: model,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GoalPlansTable, GoalPlanRow>(table),
                  BaseReferences<_$AppDatabase, $GoalPlansTable, GoalPlanRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GoalPlansTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalPlansTable,
      GoalPlanRow,
      $$GoalPlansTableFilterComposer,
      $$GoalPlansTableOrderingComposer,
      $$GoalPlansTableAnnotationComposer,
      $$GoalPlansTableCreateCompanionBuilder,
      $$GoalPlansTableUpdateCompanionBuilder,
      (
        GoalPlanRow,
        BaseReferences<_$AppDatabase, $GoalPlansTable, GoalPlanRow>,
      ),
      GoalPlanRow,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String kind,
      required String account,
      required int seq,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> kind,
      Value<String> account,
      Value<int> seq,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get account => $composableBuilder(
    column: $table.account,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get account =>
      $composableBuilder(column: $table.account, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursor,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursor,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
          ),
          SyncCursor,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> kind = const Value.absent(),
                Value<String> account = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                kind: kind,
                account: account,
                seq: seq,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String kind,
                required String account,
                required int seq,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                kind: kind,
                account: account,
                seq: seq,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncCursorsTable, SyncCursor>(table),
                  BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursor,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursor,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursor>,
      ),
      SyncCursor,
      PrefetchHooks Function()
    >;
typedef $$PendingCapturesTableCreateCompanionBuilder =
    PendingCapturesCompanion Function({
      required String dedupeKey,
      required String app,
      Value<String?> sender,
      Value<String?> savedAs,
      required int amountPaise,
      required TxnType type,
      Value<String?> payee,
      required bool payeeIsPerson,
      required DateTime occurredAt,
      Value<String?> suggestedCategoryId,
      required String preview,
      required String previewSpans,
      Value<String?> lookalike,
      required DateTime capturedAt,
      Value<DateTime?> skippedAt,
      Value<int> rowid,
    });
typedef $$PendingCapturesTableUpdateCompanionBuilder =
    PendingCapturesCompanion Function({
      Value<String> dedupeKey,
      Value<String> app,
      Value<String?> sender,
      Value<String?> savedAs,
      Value<int> amountPaise,
      Value<TxnType> type,
      Value<String?> payee,
      Value<bool> payeeIsPerson,
      Value<DateTime> occurredAt,
      Value<String?> suggestedCategoryId,
      Value<String> preview,
      Value<String> previewSpans,
      Value<String?> lookalike,
      Value<DateTime> capturedAt,
      Value<DateTime?> skippedAt,
      Value<int> rowid,
    });

class $$PendingCapturesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingCapturesTable> {
  $$PendingCapturesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get app => $composableBuilder(
    column: $table.app,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get savedAs => $composableBuilder(
    column: $table.savedAs,
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

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get suggestedCategoryId => $composableBuilder(
    column: $table.suggestedCategoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get previewSpans => $composableBuilder(
    column: $table.previewSpans,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lookalike => $composableBuilder(
    column: $table.lookalike,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get skippedAt => $composableBuilder(
    column: $table.skippedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingCapturesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingCapturesTable> {
  $$PendingCapturesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get app => $composableBuilder(
    column: $table.app,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sender => $composableBuilder(
    column: $table.sender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get savedAs => $composableBuilder(
    column: $table.savedAs,
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

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get suggestedCategoryId => $composableBuilder(
    column: $table.suggestedCategoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preview => $composableBuilder(
    column: $table.preview,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get previewSpans => $composableBuilder(
    column: $table.previewSpans,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lookalike => $composableBuilder(
    column: $table.lookalike,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get skippedAt => $composableBuilder(
    column: $table.skippedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingCapturesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingCapturesTable> {
  $$PendingCapturesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get app =>
      $composableBuilder(column: $table.app, builder: (column) => column);

  GeneratedColumn<String> get sender =>
      $composableBuilder(column: $table.sender, builder: (column) => column);

  GeneratedColumn<String> get savedAs =>
      $composableBuilder(column: $table.savedAs, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<TxnType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<bool> get payeeIsPerson => $composableBuilder(
    column: $table.payeeIsPerson,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get suggestedCategoryId => $composableBuilder(
    column: $table.suggestedCategoryId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preview =>
      $composableBuilder(column: $table.preview, builder: (column) => column);

  GeneratedColumn<String> get previewSpans => $composableBuilder(
    column: $table.previewSpans,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lookalike =>
      $composableBuilder(column: $table.lookalike, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get skippedAt =>
      $composableBuilder(column: $table.skippedAt, builder: (column) => column);
}

class $$PendingCapturesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingCapturesTable,
          PendingCapture,
          $$PendingCapturesTableFilterComposer,
          $$PendingCapturesTableOrderingComposer,
          $$PendingCapturesTableAnnotationComposer,
          $$PendingCapturesTableCreateCompanionBuilder,
          $$PendingCapturesTableUpdateCompanionBuilder,
          (
            PendingCapture,
            BaseReferences<
              _$AppDatabase,
              $PendingCapturesTable,
              PendingCapture
            >,
          ),
          PendingCapture,
          PrefetchHooks Function()
        > {
  $$PendingCapturesTableTableManager(
    _$AppDatabase db,
    $PendingCapturesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingCapturesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingCapturesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingCapturesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dedupeKey = const Value.absent(),
                Value<String> app = const Value.absent(),
                Value<String?> sender = const Value.absent(),
                Value<String?> savedAs = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<TxnType> type = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<bool> payeeIsPerson = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String?> suggestedCategoryId = const Value.absent(),
                Value<String> preview = const Value.absent(),
                Value<String> previewSpans = const Value.absent(),
                Value<String?> lookalike = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<DateTime?> skippedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingCapturesCompanion(
                dedupeKey: dedupeKey,
                app: app,
                sender: sender,
                savedAs: savedAs,
                amountPaise: amountPaise,
                type: type,
                payee: payee,
                payeeIsPerson: payeeIsPerson,
                occurredAt: occurredAt,
                suggestedCategoryId: suggestedCategoryId,
                preview: preview,
                previewSpans: previewSpans,
                lookalike: lookalike,
                capturedAt: capturedAt,
                skippedAt: skippedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dedupeKey,
                required String app,
                Value<String?> sender = const Value.absent(),
                Value<String?> savedAs = const Value.absent(),
                required int amountPaise,
                required TxnType type,
                Value<String?> payee = const Value.absent(),
                required bool payeeIsPerson,
                required DateTime occurredAt,
                Value<String?> suggestedCategoryId = const Value.absent(),
                required String preview,
                required String previewSpans,
                Value<String?> lookalike = const Value.absent(),
                required DateTime capturedAt,
                Value<DateTime?> skippedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingCapturesCompanion.insert(
                dedupeKey: dedupeKey,
                app: app,
                sender: sender,
                savedAs: savedAs,
                amountPaise: amountPaise,
                type: type,
                payee: payee,
                payeeIsPerson: payeeIsPerson,
                occurredAt: occurredAt,
                suggestedCategoryId: suggestedCategoryId,
                preview: preview,
                previewSpans: previewSpans,
                lookalike: lookalike,
                capturedAt: capturedAt,
                skippedAt: skippedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PendingCapturesTable, PendingCapture>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $PendingCapturesTable,
                    PendingCapture
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingCapturesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingCapturesTable,
      PendingCapture,
      $$PendingCapturesTableFilterComposer,
      $$PendingCapturesTableOrderingComposer,
      $$PendingCapturesTableAnnotationComposer,
      $$PendingCapturesTableCreateCompanionBuilder,
      $$PendingCapturesTableUpdateCompanionBuilder,
      (
        PendingCapture,
        BaseReferences<_$AppDatabase, $PendingCapturesTable, PendingCapture>,
      ),
      PendingCapture,
      PrefetchHooks Function()
    >;
typedef $$UpcomingPaymentsTableCreateCompanionBuilder =
    UpcomingPaymentsCompanion Function({
      required String dedupeKey,
      required int amountPaise,
      Value<String?> payee,
      Value<String?> categoryId,
      required DateTime dueOn,
      required DateTime readAt,
      Value<DateTime?> dismissedAt,
      Value<int> rowid,
    });
typedef $$UpcomingPaymentsTableUpdateCompanionBuilder =
    UpcomingPaymentsCompanion Function({
      Value<String> dedupeKey,
      Value<int> amountPaise,
      Value<String?> payee,
      Value<String?> categoryId,
      Value<DateTime> dueOn,
      Value<DateTime> readAt,
      Value<DateTime?> dismissedAt,
      Value<int> rowid,
    });

class $$UpcomingPaymentsTableFilterComposer
    extends Composer<_$AppDatabase, $UpcomingPaymentsTable> {
  $$UpcomingPaymentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UpcomingPaymentsTableOrderingComposer
    extends Composer<_$AppDatabase, $UpcomingPaymentsTable> {
  $$UpcomingPaymentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payee => $composableBuilder(
    column: $table.payee,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueOn => $composableBuilder(
    column: $table.dueOn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get readAt => $composableBuilder(
    column: $table.readAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UpcomingPaymentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $UpcomingPaymentsTable> {
  $$UpcomingPaymentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<int> get amountPaise => $composableBuilder(
    column: $table.amountPaise,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payee =>
      $composableBuilder(column: $table.payee, builder: (column) => column);

  GeneratedColumn<String> get categoryId => $composableBuilder(
    column: $table.categoryId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dueOn =>
      $composableBuilder(column: $table.dueOn, builder: (column) => column);

  GeneratedColumn<DateTime> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );
}

class $$UpcomingPaymentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UpcomingPaymentsTable,
          UpcomingPayment,
          $$UpcomingPaymentsTableFilterComposer,
          $$UpcomingPaymentsTableOrderingComposer,
          $$UpcomingPaymentsTableAnnotationComposer,
          $$UpcomingPaymentsTableCreateCompanionBuilder,
          $$UpcomingPaymentsTableUpdateCompanionBuilder,
          (
            UpcomingPayment,
            BaseReferences<
              _$AppDatabase,
              $UpcomingPaymentsTable,
              UpcomingPayment
            >,
          ),
          UpcomingPayment,
          PrefetchHooks Function()
        > {
  $$UpcomingPaymentsTableTableManager(
    _$AppDatabase db,
    $UpcomingPaymentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UpcomingPaymentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UpcomingPaymentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UpcomingPaymentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> dedupeKey = const Value.absent(),
                Value<int> amountPaise = const Value.absent(),
                Value<String?> payee = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                Value<DateTime> dueOn = const Value.absent(),
                Value<DateTime> readAt = const Value.absent(),
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UpcomingPaymentsCompanion(
                dedupeKey: dedupeKey,
                amountPaise: amountPaise,
                payee: payee,
                categoryId: categoryId,
                dueOn: dueOn,
                readAt: readAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String dedupeKey,
                required int amountPaise,
                Value<String?> payee = const Value.absent(),
                Value<String?> categoryId = const Value.absent(),
                required DateTime dueOn,
                required DateTime readAt,
                Value<DateTime?> dismissedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UpcomingPaymentsCompanion.insert(
                dedupeKey: dedupeKey,
                amountPaise: amountPaise,
                payee: payee,
                categoryId: categoryId,
                dueOn: dueOn,
                readAt: readAt,
                dismissedAt: dismissedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UpcomingPaymentsTable, UpcomingPayment>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UpcomingPaymentsTable,
                    UpcomingPayment
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UpcomingPaymentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UpcomingPaymentsTable,
      UpcomingPayment,
      $$UpcomingPaymentsTableFilterComposer,
      $$UpcomingPaymentsTableOrderingComposer,
      $$UpcomingPaymentsTableAnnotationComposer,
      $$UpcomingPaymentsTableCreateCompanionBuilder,
      $$UpcomingPaymentsTableUpdateCompanionBuilder,
      (
        UpcomingPayment,
        BaseReferences<_$AppDatabase, $UpcomingPaymentsTable, UpcomingPayment>,
      ),
      UpcomingPayment,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TxnsTableTableManager get txns => $$TxnsTableTableManager(_db, _db.txns);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$GoalDepositsTableTableManager get goalDeposits =>
      $$GoalDepositsTableTableManager(_db, _db.goalDeposits);
  $$TagRulesTableTableManager get tagRules =>
      $$TagRulesTableTableManager(_db, _db.tagRules);
  $$PrefsTableTableManager get prefs =>
      $$PrefsTableTableManager(_db, _db.prefs);
  $$InsightsTableTableManager get insights =>
      $$InsightsTableTableManager(_db, _db.insights);
  $$ChatMessagesTableTableManager get chatMessages =>
      $$ChatMessagesTableTableManager(_db, _db.chatMessages);
  $$GoalPlansTableTableManager get goalPlans =>
      $$GoalPlansTableTableManager(_db, _db.goalPlans);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$PendingCapturesTableTableManager get pendingCaptures =>
      $$PendingCapturesTableTableManager(_db, _db.pendingCaptures);
  $$UpcomingPaymentsTableTableManager get upcomingPayments =>
      $$UpcomingPaymentsTableTableManager(_db, _db.upcomingPayments);
}
