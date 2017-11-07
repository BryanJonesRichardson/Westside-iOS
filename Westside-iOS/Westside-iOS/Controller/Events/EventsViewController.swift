import UIKit
import Forge

class EventsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    private var events = Array<Event>()
    
    init(title: String) {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString(title, comment: "")
//        self.navigationItem.titleView = UIImageView(image: UIImage(named: "logo_fox_header"))
//        self.tabBarItem.image = UIImage(named: "ico_upcoming_off")
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.alwaysBounceVertical = false
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.register(class: EventCell.self)
    }
    
    // MARK: - Actions
    func loadEvents(completion: ((URLResult<Array<Event>>) -> Void)? = nil) {
        Store.sharedStore.fetchEvents { [weak self] result in
            switch result {
            case .value(let events, _):
                self?.events = events
                self?.tableView?.reloadData()
                completion?(result)
            case .error(let error):
                print("Hi Bryan!\(error.localizedDescription)")
            }
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.reusableCell() as EventCell
        let event = events[indexPath.row]
        
        cell.titleLabel.text = event.title
        cell.descriptionLabel.text = event.eventDescription
        cell.monthLabel.text = event.monthString
        cell.dateLabel.text = event.dateString
        cell.groupLabel.text = "Ministry Group Example"
        
        return cell
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.count
    }
    
}

