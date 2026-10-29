class CmsPageModel {
  const CmsPageModel({
    required this.title,
    required this.content,
    required this.email,
    required this.mobile,
  });

  final String title;
  final String content;
  final String email;
  final String mobile;

  factory CmsPageModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : (json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : json);

    return CmsPageModel(
      title: (data['title'] ?? '').toString(),
      content: (data['content'] ?? '').toString(),
      email: (data['email'] ?? '').toString(),
      mobile: (data['mobile'] ?? '').toString(),
    );
  }
}
