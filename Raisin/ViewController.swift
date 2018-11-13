//
//  ViewController.swift
//  ChatUI
//
//  Created by Wilson Balderrama on 1/2/17.
//  Copyright © 2017 Wilson Balderrama. All rights reserved.
//
import UIKit

import JSQMessagesViewController
import Firebase
import FirebaseDatabase
import FirebaseUI
import SDWebImage

//JSQMessage:User
struct User {
    let id: String
    var name: String
}

class ViewController: JSQMessagesViewController {
    var debug = true
    //user1が使用者側、user2が相手側
    var user1 = User(id: "user", name: "後藤直")
    let user2 = User(id: "mei", name: "メイちゃん")
    
    //上部の３ボタン
    let connectButton       = UIButton(type: UIButtonType.system)
    let captureButton       = UIButton(type: UIButtonType.system)
    let voiceRecogButton    = UIButton(type: UIButtonType.system)
    
    var currentUser: User {
        return user1
    }
    var messages = [JSQMessage]()
}

extension ViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        //上部バーの作成
        makeTopBar()
        //JSQMessage 初期設定
        self.senderId = currentUser.id
        self.senderDisplayName = currentUser.name
        
        //Firebase
        let ref = Database.database().reference()
        ref.observe(.value, with: { snapshot in
            guard let dic = snapshot.value as? Dictionary<String, AnyObject> else {return}
            guard let posts = dic["messages"] as? Dictionary<String, Dictionary<String, AnyObject>> else {return}
            // keyとdateが入ったタプルを作る
            var keyValueArray: [(String, Int)] = []
            for (key, value) in posts {
                keyValueArray.append((key: key, date: value["date"] as! Int))
            }
            // タプルの中のdate でソートしてタプルの順番を揃える(配列で) これでkeyが順番通りになる
            keyValueArray.sort{$0.1 < $1.1}
            // messagesを再構成
            var preMessages = [JSQMessage]()
            for sortedTuple in keyValueArray {
                // 揃えた順番通りにメッセージを作成
                for (key, value) in posts {
                    if key == sortedTuple.0 {
                        self.JSQMessageAppend(preMessages:&preMessages,value: value)
                    }
                }
            }
            self.messages = preMessages
            
            self.collectionView.reloadData()
        })

    }
    func JSQMessageAppend(preMessages:inout [JSQMessage],value:[String:AnyObject]){
        //print(value)
        let senderId = value["senderId"] as! String
        let text = value["text"] as! String
        let displayName = value["displayName"] as! String
        switch value["textType"] as! String{
        case "SysMess":break
        case"Image":
            preMessages.append(JSQMessage(senderId: senderId, displayName: displayName, media: createPhotoItem(url: text, isOutgoing: false)))
        default:
            preMessages.append(JSQMessage(senderId: senderId, displayName: displayName, text: text))
        }
    }
}

