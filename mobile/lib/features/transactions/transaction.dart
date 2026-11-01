class Transaction {
  final int id;
  final double amount;
  final String type; // "debit" or "credit"
  final String merchant;
  final String category;
  final String? description;
  final DateTime txnDate;

  const Transaction({
    required this.id,
    required this.amount,
    required this.type,
    required this.merchant,
    required this.category,
    required this.txnDate,
    this.description,
  });

  bool get isDebit => type == 'debit';

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as int,
        // Pydantic sends Decimal as a string, so parse via toString()
        amount: double.parse(j['amount'].toString()),
        type: j['type'] as String,
        merchant: j['merchant'] as String,
        category: j['category'] as String,
        description: j['description'] as String?,
        txnDate: DateTime.parse(j['txn_date'] as String),
      );
}

class ImportResult {
  final int imported, duplicates, skipped;
  const ImportResult(this.imported, this.duplicates, this.skipped);

  factory ImportResult.fromJson(Map<String, dynamic> j) =>
      ImportResult(j['imported'] as int, j['duplicates'] as int, j['skipped'] as int);

  String get summary =>
      '$imported imported • $duplicates duplicates ignored • $skipped skipped';
}