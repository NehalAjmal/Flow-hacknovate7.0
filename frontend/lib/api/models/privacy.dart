import '../../core/json.dart';

class DataCategory {
  const DataCategory({required this.name, required this.description, required this.itemCount, this.retentionDays});
  final String name;
  final String description;
  final int itemCount;
  final int? retentionDays;

  factory DataCategory.fromJson(Json j) => DataCategory(
    name: str(j['name']) ?? '',
    description: str(j['description']) ?? '',
    itemCount: intOrNull(j['item_count']) ?? 0,
    retentionDays: intOrNull(j['retention_days']),
  );
}

class DataSummary {
  const DataSummary({required this.categories});
  final List<DataCategory> categories;

  factory DataSummary.fromJson(Json j) => DataSummary(categories: asJsonList(j['categories']).map(DataCategory.fromJson).toList());
}

enum ExportStatus implements WireEnum {
  pending('pending'),
  ready('ready'),
  failed('failed');

  const ExportStatus(this.wire);
  @override
  final String wire;
}

class ExportJob {
  const ExportJob({required this.id, required this.status, this.downloadUrl});
  final String id;
  final ExportStatus status;
  final String? downloadUrl;

  factory ExportJob.fromJson(Json j) => ExportJob(
    id: reqStr(j, 'id'),
    status: enumFromWire(ExportStatus.values, j['status'], ExportStatus.pending),
    downloadUrl: str(j['download_url']),
  );
}
