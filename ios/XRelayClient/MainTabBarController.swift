import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        let home = UINavigationController(rootViewController: TimelineViewController())
        home.tabBarItem = UITabBarItem(tabBarSystemItem: .favorites, tag: 0)
        let search = UINavigationController(rootViewController: SearchViewController())
        search.tabBarItem = UITabBarItem(tabBarSystemItem: .search, tag: 1)
        let settings = UINavigationController(rootViewController: SettingsViewController())
        settings.tabBarItem = UITabBarItem(tabBarSystemItem: .more, tag: 2)
        viewControllers = [home, search, settings]
    }
}
