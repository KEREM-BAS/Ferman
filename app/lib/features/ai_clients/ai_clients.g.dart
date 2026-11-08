// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ai_clients.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// `ferman-mcp` beside the app's executable ([mcpPumpPath]); null on the web.
/// Tests give it a fixed path.

@ProviderFor(mcpPump)
final mcpPumpProvider = McpPumpProvider._();

/// `ferman-mcp` beside the app's executable ([mcpPumpPath]); null on the web.
/// Tests give it a fixed path.

final class McpPumpProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// `ferman-mcp` beside the app's executable ([mcpPumpPath]); null on the web.
  /// Tests give it a fixed path.
  McpPumpProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mcpPumpProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mcpPumpHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return mcpPump(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$mcpPumpHash() => r'3ba0a26e3780f54fbec5eba865ad1760240e6fda';

/// Claude Desktop's configuration file where one-click setup can write it
/// ([claudeDesktopConfig]), or null. Tests give it a temporary file.

@ProviderFor(claudeDesktopConfigFile)
final claudeDesktopConfigFileProvider = ClaudeDesktopConfigFileProvider._();

/// Claude Desktop's configuration file where one-click setup can write it
/// ([claudeDesktopConfig]), or null. Tests give it a temporary file.

final class ClaudeDesktopConfigFileProvider
    extends $FunctionalProvider<String?, String?, String?>
    with $Provider<String?> {
  /// Claude Desktop's configuration file where one-click setup can write it
  /// ([claudeDesktopConfig]), or null. Tests give it a temporary file.
  ClaudeDesktopConfigFileProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claudeDesktopConfigFileProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claudeDesktopConfigFileHash();

  @$internal
  @override
  $ProviderElement<String?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  String? create(Ref ref) {
    return claudeDesktopConfigFile(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$claudeDesktopConfigFileHash() =>
    r'636b6d92f7a0959bd71a04a5eafa6c5096e4a639';

/// AI clients through MCP (ADR 0019, G94), as `aiClientsProvider`: the host
/// runs while Settings › AI clients' switch (`AppSettings.aiClients`) is on,
/// off by default; the connected clients with their edit permission, read
/// only until the person grants it; the requests they make, answered through
/// a dialog; and their steps, which reach the pages and the history as the
/// person's own do.

@ProviderFor(AiClients)
final aiClientsProvider = AiClientsProvider._();

/// AI clients through MCP (ADR 0019, G94), as `aiClientsProvider`: the host
/// runs while Settings › AI clients' switch (`AppSettings.aiClients`) is on,
/// off by default; the connected clients with their edit permission, read
/// only until the person grants it; the requests they make, answered through
/// a dialog; and their steps, which reach the pages and the history as the
/// person's own do.
final class AiClientsProvider
    extends $NotifierProvider<AiClients, AiClientsState> {
  /// AI clients through MCP (ADR 0019, G94), as `aiClientsProvider`: the host
  /// runs while Settings › AI clients' switch (`AppSettings.aiClients`) is on,
  /// off by default; the connected clients with their edit permission, read
  /// only until the person grants it; the requests they make, answered through
  /// a dialog; and their steps, which reach the pages and the history as the
  /// person's own do.
  AiClientsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'aiClientsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$aiClientsHash();

  @$internal
  @override
  AiClients create() => AiClients();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AiClientsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AiClientsState>(value),
    );
  }
}

String _$aiClientsHash() => r'4445781f00accaa28a80b9cd3a625b6e259a7173';

/// AI clients through MCP (ADR 0019, G94), as `aiClientsProvider`: the host
/// runs while Settings › AI clients' switch (`AppSettings.aiClients`) is on,
/// off by default; the connected clients with their edit permission, read
/// only until the person grants it; the requests they make, answered through
/// a dialog; and their steps, which reach the pages and the history as the
/// person's own do.

abstract class _$AiClients extends $Notifier<AiClientsState> {
  AiClientsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AiClientsState, AiClientsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AiClientsState, AiClientsState>,
              AiClientsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
