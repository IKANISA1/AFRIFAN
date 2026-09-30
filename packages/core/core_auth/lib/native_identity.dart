/// Disabled, explicitly selected native identity foundation.
///
/// This library does not select or replace the app's Supabase authentication.
/// Supply an independently accepted OS protected credential store before enabling.
library;

export 'src/native_identity/controller.dart';
export 'src/native_identity/io_transport.dart';
export 'src/native_identity/journal.dart';
export 'src/native_identity/models.dart';
export 'src/native_identity/ports.dart';
export 'src/native_identity/wire_client.dart';
