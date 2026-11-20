class Equipment {
  Equipment({
    required this.id,
    required String name,
    required this.quantity,
    this.inUse = 0,
    String unit = 'pcs',
    this.condition = 'Ready',
    String location = '',
    String notes = '',
  }) : name = name.trim(),
       unit = unit.trim(),
       location = location.trim(),
       notes = notes.trim() {
    if (this.name.isEmpty || this.name.length > 180) {
      throw ArgumentError('Enter an equipment name (up to 180 characters).');
    }
    if (quantity < 1 || inUse < 0 || inUse > quantity) {
      throw ArgumentError(
        'In-use quantity must be between zero and total quantity.',
      );
    }
    if (this.unit.isEmpty || this.unit.length > 40) {
      throw ArgumentError('Enter a unit (up to 40 characters).');
    }
    if (!conditions.contains(condition)) {
      throw ArgumentError('Choose a valid equipment condition.');
    }
  }

  static const conditions = ['Ready', 'Needs maintenance', 'Out of service'];
  final String id, name, unit, condition, location, notes;
  final int quantity, inUse;
  int get available => condition == 'Ready' ? quantity - inUse : 0;

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
    id: json['id'] as String,
    name: json['name'] as String,
    quantity: json['quantity'] as int,
    inUse: json['in_use'] as int,
    unit: json['unit'] as String,
    condition: json['condition'] as String,
    location: json['location'] as String,
    notes: json['notes'] as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'quantity': quantity,
    'in_use': inUse,
    'unit': unit,
    'condition': condition,
    'location': location,
    'notes': notes,
  };
}
