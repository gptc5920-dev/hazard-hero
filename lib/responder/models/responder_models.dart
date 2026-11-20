class ResponderUser {
  const ResponderUser({
    required this.id,
    required this.email,
    required this.name,
    required this.office,
  });
  final String id, email, name, office;
  factory ResponderUser.fromJson(Map<String, dynamic> j) => ResponderUser(
    id: j['id'].toString(),
    email: j['email'].toString(),
    name: (j['full_name'] ?? '${j['first_name'] ?? ''} ${j['last_name'] ?? ''}')
        .toString()
        .trim(),
    office: j['office']?.toString() ?? '',
  );
}

class ManagedRecord {
  const ManagedRecord(this.data);
  final Map<String, dynamic> data;
  String get id => data['id'].toString();
  String get title =>
      (data['title'] ??
              data['name'] ??
              data['organization_name'] ??
              data['email'] ??
              data['alert_code'] ??
              id)
          .toString();
}

enum DeletionMode { none, soft, permanent }

class CrudModule {
  const CrudModule(
    this.path,
    this.label,
    this.icon,
    this.fields, {
    this.actions = const [],
    this.deletionMode = DeletionMode.soft,
  });
  final String path, label;
  final dynamic icon;
  final List<FormFieldSpec> fields;
  final List<String> actions;
  final DeletionMode deletionMode;

  bool get canDelete => deletionMode != DeletionMode.none;
  bool get supportsSoftDelete => deletionMode == DeletionMode.soft;
}

enum FormFieldDataType {
  text,
  integer,
  decimal,
  email,
  phone,
  password,
  dateTime,
  choice,
  boolean,
  stringList,
  relation,
}

class FormFieldSpec {
  const FormFieldSpec(
    this.name,
    this.label, {
    this.required = false,
    this.requiredOnCreate = false,
    this.multiline = false,
    this.type = FormFieldDataType.text,
    this.choices = const [],
    this.minValue,
    this.maxValue,
    this.maxLength,
    this.relationModule,
    this.relationLabelField,
    this.helperText,
  });
  final String name, label;
  final bool required, requiredOnCreate, multiline;
  final FormFieldDataType type;
  final List<String> choices;
  final num? minValue, maxValue;
  final int? maxLength;
  final String? relationModule, relationLabelField, helperText;

  bool get number =>
      type == FormFieldDataType.integer || type == FormFieldDataType.decimal;
  bool get dateTime => type == FormFieldDataType.dateTime;
  bool get isChoice => type == FormFieldDataType.choice;
  bool get isBoolean => type == FormFieldDataType.boolean;
  bool get isStringList => type == FormFieldDataType.stringList;
  bool get isRelation => type == FormFieldDataType.relation;
}
