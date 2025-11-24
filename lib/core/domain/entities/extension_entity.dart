import 'package:equatable/equatable.dart';

enum ExtensionType { cloudstream, aniyomi, mangayomi, lnreader }

class ExtensionEntity extends Equatable {
  final String id;
  final String name;
  final String version;
  final ExtensionType type;
  final String language;
  final bool isInstalled;
  final bool isNsfw;
  final String? iconUrl;

  const ExtensionEntity({
    required this.id,
    required this.name,
    required this.version,
    required this.type,
    required this.language,
    required this.isInstalled,
    required this.isNsfw,
    this.iconUrl,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    version,
    type,
    language,
    isInstalled,
    isNsfw,
    iconUrl,
  ];
}
