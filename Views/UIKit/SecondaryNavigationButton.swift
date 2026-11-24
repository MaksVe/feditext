// Copyright © 2021 Metabolist. All rights reserved.

import Combine
import SDWebImage
import UIKit
import ViewModels

final class SecondaryNavigationButton: UIBarButtonItem {
  private var cancellables = Set<AnyCancellable>()

  init(viewModel: NavigationViewModel, rootViewModel: RootViewModel) {
    super.init()

    let button = UIButton(
      type: .custom,
      primaryAction: UIAction { _ in viewModel.presentingSecondaryNavigation = true }
    )

      button.accessibilityLabel = NSLocalizedString("secondary-navigation-button.accessibility-title", comment: "")
      button.layer.cornerRadius = .barButtonItemDimension / 2
      button.clipsToBounds = true

      let avatarImageView = SDAnimatedImageView()

      avatarImageView.translatesAutoresizingMaskIntoConstraints = false
      avatarImageView.contentMode = .scaleAspectFill
      avatarImageView.isUserInteractionEnabled = false  // let taps and long-press reach the button
      button.addSubview(avatarImageView)

      NSLayoutConstraint.activate([
        avatarImageView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
        avatarImageView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
        avatarImageView.topAnchor.constraint(equalTo: button.topAnchor),
        avatarImageView.bottomAnchor.constraint(equalTo: button.bottomAnchor),
      ])

    customView = button

    NSLayoutConstraint.activate([
      button.widthAnchor.constraint(equalToConstant: .barButtonItemDimension),
      button.heightAnchor.constraint(equalToConstant: .barButtonItemDimension),
    ])

      viewModel.identityContext.$identity
        .sink { identity in
          avatarImageView.sd_setImage(
            with: identity.image,
            placeholderImage: UIImage(systemName: "line.horizontal.3")
          )
        }
        .store(in: &cancellables)

      viewModel.identityContext.$appPreferences
        .map { $0.animateAvatars == .everywhere }
        .removeDuplicates()
        .sink { animate in
          avatarImageView.autoPlayAnimatedImage = animate

          if animate {
            avatarImageView.startAnimating()
          } else {
            avatarImageView.stopAnimating()
          }
        }
        .store(in: &cancellables)

    let imageTransformer = SDImageRoundCornerTransformer(
      radius: .greatestFiniteMagnitude,
      corners: .allCorners,
      borderWidth: 0,
      borderColor: nil
    )

    viewModel.$recentIdentities
      .sink { identities in
        button.menu = UIMenu(
          children: identities.map { identity in
            UIDeferredMenuElement { completion in
              let action = UIAction(title: identity.handle) { _ in
                rootViewModel.identitySelected(id: identity.id)
              }

              if let image = identity.image {
                SDWebImageManager.shared.loadImage(
                  with: image,
                  options: [.transformAnimatedImage],
                  context: [.imageTransformer: imageTransformer],
                  progress: nil
                ) { (image, _, _, _, _, _) in
                  action.image = image

                  completion([action])
                }
              } else {
                completion([action])
              }
            }
          }
        )
      }
      .store(in: &cancellables)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
}
