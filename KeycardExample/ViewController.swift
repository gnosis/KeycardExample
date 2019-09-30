//
//  ViewController.swift
//  KeycardExample
//
//  Created by Dmitry Bespalov on 03.09.19.
//  Copyright © 2019 Gnosis Ltd. All rights reserved.
//

import UIKit
import CoreNFC
import Keycard

class TableViewController: UITableViewController {

    var actions: [Action] = []

    var keycardController: KeycardController?

    override func viewDidLoad() {
        super.viewDidLoad()

        actions = [
            Action(name: "Select", closure: { [unowned self] in self.select() }),
            Action(name: "Initialize", closure: { [unowned self] in self.initialize() }),
        ]

        DispatchQueue.main.async {
            if !KeycardController.isAvailable {
                let alertController = UIAlertController(
                    title: "Scanning Not Supported",
                    message: "This device doesn't support tag scanning. The functionality is disabled.",
                    preferredStyle: .alert
                )
                alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self.present(alertController, animated: true, completion: nil)
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return actions.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Action", for: indexPath)
        let action = actions[indexPath.row]
        cell.textLabel?.text = action.name
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let action = actions[indexPath.row]
        action.closure()
    }

    func select() {
        keycardController = KeycardController(onConnect: { [unowned self] channel in
            do {
                let cmdSet = KeycardCommandSet(cardChannel: channel)
                let info = try ApplicationInfo(cmdSet.select().checkOK().data)
                print(info)
                self.keycardController?.stop(alertMessage: "Success")
            } catch {
                print("Error: \(error)")
                self.keycardController?.stop(errorMessage: "Read error. Please try again.")
            }
            self.keycardController = nil
        }, onFailure: { [unowned self] error in
            print("Disconnected: \(error)")
            self.keycardController = nil
        })
        keycardController?.start(alertMessage: "Hold your iPhone near a Status Keycard.")
    }

    func initialize() {
        let initializeAction: (String, String, String) -> Void = { [unowned self] pin, puk, pass in
            self.keycardController = KeycardController(onConnect: { [unowned self] channel in
                do {
                    let cmdSet = KeycardCommandSet(cardChannel: channel)
                    try cmdSet.select().checkOK()
                    try cmdSet.initialize(pin: pin, puk: puk, pairingPassword: pass).checkOK()
                    self.keycardController?.stop(alertMessage: "Success")
                } catch {
                    self.keycardController?.stop(errorMessage: "Read error. Please try again.")
                    self.present(string: "Error: \(error)")
                }
                self.keycardController = nil
            }, onFailure: { [unowned self] error in
                print("Disconnected: \(error)")
                self.keycardController = nil
            })
            self.keycardController?.start(alertMessage: "Hold your iPhone near a Status Keycard.")
        }

        let inputAlert = UIAlertController(
            title: "Input",
            message: "Please enter required information",
            preferredStyle: .alert)
        inputAlert.addTextField { field in
            field.placeholder = "PIN (6 digits)"
            field.keyboardType = .numberPad
        }
        inputAlert.addTextField { field in
            field.placeholder = "PUK (12 digits)"
            field.keyboardType = .numberPad
        }
        inputAlert.addTextField { field in
            field.placeholder = "Pairing Password"
        }
        inputAlert.addAction(UIAlertAction(title: "Initialize", style: .default, handler: { [unowned inputAlert] action in
            guard let pin = inputAlert.textFields?[0].text,
                let puk = inputAlert.textFields?[1].text,
                let pass = inputAlert.textFields?[2].text else {
                    return
            }
            let memo = """
            PIN: \(pin)
            PUK: \(puk)
            Pairing Password: \(pass)
            """
            UIPasteboard.general.string = memo
            initializeAction(pin, puk, pass)
        }))
        inputAlert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(inputAlert, animated: true, completion: nil)
    }

    func present(string: String) {
        if !Thread.isMainThread {
            DispatchQueue.main.async { self.present(string: string) }
            return
        }
        let alertController = UIAlertController(
            title: "Result",
            message: string,
            preferredStyle: .alert
        )
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }

}

struct Action {
    var name: String
    var closure: () -> Void
}
