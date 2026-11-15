
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
  String? _loadError;

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
              _loadError = null;
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
            await _refreshNavigationState();

            if (!mounted) return;

            setState(() {
              _progress = 100;
              _isLoading = false;
              _loadError = null;
            });
          },
          onWebResourceError: (error) {
            if (!mounted || error.isForMainFrame == false) {
              return;
            }

            setState(() {
              _isLoading = false;
              _progress = 100;
              _loadError =
                  'تعذر تحميل صفحة الخبر. تحقق من الإنترنت وحاول التحديث.';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);

            if (uri == null ||
                !uri.hasAuthority ||
                uri.host.isEmpty ||
                (uri.scheme != 'https' &&
                    uri.scheme != 'http')) {
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
        ),
      );

    final initialUri = Uri.tryParse(widget.url);

    if (initialUri == null ||
        !initialUri.hasAuthority ||
        initialUri.host.isEmpty ||
        (initialUri.scheme != 'https' &&
            initialUri.scheme != 'http')) {
      _isLoading = false;
      _loadError = 'رابط الخبر غير صالح.';
    } else {
      _controller.loadRequest(initialUri);
    }
  }

  Future<void> _refreshNavigationState() async {
    try {
      final canBack = await _controller.canGoBack();

      if (!mounted) return;

      setState(() {
        _canGoBack = canBack;
      });
    } catch (_) {
      // فشل قراءة حالة الرجوع لا يمنع عرض الصفحة.
    }
  }

  /// يرجع إلى الصفحة السابقة داخل الخبر.
  ///
  /// يرجع true إذا تم الرجوع داخل WebView،
  /// وfalse إذا لم توجد صفحة سابقة أو حدث خطأ.
  Future<bool> _goBackInsidePage() async {
    try {
      final canBack = await _controller.canGoBack();

      if (!canBack) {
        if (mounted && _canGoBack) {
          setState(() {
            _canGoBack = false;
          });
        }

        return false;
      }

      await _controller.goBack();
      await _refreshNavigationState();

      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _canGoBack = false;
        });
      }

      return false;
    }
  }

  /// زر الرجوع الظاهر في شريط التطبيق.
  ///
  /// يحاول الرجوع داخل الخبر أولًا، ثم يغلق الشاشة.
  Future<void> _onBackPressed() async {
    final navigatedInsidePage =
        await _goBackInsidePage();

    if (!navigatedInsidePage && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _refreshPage() async {
    if (_isLoading) return;

    try {
      setState(() {
        _loadError = null;
        _isLoading = true;
        _progress = 0;
      });

      await _controller.reload();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _loadError = 'تعذر تحديث صفحة الخبر.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      // نسمح بإغلاق الشاشة مباشرة عندما لا توجد
      // صفحة سابقة داخل WebView.
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        // لو الشاشة أُغلقت بالفعل فلا ننفذ أي إجراء إضافي.
        if (didPop) return;

        // لو الرجوع ممنوع بسبب وجود صفحة سابقة،
        // نرجع داخل الخبر بدل إغلاق الشاشة.
        _onBackPressed();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFF080A10),
          appBar: AppBar(
            backgroundColor: const Color(0xFF10131C),
            foregroundColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: Text(
              widget.title.trim().isEmpty
                  ? 'الخبر'
                  : widget.title.trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            leading: IconButton(
              tooltip: _canGoBack
                  ? 'رجوع داخل الخبر'
                  : 'إغلاق الخبر',
              onPressed: _onBackPressed,
              icon: const Icon(
                Icons.arrow_back_rounded,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'تحديث الصفحة',
                onPressed:
                    _isLoading ? null : _refreshPage,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Color(0xFF67E8F9),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              if (_isLoading)
                SizedBox(
                  height: 2,
                  child: LinearProgressIndicator(
                    value: _progress > 0
                        ? _progress / 100
                        : null,
                    backgroundColor: Colors.transparent,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                      Color(0xFF67E8F9),
                    ),
                  ),
                )
              else
                const SizedBox(height: 2),

              if (_loadError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(
                    10,
                    8,
                    10,
                    4,
                  ),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF251A1A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x66FF7979),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Color(0xFFFF8B8B),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _loadError!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إعادة المحاولة',
                        onPressed: _refreshPage,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Color(0xFF67E8F9),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: WebViewWidget(
                  controller: _controller,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
