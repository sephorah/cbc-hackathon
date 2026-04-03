import '../models/work_signal.dart';

/// Fetches incident and on-call data from Rootly MCP.
/// Full implementation: issues #13, #14.
class RootlyService {
  Future<WorkSignal> fetchWorkSignal() async {
    // TODO(issue-13/14): implement Rootly MCP integration via `http` package
    throw UnimplementedError(
      'RootlyService not yet implemented — use MockRootlyService for demo.',
    );
  }
}
