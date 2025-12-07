/// Simple subtitle MIME detection inspired by
/// ref/umbrella/src/core/utils/detectSubtitleMimeType.ts.
String? detectSubtitleMimeType(String url) {
  final extension = url.split('.').last.toLowerCase();
  switch (extension) {
    case 'vtt':
      return 'text/vtt';
    case 'srt':
      return 'text/srt';
    case 'sub':
      return 'text/sub';
    case 'sbv':
      return 'text/sbv';
    case 'smi':
      return 'text/smi';
    case 'ssa':
      return 'text/ssa';
    case 'ass':
      return 'text/ass';
    default:
      return null;
  }
}
