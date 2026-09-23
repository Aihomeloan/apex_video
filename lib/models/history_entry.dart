class HistoryEntry {
  final String id;
  final List<String> clipPaths;
  final String scriptPrompt;
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.clipPaths,
    required this.scriptPrompt,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'clipPaths': clipPaths,
        'scriptPrompt': scriptPrompt,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        id: json['id'] as String,
        clipPaths: List<String>.from(json['clipPaths'] as List),
        scriptPrompt: json['scriptPrompt'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
