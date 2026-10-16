import 'dart:async';
import 'dart:ui' show FlutterView, SemanticsRole;

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The screen-reader side of the notices (`Toast`, `Banner`): one
/// semantics node labelled by the text inside [child], announced when it
/// appears. An internal building block of the feedback group, kept out of
/// the component library.
///
/// Without [alert] it is a polite live region, the design's
/// `role="status"`.
///
/// With [alert] (a danger toast, a danger or warning banner: the design's
/// `role="alert"`, `aria-live="assertive"`) it is announced assertively.
/// Flutter allows no live region on a node with the alert role, so:
///
/// - on the web the node has the alert role, which browsers announce
///   assertively on their own;
/// - elsewhere, where the platform supports announcements
///   ([MediaQueryData.supportsAnnounce]: the desktop systems, iOS), the
///   node has the alert role and the text is also sent once as an
///   assertive announcement ([SemanticsService.sendAnnouncement]) when it
///   appears and again when it changes, because Flutter's desktop bridges
///   do not announce roles;
/// - where announcements are not supported (Android) it stays a polite
///   live region, as Flutter's own error texts do.
///
/// The announced text is what the node's label holds: the text of the
/// [RichText]s below, in order, leaving out nested semantics containers
/// (the action buttons) and excluded semantics.
class FeedbackSemantics extends StatefulWidget {
  /// Describes [child] to screen readers, assertively when [alert].
  const new({required this.alert, required this.child, super.key});

  /// Whether the notice is an alert, announced assertively.
  final bool alert;

  /// The notice.
  final Widget child;

  /// The text of the [RichText]s below [root], as the merged semantics
  /// label holds it: nested semantics containers and excluded semantics
  /// are left out, the parts joined by line breaks.
  static String textBelow(Element root) {
    final parts = <String>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Semantics &&
          (widget.container || widget.excludeSemantics)) {
        return;
      }
      if (widget is ExcludeSemantics && widget.excluding) return;
      if (widget is RichText) {
        final text = widget.text.toPlainText(includePlaceholders: false);
        if (text.trim().isNotEmpty) parts.add(text);
        return;
      }
      element.visitChildren(visit);
    }

    root.visitChildren(visit);
    return parts.join('\n');
  }

  @override
  State<FeedbackSemantics> createState() => _FeedbackSemanticsState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('alert', value: alert, ifTrue: 'alert'));
  }
}

class _FeedbackSemanticsState extends State<FeedbackSemantics> {
  /// The text last announced, so an unchanged notice is not announced
  /// again on rebuild.
  String? _announced;
  bool _scheduled = false;
  FlutterView? _view;
  TextDirection _direction = TextDirection.ltr;

  void _scheduleAnnouncement() {
    if (_scheduled) return;
    _scheduled = true;
    // After the frame, when the text below has been built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final view = _view;
      if (!mounted || view == null) return;
      var text = '';
      // The node's own Semantics is the first element below this one.
      context.visitChildElements(
        (semantics) => text = FeedbackSemantics.textBelow(semantics),
      );
      if (text.isEmpty || text == _announced) return;
      _announced = text;
      unawaited(
        SemanticsService.sendAnnouncement(
          view,
          text,
          _direction,
          assertiveness: Assertiveness.assertive,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final supportsAnnounce =
        MediaQuery.maybeSupportsAnnounceOf(context) ?? false;
    final alertRole = widget.alert && (kIsWeb || supportsAnnounce);
    if (widget.alert && !kIsWeb && supportsAnnounce) {
      _view = View.maybeOf(context);
      _direction = Directionality.of(context);
      _scheduleAnnouncement();
    } else {
      // A notice that becomes an alert again is announced again.
      _announced = null;
    }
    return Semantics(
      container: true,
      role: alertRole ? SemanticsRole.alert : null,
      liveRegion: !alertRole,
      child: widget.child,
    );
  }
}
