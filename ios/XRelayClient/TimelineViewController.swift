import UIKit

final class TimelineViewController: UITableViewController {
    private var posts: [TimelinePost] = []
    private let refresh = UIRefreshControl()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "ホーム"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .compose, target: self, action: #selector(compose))
        tableView.register(PostCell.self, forCellReuseIdentifier: PostCell.reuseID)
        refresh.addTarget(self, action: #selector(load), for: .valueChanged)
        tableView.refreshControl = refresh
        load()
    }

    @objc private func load() {
        RelayClient.shared.getTimeline { [weak self] result in
            self?.refresh.endRefreshing()
            switch result {
            case .success(let posts):
                self?.posts = posts
                self?.tableView.reloadData()
            case .failure(let error):
                self?.showError(error)
            }
        }
    }

    @objc private func compose() {
        let alert = UIAlertController(title: "ポスト", message: nil, preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "いまどうしてる？"
            field.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "キャンセル", style: .cancel))
        alert.addAction(UIAlertAction(title: "投稿", style: .default) { [weak self, weak alert] _ in
            guard let text = alert?.textFields?.first?.text, !text.isEmpty else { return }
            RelayClient.shared.post(text: text) { result in
                switch result {
                case .success:
                    self?.load()
                case .failure(let error):
                    self?.showError(error)
                }
            }
        })
        present(alert, animated: true)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { posts.count }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: PostCell.reuseID, for: indexPath) as! PostCell
        cell.configure(posts[indexPath.row])
        return cell
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "読み込みに失敗しました", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "閉じる", style: .default))
        present(alert, animated: true)
    }
}

final class PostCell: UITableViewCell {
    static let reuseID = "PostCell"
    private let nameLabel = UILabel()
    private let textLabelView = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        nameLabel.font = UIFont.boldSystemFont(ofSize: 16)
        textLabelView.font = UIFont.systemFont(ofSize: 15)
        textLabelView.numberOfLines = 0
        let stack = UIStackView(arrangedSubviews: [nameLabel, textLabelView])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(_ post: TimelinePost) {
        nameLabel.text = post.handle.isEmpty ? post.name : "\(post.name) @\(post.handle)"
        textLabelView.text = post.text
    }
}
