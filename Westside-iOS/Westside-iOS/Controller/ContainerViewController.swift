import Foundation
import UIKit

class ContainerViewController: UIViewController, UINavigationControllerDelegate, UIGestureRecognizerDelegate {
    
    enum SidePanelState {
        case closed
        case closing
        case open
        case opening
        
        var isTransitioning: Bool {
            return self == .closing || self == .opening
        }
    }
    
    private let invisibleSwipeZoneWidth = 40
    
    @IBOutlet weak var contentContainerView: UIView!
    @IBOutlet weak var menuContainerView: UIView!
    @IBOutlet weak var menuLeftConstraint: NSLayoutConstraint!
    @IBOutlet weak var menuOverlayView: UIControl!
    
    var westsideTabBarController: WestsideTabBarController
    var contentNavigationController: UINavigationController
    var menuNavigationController: UINavigationController
    var loginViewController: LoginViewController?
    var registerViewController: RegisterViewController?
    
    let reachability: Reachability
    
    let menuBarButton = UIBarButtonItem(
        image: UIImage(named:"icon_menu.png"),
        style: .plain,
        target: self,
        action: #selector(openMenu(_:))
    )
    
    var menuState = SidePanelState.closed {
        didSet {
            if !menuState.isTransitioning {
                menuLeftConstraint.constant = menuState == .open ? 0 : -menuContainerView.bounds.size.width
                UIView.animate(withDuration: 0.25,
                               delay: 0,
                               options: .curveEaseOut,
                               animations: {
                                self.menuContainerView.layoutIfNeeded()
                                self.menuOverlayView.alpha = self.overlayAlpha(forMenu: true)
                })
            }
        }
    }
    
    private var sidePanelGestureRecognizer: UIPanGestureRecognizer!
    
    // MARK: - Init methods
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        menuNavigationController = UINavigationController(rootViewController: MenuViewController(title:"MVC"))
        
        westsideTabBarController = WestsideTabBarController()
        contentNavigationController = UINavigationController(rootViewController: westsideTabBarController)
        contentNavigationController.title = "ContentNavController"
        
        reachability = Reachability(hostname: Store.resourceEndpoint)!
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        menuNavigationController.delegate = self
        contentNavigationController.delegate = self
        
        sidePanelGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
        sidePanelGestureRecognizer.delegate = self
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setUpChildViewController(viewController: menuNavigationController, containerView: menuContainerView)
        setUpChildViewController(viewController: contentNavigationController, containerView: contentContainerView)
        
        view.addGestureRecognizer(sidePanelGestureRecognizer)
        
        contentNavigationController.navigationBar.barTintColor = UIColor.midGray()
        contentNavigationController.navigationItem.leftBarButtonItem = menuBarButton
        menuBarButton.tintColor = UIColor.white
        
        try? reachability.startNotifier()
        
        reachability.whenUnreachable = { [weak self] _ in
            DispatchQueue.main.async {
                self?.view.makeToast(NSLocalizedString("No network connection", comment: ""), duration: 5)
            }
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        contentNavigationController.isNavigationBarHidden = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        structureView()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        structureView()
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return .allButUpsideDown
        }
        
        return .portrait
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - IBActions
    
    @IBAction func closeMenu(_ sender: AnyObject) {
        menuState = .closed
    }
    
    @IBAction func openMenu(_ sender: UIBarButtonItem) {
        menuState = .open
    }

    // MARK: - Private methods
    
    private func structureView() {
        menuState = .closed
        menuOverlayView.alpha = overlayAlpha(forMenu: true)
        sidePanelGestureRecognizer.isEnabled = true
    }
    
    private func overlayAlpha(forMenu: Bool) -> CGFloat {
        return 0.75 / menuContainerView.frame.size.width * menuLeftConstraint.constant + 0.75
    }
    
    private func setupContentNavBar(for viewController: UIViewController) {
        structureView()
        
        viewController.title = "Westside CME"
        viewController.navigationItem.leftBarButtonItem = menuBarButton
        menuBarButton.tintColor = UIColor.white
    }
    
