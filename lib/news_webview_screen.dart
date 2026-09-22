import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NewsWebViewScreen extends StatefulWidget {
  final String url;
  final String title;

  const NewsWebViewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<NewsWebViewScreen> createState() =>
      _NewsWebViewScreenState();
}

class _NewsWebViewScreenState
    extends State<NewsWebViewScreen> {
  late final WebViewController _controller;

  int _progress = 0;
  bool _isLoading = true;
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setBackgroundColor(
        const Color(0xFF080A10),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;

            setState(() {
              _isLoading = true;
              _progress = 0;
            });
          },
          onProgress: (value) {
            if (!mounted) return;

            setState(() {
              _progress = value;
              _isLoading = value < 100;
            });
          },
          onPageFinished: (_) async {
            if (!mounted) return;

            final canBack =
                await _controller.canGoBack();

            if (!mounted) return;

            setState(() {
              _progress = 100;
              _isLoading = false;
              _canGoBack = canBack;
            });
          },
          onNavigationRequest: (request) {
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(
        Uri.parse(widget.url),
      );
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();

      if (mounted) {
        setState(() {
          _canGoBack = true;
        });
      }

      return false;
    }

    return true;
  }

  Future<void> _refreshPage() async {
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor:
              const Color(0xFF080A10),
          appBar: AppBar(
            backgroundColor:
                const Color(0xFF10131C),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              widget.title.trim().isEmpty
                  ? 'الخبر'
                  : widget.title.trim(),
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            leading: IconButton(
              tooltip: 'رجوع',
              onPressed: () async {
                final shouldClose =
                    await _handleBack();

                if (shouldClose &&
                    mounted) {
                  Navigator.of(context).pop();
                }
              },
              icon: const Icon(
                Icons.arrow_back_rounded,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'تحديث',
                onPressed: _refreshPage,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color:
                      Color(0xFFFFD76A),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoading)
                SizedBox(
                  height: 2,
                  child:
                      LinearProgressIndicator(
                    value: _progress > 0
                        ? _progress / 100
                        : null,
                    backgroundColor:
                        Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      Color(0xFFFFD76A),
                    ),
                  ),
                )
              else
                const SizedBox(height: 2),
              Expanded(
                child: WebViewWidget(
                  controller:
                      _controller,
                ),
              ),
            ],
          ),
          bottomNavigationBar:
              SafeArea(
            top: false,
            child: Container(
              height: 52,
              decoration:
                  const BoxDecoration(
                color: Color(0xFF10131C),
                border: Border(
                  top: BorderSide(
                    color: Color(0x22FFFFFF),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,
                children: [
                  IconButton(
                    tooltip:
                        'رجوع داخل الخبر',
                    onPressed: _canGoBack
                        ? () async {
                            await _controller
                                .goBack();

                            if (mounted) {
                              final canBack =
                                  await _controller
                                      .canGoBack();

                              if (mounted) {
                                setState(() {
                                  _canGoBack =
                                      canBack;
                                });
                              }
                            }
                          }
                        : null,
                    icon: Icon(
                      Icons
                          .arrow_back_ios_new_rounded,
                      color: _canGoBack
                          ? Colors.white
                          : Colors.white24,
                      size: 19,
                    ),
                  ),
                  IconButton(
                    tooltip: 'تحديث',
                    onPressed: _refreshPage,
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color:
                          Color(0xFFFFD76A),
                    ),
                  ),
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).pop();
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
