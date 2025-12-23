import 'package:flutter/material.dart';

import 'set_new_plan_page.dart';

/// Màn hình Add New Plan độc lập, dùng cùng UI với SetNewPlanPage.
class AddPlanPage extends StatelessWidget {
  const AddPlanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SetNewPlanPage(
      showBackButton: false,
    );
  }
}

