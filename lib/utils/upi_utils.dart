/// Returns true if [value] looks like a well-formed UPI Virtual Payment Address.
///
/// Accepts common formats:
///   ramlal@oksbi, 9876543210@ybl, merchant@ibl, abc.def@okaxis
/// Rejects:
///   bare words with no @, double-@ strings, empty handles / VPA banks
bool isValidUpiId(String value) {
  final parts = value.trim().split('@');
  if (parts.length != 2) return false;
  final handle = parts[0];
  final vpa = parts[1];
  if (handle.isEmpty || vpa.length < 2) return false;
  return RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(handle) &&
      RegExp(r'^[a-zA-Z0-9.]+$').hasMatch(vpa);
}
