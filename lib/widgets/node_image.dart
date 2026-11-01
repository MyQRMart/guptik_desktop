import 'package:flutter/widgets.dart';
import '../services/node/node_http.dart';

/// Image.network for node-hosted images: attaches the right bearer token (owner token for this PC's
/// node, anonymous viewer token for other people's nodes) before loading.
class NodeImage extends StatefulWidget {
  const NodeImage(this.url, {super.key, this.fit, this.width, this.height, this.errorBuilder, this.loadingBuilder});
  final String url;
  final BoxFit? fit;
  final double? width;
  final double? height;
  final ImageErrorWidgetBuilder? errorBuilder;
  final ImageLoadingBuilder? loadingBuilder;

  @override
  State<NodeImage> createState() => _NodeImageState();
}

class _NodeImageState extends State<NodeImage> {
  Map<String, String>? _headers;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(NodeImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _prepare();
  }

  Future<void> _prepare() async {
    final u = Uri.tryParse(widget.url);
    var h = NodeHttp.headersFor(widget.url);
    if (h.isEmpty && u != null && u.hasAuthority && !NodeHttp.isOwnNode(u)) {
      await NodeHttp.viewerToken(u);
      h = NodeHttp.headersFor(widget.url);
    }
    if (!mounted) return;
    setState(() => _headers = h);
  }

  @override
  Widget build(BuildContext context) {
    final h = _headers;
    if (h == null) return SizedBox(width: widget.width, height: widget.height);
    return Image.network(widget.url,
        headers: h.isEmpty ? null : h,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder);
  }
}
