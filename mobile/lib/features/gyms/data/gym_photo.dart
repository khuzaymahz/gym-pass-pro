class GymPhoto {
  final String id;
  final String url;
  final int sortOrder;
  final String? altTextEn;
  final String? altTextAr;

  const GymPhoto({
    required this.id,
    required this.url,
    required this.sortOrder,
    this.altTextEn,
    this.altTextAr,
  });

  factory GymPhoto.fromJson(Map<String, dynamic> json) {
    return GymPhoto(
      id: json['id'] as String,
      url: json['url'] as String,
      sortOrder: (json['sortOrder'] ?? json['sort_order'] ?? 0) as int,
      altTextEn: json['altTextEn'] as String? ?? json['alt_text_en'] as String?,
      altTextAr: json['altTextAr'] as String? ?? json['alt_text_ar'] as String?,
    );
  }
}