    // MARK: - UINavigationControllerDelegate
    
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController,animated: Bool) {
        if navigationController == contentNavigationController {
            setupContentNavBar(for: viewController)
        }
        
        if (viewController is NavigatableViewController) {
            viewController.navigationItem.leftBarButtonItem = nil
            
        
            for var i in (0..<navigationController.viewControllers.count - 1) {
                viewController.navigationItem.leftBarButtonItem = nil
                navigationController.viewControllers[i].title = "Back"
            }
            
        }
        
        navigationController.isNavigationBarHidden = false
        navigationController.navigationBar.barTintColor = UIColor.primaryColor()
        navigationController.navigationBar.tintColor = UIColor.white
        navigationController.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
    }
    
    // MARK: - Pan gesture
    
    @objc func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            if menuState.isTransitioning {
                let originalConstraint = menuState == .closing ? 0 : -menuContainerView.frame.size.width
                let newConstraint = originalConstraint + recognizer.translation(in: view).x
                
                if newConstraint >= -menuContainerView.frame.size.width && newConstraint <= 0 {
                    menuLeftConstraint.constant = newConstraint
                    menuOverlayView.alpha = overlayAlpha(forMenu: true)
                }
            }
        case .ended:
            if menuState.isTransitioning {
                let shouldClose = (menuState == .opening && menuContainerView.frame.origin.x < -0.75 * menuContainerView.frame.size.width)
                    || (menuState != .opening && menuContainerView.frame.origin.x < -0.25 * menuContainerView.frame.size.width)
                
                menuState = shouldClose ? .closed : .open
            }
        default:
            break
        }
    }
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Pan to close
        if menuState == .open {
            menuState = .closing
            return true
        }
        
        // Pan to open menu on left
        let gestureX = Int(gestureRecognizer.location(in: view).x)
        if gestureX <= invisibleSwipeZoneWidth {
            menuState = .opening
            return true
        }
        
        // Pan to open cart on right, if not on iPad (since activates multitasking)
        if gestureX >= Int(view.frame.size.width) - invisibleSwipeZoneWidth && UIDevice.current.userInterfaceIdiom == .phone {
            return true
        }
        
        return false
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }
    
    // MARK: - MenuViewControllerDelegate
    
    func displayContent(content: ContentDisplayable, title: String, destination: UIViewController?) {
        menuState = .closed
        switch content {
        case .push:
            pushToViewController(viewController: destination!)
        case .view:
            transitionToViewController(viewController: destination!)
        case .action(let action):
            handleAction(action: action)
            return
        }
    }
    
    private func handleAction(action: ContentActionable) {
        switch action {
        case .register:
            showRegisterViewController()
        case .login:
            showLoginViewController()
        case .logout:
            Store.sharedStore.logout()
            menuNavigationController.setViewControllers([MenuViewController(title: "MVC")], animated: false)
        }
    }
    
    func transitionToViewController(viewController: UIViewController) {
        contentNavigationController.setViewControllers([viewController], animated: false)
        setupContentNavBar(for: viewController)
    }

    func pushToViewController(viewController: UIViewController) {
        contentNavigationController.pushViewController(viewController, animated: true)
    }
    
    func showLoginViewController() {
        loginViewController = LoginViewController()
        loginViewController!.delegate = self
        
        let loginNavController = UINavigationController(rootViewController: loginViewController!)
        loginNavController.navigationBar.barTintColor = UIColor.primaryColor()
        loginNavController.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
        present(loginNavController, animated: true, completion: nil)
    }
    
    func showRegisterViewController() {
        registerViewController = RegisterViewController()
        registerViewController!.delegate = self
        
        let registerNavController = UINavigationController(rootViewController: registerViewController!)
        registerNavController.navigationBar.barTintColor = UIColor.primaryColor()
        registerNavController.navigationBar.titleTextAttributes = [NSAttributedStringKey.foregroundColor : UIColor.white]
        present(registerNavController, animated: true, completion: nil)
    }
    
    func removeViewController() {
        dismiss(animated: true) {
            self.loginViewController = nil
            self.registerViewController = nil
        }
    }
}

extension UIViewController {
    var containerViewController: ContainerViewController? {
        var vc = Optional(self)
        while vc != nil {
            if let cvc = vc as? ContainerViewController {
                return cvc
            }
            vc = vc?.parent
        }
        return nil
    }
}

extension ContainerViewController: LoginViewControllerDelegate, RegisterViewControllerDelegate {
    func loginDidSucceed() {
        menuNavigationController.setViewControllers([MenuViewController(title: "MVC")], animated: false)
        removeViewController()
    }
    
    func loginDidCancel() {
        removeViewController()
    }
    
    func registrationDidSucceed() {
        menuNavigationController.setViewControllers([MenuViewController(title: "MVC")], animated: false)
        removeViewController()
    }
    
    func registrationDidCancel() {
        removeViewController()
    }
}
