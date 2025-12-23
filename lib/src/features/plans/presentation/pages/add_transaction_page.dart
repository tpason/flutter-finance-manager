import 'package:flutter/material.dart';

import 'set_new_plan_page.dart';

/// Trang Add dùng lại logic nhập giao dịch nhưng copy khác title/label.
class AddTransactionPage extends StatelessWidget {
  const AddTransactionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SetNewPlanPage(
      title: 'Add Transaction',
      subtitle: 'Log a new transaction quickly.',
      nameLabel: 'Title',
      nameHint: 'Transaction title',
      descriptionLabel: 'Description',
      descriptionHint: 'What is this for?',
      categoryLabel: 'Category',
      amountLabel: 'Amount',
      amountHint: 'Enter amount',
      saveLabel: 'Add Transaction',
    );
  }
}

