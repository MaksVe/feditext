// Copyright © 2021 Metabolist. All rights reserved.

import Combine
import SwiftUI
import ViewModels

final class MainNavigationViewController: UITabBarController {
  private let viewModel: NavigationViewModel
  private let rootViewModel: RootViewModel
  private var cancellables = Set<AnyCancellable>()

  private var newStatusButtonView: NewStatusButtonView?
  private var newStatusButtonConstraints: [NSLayoutConstraint] = []
    
  init(viewModel: NavigationViewModel, rootViewModel: RootViewModel) {
    self.viewModel = viewModel
    self.rootViewModel = rootViewModel

    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    delegate = self

    viewModel.$presentedComposeStatusViewModel
      .sink { [weak self] in
        if let composeStatusViewModel = $0 {
          self?.presentComposeStatus(composeStatusViewModel: composeStatusViewModel)
        } else {
          self?.dismissComposeStatus()
        }
      }
      .store(in: &cancellables)

    viewModel.$presentingSecondaryNavigation
      .sink { [weak self] in
        if $0 {
          self?.presentSecondaryNavigation()
        } else {
          self?.dismissSecondaryNavigation()
        }
      }
      .store(in: &cancellables)

    viewModel.identityContext.$identity.map(\.pending)
      .removeDuplicates()
      .sink { [weak self] in self?.setupViewControllers(pending: $0) }
      .store(in: &cancellables)

    viewModel.navigations
      .receive(on: DispatchQueue.main)
      .sink { [weak self] in self?.handle(navigation: $0) }
      .store(in: &cancellables)

    NotificationCenter.default.publisher(for: UIScene.willEnterForegroundNotification)
      .debounce(for: .seconds(Self.refreshFromBackgroundDebounceInterval), scheduler: DispatchQueue.main)
      .sink { [weak self] _ in self?.viewModel.refreshIdentity() }
      .store(in: &cancellables)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    viewModel.refreshIdentity()
  }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        installNewStatusButtonBottomConstraintIfNeeded()
    }
    
    private func installNewStatusButtonBottomConstraintIfNeeded() {
        guard let button = newStatusButtonView, newStatusButtonConstraints.isEmpty else { return }

        let constraint: NSLayoutConstraint
        if tabBar.isDescendant(of: view) {
            constraint = button.bottomAnchor.constraint(equalTo: tabBar.topAnchor,
                                                        constant: -.defaultSpacing * 2)
        } else {
            // Tab bar isn't in our hierarchy (floating/hosted elsewhere): fall back to the safe area.
            constraint = button.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                                                        constant: -(tabBar.frame.height + .defaultSpacing * 2))
        }
        constraint.isActive = true
        newStatusButtonConstraints = [constraint]
    }
}

extension MainNavigationViewController: UITabBarControllerDelegate {
  func tabBarController(
    _ tabBarController: UITabBarController,
    shouldSelect viewController: UIViewController
  ) -> Bool {
    if viewController === selectedViewController,
      let navigationController = viewController as? UINavigationController,
      navigationController.viewControllers.count == 1
    {
      (navigationController.viewControllers.first as? ScrollableToTop)?.scrollToTop(animated: true)
    }

    return true
  }
}

extension MainNavigationViewController: NavigationHandling {
  func handle(navigation: Navigation) {
    switch navigation {
    case .notification:
      let index = NavigationViewModel.Tab.notifications.rawValue

      guard let viewControllers = viewControllers,
        viewControllers.count > index,
        let notificationsNavigationController = viewControllers[index] as? UINavigationController,
        let notificationsViewController =
          notificationsNavigationController.viewControllers.first as? NotificationsViewController
      else { break }

      selectedIndex = index
      notificationsNavigationController.popToRootViewController(animated: false)
      notificationsViewController.handle(navigation: navigation)
    default:
      ((selectedViewController as? UINavigationController)?
        .topViewController as? NavigationHandling)?
        .handle(navigation: navigation)
    }
  }
}

extension MainNavigationViewController {
  fileprivate static let secondaryNavigationViewTag = UUID().hashValue
  fileprivate static let composeStatusViewTag = UUID().hashValue
  fileprivate static let refreshFromBackgroundDebounceInterval: TimeInterval = 30

