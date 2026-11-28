// Copyright © 2020 Metabolist. All rights reserved.

import UIKit
import ViewModels

final class StatusTableViewCell: UITableViewCell {
  var viewModel: StatusViewModel?

  override func updateConfiguration(using state: UICellConfigurationState) {
    guard let viewModel = viewModel else { return }

    contentConfiguration = StatusContentConfiguration(viewModel: viewModel).updated(for: state)
    accessibilityElements = [contentView]
  }

  override func layoutSubviews() {
    super.layoutSubviews()

    separatorInset.left = UIDevice.current.userInterfaceIdiom == .phone ? 0 : layoutMargins.left

    if viewModel?.configuration.hasReplyFollowing ?? false {
      // Hide the separator by insetting it to zero width.
      // Don't use `.greatestFiniteMagnitude` here: the separator view ends up that wide,
      // which breaks the system's touch hit-testing for the whole window, so touches stop reaching the app.
      separatorInset.right = max(bounds.width - separatorInset.left, 0)
    } else {
      separatorInset.right = UIDevice.current.userInterfaceIdiom == .phone ? 0 : layoutMargins.right
    }
  }
}