extension ViewController {
    //上部バーの作成
    func makeTopBar(){
        let rect1 = UIView()
        rect1.frame = CGRect(x:0,y:0,width:self.view.frame.width,height:50)
        rect1.backgroundColor = UIColor(hex: "e6e6fa")
        self.view.addSubview(rect1)
        connectButton.tag = 1
        captureButton.tag = 2
        voiceRecogButton.tag = 3
        makeTopBarButton(Button: connectButton)
        makeTopBarButton(Button: captureButton)
        makeTopBarButton(Button: voiceRecogButton)
    }
    func makeTopBarButton(Button: UIButton){
         //makeTopBarボタンの初期化
        Button.sizeToFit()
        switch Button.tag {
        case 1:
            Button.setTitle("1", for: UIControlState.normal)
            Button.frame = CGRect(x:self.view.frame.width*0/3,y:20,width:self.view.frame.width/3,height:30)
        case 2:
            Button.setTitle("2", for: UIControlState.normal)
            Button.frame = CGRect(x:self.view.frame.width*1/3,y:20,width:self.view.frame.width/3,height:30)
        case 3:
            Button.setTitle("3", for: UIControlState.normal)
            Button.frame = CGRect(x:self.view.frame.width*2/3,y:20,width:self.view.frame.width/3,height:30)
        default:break
        }
        Button.isEnabled = true
        Button.addTarget(self, action: #selector(buttonUpEvent(_:)), for: UIControlEvents.touchUpInside)
        Button.addTarget(self, action: #selector(buttonPressEvent(_:)), for: UIControlEvents.touchDown)
        Button.layer.borderColor = UIColor.blue.cgColor
        Button.layer.borderWidth = 1
        self.view.addSubview(Button)
    }
    
    //TopBarの各ボタンが押された時
    @objc func buttonPressEvent(_ sender: UIButton) {
        switch sender.tag {
        case 1:break
        case 2://-----------画像要求----------//
           // bleControl.send(Message: "キャプテャ要求")
            firebaseSend(senderId: "mei → goto", text: "image.png", senderDisplayName: "mei → goto", textType: "Image", date:Date() )
        case 3:break
        default:break
        }
    }
    
    //TopBarの各ボタンが離された時
    @objc func buttonUpEvent(_ sender: UIButton) {
        switch sender.tag {
        case 1:break
        case 2:break
        case 3:break
        default:break
        }
    }
    func firebaseSend(senderId:String!,text :String!,senderDisplayName:String!,textType:String!,date:Date!){
        let ref = Database.database().reference()
        ref.child("messages").childByAutoId().setValue(["senderId": senderId, "text": text, "displayName": senderDisplayName, "date": [".sv": "timestamp"] ,"textType" :textType])
    }
    
    //Sendボタンが押された時
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        //Firebaseのデータベースの参照
        firebaseSend(senderId: senderId, text: text, senderDisplayName: senderDisplayName, textType: "Message", date: date)
        //JSQMessage化
        let message = JSQMessage(senderId: user1.id, senderDisplayName: user1.name, date: date, text: text)
        //画面への表示
        messages.append(message!)
        finishSendingMessage()
    }
    //添付ファイルボタンが押された時
    override func didPressAccessoryButton(_ sender: UIButton!) {}
}

//JSQMessageライブラリの表示設定
extension ViewController {
    //時刻表示のための高さ調整
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForCellTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        
        let message = messages[indexPath.item]
        if indexPath.item == 0 {
            return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: message.date)
        }
        if indexPath.item - 1 > 0 {
            let previousMessage = messages[indexPath.item - 1]
            if message.date.timeIntervalSince(previousMessage.date) / 60 > 1 {
                return JSQMessagesTimestampFormatter.shared().attributedTimestamp(for: message.date)
            }
        }
        return nil
    }
    // 送信時刻を出すために高さを調整する
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForCellTopLabelAt indexPath: IndexPath!) -> CGFloat {
        
        if indexPath.item == 0 {
            return kJSQMessagesCollectionViewCellLabelHeightDefault
        }
        if indexPath.item - 1 > 0 {
            let previousMessage = messages[indexPath.item - 1]
            let message = messages[indexPath.item]
            if message.date .timeIntervalSince(previousMessage.date) / 60 > 1 {
                return kJSQMessagesCollectionViewCellLabelHeightDefault
            }
        }
        return 0.0
    }
    //各送信者の表示について
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!)-> NSAttributedString! {
        return NSAttributedString(string: self.messages[indexPath.row].senderDisplayName)
    }
    //各メッセージの高さ
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!,heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        return 15
    }
    //各送信者の表示に画像を使うか
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        //senderId == mei以外　だった場合表示しない
        return messages[indexPath.row].senderId == "mei" ? JSQMessagesAvatarImage.avatar(with: UIImage(named: "meiface")):nil
    }
    
    //各メッセージのテキスト色
    override func collectionView(_ collectionView: UICollectionView,cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        switch messages[indexPath.row].senderId {
        case senderId:
            cell.textView?.textColor = UIColor.white
        case "mei":
            cell.textView?.textColor = UIColor.darkGray
        default:
            cell.textView?.textColor = UIColor.darkGray
        }
        return cell
    }
    
    //各メッセージの背景色
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource! {
        
        let bubbleFactory = JSQMessagesBubbleImageFactory()
        let message = messages[indexPath.row]
        switch message.senderId {
        case currentUser.id:
            return bubbleFactory?.outgoingMessagesBubbleImage(with: UIColor(red: 112/255, green: 192/255, blue:  75/255, alpha: 1))
        case "mei":
            let tmp = message.senderDisplayName.components(separatedBy:" ")
            //print(tmp)
            if(tmp[2] == currentUser.name){
                return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor(red: 112/255, green: 192/255, blue:  75/255, alpha: 1))
            }else{
                return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor(hex: "e6e6fa"))
            }
        default:
            return bubbleFactory?.incomingMessagesBubbleImage(with: UIColor(hex: "e6e6fa"))
        }
    }
    
    //メッセージの総数を取得
    override func collectionView(_ collectionView: UICollectionView,numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    //メッセージの内容参照場所の設定
    override func collectionView(_ collectionView: JSQMessagesCollectionView!,messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData! {
        return messages[indexPath.row]
    }
    //textboxの内容が変化した時
    override func textViewDidChange(_ textView: UITextView) {
        if (textView != self.inputToolbar.contentView.textView) {
            return
        }
        if(debug == true){
        self.inputToolbar.toggleSendButtonEnabled()
        }
    }
    //JSQPhotoMediaItem化
    private func createPhotoItem(url: String, isOutgoing: Bool) -> JSQPhotoMediaItem {
        print("creating photo item url = " + url)
        let photoItem = JSQPhotoMediaItem()
        DispatchQueue.global().async {
           // photoItem.image = self.createImage(url: url)
            self.createImage(url: url){image in
                photoItem.image = image
            }
            DispatchQueue.main.async {
                
                self.collectionView?.reloadData()
            }
        }
        photoItem.appliesMediaViewMaskAsOutgoing = isOutgoing
        return photoItem
    }
    //画像のDL
   // private func createImage(url:String) -> UIImage {
    private func createImage(url:String, completion: @escaping(_ image: UIImage?) -> ()) {
        let storage = Storage.storage()
        let storageRef = storage.reference(forURL: "gs://raisin-95256.appspot.com")
        let reference = storageRef.child(url)
        let placeholderImage = UIImage(named: "placeholder.jpg")
        DispatchQueue.main.async {
            var imageView : UIImageView? = nil
            imageView = UIImageView()
            imageView?.sd_setImage(with: reference, placeholderImage: placeholderImage)
            completion(imageView?.image)
        }
    }
}
extension UIColor {
    convenience init(hex: String, alpha: CGFloat) {
        let v = hex.map { String($0) } + Array(repeating: "0", count: max(6 - hex.count, 0))
        let r = CGFloat(Int(v[0] + v[1], radix: 16) ?? 0) / 255.0
        let g = CGFloat(Int(v[2] + v[3], radix: 16) ?? 0) / 255.0
        let b = CGFloat(Int(v[4] + v[5], radix: 16) ?? 0) / 255.0
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
    convenience init(hex: String) {
        self.init(hex: hex, alpha: 1.0)
    }
}

