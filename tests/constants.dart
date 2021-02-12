Map<String, String> hashes = {
  'blob_1.txt': '9f5d907f6553b099b8dfe749b179951411a3e5ba',
  'blob_2.txt': 'b6fc4c620b67d95f953a5c1c1230aaab5db5a1b0',
  'blob_3.txt': 'e69de29bb2d1d6434b8b29ae775ad8c2e48c5391',
};

bool listEq(List list1, List list2) {
  if (list1.length != list2.length) return false;
  for (var i = 0; i < list1.length; i++) {
    if (list1[i] != list2[i]) return false;
  }
  return true;
}