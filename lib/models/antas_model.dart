class Antas {
  final int id;
  final int teacher_id;
  final int level;
  final String title;
  final bool is_done; // Add is_done field
  final List<Aralin> aralins; // Assuming Aralin is a separate model for the aralins list

  Antas({
    required this.id,
    required this.teacher_id,
    required this.level,
    required this.title,
    required this.is_done,
    required this.aralins,
  });

  factory Antas.fromJson(Map<String, dynamic> json) {
    return Antas(
      id: json['id'] as int,
      teacher_id: json['teacher_id'] as int,
      level: json['level'] as int,
      title: json['title'] as String,
      is_done: json['is_done'] as bool, // Parse is_done as boolean
      aralins: (json['aralins'] as List<dynamic>?)
          ?.map((aralinJson) => Aralin.fromJson(aralinJson))
          .toList() ?? [],
    );
  }
}

class Aralin {
  final int id;
  final int aralin_no;
  final String title;
  final String details;
  final String attachment_filename;

  Aralin({
    required this.id,
    required this.aralin_no,
    required this.title,
    required this.details,
    required this.attachment_filename,
  });

  factory Aralin.fromJson(Map<String, dynamic> json) {
    return Aralin(
      id: json['id'] as int,
      aralin_no: json['aralin_no'] as int,
      title: json['title'] as String,
      details: json['details'] as String,
      attachment_filename: json['attachment_filename'] as String,
    );
  }
}