//
//  ViewController.swift
//  CobyTalk
//
//  Created by Coby Kim on 2022/10/30.
//

import UIKit

import FirebaseAuth
import FirebaseFirestore
import SnapKit
import Then
import MessageUI

final class ChatViewController: BaseViewController {
    
    private var name: String
    private var fromId: String
    private var toId: String
    
    private var chatMessages = [ChatMessage]()
    
    private var currentUser: User?
    private var chatUser: User?
    private var chatUserProfileImage: UIImage?
    
    private var firestoreListener: ListenerRegistration?
    
    init(name: String, fromId: String, toId: String) {
        self.name = name
        self.fromId = fromId
        self.toId = toId
        super.init(nibName: nil, bundle: nil)
        
        title = name
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private lazy var chatTableView = UITableView().then {
        $0.register(ChatTableViewCell.self, forCellReuseIdentifier: ChatTableViewCell.className)
        $0.register(MyChatTableViewCell.self, forCellReuseIdentifier: MyChatTableViewCell.className)
        $0.delegate = self
        $0.dataSource = self
        
        $0.separatorStyle = .none
    }
    
    private lazy var chatSendView = ChatSendView().then {
        $0.chatSendbutton.addTarget(self, action: #selector(didTapChatSendbutton), for: .touchUpInside)
    }

    private lazy var reportButton = ReportButton().then {
        $0.addTarget(self, action: #selector(didTapReportButton), for: .touchUpInside)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        hidekeyboardWhenTappedAroundExceptSendView()
        fetchData()
        setupRightNavigationBarItem(with: reportButton)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        tabBarController?.tabBar.isHidden = true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tabBarController?.tabBar.isHidden = false
    }
    
    override func render() {
        view.addSubviews(chatSendView, chatTableView)
        
        chatSendView.snp.makeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(5)
        }
        
        chatTableView.snp.makeConstraints {
            $0.top.leading.trailing.equalToSuperview()
            $0.bottom.equalTo(chatSendView.snp.top).offset(-10)
        }
    }
    
    private func fetchData() {
        Task { [weak self] in
            self?.currentUser = await FirebaseManager.shared.getUser()
            self?.chatUser = await FirebaseManager.shared.getUserWithId(id: toId)
            getChatUserProfileImage()
        }
        getChatMessages()
    }
    
    private func getChatUserProfileImage() {
        DispatchQueue.global().async { [weak self] in
            if let chatUser = self?.chatUser {
                let imageUrl = chatUser.profileImageUrl
                
                FirebaseManager.shared.downloadImage(at: imageUrl) { image in
                    guard let image = image else { return }
                    self?.chatUserProfileImage = image
                }
            }
        }
    }
    
    private func getChatMessages() {
        let firestoreReference = FirebaseManager.shared.firestore
            .collection("messages")
            .document(fromId)
            .collection(toId)
            .order(by: "timestamp")
        
        firestoreListener = firestoreReference.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }
            guard let snapshot = querySnapshot else {
                print("Error listening for ChatMessages: \(error?.localizedDescription ?? "No error")")
                return
            }
            
            snapshot.documentChanges.forEach { change in
                self.handleDocumentChange(change)
            }
        }
    }
    
    private func addChatMessageToTable(_ chatMessage: ChatMessage) {
        let docId = chatMessage.id
        
        if chatMessages.contains(where: { $0.id == docId }) { return }
        chatMessages.append(chatMessage)
        
        guard let index = chatMessages.firstIndex(where: { $0.id == docId }) else { return }
        
        chatTableView.insertRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }
    
    private func updateChatMessageInTable(_ chatMessage: ChatMessage) {
        let docId = chatMessage.id
        guard let index = chatMessages.firstIndex(where: { $0.id == docId }) else { return }
        
        chatMessages[index] = chatMessage
        chatTableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }
    
    private func removeChatMessageFromTable(_ chatMessage: ChatMessage) {
        let docId = chatMessage.id
        guard let index = chatMessages.firstIndex(where: { $0.id == docId }) else { return }
        
        chatMessages.remove(at: index)
        chatTableView.deleteRows(at: [IndexPath(row: index, section: 0)], with: .automatic)
    }
    
    private func handleDocumentChange(_ change: DocumentChange) {
        guard let chatMessage = try? change.document.data(as: ChatMessage.self) else {
            return
        }
        
        switch change.type {
        case .added:
            addChatMessageToTable(chatMessage)
        case .modified:
            updateChatMessageInTable(chatMessage)
        case .removed:
            removeChatMessageFromTable(chatMessage)
        }
        
        scrollToBottom()
    }
    