  fileprivate func setupViewControllers(pending: Bool) {
    var controllers: [UIViewController] = [
      TimelinesViewController(
        viewModel: viewModel,
        rootViewModel: rootViewModel
      )
    ]

    if viewModel.identityContext.identity.authenticated && !pending {
      tabBar.isHidden = false
      controllers.append(
        ExploreViewController(
          viewModel: viewModel.exploreViewModel(),
          rootViewModel: rootViewModel
        )
      )
      controllers.append(NotificationsViewController(viewModel: viewModel, rootViewModel: rootViewModel))

      if viewModel.canListConversations {
        let conversationsViewController = TableViewController(
          viewModel: viewModel.conversationsViewModel(),
          rootViewModel: rootViewModel
        )

        conversationsViewController.tabBarItem = NavigationViewModel.Tab.messages.tabBarItem
        conversationsViewController.navigationItem.title = NavigationViewModel.Tab.messages.title

        controllers.append(conversationsViewController)
      }

      setupNewStatusButton()
    } else {
      tabBar.isHidden = true
        newStatusButtonView?.removeFromSuperview()
        newStatusButtonView = nil
        newStatusButtonConstraints = []
    }

    let secondaryNavigationButton = SecondaryNavigationButton(viewModel: viewModel, rootViewModel: rootViewModel)

    for controller in controllers {
      controller.navigationItem.leftBarButtonItem = secondaryNavigationButton
    }

    viewControllers = controllers.map(SwipeableNavigationController.init(rootViewController:))
  }

    func setupNewStatusButton() {
        guard newStatusButtonView == nil else { return }   // also prevents duplicate buttons

        let button = NewStatusButtonView(primaryAction: UIAction { [weak self] _ in
            guard let self = self else { return }
            self.viewModel.presentedComposeStatusViewModel =
                self.rootViewModel.composeStatusViewModel(identityContext: self.viewModel.identityContext)
        })
        button.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(button)
        newStatusButtonView = button

        viewModel.identityContext.$appPreferences.map(\.statusWord).removeDuplicates().sink {
            switch $0 {
            case .toot:
                button.button.accessibilityLabel =
                    NSLocalizedString("compose-button.accessibility-label.toot", comment: "")
            case .post:
                button.button.accessibilityLabel =
                    NSLocalizedString("compose-button.accessibility-label.post", comment: "")
            }
        }
        .store(in: &cancellables)

        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: .newStatusButtonDimension),
            button.heightAnchor.constraint(equalToConstant: .newStatusButtonDimension),
            button.trailingAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.trailingAnchor,
                constant: -.defaultSpacing * 2)
        ])
        // bottom constraint is installed in viewDidLayoutSubviews
    }

  fileprivate func presentSecondaryNavigation() {
    if let presentedViewController = presentedViewController {
      if presentedViewController.view.tag == Self.secondaryNavigationViewTag {
        return
      } else {
        dismiss(animated: true)
      }
    }

    let secondaryNavigationView = SecondaryNavigationView(viewModel: viewModel)
      .environmentObject(rootViewModel)
    let hostingController = UIHostingController(rootView: secondaryNavigationView)

    hostingController.navigationItem.leftBarButtonItem = UIBarButtonItem(
      systemItem: .close,
      primaryAction: UIAction { [weak self] _ in self?.viewModel.presentingSecondaryNavigation = false }
    )
    hostingController.navigationItem.titleView = SecondaryNavigationTitleView(viewModel: viewModel)

    let navigationController = UINavigationController(rootViewController: hostingController)

    navigationController.view.tag = Self.secondaryNavigationViewTag

    present(navigationController, animated: true)
  }

  fileprivate func dismissSecondaryNavigation() {
    if presentedViewController?.view.tag == Self.secondaryNavigationViewTag {
      dismiss(animated: true)
    }
  }

  fileprivate func presentComposeStatus(composeStatusViewModel: ComposeStatusViewModel) {
    if let presentedViewController = presentedViewController {
      if presentedViewController.view.tag == Self.composeStatusViewTag {
        return
      } else {
        dismiss(animated: true)
      }
    }

    let composeStatusViewController = ComposeStatusViewController(
      viewModel: composeStatusViewModel,
      rootViewModel: rootViewModel
    )
    let navigationController = UINavigationController(rootViewController: composeStatusViewController)

    if UIDevice.current.userInterfaceIdiom == .phone {
      navigationController.modalPresentationStyle = .overFullScreen
    } else {
      navigationController.isModalInPresentation = true
    }

    navigationController.view.tag = Self.composeStatusViewTag

    present(navigationController, animated: true)
  }

  fileprivate func dismissComposeStatus() {
    if presentedViewController?.view.tag == Self.composeStatusViewTag {
      dismiss(animated: true)
    }
  }
}
