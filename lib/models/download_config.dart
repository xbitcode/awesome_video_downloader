class DownloadConfig {
  final String url;
  final String title;
  final int minimumBitrate;
  final bool prefersHDR;
  final bool prefersMultichannel;
  final Map<String, String>? authentication;
  final Map<String, dynamic>? additionalOptions;

  DownloadConfig({
    required this.url,
    required this.title,
    this.minimumBitrate = 2000000,
    this.prefersHDR = false,
    this.prefersMultichannel = false,
    this.authentication,
    this.additionalOptions,
  });

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'title': title,
      'minimumBitrate': minimumBitrate,
      'prefersHDR': prefersHDR,
      'prefersMultichannel': prefersMultichannel,
      'authentication': authentication,
      'additionalOptions': additionalOptions,
    };
  }
}


// our downloadconfig also contains authentication, can we also use that to fix the problem one as well?