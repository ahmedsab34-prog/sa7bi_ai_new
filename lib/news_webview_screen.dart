import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewsWebViewScreen
    extends StatefulWidget {
  final String url;
  final String title;

  const NewsWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<NewsWebViewScreen>
      createState() =>
          _NewsWebViewScreenState();
}

class _NewsWebViewScreenState
    extends State<NewsWebViewScreen> {
  late final WebViewController controller;

  int progress = 0;

  @override
  void initState() {
    super.initState();

    controller =
        WebViewController()
          ..setJavaScriptMode(
            JavaScriptMode.unrestricted,
          )
          ..setNavigationDelegate(
            NavigationDelegate(
              onProgress: (value) {
                if (!mounted) return;

                setState(() {
                  progress = value;
                });
              },
            ),
          )
          ..loadRequest(
            Uri.parse(widget.url),
          );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF080A10),
      appBar: AppBar(
        backgroundColor:
            const Color(0xFF10131C),
        foregroundColor:
            Colors.white,
        title: Text(
          widget.title,
          maxLines: 1,
          overflow:
              TextOverflow.ellipsis,
        ),
      ),
      body: Column(
        children: [
          if (progress < 100)
            LinearProgressIndicator(
              value:
                  progress / 100,
            ),
          Expanded(
            child:
                WebViewWidget(
              controller:
                  controller,
            ),
          ),
        ],
      ),
    );
  }
}
