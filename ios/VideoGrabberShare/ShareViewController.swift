import UIKit

/// Esqueleto da Fase 2. Na Fase 6 lê a URL compartilhada, grava no App Group e abre o app.
final class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
