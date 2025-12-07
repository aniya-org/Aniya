import 'package:aniya/core/extractor/base/extractor_info.dart';
import 'package:aniya/core/extractor/extractors/asianload_extractor.dart';
import 'package:aniya/core/extractor/extractors/bilibili_extractor.dart';
import 'package:aniya/core/extractor/extractors/filemoon_extractor.dart';
import 'package:aniya/core/extractor/extractors/gogo_cdn_extractor.dart';
import 'package:aniya/core/extractor/extractors/jwplayer_extractor.dart';
import 'package:aniya/core/extractor/extractors/kwik_extractor.dart';
import 'package:aniya/core/extractor/extractors/megacloud_extractor.dart';
import 'package:aniya/core/extractor/extractors/megaup_extractor.dart';
import 'package:aniya/core/extractor/extractors/mixdrop_extractor.dart';
import 'package:aniya/core/extractor/extractors/mp4player_extractor.dart';
import 'package:aniya/core/extractor/extractors/mp4upload_extractor.dart';
import 'package:aniya/core/extractor/extractors/multiquality_extractor.dart';
import 'package:aniya/core/extractor/extractors/noodlemagazine_extractor.dart';
import 'package:aniya/core/extractor/extractors/photojin_extractor.dart';
import 'package:aniya/core/extractor/extractors/pixfusion_extractor.dart';
import 'package:aniya/core/extractor/extractors/pornhat_extractor.dart';
import 'package:aniya/core/extractor/extractors/pornhub_extractor.dart';
import 'package:aniya/core/extractor/extractors/rubystream_extractor.dart';
import 'package:aniya/core/extractor/extractors/saicord_extractor.dart';
import 'package:aniya/core/extractor/extractors/send_extractor.dart';
import 'package:aniya/core/extractor/extractors/smashystream_extractor.dart';
import 'package:aniya/core/extractor/extractors/speedostream_extractor.dart';
import 'package:aniya/core/extractor/extractors/streambucket_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamsb_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamhub_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamingcommunityz_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamlare_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamoupload_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamp2p_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamtape_extractor.dart';
import 'package:aniya/core/extractor/extractors/streamwish_extractor.dart';
import 'package:aniya/core/extractor/extractors/uperbox_extractor.dart';
import 'package:aniya/core/extractor/extractors/upvid_extractor.dart';
import 'package:aniya/core/extractor/extractors/vcdnlare_extractor.dart';
import 'package:aniya/core/extractor/extractors/vidcloud_extractor.dart';
import 'package:aniya/core/extractor/extractors/vidhide_extractor.dart';
import 'package:aniya/core/extractor/extractors/vidmoly_extractor.dart';
import 'package:aniya/core/extractor/extractors/vidsrc_extractor.dart';
import 'package:aniya/core/extractor/extractors/vizcloud_extractor.dart';
import 'package:aniya/core/extractor/extractors/voe_extractor.dart';

/// Builds the list of bundled extractor infos.
/// Based on ref/umbrella/src/data/services/extractor/data/datasource/extractors/index.ts.
///
List<ExtractorInfo> buildDefaultVideoExtractors() {
  return [
    // Already implemented
    GogoCdnExtractor.info,
    VidCloudExtractor.info,
    StreamSbExtractor.info,
    StreamWishExtractor.info,
    StreamTapeExtractor.info,
    // High-priority extractors
    KwikExtractor.info,
    FilemoonExtractor.info,
    MegaUpExtractor.info,
    MixDropExtractor.info,
    VidHideExtractor.info,
    JWPlayerExtractor.info,
    // Medium-priority extractors
    AsianLoadExtractor.info,
    BilibiliExtractor.info,
    Mp4UploadExtractor.info,
    Mp4PlayerExtractor.info,
    SmashyStreamExtractor.info,
    StreamHubExtractor.info,
    StreamLareExtractor.info,
    VidMolyExtractor.info,
    VizCloudExtractor.info,
    VoeExtractor.info,
    // Lower-priority extractors
    VcdnlareExtractor.info,
    MegacloudExtractor.info,
    MultiQualityExtractor.info,
    NoodleMagazineExtractor.info,
    PhotojinExtractor.info,
    PixFusionExtractor.info,
    PornhatExtractor.info,
    PornhubExtractor.info,
    RubystreamExtractor.info,
    SaicordExtractor.info,
    SendExtractor.info,
    SpeedoStreamExtractor.info,
    StreamBucketExtractor.info,
    StreamingCommunityzExtractor.info,
    StreamOUploadExtractor.info,
    StreamP2PExtractor.info,
    UperboxExtractor.info,
    VidSrcExtractor.info,
    UpVidExtractor.info,
  ];
}
