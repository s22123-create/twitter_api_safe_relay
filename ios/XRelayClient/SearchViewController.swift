import UIKit

final class SearchViewController: UITableViewController, UISearchBarDelegate {
    private let searchBar = UISearchBar()
    private var posts: [TimelinePost] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "検索"
        searchBar.placeholder = "Xを検索"
        searchBar.delegate = self
        tableView.tableHeaderView = searchBar
        tableView.register(PostCell.self, forCellReuseIdentifier: PostCell.reuseID)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        guard let query = searchBar.text, !query.isEmpty else { return }
        searchBar.resignFirstResponder()
        RelayClient.shared.search(query) { [weak self] result in
            switch result {
            case .success(let posts):
                self?.posts = posts
                self?.tableView.reloadData()
            case .failure(let error):
                let alert = UIAlertController(title: "検索に失敗しました", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "閉じる", style: .default))
                self?.present(alert, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { posts.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.reuseID, for: indexPath) as! PostCell
        cell.configure(posts[indexPath.row])
        return cell
    }
}
