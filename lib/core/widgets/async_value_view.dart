import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/async_state.dart';
import 'app_empty_view.dart';
import 'app_error_view.dart';
import 'app_loading_view.dart';

/// Renders a Riverpod [AsyncValue] using shared loading, error, and empty views.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.builder,
    this.isEmpty,
    this.loadingMessage,
    this.emptyTitle = 'Nothing to display',
    this.emptyMessage,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final bool Function(T data)? isEmpty;
  final String? loadingMessage;
  final String emptyTitle;
  final String? emptyMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => AppLoadingView(message: loadingMessage),
      error: (error, _) => AppErrorView(
        message:
            value.errorMessage ?? 'Something went wrong. Please try again.',
        onRetry: onRetry,
      ),
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return AppEmptyView(
            title: emptyTitle,
            message: emptyMessage,
            actionLabel: onRetry != null ? 'Refresh' : null,
            onAction: onRetry,
          );
        }
        return builder(data);
      },
    );
  }
}