    private func scrollToBottom() {
        DispatchQueue.main.async {
            let index = self.chatMessages.count - 1
            if index >= 0 {
                let indexPath = IndexPath(row: index, section: 0)
                self.chatTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
            }
        }
    }
    
    @objc private func didTapChatSendbutton() {
        guard let currentUser = currentUser, let chatUser = chatUser else { return }
        guard chatSendView.chatTextField.text != "", let chatText = chatSendView.chatTextField.text else { return }
        
        FirebaseManager.shared.createChatMessage(currentUser: currentUser, chatUser: chatUser, chatText: chatText)
        PushNotificationSender().sendPushNotification(to: chatUser.token, title: currentUser.name, body: chatText)
        chatSendView.chatTextField.text = ""
    }
    
    @objc override func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue {
            chatSendView.snp.remakeConstraints {
                $0.leading.trailing.equalToSuperview().inset(10)
                $0.bottom.equalToSuperview().inset(keyboardSize.height + 5)
            }
            
            scrollToBottom()
        }
    }

    @objc override func keyboardWillHide(notification: NSNotification) {
        chatSendView.snp.remakeConstraints {
            $0.leading.trailing.equalToSuperview().inset(10)
            $0.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).inset(5)
        }
        
        scrollToBottom()
    }

    @objc private func didTapReportButton() {
        let recheckAlert = UIAlertController(title: "신고하시겠어요?", message: "이 유저를 신고하시게 된 사유에 대해서 자세히 말씀해주세요.", preferredStyle: .actionSheet)
        let confirm = UIAlertAction(title: "신고", style: .default) { _ in
            self.sendReportMail(userName: UserDefaults.standard.string(forKey: "userName"))
        }
        let cancel = UIAlertAction(title: "취소", style: .destructive, handler: nil)

        recheckAlert.addAction(confirm)
        recheckAlert.addAction(cancel)
        present(recheckAlert, animated: true, completion: nil)
    }
    
    func hidekeyboardWhenTappedAroundExceptSendView() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tap.cancelsTouchesInView = false
        chatTableView.addGestureRecognizer(tap)
    }
}

extension ChatViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return chatMessages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if chatMessages[indexPath.row].fromId == fromId {
            let cell = tableView.dequeueReusableCell(withIdentifier: MyChatTableViewCell.className, for: indexPath) as! MyChatTableViewCell

            cell.chatLabel.text = chatMessages[indexPath.row].text
            cell.chatLabel.preferredMaxLayoutWidth = 250
            cell.selectionStyle = .none
            
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: ChatTableViewCell.className, for: indexPath) as! ChatTableViewCell
            
            cell.chatLabel.text = chatMessages[indexPath.row].text
            cell.chatLabel.preferredMaxLayoutWidth = 220
            cell.selectionStyle = .none
            
            return cell
        }
    }
}

extension ChatViewController: MFMailComposeViewControllerDelegate {

    func sendReportMail(userName: String?) {
        if MFMailComposeViewController.canSendMail() {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            let currentDateString = formatter.string(from: Date())
            let composeViewController = MFMailComposeViewController()
            let dimeEmail = "haptic_04_minis@icloud.com"

            let messageBody = """
                                   -----------------------------
                                   - 신고자: \(String(describing: userName ?? "UNKNOWN"))
                                   - 신고일시: \(currentDateString)
                                   ------------------------------
                                   - 신고사유




                                   """
            composeViewController.mailComposeDelegate = self
            composeViewController.setToRecipients([dimeEmail])
            composeViewController.setSubject("")
            composeViewController.setMessageBody(messageBody, isHTML: false)
            self.present(composeViewController, animated: true, completion: nil)
        }
        else {
            showSendMailErrorAlert()
        }
    }

    func showSendMailErrorAlert() {
        let sendMailErrorAlert = UIAlertController(title: "메일 전송 실패", message: "아이폰 이메일 설정을 확인하고 다시 시도해주세요.", preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "확인", style: .default) {
            (action) in
            print("확인")
        }
        sendMailErrorAlert.addAction(confirmAction)
        self.present(sendMailErrorAlert, animated: true, completion: nil)
    }

    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true, completion: nil)
    }
}
