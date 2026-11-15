import UIKit

final class SettingsViewController: UITableViewController {
    private let urlField = UITextField()
    private let profileField = UITextField()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "設定"
        urlField.text = RelayClient.shared.baseURL.absoluteString
        urlField.placeholder = "http://localhost:3000"
        urlField.autocapitalizationType = .none
        urlField.keyboardType = .URL
        profileField.text = RelayClient.shared.profileName
        profileField.placeholder = "account1（任意）"
        tableView.tableFooterView = UIView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int { 1 }
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { 3 }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "リレーURL"
            cell.accessoryView = urlField
            urlField.frame = CGRect(x: 0, y: 0, width: 220, height: 36)
        case 1:
            cell.textLabel?.text = "プロフィール"
            cell.accessoryView = profileField
            profileField.frame = CGRect(x: 0, y: 0, width: 180, height: 36)
        default:
            cell.textLabel?.text = "保存"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = view.tintColor
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.row == 2 else { return }
        guard let urlText = urlField.text, let url = URL(string: urlText), url.scheme != nil else {
            let alert = UIAlertController(title: "URLエラー", message: APIError.invalidURL.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "閉じる", style: .default))
            present(alert, animated: true)
            return
        }
        RelayClient.shared.baseURL = url
        RelayClient.shared.profileName = profileField.text?.isEmpty == true ? nil : profileField.text
        navigationController?.popViewController(animated: true)
    }
}
